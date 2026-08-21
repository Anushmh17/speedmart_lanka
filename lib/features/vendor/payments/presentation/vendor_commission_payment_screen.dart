import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/storage_upload_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/safe_request_image.dart';
import '../../../auth/providers/auth_provider.dart';
import '../data/vendor_commission_payment_repository.dart';
import '../models/vendor_commission_payment.dart';
import '../providers/vendor_commission_payment_provider.dart';
import 'package:speedmart_lanka/core/utils/error_translator.dart';

/// Fetches Speedmart's admin bank details from Firestore platform_config.
/// Returns null while loading or if not configured by admin.
final _adminBankDetailsProvider = FutureProvider<Map<String, String>?>((ref) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('platform_config')
        .doc('bank_details')
        .get();
    if (doc.exists && doc.data() != null && doc.data()!.isNotEmpty) {
      return doc.data()!.map((k, v) => MapEntry(k, v.toString()));
    }
  } catch (e) {
    debugPrint('[CommissionPayment] Could not load bank details from Firestore: $e');
  }
  return null;
});

/// Vendor Commission Payment Screen — embedded in the Earnings (Wallet) tab.
///
/// Shows:
///   1. Admin's bank account details (to transfer to)
///   2. Receipt upload flow
///   3. History of past payment records
class VendorCommissionPaymentScreen extends ConsumerStatefulWidget {
  const VendorCommissionPaymentScreen({super.key, this.scrollController});

  final ScrollController? scrollController;

  @override
  ConsumerState<VendorCommissionPaymentScreen> createState() =>
      _VendorCommissionPaymentScreenState();
}

class _VendorCommissionPaymentScreenState
    extends ConsumerState<VendorCommissionPaymentScreen> {
  final _noteCtrl = TextEditingController();
  bool _uploading = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Receipt upload & submit ────────────────────────────────────────────────

  Future<void> _submitReceipt([VendorCommissionPayment? payment]) async {
    if (_uploading) return;

    // Pick image
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (file == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final user = ref.read(currentUserProvider);
      final vendorId = payment?.vendorId ?? user?.id ?? 'unknown';
      final ts = DateTime.now().millisecondsSinceEpoch;
      final url = await StorageUploadService.instance.uploadImage(
        file.path,
        'commission_receipts/$vendorId/$ts.jpg',
        quality: 80,
      );

      if (payment != null) {
        await VendorCommissionPaymentRepository.instance.submitReceipt(
          paymentId: payment.id,
          receiptUrl: url,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
      } else {
        await VendorCommissionPaymentRepository.instance.submitVendorDirectReceipt(
          vendorId: user?.id ?? '',
          vendorName: user?.businessName ?? user?.fullName ?? 'Vendor',
          receiptUrl: url,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
      }

      _noteCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Transfer receipt submitted — Speedmart will review shortly.'),
              ),
            ]),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorTranslator.friendly(e)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final user = ref.watch(currentUserProvider);
    final paymentsAsync = ref.watch(vendorCommissionPaymentsProvider);
    final bankAsync = ref.watch(_adminBankDetailsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(vendorCommissionPaymentsProvider);
        ref.invalidate(_adminBankDetailsProvider);
      },
      child: SingleChildScrollView(
        controller: widget.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(children: [
              const Icon(Icons.account_balance_rounded,
                  color: AppColors.vendorColor, size: 26),
              const SizedBox(width: 10),
              Text('Commission Payments', style: AppTextStyles.h1(primaryText)),
            ]),
            const SizedBox(height: 6),
            Text(
              'Pay your platform commission via bank transfer and upload your receipt. '
              'Speedmart will verify and update your balance.',
              style: AppTextStyles.bodyMedium(secondaryText),
            ),
            const SizedBox(height: 24),

            // ── Speedmart bank details ──
            _buildBankDetailsCard(bankAsync, isDark, primaryText, secondaryText, cardColor, borderColor),
            const SizedBox(height: 20),

            // ── Direct Upload Receipt Card ──
            _buildDirectUploadCard(isDark, primaryText, secondaryText, cardColor, borderColor),
            const SizedBox(height: 24),

            // ── Payment records ──
            paymentsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.vendorColor)),
              error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: AppTextStyles.bodyMedium(AppColors.error))),
              data: (payments) {
                if (payments.isEmpty) {
                  return _buildEmptyState(isDark, secondaryText);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Payment Records',
                        style: AppTextStyles.h2(primaryText)),
                    const SizedBox(height: 12),
                    ...payments.map((p) => _buildPaymentCard(
                          context,
                          p,
                          user,
                          isDark,
                          primaryText,
                          secondaryText,
                          cardColor,
                          borderColor,
                        )),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankDetailsCard(
    AsyncValue<Map<String, String>?> bankAsync,
    bool isDark,
    Color primaryText,
    Color secondaryText,
    Color cardColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.vendorColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.vendorColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.account_balance_outlined,
                color: AppColors.vendorColor, size: 20),
            const SizedBox(width: 8),
            Text('Transfer to Speedmart Lanka',
                style: AppTextStyles.subtitle(primaryText)
                    .copyWith(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 14),
          bankAsync.when(
            loading: () => const SizedBox(
              height: 48,
              child:
                  Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.vendorColor)),
            ),
            error: (_, __) => Text(
              'Bank details not configured yet. Contact Speedmart admin.',
              style: AppTextStyles.bodySmall(AppColors.error),
            ),
            data: (bank) {
              if (bank == null || bank.isEmpty) {
                return Text(
                  'Bank details not configured yet. Contact your Speedmart admin.',
                  style: AppTextStyles.bodySmall(secondaryText),
                );
              }
              return Column(
                children: bank.entries.map((entry) {
                  return _bankDetailRow(
                    _friendlyKey(entry.key),
                    entry.value,
                    primaryText,
                    secondaryText,
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppColors.warning, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'After transferring, upload your receipt below and notify Speedmart for verification.',
                  style: AppTextStyles.caption(AppColors.warning)
                      .copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _bankDetailRow(
      String label, String value, Color primaryText, Color secondaryText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: AppTextStyles.caption(secondaryText)),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label copied'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Row(children: [
                Expanded(
                  child: Text(
                    value,
                    style: AppTextStyles.bodyMedium(primaryText)
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const Icon(Icons.copy_rounded, size: 14, color: AppColors.vendorColor),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _friendlyKey(String key) {
    switch (key) {
      case 'bank_name':
        return 'Bank Name';
      case 'branch':
        return 'Branch';
      case 'account_name':
        return 'Account Name';
      case 'account_number':
        return 'Account No.';
      default:
        return key
            .split('_')
            .map((w) => w[0].toUpperCase() + w.substring(1))
            .join(' ');
    }
  }

  Widget _buildDirectUploadCard(
    bool isDark,
    Color primaryText,
    Color secondaryText,
    Color cardColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.vendorColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.cloud_upload_outlined,
                color: AppColors.vendorColor, size: 20),
            const SizedBox(width: 8),
            Text('Upload Transfer Receipt',
                style: AppTextStyles.subtitle(primaryText)
                    .copyWith(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          Text(
            'Made a bank transfer to Speedmart? Attach your payment receipt photo below for verification.',
            style: AppTextStyles.bodySmall(secondaryText),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(
              hintText: 'Optional note (e.g., "Paid Rs. 2500 on 13 Aug")',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              isDense: true,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _uploading ? null : () => _submitReceipt(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.vendorColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_photo_alternate_rounded),
              label: Text(_uploading
                  ? 'Uploading…'
                  : 'Upload Receipt & Notify Speedmart'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color secondaryText) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(children: [
        Icon(Icons.check_circle_outline_rounded,
            size: 56, color: AppColors.success.withValues(alpha: 0.7)),
        const SizedBox(height: 16),
        Text('No outstanding commission',
            style: AppTextStyles.subtitle(
                isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)),
        const SizedBox(height: 6),
        Text(
          'Your commission balance will appear here\nonce Speedmart adds a payment record.',
          style: AppTextStyles.bodyMedium(secondaryText),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  Widget _buildPaymentCard(
    BuildContext context,
    VendorCommissionPayment payment,
    dynamic user,
    bool isDark,
    Color primaryText,
    Color secondaryText,
    Color cardColor,
    Color borderColor,
  ) {
    final statusColor = _statusColor(payment.status);
    final canSubmitReceipt = payment.status == VendorCommissionPaymentStatus.pending ||
        payment.status == VendorCommissionPaymentStatus.partial;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        children: [
          // Status header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: [
              Icon(_statusIcon(payment.status), color: statusColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  payment.status.displayLabel,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                _formatDate(payment.updatedAt),
                style: AppTextStyles.caption(secondaryText),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount owed
                if (payment.amountOwed > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Amount to Pay',
                          style: AppTextStyles.bodyMedium(secondaryText)),
                      Text(
                        'Rs. ${payment.amountOwed.toStringAsFixed(2)}',
                        style: AppTextStyles.h2(AppColors.error).copyWith(
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.success, size: 18),
                      const SizedBox(width: 6),
                      Text('Fully Settled',
                          style: AppTextStyles.subtitle(AppColors.success)),
                    ],
                  ),
                ],

                if (payment.amountPaid > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Amount Paid',
                          style: AppTextStyles.caption(secondaryText)),
                      Text(
                        'Rs. ${payment.amountPaid.toStringAsFixed(2)}',
                        style: AppTextStyles.bodyMedium(AppColors.success)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],

                // Admin note
                if (payment.adminNote != null &&
                    payment.adminNote!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.admin_panel_settings_outlined,
                            color: AppColors.info, size: 15),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Admin: ${payment.adminNote}',
                            style: AppTextStyles.caption(AppColors.info),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Existing receipt preview
                if (payment.receiptUrl != null) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Text('Submitted Receipt',
                      style: AppTextStyles.caption(secondaryText)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showReceiptFullScreen(context, payment.receiptUrl!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: NetworkFallbackImage(
                        url: payment.receiptUrl!,
                        width: double.infinity,
                        height: 160,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (payment.receiptNote != null &&
                      payment.receiptNote!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Your note: ${payment.receiptNote}',
                      style: AppTextStyles.caption(secondaryText),
                    ),
                  ],
                ],

                // Upload receipt section
                if (canSubmitReceipt && payment.amountOwed > 0) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Text(
                    payment.receiptUrl != null
                        ? 'Update Receipt'
                        : 'Upload Transfer Receipt',
                    style: AppTextStyles.subtitle(primaryText),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteCtrl,
                    decoration: InputDecoration(
                      hintText: 'Optional note (e.g., "Transferred on 13 Aug")',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _uploading ? null : () => _submitReceipt(payment),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.vendorColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _uploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              payment.receiptUrl != null
                                  ? Icons.upload_file_rounded
                                  : Icons.add_photo_alternate_rounded),
                      label: Text(_uploading
                          ? 'Uploading…'
                          : payment.receiptUrl != null
                              ? 'Replace Receipt & Resubmit'
                              : 'Upload Receipt & Notify Speedmart'),
                    ),
                  ),
                ],

                // Status chip for submitted/accepted
                if (payment.status ==
                    VendorCommissionPaymentStatus.receiptSubmitted) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.hourglass_top_rounded,
                          color: AppColors.warning, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Receipt submitted. Speedmart is reviewing your payment.',
                          style: AppTextStyles.caption(AppColors.warning),
                        ),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showReceiptFullScreen(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: NetworkFallbackImage(
                url: url,
                fit: BoxFit.contain,
                height: 400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(VendorCommissionPaymentStatus status) {
    switch (status) {
      case VendorCommissionPaymentStatus.pending:
        return AppColors.error;
      case VendorCommissionPaymentStatus.receiptSubmitted:
        return AppColors.warning;
      case VendorCommissionPaymentStatus.accepted:
        return AppColors.success;
      case VendorCommissionPaymentStatus.partial:
        return AppColors.info;
    }
  }

  IconData _statusIcon(VendorCommissionPaymentStatus status) {
    switch (status) {
      case VendorCommissionPaymentStatus.pending:
        return Icons.payment_rounded;
      case VendorCommissionPaymentStatus.receiptSubmitted:
        return Icons.hourglass_top_rounded;
      case VendorCommissionPaymentStatus.accepted:
        return Icons.check_circle_rounded;
      case VendorCommissionPaymentStatus.partial:
        return Icons.splitscreen_rounded;
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';
}
