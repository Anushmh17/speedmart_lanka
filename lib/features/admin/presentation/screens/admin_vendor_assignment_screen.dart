import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/commission_input_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../shared/utils/category_sync_helper.dart';
import '../../../admin/providers/admin_provider.dart';
import '../../../admin/providers/category_provider.dart';
import '../widgets/admin_vendor_location_preview.dart';
import '../widgets/admin_screen_header.dart';

class AdminVendorAssignmentScreen extends ConsumerStatefulWidget {
  const AdminVendorAssignmentScreen({
    super.key,
    required this.vendor,
  });

  final dynamic vendor;

  @override
  ConsumerState<AdminVendorAssignmentScreen> createState() =>
      _AdminVendorAssignmentScreenState();
}

class _AdminVendorAssignmentScreenState
    extends ConsumerState<AdminVendorAssignmentScreen> {
  late final TextEditingController _shopNameCtrl;
  late final TextEditingController _shopAddressCtrl;
  late final TextEditingController _latitudeCtrl;
  late final TextEditingController _longitudeCtrl;
  late final TextEditingController _radiusCtrl;
  late final TextEditingController _commissionCtrl;

  List<String> _selectedCategories = [];
  bool _hasInitializedCategories = false;
  bool _isApproved = false;
  bool _isSaving = false;
  bool _isLoading = true;
  dynamic _latestVendor;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadLatestVendorData();
  }

  void _initializeControllers() {
    _shopNameCtrl = TextEditingController(text: widget.vendor.shopName ?? '');
    _shopAddressCtrl =
        TextEditingController(text: widget.vendor.shopAddress ?? '');
    _latitudeCtrl = TextEditingController(
      text: widget.vendor.shopLatitude?.toString() ?? '',
    );
    _longitudeCtrl = TextEditingController(
      text: widget.vendor.shopLongitude?.toString() ?? '',
    );
    _radiusCtrl = TextEditingController(
      text: widget.vendor.assignedRadiusKm?.toString() ?? '5',
    );
    _commissionCtrl = TextEditingController(
      text: ((widget.vendor.commissionRate ?? 0.0) * 100).toStringAsFixed(1),
    );
  }

  Future<void> _loadLatestVendorData() async {
    try {
      // Clean only this vendor's categories locally - do not run global sync
      await ref.read(categoryProvider.notifier).cleanSingleUserCategoryKeysWithRepository(widget.vendor.id);
      final authNotifier = ref.read(authProvider.notifier);
      final latestVendor = await authNotifier.getUserById(widget.vendor.id);
      
      if (latestVendor == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      _latestVendor = latestVendor;

      if (!_hasInitializedCategories) {
        final allowed = CategorySyncHelper.sanitizeCategoryKeys(latestVendor.allowedCategories);
        final submitted = CategorySyncHelper.sanitizeCategoryKeys(latestVendor.vendorCategories);
        
        if (allowed.isNotEmpty) {
          _selectedCategories = allowed;
        } else if (latestVendor.vendorStatus?.name == 'pendingApproval' || latestVendor.vendorApproved != true) {
          _selectedCategories = submitted;
        } else {
          _selectedCategories = [];
        }
        
        _hasInitializedCategories = true;
      }
      
      _isApproved = latestVendor.vendorApproved ?? false;
      
      _shopNameCtrl.text = latestVendor.shopName ?? '';
      _shopAddressCtrl.text = latestVendor.shopAddress ?? '';
      _latitudeCtrl.text = latestVendor.shopLatitude?.toString() ?? '';
      _longitudeCtrl.text = latestVendor.shopLongitude?.toString() ?? '';
      _radiusCtrl.text = latestVendor.assignedRadiusKm?.toString() ?? '5';
      _commissionCtrl.text = ((latestVendor.commissionRate ?? 0.0) * 100).toStringAsFixed(1);
    } catch (e) {
      debugPrint('[AdminVendorAssignment] Error loading vendor: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _shopAddressCtrl.dispose();
    _latitudeCtrl.dispose();
    _longitudeCtrl.dispose();
    _radiusCtrl.dispose();
    _commissionCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAssignment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isApproved) {
      if (_shopNameCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shop name is required to approve'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (_shopAddressCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shop address is required to approve'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (_latitudeCtrl.text.trim().isEmpty || _longitudeCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shop coordinates are required to approve'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (_selectedCategories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('At least one category is required to approve'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (_radiusCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service radius is required to approve'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final authNotifier = ref.read(authProvider.notifier);
      // Sanitize selected categories using current repository keys
      final sanitized = CategorySyncHelper.sanitizeCategoryKeys(_selectedCategories);
      await authNotifier.updateVendorShopAssignment(
        vendorId: widget.vendor.id,
        shopName: _shopNameCtrl.text.trim(),
        shopAddress: _shopAddressCtrl.text.trim(),
        shopLatitude: double.parse(_latitudeCtrl.text.trim()),
        shopLongitude: double.parse(_longitudeCtrl.text.trim()),
        assignedRadiusKm: double.parse(_radiusCtrl.text.trim()),
        vendorApproved: _isApproved,
        allowedCategories: sanitized,
        requestedCategories: [],
        hasPendingCategoryRequest: false,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isApproved
              ? 'Shop Owner approved successfully'
              : 'Shop Owner categories updated'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: _isLoading || _isSaving
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.adminColor),
            )
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  AdminScreenHeader(
                    title: 'Assign Store',
                    subtitle: widget.vendor.businessName ?? widget.vendor.fullName,
                    icon: Icons.storefront_rounded,
                    isDark: isDark,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Commission Rate
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.adminColor.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.adminColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.percent_rounded, color: AppColors.adminColor, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Commission Rate', style: AppTextStyles.caption(secondaryText)),
                                Text(
                                  '${(((_latestVendor ?? widget.vendor).commissionRate ?? 0.0) * 100).toStringAsFixed(1)}%',
                                  style: AppTextStyles.bodyMedium(primaryText).copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _showCommissionEditDialog(context, primaryText),
                            style: TextButton.styleFrom(foregroundColor: AppColors.adminColor),
                            child: const Text('Edit Rate'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Approve Shop Owner',
                            style: AppTextStyles.bodyMedium(primaryText),
                          ),
                        ),
                        Switch(
                          value: _isApproved,
                          onChanged: (val) => setState(() => _isApproved = val),
                          activeColor: AppColors.adminColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (widget.vendor.shopLocationDetectedAt != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.customerColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.customerColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shop Owner-Submitted Location',
                              style: AppTextStyles.labelLarge(primaryText),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.vendor.shopLocationAccuracyMeters != null
                                        ? '📍 GPS Detected (±${widget.vendor.shopLocationAccuracyMeters!.toStringAsFixed(0)}m accuracy)'
                                        : '✍️ Manual Entry',
                                    style: AppTextStyles.bodySmall(secondaryText),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Submitted: ${widget.vendor.shopLocationDetectedAt?.toString().split('.')[0] ?? 'N/A'}',
                              style: AppTextStyles.caption(secondaryText),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    AdminVendorLocationPreview(
                      latitude: widget.vendor.shopLatitude,
                      longitude: widget.vendor.shopLongitude,
                      shopAddress: widget.vendor.shopAddress,
                      locationSource: widget.vendor.shopLocationSource,
                      accuracyMeters: widget.vendor.shopLocationAccuracyMeters,
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Shop Details',
                      style: AppTextStyles.h3(primaryText),
                    ),
                    const SizedBox(height: 12),

                    AppTextField(
                      label: 'Shop Name',
                      hint: 'e.g., Downtown Store',
                      controller: _shopNameCtrl,
                      prefixIcon: Icons.storefront_rounded,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Shop name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    AppTextField(
                      label: 'Shop Address',
                      hint: 'Full street address',
                      controller: _shopAddressCtrl,
                      prefixIcon: Icons.location_on_outlined,
                      maxLines: 2,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Shop address is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'GPS Location',
                      style: AppTextStyles.h3(primaryText),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Latitude',
                            hint: '-90 to 90',
                            controller: _latitudeCtrl,
                            prefixIcon: Icons.location_on_rounded,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Required';
                              }
                              try {
                                final lat = double.parse(v.trim());
                                if (lat < -90 || lat > 90) {
                                  return 'Invalid';
                                }
                              } catch (_) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Longitude',
                            hint: '-180 to 180',
                            controller: _longitudeCtrl,
                            prefixIcon: Icons.location_on_rounded,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Required';
                              }
                              try {
                                final lng = double.parse(v.trim());
                                if (lng < -180 || lng > 180) {
                                  return 'Invalid';
                                }
                              } catch (_) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    AppTextField(
                      label: 'Service Radius (KM)',
                      hint: 'e.g., 5',
                      controller: _radiusCtrl,
                      prefixIcon: Icons.straighten_rounded,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Radius is required';
                        }
                        try {
                          final radius = double.parse(v.trim());
                          if (radius <= 0) {
                            return 'Radius must be > 0';
                          }
                        } catch (_) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    if (_latestVendor?.vendorCategories != null && _latestVendor.vendorCategories!.isNotEmpty) ...[
                      Text(
                        'Shop Owner Submitted Categories',
                        style: AppTextStyles.h3(primaryText),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.app_registration, color: Colors.blue, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Selected during registration',
                                  style: AppTextStyles.caption(Colors.blue),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Consumer(
                              builder: (context, ref, _) {
                                final allCategories = ref.watch(activeCategoriesProvider);
                                final sanitized = CategorySyncHelper.sanitizeCategoryKeys(_latestVendor.vendorCategories);
                                final validKeys = sanitized.where((key) => 
                                  CategorySyncHelper.getCategoryByKey(key, allCategories) != null
                                ).toList();
                                final displayNames = CategorySyncHelper.getDisplayNames(validKeys, allCategories);
                                
                                if (validKeys.isEmpty) {
                                  return Text(
                                    'No categories found',
                                    style: AppTextStyles.caption(secondaryText),
                                  );
                                }
                                
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: displayNames.map((displayCat) => Chip(
                                    label: Text(displayCat),
                                    backgroundColor: Colors.blue.withOpacity(0.15),
                                    labelStyle: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  )).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    Text(
                      'Current Approved Categories',
                      style: AppTextStyles.h3(primaryText),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.success.withOpacity(0.3)),
                      ),
                      child: _latestVendor?.allowedCategories != null && _latestVendor.allowedCategories!.isNotEmpty
                          ? Consumer(
                              builder: (context, ref, _) {
                                final allCategories = ref.watch(activeCategoriesProvider);
                                final sanitized = CategorySyncHelper.sanitizeCategoryKeys(_latestVendor.allowedCategories);
                                final validKeys = sanitized.where((key) => 
                                  CategorySyncHelper.getCategoryByKey(key, allCategories) != null
                                ).toList();
                                final displayNames = CategorySyncHelper.getDisplayNames(validKeys, allCategories);
                                
                                if (validKeys.isEmpty) {
                                  return Text(
                                    'No approved categories',
                                    style: AppTextStyles.bodySmall(secondaryText),
                                  );
                                }
                                
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: displayNames.map((displayCat) => Chip(
                                    label: Text(displayCat),
                                    backgroundColor: AppColors.success.withOpacity(0.15),
                                    labelStyle: TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  )).toList(),
                                );
                              },
                            )
                          : Text(
                              'No approved categories',
                              style: AppTextStyles.bodySmall(secondaryText),
                            ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Shop Owner Requested Categories',
                      style: AppTextStyles.h3(primaryText),
                    ),
                    const SizedBox(height: 12),
                    if (_latestVendor?.hasPendingCategoryRequest == true &&
                        _latestVendor?.requestedCategories != null &&
                        _latestVendor.requestedCategories!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Pending Category Request',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Consumer(
                              builder: (context, ref, _) {
                                final allCategories = ref.watch(activeCategoriesProvider);
                                final sanitized = CategorySyncHelper.sanitizeCategoryKeys(_latestVendor.requestedCategories);
                                final validKeys = sanitized.where((key) => 
                                  CategorySyncHelper.getCategoryByKey(key, allCategories) != null
                                ).toList();
                                final displayNames = CategorySyncHelper.getDisplayNames(validKeys, allCategories);
                                
                                if (validKeys.isEmpty) {
                                  return Text(
                                    'No categories found',
                                    style: AppTextStyles.caption(secondaryText),
                                  );
                                }
                                
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: displayNames.map((displayCat) => Chip(
                                    label: Text(displayCat),
                                    backgroundColor: Colors.orange.withOpacity(0.15),
                                    labelStyle: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  )).toList(),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    final merged = CategorySyncHelper.sanitizeCategoryKeys([
                                      ..._selectedCategories,
                                      ..._latestVendor.requestedCategories!,
                                    ]);
                                    _selectedCategories = merged;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Requested categories added to selector'),
                                      backgroundColor: Colors.orange,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('Add Requested Categories'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange,
                                  side: const BorderSide(color: Colors.orange),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'No pending category request',
                          style: AppTextStyles.bodySmall(secondaryText),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Allowed Categories',
                            style: AppTextStyles.h3(primaryText),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedCategories.clear();
                            });
                          },
                          icon: const Icon(Icons.clear_all, size: 18),
                          label: const Text('Clear All'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ref.watch(activeCategoriesProvider).map((cat) {
                        return FilterChip(
                          label: Text(cat.displayName),
                          selected: _selectedCategories.contains(cat.normalizedKey),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                if (!_selectedCategories.contains(cat.normalizedKey)) {
                                  _selectedCategories.add(cat.normalizedKey);
                                }
                              } else {
                                _selectedCategories.remove(cat.normalizedKey);
                              }
                            });
                          },
                          selectedColor: AppColors.adminColor,
                          labelStyle: TextStyle(
                            color: _selectedCategories.contains(cat.normalizedKey)
                                ? Colors.white
                                : primaryText,
                          ),
                        );
                      }).toList(),
                    ),

                    if (_selectedCategories.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Select at least one category',
                          style: AppTextStyles.caption(Colors.red),
                        ),
                      ),

                    const SizedBox(height: 32),

                    // Vendor Bank Details (read-only for admin)
                    if (((_latestVendor ?? widget.vendor).bankName ?? '').isNotEmpty ||
                        ((_latestVendor ?? widget.vendor).bankAccountNumber ?? '').isNotEmpty) ...[
                      Text('Bank / Payment Details', style: AppTextStyles.h3(primaryText)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.adminColor.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.adminColor.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.account_balance_rounded,
                                    color: AppColors.adminColor, size: 16),
                                const SizedBox(width: 8),
                                Text('Used for commission settlement',
                                    style: AppTextStyles.caption(secondaryText)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _adminBankRow('Bank', (_latestVendor ?? widget.vendor).bankName, primaryText, secondaryText),
                            _adminBankRow('Branch', (_latestVendor ?? widget.vendor).bankBranch, primaryText, secondaryText),
                            _adminBankRow('Account Holder', (_latestVendor ?? widget.vendor).bankAccountName, primaryText, secondaryText),
                            _adminBankRow('Account No.', (_latestVendor ?? widget.vendor).bankAccountNumber, primaryText, secondaryText),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      Text('Bank / Payment Details', style: AppTextStyles.h3(primaryText)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.warning.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppColors.warning, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Vendor has not added bank details yet.',
                                style: AppTextStyles.bodySmall(secondaryText),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedCategories.isEmpty ? null : _saveAssignment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.adminColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Save Assignment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _adminBankRow(String label, String? value, Color primaryText, Color secondaryText) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text('$label:', style: AppTextStyles.caption(secondaryText)),
          ),
          Expanded(
            child: Text(value,
                style: AppTextStyles.bodySmall(primaryText),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  void _showCommissionEditDialog(BuildContext context, Color primaryText) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Edit Commission Rate', style: AppTextStyles.h2(primaryText)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set commission for ${widget.vendor.businessName ?? widget.vendor.fullName}:',
                style: AppTextStyles.bodyMedium(primaryText),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _commissionCtrl,
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final pct = double.tryParse(_commissionCtrl.text);
                if (pct != null && pct >= 0 && pct <= 100) {
                  await ref.read(adminProvider.notifier).updateVendorCommission(widget.vendor.id, pct / 100);
                  final updated = await ref.read(authProvider.notifier).getUserById(widget.vendor.id);
                  if (mounted) {
                    setState(() => _latestVendor = updated);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Commission updated to ${pct.toStringAsFixed(1)}%'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid percentage between 0 and 100'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.adminColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
