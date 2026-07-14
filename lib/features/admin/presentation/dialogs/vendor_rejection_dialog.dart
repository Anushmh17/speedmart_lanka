import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/models/user_model.dart';
import '../../providers/admin_provider.dart';

class VendorRejectionDialog extends ConsumerStatefulWidget {
  const VendorRejectionDialog({
    super.key,
    required this.vendor,
  });

  final UserModel vendor;

  @override
  ConsumerState<VendorRejectionDialog> createState() =>
      _VendorRejectionDialogState();
}

class _VendorRejectionDialogState extends ConsumerState<VendorRejectionDialog> {
  late TextEditingController _reasonController;
  String? _selectedReason;

  final List<String> _commonReasons = [
    'Incomplete vendor profile',
    'Invalid business documentation',
    'Duplicate account detected',
    'Business location outside service area',
    'Policy compliance violation',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;

    return AlertDialog(
      title: const Text('Reject Shop Owner Registration'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rejecting shop owner:',
              style: AppTextStyles.bodyMedium(primaryText),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.vendor.businessName ?? widget.vendor.fullName,
                    style: AppTextStyles.subtitle(AppColors.error),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.vendor.email,
                    style: AppTextStyles.bodySmall(secondaryText),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select rejection reason:',
              style: AppTextStyles.bodyMedium(primaryText),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: Column(
                children: _commonReasons.map((reason) {
                  return RadioListTile<String>(
                    value: reason,
                    groupValue: _selectedReason,
                    onChanged: (value) {
                      setState(() => _selectedReason = value);
                      if (value != 'Other') {
                        _reasonController.clear();
                      }
                    },
                    title: Text(reason, style: AppTextStyles.bodySmall(primaryText)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
            ),
            if (_selectedReason == 'Other') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                decoration: InputDecoration(
                  hintText: 'Enter custom rejection reason',
                  hintStyle: TextStyle(color: secondaryText),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(maxHeight: 80),
                ),
                maxLines: 2,
                style: AppTextStyles.bodySmall(primaryText),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_outlined, color: AppColors.warning, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Shop owner will be notified and cannot reapply automatically',
                      style: AppTextStyles.caption(secondaryText),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          onPressed: (_selectedReason == null)
              ? null
              : () async {
                  final reason = _selectedReason == 'Other'
                      ? _reasonController.text
                      : _selectedReason!;

                  try {
                    await ref.read(adminProvider.notifier).rejectVendor(
                          vendorId: widget.vendor.id,
                          reason: reason,
                        );
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${widget.vendor.businessName ?? widget.vendor.fullName} rejected',
                          ),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error rejecting shop owner: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
