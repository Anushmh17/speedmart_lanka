import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_state_widgets.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../requests/models/shopping_request.dart';
import '../../../requests/providers/request_provider.dart';
import '../../models/proposal.dart';
import '../../providers/proposal_provider.dart';
import '../../../../core/providers/notification_provider.dart';

class ProposalCreateScreen extends ConsumerStatefulWidget {
  const ProposalCreateScreen({super.key, required this.request});
  final ShoppingRequest request;

  @override
  ConsumerState<ProposalCreateScreen> createState() => _ProposalCreateScreenState();
}

class _ProposalCreateScreenState extends ConsumerState<ProposalCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _deliveryChargeController = TextEditingController(text: '200');
  final _deliveryTimeController = TextEditingController(text: 'Within 2 hours');

  // Track availability state for each item by index/id
  // Key: item index/id, Value: ProposalItemStatus
  late Map<String, ProposalItemStatus> _itemStatuses;
  late Map<String, TextEditingController> _priceControllers;
  late Map<String, TextEditingController> _remarkControllers;
  
  // Alternative item controllers
  late Map<String, TextEditingController> _altNameControllers;
  late Map<String, TextEditingController> _altBrandControllers;
  late Map<String, TextEditingController> _altReasonControllers;

  double _itemsTotal = 0.0;
  double _deliveryCharge = 200.0;

  @override
  void initState() {
    super.initState();
    _itemStatuses = {};
    _priceControllers = {};
    _remarkControllers = {};
    _altNameControllers = {};
    _altBrandControllers = {};
    _altReasonControllers = {};

    for (final item in widget.request.items) {
      _itemStatuses[item.id] = ProposalItemStatus.available;
      _priceControllers[item.id] = TextEditingController(text: '100');
      _remarkControllers[item.id] = TextEditingController();
      _altNameControllers[item.id] = TextEditingController(text: '${item.name} Alternative');
      _altBrandControllers[item.id] = TextEditingController();
      _altReasonControllers[item.id] = TextEditingController(text: 'Original brand out of stock.');
    }

    _calculateTotal();

    _deliveryChargeController.addListener(() {
      setState(() {
        _deliveryCharge = double.tryParse(_deliveryChargeController.text) ?? 0.0;
      });
    });
  }

  @override
  void dispose() {
    _deliveryChargeController.dispose();
    _deliveryTimeController.dispose();
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    for (final controller in _remarkControllers.values) {
      controller.dispose();
    }
    for (final controller in _altNameControllers.values) {
      controller.dispose();
    }
    for (final controller in _altBrandControllers.values) {
      controller.dispose();
    }
    for (final controller in _altReasonControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _calculateTotal() {
    double total = 0.0;
    for (final item in widget.request.items) {
      final status = _itemStatuses[item.id];
      if (status == ProposalItemStatus.available || status == ProposalItemStatus.alternative) {
        final price = double.tryParse(_priceControllers[item.id]?.text ?? '0') ?? 0.0;
        total += price * item.quantity;
      }
    }
    setState(() {
      _itemsTotal = total;
    });
  }

  Future<void> _submitProposal() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final proposalItems = <ProposalItem>[];
    final missingItemIds = <String>[];

    for (final item in widget.request.items) {
      final status = _itemStatuses[item.id]!;
      if (status == ProposalItemStatus.unavailable) {
        missingItemIds.add(item.id);
        proposalItems.add(
          ProposalItem(
            requestItemId: item.id,
            requestItemName: item.name,
            quantity: item.quantity,
            status: ProposalItemStatus.unavailable,
          ),
        );
      } else if (status == ProposalItemStatus.available) {
        final price = double.tryParse(_priceControllers[item.id]?.text ?? '0') ?? 0.0;
        proposalItems.add(
          ProposalItem(
            requestItemId: item.id,
            requestItemName: item.name,
            quantity: item.quantity,
            status: ProposalItemStatus.available,
            price: price,
            description: _remarkControllers[item.id]?.text,
          ),
        );
      } else {
        // Alternative
        final price = double.tryParse(_priceControllers[item.id]?.text ?? '0') ?? 0.0;
        proposalItems.add(
          ProposalItem(
            requestItemId: item.id,
            requestItemName: item.name,
            quantity: item.quantity,
            status: ProposalItemStatus.alternative,
            price: price,
            description: _remarkControllers[item.id]?.text,
            alternativeName: _altNameControllers[item.id]?.text,
            alternativeBrand: _altBrandControllers[item.id]?.text,
            alternativeReason: _altReasonControllers[item.id]?.text,
          ),
        );
      }
    }

    final requestState = ref.read(requestProvider);

    final proposal = Proposal(
      id: '', // Generated by repo
      requestId: widget.request.id,
      vendorId: user.id,
      vendorBusinessName: user.businessName ?? 'Partner Vendor',
      items: proposalItems,
      missingItemIds: missingItemIds,
      deliveryCharge: _deliveryCharge,
      estimatedDeliveryTime: _deliveryTimeController.text,
      totalPrice: _itemsTotal + _deliveryCharge,
      createdAt: DateTime.now(),
      vendorLatitude: requestState.vendorLatitude,
      vendorLongitude: requestState.vendorLongitude,
    );

    try {
      await ref.read(proposalProvider.notifier).submitProposal(proposal);
      if (mounted) {
        // Trigger simulated Customer Notification after 1.5 seconds!
        Future.delayed(const Duration(milliseconds: 1500), () {
          ref.read(notificationProvider.notifier).triggerNotification(
            title: 'New Bid Received! 🏷️',
            body: 'A Partner Merchant submitted a bid of Rs. ${proposal.totalPrice.toStringAsFixed(0)} for request ${proposal.requestId}.',
            icon: Icons.local_offer_rounded,
            color: AppColors.customerColor,
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Proposal submitted successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
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

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Create Proposal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Request summary card
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(widget.request.id, style: AppTextStyles.subtitle(primaryText)),
                              StatusBadge(label: 'Approx. Distance: ${widget.request.approximateDistance} km', color: AppColors.vendorColor),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Area: ${widget.request.customerArea}', style: AppTextStyles.bodyMedium(secondaryText)),
                          Text('Customer name & phone are masked for protection.', style: AppTextStyles.caption(AppColors.warning)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text('Item Verification', style: AppTextStyles.h2(primaryText)),
                    const SizedBox(height: 12),

                    // List of items to verify
                    ...widget.request.items.map((item) {
                      final status = _itemStatuses[item.id]!;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: AppTextStyles.subtitle(primaryText),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Quantity: ${item.quantity} | Preferred Brand: ${item.preferredBrand ?? "Any"}',
                                        style: AppTextStyles.bodySmall(secondaryText),
                                      ),
                                      if (item.description != null && item.description!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Note: ${item.description}',
                                          style: AppTextStyles.caption(secondaryText),
                                        ),
                                      ]
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Segmented Availability Control
                            Row(
                              children: [
                                Expanded(
                                  child: _StatusSegmentButton(
                                    label: 'Available',
                                    icon: Icons.check_circle_outline_rounded,
                                    isSelected: status == ProposalItemStatus.available,
                                    color: AppColors.success,
                                    onTap: () {
                                      setState(() {
                                        _itemStatuses[item.id] = ProposalItemStatus.available;
                                        _calculateTotal();
                                      });
                                    },
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _StatusSegmentButton(
                                    label: 'Alternative',
                                    icon: Icons.swap_horiz_rounded,
                                    isSelected: status == ProposalItemStatus.alternative,
                                    color: AppColors.vendorColor,
                                    onTap: () {
                                      setState(() {
                                        _itemStatuses[item.id] = ProposalItemStatus.alternative;
                                        _calculateTotal();
                                      });
                                    },
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _StatusSegmentButton(
                                    label: 'Missing',
                                    icon: Icons.cancel_outlined,
                                    isSelected: status == ProposalItemStatus.unavailable,
                                    color: Colors.red,
                                    onTap: () {
                                      setState(() {
                                        _itemStatuses[item.id] = ProposalItemStatus.unavailable;
                                        _calculateTotal();
                                      });
                                    },
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),

                            // Conditional Sub-forms
                            if (status == ProposalItemStatus.available) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _priceControllers[item.id],
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Unit Price (LKR)',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        prefixText: 'Rs. ',
                                      ),
                                      onChanged: (_) => _calculateTotal(),
                                      validator: (val) {
                                        if (val == null || val.isEmpty) return 'Enter price';
                                        if (double.tryParse(val) == null) return 'Invalid';
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _remarkControllers[item.id],
                                      decoration: InputDecoration(
                                        labelText: 'Remarks (Optional)',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (status == ProposalItemStatus.alternative) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _altNameControllers[item.id],
                                decoration: InputDecoration(
                                  labelText: 'Alternative Product Name',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) return 'Enter alternative product name';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _altBrandControllers[item.id],
                                      decoration: InputDecoration(
                                        labelText: 'Brand/Model (Optional)',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _priceControllers[item.id],
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Unit Price (LKR)',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        prefixText: 'Rs. ',
                                      ),
                                      onChanged: (_) => _calculateTotal(),
                                      validator: (val) {
                                        if (val == null || val.isEmpty) return 'Enter price';
                                        if (double.tryParse(val) == null) return 'Invalid';
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _altReasonControllers[item.id],
                                decoration: InputDecoration(
                                  labelText: 'Reason for Replacement',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) return 'Enter replacement reason';
                                  return null;
                                },
                              ),
                            ]
                          ],
                        ),
                      );
                    }).toList(),

                    Text('Shipping & Logistics', style: AppTextStyles.h2(primaryText)),
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
                            controller: _deliveryChargeController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Estimated Delivery/Shipping Charge (LKR)',
                              prefixText: 'Rs. ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Enter delivery charge';
                              if (double.tryParse(val) == null) return 'Invalid amount';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _deliveryTimeController,
                            decoration: InputDecoration(
                              labelText: 'Estimated Delivery Time',
                              hintText: 'e.g. 1-2 hours, Same day before 6 PM',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Enter estimated delivery time';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),

            // Summary Bottom Panel
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                border: Border(top: BorderSide(color: borderColor)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Items Subtotal:', style: AppTextStyles.bodyMedium(secondaryText)),
                        Text('Rs. ${_itemsTotal.toStringAsFixed(2)}', style: AppTextStyles.bodyMedium(primaryText)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Delivery Charge:', style: AppTextStyles.bodyMedium(secondaryText)),
                        Text('Rs. ${_deliveryCharge.toStringAsFixed(2)}', style: AppTextStyles.bodyMedium(primaryText)),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Bid Price:', style: AppTextStyles.subtitle(primaryText)),
                        Text(
                          'Rs. ${(_itemsTotal + _deliveryCharge).toStringAsFixed(2)}',
                          style: AppTextStyles.h1(AppColors.vendorColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.vendorColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: _submitProposal,
                        child: Text(
                          'Submit Proposal',
                          style: AppTextStyles.button(Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _StatusSegmentButton extends StatelessWidget {
  const _StatusSegmentButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
    required this.isDark,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
