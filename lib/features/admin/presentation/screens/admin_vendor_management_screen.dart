import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/routes/route_names.dart';
import '../../providers/admin_provider.dart';

class AdminVendorManagementScreen extends ConsumerStatefulWidget {
  const AdminVendorManagementScreen({super.key});

  @override
  ConsumerState<AdminVendorManagementScreen> createState() =>
      _AdminVendorManagementScreenState();
}

class _AdminVendorManagementScreenState
    extends ConsumerState<AdminVendorManagementScreen> {
  String _statusFilter = 'all';

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

    // Filter to vendors only
    final vendors = allUsers
        .where((u) => u.role.name == 'vendor')
        .toList();

    // Apply status filter
    final filteredVendors = vendors.where((v) {
      switch (_statusFilter) {
        case 'pending':
          return v.vendorApproved != true;
        case 'approved_no_shop':
          return v.vendorApproved == true && v.isShopLocationAssigned != true;
        case 'active':
          return v.vendorApproved == true && v.isShopLocationAssigned == true;
        default:
          return true;
      }
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Management'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.all(16),
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
                ],
              ),
            ),
          ),
          // Vendor list
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
                          'No vendors found',
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
          if (vendor.vendorCategories != null &&
              vendor.vendorCategories!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: (vendor.vendorCategories as List<String>)
                  .take(3)
                  .map(
                    (cat) => Chip(
                      label: Text(cat),
                      labelStyle: const TextStyle(fontSize: 10),
                      padding: EdgeInsets.zero,
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                context.push(
                  '${RouteNames.adminVendorAssignment.replaceFirst(':id', vendor.id)}',
                  extra: vendor,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.adminColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Manage'),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(dynamic vendor) {
    if (vendor.vendorApproved != true) {
      return AppColors.warning;
    } else if (vendor.isShopLocationAssigned != true) {
      return Colors.orange;
    } else {
      return AppColors.success;
    }
  }

  String _getStatusLabel(dynamic vendor) {
    if (vendor.vendorApproved != true) {
      return 'Pending';
    } else if (vendor.isShopLocationAssigned != true) {
      return 'No Shop';
    } else {
      return 'Active';
    }
  }
}
