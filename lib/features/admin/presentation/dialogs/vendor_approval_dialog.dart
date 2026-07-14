import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/utils/category_sync_helper.dart';
import '../../providers/admin_provider.dart';
import '../../providers/category_provider.dart';

class VendorApprovalDialog extends ConsumerStatefulWidget {
  const VendorApprovalDialog({
    super.key,
    required this.vendor,
  });

  final UserModel vendor;

  @override
  ConsumerState<VendorApprovalDialog> createState() =>
      _VendorApprovalDialogState();
}

class _VendorApprovalDialogState extends ConsumerState<VendorApprovalDialog> {
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return AlertDialog(
      title: const Text('Approve Shop Owner'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm shop owner approval for:',
              style: AppTextStyles.bodyMedium(primaryText),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.vendor.businessName ?? widget.vendor.fullName,
                    style: AppTextStyles.subtitle(AppColors.success),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.vendor.email,
                    style: AppTextStyles.bodySmall(secondaryText),
                  ),
                  if (widget.vendor.vendorCategories != null &&
                      widget.vendor.vendorCategories!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Consumer(
                      builder: (context, ref, _) {
                        final allCategories = ref.watch(activeCategoriesProvider);
                        final sanitized = CategorySyncHelper.sanitizeCategoryKeys(
                          widget.vendor.vendorCategories ?? []
                        );
                        final validKeys = sanitized.where((key) => 
                          CategorySyncHelper.getCategoryByKey(key, allCategories) != null
                        ).toList();
                        
                        if (validKeys.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        
                        final displayNames = CategorySyncHelper.getDisplayNames(
                          validKeys,
                          allCategories,
                        );
                        
                        return Wrap(
                          spacing: 6,
                          children: displayNames
                              .take(3)
                              .map((cat) => Chip(
                                    label: Text(cat),
                                    labelStyle: const TextStyle(fontSize: 10),
                                    padding: EdgeInsets.zero,
                                    backgroundColor:
                                        AppColors.success.withOpacity(0.15),
                                  ))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'Add approval notes (optional)',
                hintStyle: TextStyle(color: secondaryText),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxHeight: 100),
              ),
              maxLines: 3,
              minLines: 2,
              style: AppTextStyles.bodySmall(primaryText),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Shop owner will be notified of approval',
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
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            try {
              await ref.read(adminProvider.notifier).approveVendor(
                    vendorId: widget.vendor.id,
                    notes: _notesController.text.isNotEmpty
                        ? _notesController.text
                        : null,
                  );
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${widget.vendor.businessName ?? widget.vendor.fullName} approved successfully',
                    ),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error approving shop owner: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            }
          },
          child: const Text('Approve'),
        ),
      ],
    );
  }
}
