import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/commission_input_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../shared/models/vendor_status.dart';
import '../../providers/admin_provider.dart';
import '../dialogs/vendor_approval_dialog.dart';
import '../dialogs/vendor_rejection_dialog.dart';
import '../dialogs/vendor_suspension_dialog.dart';
import '../../../../shared/utils/category_sync_helper.dart';
import '../../../../shared/models/category_model.dart';
import '../../providers/category_provider.dart';
import '../widgets/admin_screen_header.dart';

class AdminVendorManagementScreen extends ConsumerStatefulWidget {
  const AdminVendorManagementScreen({super.key});

  @override
  ConsumerState<AdminVendorManagementScreen> createState() =>
      _AdminVendorManagementScreenState();
}

class _AdminVendorManagementScreenState
    extends ConsumerState<AdminVendorManagementScreen> {
  String _statusFilter = 'all';

  Widget _buildCategoryChipsPreview(
    List<String> categories,
    List<CategoryModel> allCategories, {
    int maxVisible = 3,
  }) {
    final sanitized = CategorySyncHelper.sanitizeCategoryKeys(categories);
    // Filter to only valid/existing categories in repository
    final validKeys = sanitized.where((key) => 
      CategorySyncHelper.getCategoryByKey(key, allCategories) != null
    ).toList();
    
    // If no valid categories, show nothing
    if (validKeys.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final displayNames = CategorySyncHelper.getDisplayNames(
      validKeys,
      allCategories,
    );
    
    // Deduplicate display names
    final uniqueDisplayNames = <String>{...displayNames}.toList();
    
    final visible = uniqueDisplayNames.take(maxVisible).toList();
    final remaining = uniqueDisplayNames.length - maxVisible;

    final chips = visible
        .map(
          (displayCat) => Chip(
            label: Text(displayCat),
            labelStyle: const TextStyle(fontSize: 10),
            padding: EdgeInsets.zero,
          ),
        )
        .toList();

    if (remaining > 0) {
      chips.add(
        Chip(
          label: Text('+$remaining more'),
          labelStyle: const TextStyle(fontSize: 10),
          backgroundColor: Colors.grey.withOpacity(0.3),
          padding: EdgeInsets.zero,
        ),
      );
    }

    return Wrap(
      spacing: 4,
      children: chips,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final adminState = ref.watch(adminProvider);
    final allUsers = adminState.users;
    final allCategories = ref.watch(activeCategoriesProvider);

    final vendors = allUsers
        .where((u) => u.role.name == 'vendor')
        .toList();

    final filteredVendors = vendors.where((v) {
      switch (_statusFilter) {
        case 'pending':
          return v.vendorStatus == VendorStatus.pendingApproval;
        case 'approved_no_shop':
          return v.vendorStatus == VendorStatus.approved && v.isShopLocationAssigned != true;
        case 'active':
          return v.vendorStatus == VendorStatus.approved && v.isShopLocationAssigned == true;
        case 'rejected':
          return v.vendorStatus == VendorStatus.rejected;
        case 'suspended':
          return v.vendorStatus == VendorStatus.suspended;
        default:
          return true;
      }
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Column(
        children: [
          AdminScreenHeader(
            title: 'Shop Owner Management',
            subtitle: 'Approve, assign & manage shop owners',
            icon: Icons.verified_user_rounded,
            isDark: isDark,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all', _statusFilter, isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending', 'pending', _statusFilter, isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'No Shop',
                    'approved_no_shop',
                    _statusFilter,
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip('Active', 'active', _statusFilter, isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('Rejected', 'rejected', _statusFilter, isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('Suspended', 'suspended', _statusFilter, isDark),
                ],
              ),
            ),
          ),
          Expanded(
            child: adminState.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.adminColor,
                    ),
                  )
                : filteredVendors.isEmpty
                    ? Center(
                        child: Text(
                          'No shop owners found',
                          style: AppTextStyles.bodyMedium(secondaryText),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredVendors.length,
                        itemBuilder: (context, index) {
                          final vendor = filteredVendors[index];
                          return _buildVendorCard(
                            context,
                            vendor,
                            isDark,
                            primaryText,
                            secondaryText,
                            cardColor,
                            borderColor,
                            allCategories,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String currentFilter,
    bool isDark,
  ) {
    final isSelected = currentFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _statusFilter = value);
      },
      backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
      selectedColor: AppColors.adminColor,
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildVendorCard(
    BuildContext context,
    dynamic vendor,
    bool isDark,
    Color primaryText,
    Color secondaryText,
    Color cardColor,
    Color borderColor,
    List<CategoryModel> allCategories,
  ) {
    final statusColor = _getStatusColor(vendor);
    final statusLabel = _getStatusLabel(vendor);
    final shopAssignedLabel =
        vendor.isShopLocationAssigned == true ? 'Assigned' : 'Not Assigned';
    final shopAssignedColor =
        vendor.isShopLocationAssigned == true ? AppColors.success : AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor.businessName ?? vendor.fullName,
                      style: AppTextStyles.bodyMedium(primaryText)
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${vendor.email} · ${vendor.phone}',
                      style: AppTextStyles.caption(secondaryText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Chip(
                    label: Text(statusLabel),
                    backgroundColor: statusColor.withOpacity(0.15),
                    labelStyle: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Shop: ${vendor.shopName ?? 'Not set'}',
                  style: AppTextStyles.bodySmall(primaryText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(shopAssignedLabel),
                backgroundColor: shopAssignedColor.withOpacity(0.15),
                labelStyle: TextStyle(
                  color: shopAssignedColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (vendor.assignedRadiusKm != null) ...[
            const SizedBox(height: 8),
            Text(
              'Radius: ${vendor.assignedRadiusKm?.toStringAsFixed(0) ?? '—'}km',
              style: AppTextStyles.caption(secondaryText),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Commission: ${((vendor.commissionRate ?? 0.0) * 100).toStringAsFixed(1)}%',
                style: AppTextStyles.caption(secondaryText).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (vendor.vendorStatus == VendorStatus.approved) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _showCommissionEditDialog(context, vendor),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.adminColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Edit Rate',
                      style: AppTextStyles.caption(AppColors.adminColor).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (vendor.allowedCategories != null &&
              vendor.allowedCategories!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Builder(
              builder: (ctx) {
                final sanitized = CategorySyncHelper.sanitizeCategoryKeys(vendor.allowedCategories);
                final validKeys = sanitized.where((key) => 
                  CategorySyncHelper.getCategoryByKey(key, allCategories) != null
                ).toList();
                
                if (validKeys.isEmpty) {
                  return Text(
                    'No approved categories',
                    style: AppTextStyles.caption(secondaryText),
                  );
                }
                
                return _buildCategoryChipsPreview(vendor.allowedCategories!, allCategories);
              },
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'No approved categories',
              style: AppTextStyles.caption(secondaryText),
            ),
          ],
          if (vendor.hasPendingCategoryRequest == true &&
              vendor.requestedCategories != null &&
              vendor.requestedCategories!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Builder(
              builder: (ctx) {
                final sanitized = CategorySyncHelper.sanitizeCategoryKeys(vendor.requestedCategories);
                final validKeys = sanitized.where((key) => 
                  CategorySyncHelper.getCategoryByKey(key, allCategories) != null
                ).toList();
                
                if (validKeys.isEmpty) {
                  return const SizedBox.shrink();
                }
                
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pending_actions, size: 14, color: Colors.orange),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildCategoryChipsPreview(
                          vendor.requestedCategories!,
                          allCategories,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 12),
          _buildActionButtons(context, vendor),
        ],
      ),
    );
  }

  Color _getStatusColor(dynamic vendor) {
    if (vendor.vendorStatus == VendorStatus.pendingApproval) {
      return AppColors.warning;
    } else if (vendor.vendorStatus == VendorStatus.rejected) {
      return AppColors.error;
    } else if (vendor.vendorStatus == VendorStatus.suspended) {
      return AppColors.error;
    } else if (vendor.vendorStatus == VendorStatus.approved && vendor.isShopLocationAssigned != true) {
      return Colors.orange;
    } else {
      return AppColors.success;
    }
  }

  String _getStatusLabel(dynamic vendor) {
    if (vendor.vendorStatus == VendorStatus.pendingApproval) {
      return 'Pending';
    } else if (vendor.vendorStatus == VendorStatus.rejected) {
      return 'Rejected';
    } else if (vendor.vendorStatus == VendorStatus.suspended) {
      return 'Suspended';
    } else if (vendor.vendorStatus == VendorStatus.approved && vendor.isShopLocationAssigned != true) {
      return 'No Shop';
    } else {
      return 'Active';
    }
  }

  Widget _buildActionButtons(BuildContext context, dynamic vendor) {
    if (vendor.vendorStatus == VendorStatus.pendingApproval) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => VendorRejectionDialog(vendor: vendor),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                foregroundColor: AppColors.error,
              ),
              label: const Text('Reject'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_rounded),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => VendorApprovalDialog(vendor: vendor),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              label: const Text('Approve'),
            ),
          ),
        ],
      );
    } else if (vendor.vendorStatus == VendorStatus.suspended) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                await context.push(
                  '${RouteNames.adminVendorAssignment.replaceFirst(':id', vendor.id)}',
                  extra: vendor,
                );
                ref.invalidate(adminProvider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.adminColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('View Details'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle),
              onPressed: () async {
                await ref.read(adminProvider.notifier).toggleUserActive(vendor.id);
                ref.invalidate(adminProvider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              label: const Text('Activate'),
            ),
          ),
        ],
      );
    } else if (vendor.vendorStatus == VendorStatus.approved) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                await context.push(
                  '${RouteNames.adminVendorAssignment.replaceFirst(':id', vendor.id)}',
                  extra: vendor,
                );
                ref.invalidate(adminProvider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.adminColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Manage'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.block_rounded),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => VendorSuspensionDialog(vendor: vendor),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                foregroundColor: AppColors.error,
              ),
              label: const Text('Suspend'),
            ),
          ),
        ],
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            await context.push(
              '${RouteNames.adminVendorAssignment.replaceFirst(':id', vendor.id)}',
              extra: vendor,
            );
            ref.invalidate(adminProvider);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.adminColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('View Details'),
        ),
      );
    }
  }

  void _showCommissionEditDialog(BuildContext context, dynamic vendor) {
    final controller = TextEditingController(
      text: ((vendor.commissionRate ?? 0.0) * 100).toStringAsFixed(1),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Commission Rate', style: AppTextStyles.h2(primaryText)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set the platform commission percentage for ${vendor.businessName ?? vendor.fullName}:',
                style: AppTextStyles.bodyMedium(primaryText),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [CommissionInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Commission Percentage (%)',
                  border: OutlineInputBorder(),
                  suffixText: '%',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final double? pct = double.tryParse(controller.text);
                if (pct != null && pct >= 0 && pct <= 100) {
                  final double rate = pct / 100;
                  await ref.read(adminProvider.notifier).updateVendorCommission(vendor.id, rate);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Commission updated to ${pct.toStringAsFixed(1)}%'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid percentage between 0 and 100'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
