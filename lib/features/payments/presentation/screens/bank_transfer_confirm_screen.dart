import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speedmart_lanka/features/payments/data/checkout_service.dart';
import 'package:speedmart_lanka/features/payments/data/bank_transfer_instruction_service.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/connectivity_service.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/services/storage_upload_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/permission_utils.dart';
import '../../../notifications/models/notification_type.dart';
import '../../../notifications/providers/notification_provider.dart'
    as notification_feature;
import '../../../orders/models/order_model.dart';
import '../../../orders/providers/order_provider.dart';
import '../../models/payment.dart';
import '../../providers/payment_provider.dart';
import 'package:speedmart_lanka/core/utils/error_translator.dart';

class BankTransferConfirmScreen extends ConsumerStatefulWidget {
  const BankTransferConfirmScreen({
    super.key,
    required this.order,
    required this.payment,
    this.remaining = const [],
  });

  final OrderModel order;
  final PaymentModel payment;
  final List<Map<String, dynamic>> remaining;

  @override
  ConsumerState<BankTransferConfirmScreen> createState() =>
      _BankTransferConfirmScreenState();
}

class _BankTransferConfirmScreenState
    extends ConsumerState<BankTransferConfirmScreen> {
  String? _localReceiptPath;
  bool _isSubmitting = false;
  late final Future<BankTransferInstruction?> _instructionFuture;

  @override
  void initState() {
    super.initState();
    _instructionFuture = BankTransferInstructionService.instance
        .getForProposal(widget.payment.proposalId);
  }

  Future<void> _pickReceipt() async {
    if (!await AppPermissionUtils.ensureGalleryPermission(context)) return;
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() => _localReceiptPath = file.path);
  }

  Future<void> _confirmPayment() async {
    if (_isSubmitting) return;

    final online = await ConnectivityService.instance.isOnline();
    if (!online) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No network. Check your connection and try again.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final instruction = await _instructionFuture;
      if (instruction?.hasRequiredDetails != true) {
        throw StateError(
          'Bank details are unavailable for this proposal. Choose another payment method.',
        );
      }
      if (_localReceiptPath == null) {
        throw StateError('Please upload the bank transfer receipt.');
      }
      // Upload receipt image if provided
      String? receiptImageUrl;
      if (_localReceiptPath != null) {
        final customerId = FirebaseAuth.instance.currentUser?.uid;
        if (customerId == null) throw StateError('User not authenticated.');
        final ts = DateTime.now().millisecondsSinceEpoch;
        receiptImageUrl = await StorageUploadService.instance.uploadImage(
          _localReceiptPath!,
          'bank_receipts/$customerId/${widget.payment.id}_$ts.jpg',
          quality: 80,
        );
      }

      // Mark payment as pendingBankTransfer with optional receipt URL
      await CheckoutService.instance.submitBankTransferReceipt(
        paymentId: widget.payment.id,
        receiptImageUrl: receiptImageUrl,
      );

      // Reload payment state
      await ref.read(paymentProvider.notifier).loadCustomerPayments();

      // Notify vendor that customer has confirmed the bank transfer
      await ref
          .read(notification_feature.notificationProvider.notifier)
          .createNotification(
            type: NotificationType.bankTransferReceiptSubmitted,
            title: 'Bank Transfer Confirmed',
            body:
                'Customer has confirmed bank transfer for order ${widget.order.id}. Please verify and start preparing.',
            userId: widget.order.vendorId,
            relatedId: widget.order.id,
          );

      // Reload orders
      await ref.read(orderProvider.notifier).loadCustomerOrders();

      if (!mounted) return;

      if (widget.remaining.isNotEmpty) {
        final next = widget.remaining.first;
        context.pushReplacement('/customer/bank-transfer-confirm', extra: {
          'order': next['order'],
          'payment': next['payment'],
          'remaining': widget.remaining.sublist(1),
        });
        return;
      }

      // Navigate to receipt screen
      context.pushReplacement(RouteNames.customerPaymentReceipt, extra: {
        'order': widget.order,
        'payment': widget.payment.copyWith(
          receiptImageUrl: receiptImageUrl,
          paymentStatus: PaymentStatus.pendingBankTransfer,
        ),
      });
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorTranslator.friendly(e)),
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
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Confirm Bank Transfer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _isSubmitting ? null : () => context.pop(),
        ),
      ),
      body: _isSubmitting
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.customerColor),
                  SizedBox(height: 16),
                  Text('Submitting confirmation...',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.customerColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color:
                              AppColors.customerColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                color: AppColors.customerColor),
                            const SizedBox(width: 8),
                            Text('Bank Transfer Instructions',
                                style: AppTextStyles.subtitle(
                                    AppColors.customerColor)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please transfer Rs. ${widget.payment.amount.toStringAsFixed(2)} to the vendor\'s bank account shown below, then tap "I\'ve Paid" to notify the vendor.',
                          style: AppTextStyles.bodyMedium(primaryText),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  FutureBuilder<BankTransferInstruction?>(
                    future: _instructionFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 20),
                          child: LinearProgressIndicator(),
                        );
                      }
                      final instruction = snapshot.data;
                      if (instruction?.hasRequiredDetails != true) {
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            'Bank details are not available for this offer. Please use another payment method.',
                            style: AppTextStyles.bodyMedium(primaryText),
                          ),
                        );
                      }
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vendor Bank Details',
                              style: AppTextStyles.subtitle(primaryText),
                            ),
                            const SizedBox(height: 12),
                            if (instruction!.bankName?.trim().isNotEmpty == true)
                              _infoRow('Bank', instruction.bankName!, primaryText,
                                  secondaryText),
                            if (instruction.bankBranch?.trim().isNotEmpty == true)
                              _infoRow('Branch', instruction.bankBranch!, primaryText,
                                  secondaryText),
                            _infoRow('Account Holder', instruction.accountName!,
                                primaryText, secondaryText),
                            _infoRow('Account Number', instruction.accountNumber!,
                                primaryText, secondaryText),
                          ],
                        ),
                      );
                    },
                  ),

                  // Amount to transfer
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Transfer Amount',
                            style: AppTextStyles.caption(secondaryText)),
                        const SizedBox(height: 4),
                        Text(
                          'Rs. ${widget.payment.amount.toStringAsFixed(2)}',
                          style: AppTextStyles.h1(AppColors.customerColor)
                              .copyWith(fontSize: 28),
                        ),
                        const SizedBox(height: 12),
                        _infoRow('Order ID', widget.order.id, primaryText,
                            secondaryText),
                        _infoRow('Fulfilled by', 'Verified Partner',
                            primaryText, secondaryText),
                        _infoRow(
                            'Reference',
                            widget.payment.transactionReference,
                            primaryText,
                            secondaryText),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Receipt upload
                  Text('Upload Payment Receipt',
                      style: AppTextStyles.h2(primaryText)),
                  const SizedBox(height: 8),
                  Text(
                    'Attach a screenshot or photo of your bank transfer receipt. It is required before the vendor can verify payment.',
                    style: AppTextStyles.bodyMedium(secondaryText),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickReceipt,
                    child: Container(
                      width: double.infinity,
                      height: _localReceiptPath != null ? 200 : 100,
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _localReceiptPath != null
                              ? AppColors.customerColor
                              : borderColor,
                          width: _localReceiptPath != null ? 2 : 1,
                        ),
                      ),
                      child: _localReceiptPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.file(
                                File(_localReceiptPath!),
                                fit: BoxFit.cover,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.upload_file_rounded,
                                    size: 36,
                                    color:
                                        secondaryText.withValues(alpha: 0.5)),
                                const SizedBox(height: 8),
                                Text('Tap to upload receipt',
                                    style: AppTextStyles.bodyMedium(
                                        secondaryText)),
                              ],
                            ),
                    ),
                  ),
                  if (_localReceiptPath != null) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => setState(() => _localReceiptPath = null),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Remove'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.error),
                    ),
                  ],
                  const SizedBox(height: 32),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.customerColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: _confirmPayment,
                      child: Text(
                        "I've Paid — Notify Vendor",
                        style: AppTextStyles.button(Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'The vendor will be notified and will start preparing your order after verifying the transfer.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption(secondaryText),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _infoRow(
      String label, String value, Color primaryText, Color secondaryText) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption(secondaryText)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyMedium(primaryText)
                  .copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
