import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speedmart_lanka/core/theme/app_colors.dart';
import 'package:speedmart_lanka/core/theme/app_text_styles.dart';
import 'package:speedmart_lanka/features/auth/providers/auth_provider.dart';
import 'package:speedmart_lanka/core/routes/route_names.dart';
import 'package:speedmart_lanka/features/orders/models/order_model.dart';
import 'package:speedmart_lanka/features/orders/providers/order_provider.dart';
import 'package:speedmart_lanka/features/proposals/models/proposal.dart';
import 'package:speedmart_lanka/features/proposals/providers/proposal_provider.dart';
import 'package:speedmart_lanka/features/requests/models/shopping_request.dart';
import 'package:speedmart_lanka/features/requests/models/request_category_fulfillment.dart';
import 'package:speedmart_lanka/features/requests/providers/request_provider.dart';
import 'package:speedmart_lanka/features/requests/data/mock_request_repository.dart';
import 'package:speedmart_lanka/features/notifications/models/notification_type.dart';
import 'package:speedmart_lanka/features/notifications/providers/notification_provider.dart' as notification_feature;
import 'package:speedmart_lanka/features/payments/models/payment.dart';
import 'package:speedmart_lanka/features/payments/providers/payment_provider.dart';

class AcceptedVendorGroup {
  final Proposal proposal;
  final List<ProposalItem> acceptedItems;
  final bool waveDeliveryCharge;
  final double commissionRate;

  AcceptedVendorGroup({
    required this.proposal,
    required this.acceptedItems,
    this.waveDeliveryCharge = false,
    this.commissionRate = 0.0,
  });

  double get subtotal => acceptedItems.fold<double>(0.0, (sum, item) => sum + item.subtotal);
  double get deliveryCharge => waveDeliveryCharge ? 0.0 : proposal.deliveryCharge;
  double get platformCommission => (subtotal + deliveryCharge) * commissionRate;
  double get customerAmount => proposal.totalPrice; // What customer pays (includes any admin-set commission already folded into proposal total)
  double get vendorNetAmount => customerAmount - platformCommission; // Vendor net receipt after hidden platform fee
}

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({
    super.key,
    required this.proposal,
    required this.requestId,
  });

  final Proposal proposal;
  final String requestId;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;

  PaymentMethod _selectedMethod = PaymentMethod.cashOnDelivery;

  // Card controllers
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();
  final _cardNameController = TextEditingController();

  bool _isProcessing = false;
  ShoppingRequest? _request;
  String? _missingAddressError;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);

    // Look up the corresponding request to find the delivery address
    final requestsState = ref.read(requestProvider);
    try {
      _request = requestsState.requests.firstWhere(
        (r) => r.id == widget.requestId,
        orElse: () => requestsState.nearbyRequests.firstWhere(
          (r) => r.id == widget.requestId,
        ),
      );
    } catch (_) {}

    // Block payment if no delivery address
    if (_request == null || (_request!.deliveryAddress.trim().isEmpty && _request!.deliveryLocation == null)) {
      _missingAddressError = 'Delivery address missing. Please update your request delivery address.';
    }

    final initialPhone = _request?.customerPhone ?? user?.phone ?? '';
    _phoneController = TextEditingController(text: initialPhone);

    _phoneController.addListener(() {
      setState(() {});
    });

    // Load customer orders to determine waived delivery fees
    Future.microtask(() {
      ref.read(orderProvider.notifier).loadCustomerOrders();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _cardNameController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirmPayment(List<AcceptedVendorGroup> groups) async {
    if (_isProcessing) return;

    // Block if no delivery address
    if (_missingAddressError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_missingAddressError!), backgroundColor: Colors.red),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_request == null) return;

    final customer = ref.read(currentUserProvider);
    if (customer == null) return;

    if (_selectedMethod == PaymentMethod.bankTransfer || _selectedMethod == PaymentMethod.cardPlaceholder) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This payment method is a placeholder in mock mode.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final double customerLat = _request!.latitude;
      final double customerLng = _request!.longitude;
      final deliveryAddress = _request!.deliveryAddress.isNotEmpty
          ? _request!.deliveryAddress
          : (_request!.deliveryLocation?.streetAddress ?? '');

      OrderModel? firstOrder;
      PaymentModel? firstPayment;

      final updatedFulfillments = Map<String, RequestCategoryFulfillment>.from(_request!.categoryFulfillments);

      for (final group in groups) {
        final subtotal = group.subtotal;
        final deliveryFee = group.deliveryCharge;
        final platformCommission = group.platformCommission;
        final customerAmount = group.customerAmount;
        final vendorNetAmount = group.vendorNetAmount;
        final ts = DateTime.now().millisecondsSinceEpoch;
        final groupIndex = groups.indexOf(group);
        final receiptNumber = 'RCPT-${ts.toString().substring(7)}-$groupIndex';
        final transactionReference = _selectedMethod == PaymentMethod.mockOnline
            ? 'MOCK-$ts-$groupIndex'
            : 'COD-$ts-$groupIndex';

        debugPrint('[PaymentAudit] ===== PAYMENT CREATION (Group: ${group.proposal.vendorBusinessName}) =====');
        debugPrint('[PaymentAudit] Subtotal (items): $subtotal');
        debugPrint('[PaymentAudit] Delivery fee: $deliveryFee');
        debugPrint('[PaymentAudit] Platform commission (0% - no service fee): $platformCommission');
        debugPrint('[PaymentAudit] Customer pays: $customerAmount');
        debugPrint('[PaymentAudit] Vendor receives: $vendorNetAmount');

        // Only mark the proposal accepted after the customer has actually confirmed payment.
        if (group.proposal.status != ProposalStatus.accepted) {
          await ref.read(proposalProvider.notifier).acceptProposal(
                group.proposal.id,
                widget.requestId,
              );
        }

        final pendingPayment = PaymentModel(
          id: '',
          orderId: '',
          customerId: customer.id,
          vendorId: group.proposal.vendorId,
          vendorBusinessName: group.proposal.vendorBusinessName,
          proposalId: group.proposal.id,
          amount: customerAmount,
          subtotal: subtotal,
          deliveryFee: deliveryFee,
          serviceFee: platformCommission,
          platformCommission: platformCommission,
          vendorNetAmount: vendorNetAmount,
          paymentMethod: _selectedMethod,
          paymentStatus: PaymentStatus.pending,
          createdAt: DateTime.now(),
          transactionReference: transactionReference,
          receiptNumber: receiptNumber,
        );

        PaymentModel createdPayment = await ref.read(paymentProvider.notifier).createPayment(pendingPayment);
        PaymentModel finalPayment = createdPayment;

        if (_selectedMethod == PaymentMethod.mockOnline) {
          await Future.delayed(const Duration(seconds: 1));
          finalPayment = await ref.read(paymentProvider.notifier).markPaid(createdPayment.id) ?? createdPayment;
        }

        final order = OrderModel(
          id: '',
          proposalId: group.proposal.id,
          requestId: widget.requestId,
          customerId: customer.id,
          vendorId: group.proposal.vendorId,
          vendorBusinessName: group.proposal.vendorBusinessName,
          vendorPhone: '+94 77 555 4321',
          customerName: customer.fullName,
          customerPhone: _phoneController.text,
          deliveryAddress: deliveryAddress,
          customerProvince: _request!.deliveryLocation?.province ?? '',
          customerDistrict: _request!.deliveryLocation?.district ?? '',
          customerCity: _request!.deliveryLocation?.city ?? '',
          customerSuburb: _request!.deliveryLocation?.suburb ?? _request!.customerArea,
          customerFormattedAddress:
              _request!.deliveryLocation?.formattedAddress.isNotEmpty == true
                  ? _request!.deliveryLocation!.formattedAddress
                  : _request!.customerArea,
          items: group.acceptedItems,
          deliveryCharge: deliveryFee,
          totalPrice: customerAmount,
          paymentId: finalPayment.id,
          paymentMethod: _selectedMethod,
          paymentStatus: finalPayment.paymentStatus,
          isAddressReleased: true,
          addressReleasedAt: DateTime.now(),
          status: OrderStatus.accepted,
          createdAt: DateTime.now(),
          vendorLatitude: group.proposal.vendorLatitude,
          vendorLongitude: group.proposal.vendorLongitude,
          customerLatitude: customerLat,
          customerLongitude: customerLng,
          accuracy: _request!.deliveryLocation?.accuracy,
          detectedAt: _request!.deliveryLocation?.detectedAt,
          commissionRate: group.commissionRate,
        );

        final createdOrder = await ref.read(orderProvider.notifier).placeOrder(
          order,
          updateRequestStatus: groupIndex == 0,
        );
        finalPayment = await ref.read(paymentProvider.notifier).assignOrderId(createdPayment.id, createdOrder.id) ?? finalPayment;

        if (firstOrder == null) {
          firstOrder = createdOrder;
          firstPayment = finalPayment;
        }

        // Send Notifications
        if (_selectedMethod == PaymentMethod.mockOnline) {
          await ref.read(notification_feature.notificationProvider.notifier).createNotification(
            type: NotificationType.orderStatusUpdated,
            title: 'Payment Confirmed',
            body: 'Payment for order ${createdOrder.id} has been confirmed.',
            userId: group.proposal.vendorId,
            relatedId: createdOrder.id,
          );
        } else {
          await ref.read(notification_feature.notificationProvider.notifier).createNotification(
            type: NotificationType.cashOnDeliveryConfirmed,
            title: 'COD Order Confirmed',
            body: 'Customer confirmed COD for order ${createdOrder.id}.',
            userId: group.proposal.vendorId,
            relatedId: createdOrder.id,
          );
        }

        // Update category fulfillment based on payment method
        if (group.proposal.categoryNormalized != null && group.proposal.categoryNormalized!.isNotEmpty) {
          final category = group.proposal.categoryNormalized!;
          final currentFulfillment = updatedFulfillments[category];
          
          if (currentFulfillment != null) {
            if (_selectedMethod == PaymentMethod.cashOnDelivery) {
              updatedFulfillments[category] = currentFulfillment.copyWith(
                status: RequestCategoryStatus.codConfirmed,
                codConfirmedAt: DateTime.now(),
              );
            } else if (_selectedMethod == PaymentMethod.mockOnline) {
              updatedFulfillments[category] = currentFulfillment.copyWith(
                status: RequestCategoryStatus.paid,
                paidAt: DateTime.now(),
              );
            }
          }
        }
      }

      final updatedRequest = _request!.copyWith(
        categoryFulfillments: updatedFulfillments,
        updatedAt: DateTime.now(),
      );
      
      await ref.read(requestProvider.notifier).updateRequest(updatedRequest);

      // Create notifications for customer
      if (firstOrder != null) {
        if (_selectedMethod == PaymentMethod.mockOnline) {
          await ref.read(notification_feature.notificationProvider.notifier).createNotification(
            type: NotificationType.receiptGenerated,
            title: 'Receipt Generated',
            body: 'Your payment was successful and receipt is ready.',
            userId: customer.id,
            relatedId: firstOrder.id,
          );
        } else {
          await ref.read(notification_feature.notificationProvider.notifier).createNotification(
            type: NotificationType.receiptGenerated,
            title: 'COD Receipt Ready',
            body: 'Your COD order has been confirmed successfully.',
            userId: customer.id,
            relatedId: firstOrder.id,
          );
        }
      }

      await ref.read(orderProvider.notifier).loadCustomerOrders();
      await ref.read(paymentProvider.notifier).loadCustomerPayments();

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      if (firstOrder != null && firstPayment != null) {
        context.pushReplacement(RouteNames.customerPaymentReceipt, extra: {
          'order': firstOrder,
          'payment': firstPayment,
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      final failedCustomer = ref.read(currentUserProvider);
      if (failedCustomer != null) {
        await ref.read(notification_feature.notificationProvider.notifier).createNotification(
          type: NotificationType.paymentFailed,
          title: 'Payment Failed',
          body: 'Your payment attempt for the selected proposals failed. Please try again.',
          userId: failedCustomer.id,
          relatedId: widget.proposal.id,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    // If no delivery address, show error and block payment
    if (_missingAddressError != null) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        appBar: AppBar(
          title: const Text('Checkout & Payment'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_off_rounded, size: 64, color: Colors.red.withOpacity(0.6)),
                const SizedBox(height: 16),
                Text(
                  _missingAddressError!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium(primaryText),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Update Delivery Address'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_request == null) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        appBar: AppBar(
          title: const Text('Checkout & Payment'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Build the accepted groups per vendor
    final proposals = ref.watch(proposalProvider).proposals;
    final customerOrders = ref.watch(orderProvider).orders;
    final acceptedGroups = <AcceptedVendorGroup>[];
    
    // Check if there are any explicitly accepted items across any proposal for this request
    bool hasExplicitAcceptedItems = false;
    for (final p in proposals) {
      if (p.requestId == widget.requestId && p.items.any((i) => i.customerDecision == ProposalItemDecision.accepted)) {
        hasExplicitAcceptedItems = true;
        break;
      }
    }

    bool checkWaveDeliveryCharge(Proposal proposal) {
      final existingOrdersForVendor = customerOrders.where((o) =>
          o.requestId == widget.requestId &&
          o.vendorId == proposal.vendorId &&
          o.status != OrderStatus.cancelled).toList();

      if (existingOrdersForVendor.isNotEmpty) {
        final hasDispatchedOrder = existingOrdersForVendor.any((o) =>
            o.status == OrderStatus.outForDelivery ||
            o.status == OrderStatus.delivered ||
            o.status == OrderStatus.completed);
        if (!hasDispatchedOrder) {
          return true;
        }
      }
      return false;
    }

    for (final p in proposals) {
      if (p.requestId != widget.requestId) continue;
      
      final List<ProposalItem> items;
      if (hasExplicitAcceptedItems) {
        items = p.items.where((i) => i.customerDecision == ProposalItemDecision.accepted).toList();
      } else {
        if (p.status == ProposalStatus.accepted || p.id == widget.proposal.id) {
          items = p.items.where((i) => i.status != ProposalItemStatus.unavailable).toList();
        } else {
          items = [];
        }
      }

      if (items.isNotEmpty) {
        final rate = ref.watch(vendorCommissionRateProvider(p.vendorId));
        acceptedGroups.add(AcceptedVendorGroup(
          proposal: p,
          acceptedItems: items,
          waveDeliveryCharge: checkWaveDeliveryCharge(p),
          commissionRate: rate,
        ));
      }
    }

    if (acceptedGroups.isEmpty) {
      final rate = ref.watch(vendorCommissionRateProvider(widget.proposal.vendorId));
      acceptedGroups.add(AcceptedVendorGroup(
        proposal: widget.proposal,
        acceptedItems: widget.proposal.items.where((i) => i.status != ProposalItemStatus.unavailable).toList(),
        waveDeliveryCharge: checkWaveDeliveryCharge(widget.proposal),
        commissionRate: rate,
      ));
    }

    final grandTotal = acceptedGroups.fold<double>(0.0, (sum, g) => sum + g.customerAmount);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Checkout & Payment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.customerColor),
                  SizedBox(height: 16),
                  Text('Processing Payment securely...', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Delivery Details Section (Read-only)
                    Text('Delivery Details', style: AppTextStyles.h2(primaryText)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Approximate Area (Read-only)
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded, color: AppColors.customerColor, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Approximate Area', style: AppTextStyles.labelMedium(secondaryText)),
                                    const SizedBox(height: 4),
                                    Text(
                                      _request!.deliveryLocation?.approximateAreaText.isNotEmpty == true
                                          ? _request!.deliveryLocation!.approximateAreaText
                                          : _request!.customerArea,
                                      style: AppTextStyles.bodyMedium(primaryText),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // District (Read-only)
                          Row(
                            children: [
                              Icon(Icons.public_rounded, color: AppColors.customerColor, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('District', style: AppTextStyles.labelMedium(secondaryText)),
                                    const SizedBox(height: 4),
                                    Text(
                                      _request!.deliveryLocation?.district.isNotEmpty == true
                                          ? _request!.deliveryLocation!.district
                                          : 'Not specified',
                                      style: AppTextStyles.bodyMedium(primaryText),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Full Address (Read-only)
                          if (_request!.deliveryAddress.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(Icons.home_rounded, color: AppColors.customerColor, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Precise Street Address', style: AppTextStyles.labelMedium(secondaryText)),
                                      const SizedBox(height: 4),
                                      Text(
                                        _request!.deliveryAddress,
                                        style: AppTextStyles.bodyMedium(primaryText),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Delivery Note (if available)
                          if (_request!.deliveryLocation?.deliveryNote.isNotEmpty == true) ...[
                            Row(
                              children: [
                                Icon(Icons.note_rounded, color: AppColors.customerColor, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Delivery Note', style: AppTextStyles.labelMedium(secondaryText)),
                                      const SizedBox(height: 4),
                                      Text(
                                        _request!.deliveryLocation!.deliveryNote,
                                        style: AppTextStyles.bodySmall(primaryText),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Contact Phone Number (Editable)
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Contact Phone Number',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.phone_outlined),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Enter contact number';
                              return null;
                            },
                          ),

                          const SizedBox(height: 8),
                          Text(
                            'Your exact address is shared with vendors only after order confirmation.',
                            style: AppTextStyles.caption(secondaryText),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Payment Method Section
                    Text('Choose Payment Method', style: AppTextStyles.h2(primaryText)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<PaymentMethod>(
                            title: Row(
                              children: [
                                const Icon(Icons.local_shipping_outlined, color: AppColors.customerColor),
                                const SizedBox(width: 12),
                                Text('Cash on Delivery (COD)', style: AppTextStyles.bodyMedium(primaryText)),
                              ],
                            ),
                            value: PaymentMethod.cashOnDelivery,
                            groupValue: _selectedMethod,
                            activeColor: AppColors.customerColor,
                            onChanged: (val) {
                              setState(() {
                                _selectedMethod = val!;
                              });
                            },
                          ),
                          const Divider(height: 1),
                          RadioListTile<PaymentMethod>(
                            title: Row(
                              children: [
                                const Icon(Icons.payment_outlined, color: AppColors.customerColor),
                                const SizedBox(width: 12),
                                Text('Mock Online Payment', style: AppTextStyles.bodyMedium(primaryText)),
                              ],
                            ),
                            value: PaymentMethod.mockOnline,
                            groupValue: _selectedMethod,
                            activeColor: AppColors.customerColor,
                            onChanged: (val) {
                              setState(() {
                                _selectedMethod = val!;
                              });
                            },
                          ),
                          const Divider(height: 1),
                          RadioListTile<PaymentMethod>(
                            title: Row(
                              children: [
                                const Icon(Icons.account_balance_outlined, color: AppColors.customerColor),
                                const SizedBox(width: 12),
                                Text('Bank Transfer (Placeholder)', style: AppTextStyles.bodyMedium(primaryText)),
                              ],
                            ),
                            value: PaymentMethod.bankTransfer,
                            groupValue: _selectedMethod,
                            activeColor: AppColors.customerColor,
                            onChanged: (val) {
                              setState(() {
                                _selectedMethod = val!;
                              });
                            },
                          ),
                          const Divider(height: 1),
                          RadioListTile<PaymentMethod>(
                            title: Row(
                              children: [
                                const Icon(Icons.credit_card_outlined, color: AppColors.customerColor),
                                const SizedBox(width: 12),
                                Text('Card Payment (Placeholder)', style: AppTextStyles.bodyMedium(primaryText)),
                              ],
                            ),
                            value: PaymentMethod.cardPlaceholder,
                            groupValue: _selectedMethod,
                            activeColor: AppColors.customerColor,
                            onChanged: (val) {
                              setState(() {
                                _selectedMethod = val!;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Card Fields (Conditional)
                    if (_selectedMethod == PaymentMethod.cardPlaceholder) ...[
                      Text('Card Information', style: AppTextStyles.h2(primaryText)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _cardNumberController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Card Number',
                                hintText: 'xxxx xxxx xxxx xxxx',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) return 'Enter card number';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _cardExpiryController,
                                    decoration: InputDecoration(
                                      labelText: 'Expiry Date',
                                      hintText: 'MM/YY',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.isEmpty) return 'Enter expiry';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _cardCvvController,
                                    keyboardType: TextInputType.number,
                                    obscureText: true,
                                    decoration: InputDecoration(
                                      labelText: 'CVV',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.isEmpty) return 'Enter CVV';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _cardNameController,
                              decoration: InputDecoration(
                                labelText: 'Cardholder Name',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) return 'Enter cardholder name';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Pricing breakdown card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Order Summary', style: AppTextStyles.subtitle(primaryText).copyWith(fontWeight: FontWeight.bold)),
                          const Divider(height: 20),
                          ...acceptedGroups.map((group) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.proposal.vendorBusinessName,
                                    style: AppTextStyles.bodyMedium(primaryText).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  _summaryRow('  Subtotal (${group.acceptedItems.length} items)', 'Rs. ${group.subtotal.toStringAsFixed(2)}', primaryText),
                                  const SizedBox(height: 4),
                                  _summaryRow('  Delivery Fee', 'Rs. ${group.deliveryCharge.toStringAsFixed(2)}', primaryText),
                                  const SizedBox(height: 4),
                                  _summaryRow('  Vendor Total', 'Rs. ${group.customerAmount.toStringAsFixed(2)}', primaryText),
                                  const Divider(height: 12),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          _summaryRow(
                            'Grand Total',
                            'Rs. ${grandTotal.toStringAsFixed(2)}',
                            AppColors.customerColor,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.customerColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: _isProcessing ? null : () => _handleConfirmPayment(acceptedGroups),
                        child: Text(
                          _selectedMethod == PaymentMethod.cashOnDelivery
                              ? 'Confirm Cash on Delivery'
                              : _selectedMethod == PaymentMethod.mockOnline
                                  ? 'Confirm & Pay Mock Online'
                                  : 'Placeholder payment method',
                          style: AppTextStyles.button(Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  /// Helper widget for displaying a row in the order summary.
  Widget _summaryRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMedium(color)),
        Text(value, style: AppTextStyles.subtitle(color).copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

