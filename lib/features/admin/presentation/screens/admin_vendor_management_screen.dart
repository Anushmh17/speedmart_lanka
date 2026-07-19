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
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Status helpers ────────────────────────────────────────────────────────

  Color _statusColor(dynamic vendor) {
    if (vendor.vendorStatus == VendorStatus.pendingApproval) return const Color(0xFFF59E0B);
    if (vendor.vendorStatus == VendorStatus.rejected)        return AppColors.error;
    if (vendor.vendorStatus == VendorStatus.suspended)       return const Color(0xFFEF4444);
    if (vendor.vendorStatus == VendorStatus.approved && vendor.isShopLocationAssigned != true)
      return const Color(0xFF3B82F6);
    return AppColors.success;
  }

  String _statusLabel(dynamic vendor) {
    if (vendor.vendorStatus == VendorStatus.pendingApproval) return 'Pending Approval';
    if (vendor.vendorStatus == VendorStatus.rejected)        return 'Rejected';
    if (vendor.vendorStatus == VendorStatus.suspended)       return 'Suspended';
    if (vendor.vendorStatus == VendorStatus.approved && vendor.isShopLocationAssigned != true)
      return 'Approved · No Shop';
    return 'Active';
  }

  IconData _statusIcon(dynamic vendor) {
    if (vendor.vendorStatus == VendorStatus.pendingApproval) return Icons.hourglass_top_rounded;
    if (vendor.vendorStatus == VendorStatus.rejected)        return Icons.cancel_rounded;
    if (vendor.vendorStatus == VendorStatus.suspended)       return Icons.block_rounded;
    if (vendor.vendorStatus == VendorStatus.approved && vendor.isShopLocationAssigned != true)
      return Icons.store_mall_directory_outlined;
    return Icons.check_circle_rounded;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final adminState = ref.watch(adminProvider);
    final allCategories = ref.watch(activeCategoriesProvider);

    final vendors = adminState.users.where((u) => u.role.name == 'vendor').toList();

    final filteredVendors = vendors.where((v) {
      final matchesStatus = switch (_statusFilter) {
        'pending'          => v.vendorStatus == VendorStatus.pendingApproval,
        'approved_no_shop' => v.vendorStatus == VendorStatus.approved && v.isShopLocationAssigned != true,
        'active'           => v.vendorStatus == VendorStatus.approved && v.isShopLocationAssigned == true,
        'rejected'         => v.vendorStatus == VendorStatus.rejected,
        'suspended'        => v.vendorStatus == VendorStatus.suspended,
        _                  => true,
      };
      if (!matchesStatus) return false;
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return (v.businessName ?? '').toLowerCase().contains(q) ||
             (v.fullName ?? '').toLowerCase().contains(q) ||
             (v.email ?? '').toLowerCase().contains(q) ||
             (v.phone ?? '').toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF3F4F6),
      body: Column(
        children: [
          AdminScreenHeader(
            title: 'Shop Owner Management',
            subtitle: 'Approve, assign & manage shop owners',
            icon: Icons.verified_user_rounded,
            isDark: isDark,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search by name, email or phone…',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _filterChip('All', 'all', isDark),
                    _filterChip('Pending', 'pending', isDark, color: const Color(0xFFF59E0B)),
                    _filterChip('No Shop', 'approved_no_shop', isDark, color: const Color(0xFF3B82F6)),
                    _filterChip('Active', 'active', isDark, color: AppColors.success),
                    _filterChip('Rejected', 'rejected', isDark, color: AppColors.error),
                    _filterChip('Suspended', 'suspended', isDark, color: const Color(0xFFEF4444)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: adminState.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.adminColor))
                : filteredVendors.isEmpty
                    ? Center(child: Text('No shop owners found', style: AppTextStyles.bodyMedium(secondaryText)))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final crossCount = constraints.maxWidth > 900 ? 4
                              : constraints.maxWidth > 600 ? 3
                              : constraints.maxWidth > 400 ? 2
                              : 1;
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossCount,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 1.2,
                              ),
                              itemCount: filteredVendors.length,
                              itemBuilder: (context, i) => _buildVendorCard(
                                context, filteredVendors[i], isDark, cardColor, borderColor, allCategories,
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // ── Filter chip ───────────────────────────────────────────────────────────

  Widget _filterChip(String label, String value, bool isDark, {Color? color}) {
    final isSelected = _statusFilter == value;
    final chipColor = color ?? AppColors.adminColor;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _statusFilter = value),
      backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
      selectedColor: chipColor.withOpacity(0.15),
      checkmarkColor: chipColor,
      side: BorderSide(color: isSelected ? chipColor : (isDark ? AppColors.borderDark : AppColors.borderLight)),
      labelStyle: TextStyle(
        color: isSelected ? chipColor : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  // ── Vendor card ───────────────────────────────────────────────────────────

  Widget _buildVendorCard(
    BuildContext context,
    dynamic vendor,
    bool isDark,
    Color cardColor,
    Color borderColor,
    List<CategoryModel> allCategories,
  ) {
    final color = _statusColor(vendor);
    final label = _statusLabel(vendor);
    final icon = _statusIcon(vendor);
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.6), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (vendor.hasPendingCategoryRequest == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Cat. Request', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          // ── Body ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          vendor.businessName ?? vendor.fullName,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryText),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'ID ${vendor.id.substring(0, vendor.id.length > 4 ? 4 : vendor.id.length)}',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    vendor.email ?? '',
                    style: TextStyle(fontSize: 11, color: secondaryText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    vendor.phone ?? '',
                    style: TextStyle(fontSize: 11, color: secondaryText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.backgroundDark.withOpacity(0.28) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor.withOpacity(0.7)),
                    ),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _infoChip(Icons.storefront_outlined, vendor.shopName ?? 'No shop assigned', secondaryText),
                        if (vendor.assignedRadiusKm != null)
                          _infoChip(Icons.radar_rounded, '${vendor.assignedRadiusKm?.toStringAsFixed(0)}km radius', secondaryText),
                        _infoChip(Icons.percent_rounded, '${((vendor.commissionRate ?? 0.0) * 100).toStringAsFixed(1)}% commission', secondaryText),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _buildActionButtons(context, vendor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Expanded(child: Text(text, style: TextStyle(fontSize: 11, color: color), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Action buttons ────────────────────────────────────────────────────────

  Widget _buildActionButtons(BuildContext context, dynamic vendor) {
    final compact = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      minimumSize: const Size(0, 30),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 11),
    );

    if (vendor.vendorStatus == VendorStatus.pendingApproval) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await context.push(
                  RouteNames.adminVendorAssignment.replaceFirst(':id', vendor.id),
                  extra: vendor,
                );
                ref.invalidate(adminProvider);
              },
              style: compact.copyWith(
                backgroundColor: const WidgetStatePropertyAll(AppColors.adminColor),
                foregroundColor: const WidgetStatePropertyAll(Colors.white),
              ),
              child: const Text('View Details'),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => showDialog(context: context, builder: (_) => VendorRejectionDialog(vendor: vendor)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: const Size(0, 30),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => showDialog(context: context, builder: (_) => VendorApprovalDialog(vendor: vendor)),
                  style: compact.copyWith(
                    backgroundColor: const WidgetStatePropertyAll(AppColors.success),
                    foregroundColor: const WidgetStatePropertyAll(Colors.white),
                  ),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      );
    } else if (vendor.vendorStatus == VendorStatus.suspended) {
      return Row(children: [
        Expanded(child: ElevatedButton(
          onPressed: () async {
            await context.push(RouteNames.adminVendorAssignment.replaceFirst(':id', vendor.id), extra: vendor);
            ref.invalidate(adminProvider);
          },
          style: compact.copyWith(backgroundColor: WidgetStatePropertyAll(AppColors.adminColor), foregroundColor: const WidgetStatePropertyAll(Colors.white)),
          child: const Text('Details'),
        )),
        const SizedBox(width: 6),
        Expanded(child: ElevatedButton(
          onPressed: () async {
            await ref.read(adminProvider.notifier).toggleUserActive(vendor.id);
            ref.invalidate(adminProvider);
          },
          style: compact.copyWith(backgroundColor: WidgetStatePropertyAll(AppColors.success), foregroundColor: const WidgetStatePropertyAll(Colors.white)),
          child: const Text('Activate'),
        )),
      ]);
    } else if (vendor.vendorStatus == VendorStatus.approved) {
      return Row(children: [
        Expanded(child: ElevatedButton(
          onPressed: () async {
            await context.push(RouteNames.adminVendorAssignment.replaceFirst(':id', vendor.id), extra: vendor);
            ref.invalidate(adminProvider);
          },
          style: compact.copyWith(backgroundColor: WidgetStatePropertyAll(AppColors.adminColor), foregroundColor: const WidgetStatePropertyAll(Colors.white)),
          child: const Text('Manage'),
        )),
        const SizedBox(width: 6),
        Expanded(child: OutlinedButton(
          onPressed: () => showDialog(context: context, builder: (_) => VendorSuspensionDialog(vendor: vendor)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error), foregroundColor: AppColors.error, padding: const EdgeInsets.symmetric(vertical: 6), minimumSize: const Size(0, 30), textStyle: const TextStyle(fontSize: 11)),
          child: const Text('Suspend'),
        )),
      ]);
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            await context.push(RouteNames.adminVendorAssignment.replaceFirst(':id', vendor.id), extra: vendor);
            ref.invalidate(adminProvider);
          },
          style: compact.copyWith(backgroundColor: WidgetStatePropertyAll(AppColors.adminColor), foregroundColor: const WidgetStatePropertyAll(Colors.white)),
          child: const Text('View Details'),
        ),
      );
    }
  }

  // ── Commission dialog ─────────────────────────────────────────────────────

  void _showCommissionEditDialog(BuildContext context, dynamic vendor) {
    final controller = TextEditingController(
      text: ((vendor.commissionRate ?? 0.0) * 100).toStringAsFixed(1),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Commission Rate', style: AppTextStyles.h2(primaryText)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Set commission for ${vendor.businessName ?? vendor.fullName}:', style: AppTextStyles.bodyMedium(primaryText)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [CommissionInputFormatter()],
              decoration: const InputDecoration(labelText: 'Commission Percentage (%)', border: OutlineInputBorder(), suffixText: '%'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final pct = double.tryParse(controller.text);
              if (pct != null && pct >= 0 && pct <= 100) {
                await ref.read(adminProvider.notifier).updateVendorCommission(vendor.id, pct / 100);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Commission updated to ${pct.toStringAsFixed(1)}%'),
                    backgroundColor: AppColors.success,
                  ));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Enter a valid percentage between 0 and 100'),
                  backgroundColor: Colors.red,
                ));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
