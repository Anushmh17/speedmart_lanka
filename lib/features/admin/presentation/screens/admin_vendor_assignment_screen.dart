import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../shared/utils/category_constants.dart';

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
    // Prefill from vendor-submitted data (initial values)
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
      text: widget.vendor.assignedRadiusKm?.toString() ?? '20',
    );
  }

  Future<void> _loadLatestVendorData() async {
    debugPrint('[CategoryLogic] ===== SCREEN OPENED =====');
    debugPrint('[CategoryLogic] Screen opened vendorId: ${widget.vendor.id}');
    
    try {
      // Fetch fresh vendor data from repository
      final authNotifier = ref.read(authProvider.notifier);
      final latestVendor = await authNotifier.getUserById(widget.vendor.id);
      
      if (latestVendor == null) {
        debugPrint('[CategoryLogic] ERROR: Vendor not found in repository');
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      _latestVendor = latestVendor;
      debugPrint('[CategoryLogic] Assign screen approved: ${latestVendor.allowedCategories}');
      debugPrint('[CategoryLogic] Assign screen requested: ${latestVendor.requestedCategories}');

      // Initialize categories ONLY ONCE when screen opens
      if (!_hasInitializedCategories) {
        final allowed = VendorCategories.normalizeList(latestVendor.allowedCategories ?? []);
        final submitted = VendorCategories.normalizeList(latestVendor.vendorCategories ?? []);
        
        debugPrint('[VendorApprovalFix] Fresh allowedCategories: $allowed');
        debugPrint('[VendorApprovalFix] Vendor submitted categories: $submitted');
        
        if (allowed.isNotEmpty) {
          _selectedCategories = allowed;
          debugPrint('[VendorApprovalFix] Initial selector categories: $_selectedCategories (from allowed)');
        } else if (latestVendor.vendorStatus?.name == 'pendingApproval' || latestVendor.vendorApproved != true) {
          _selectedCategories = submitted;
          debugPrint('[VendorApprovalFix] Initial selector categories: $_selectedCategories (from submitted - pending approval)');
        } else {
          _selectedCategories = [];
          debugPrint('[VendorApprovalFix] Initial selector categories: empty');
        }
        
        _hasInitializedCategories = true;
      }
      
      _isApproved = latestVendor.vendorApproved ?? false;
      
      // Update controllers with fresh data
      _shopNameCtrl.text = latestVendor.shopName ?? '';
      _shopAddressCtrl.text = latestVendor.shopAddress ?? '';
      _latitudeCtrl.text = latestVendor.shopLatitude?.toString() ?? '';
      _longitudeCtrl.text = latestVendor.shopLongitude?.toString() ?? '';
      _radiusCtrl.text = latestVendor.assignedRadiusKm?.toString() ?? '20';

      debugPrint('[CategoryLogic] ===== SCREEN LOAD COMPLETE =====');
    } catch (e) {
      debugPrint('[CategoryLogic] ERROR loading vendor data: $e');
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
    super.dispose();
  }

  Future<void> _saveAssignment() async {
    if (!_formKey.currentState!.validate()) return;

    debugPrint('[CategoryLogic] ===== ADMIN SAVE START =====');
    debugPrint('[CategoryLogic] Save allowedCategories: $_selectedCategories');

    // Validate required shop fields for approval
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
      
      debugPrint('[CategoryLogic] Clear pending request: true');
      await authNotifier.updateVendorShopAssignment(
        vendorId: widget.vendor.id,
        shopName: _shopNameCtrl.text.trim(),
        shopAddress: _shopAddressCtrl.text.trim(),
        shopLatitude: double.parse(_latitudeCtrl.text.trim()),
        shopLongitude: double.parse(_longitudeCtrl.text.trim()),
        assignedRadiusKm: double.parse(_radiusCtrl.text.trim()),
        vendorApproved: _isApproved,
        allowedCategories: List<String>.from(_selectedCategories),
        requestedCategories: [],
        hasPendingCategoryRequest: false,
      );

      debugPrint('[CategoryLogic] Persisted allowedCategories: $_selectedCategories');
      debugPrint('[CategoryLogic] ===== ADMIN SAVE COMPLETE =====');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isApproved
              ? 'Vendor approved successfully'
              : 'Vendor categories updated'),
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
      appBar: AppBar(
        title: const Text('Assign Store'),
        elevation: 0,
      ),
      body: _isLoading || _isSaving
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.adminColor),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vendor info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.adminColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vendor',
                            style: AppTextStyles.caption(secondaryText),
                          ),
                          Text(
                            widget.vendor.businessName ?? widget.vendor.fullName,
                            style: AppTextStyles.bodyMedium(primaryText)
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Approval status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Approve Vendor',
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

                    // Vendor-submitted location info (if available)
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
                              'Vendor-Submitted Location',
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

                    // Shop details
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

                    // Location
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

                    // Service radius
                    AppTextField(
                      label: 'Service Radius (KM)',
                      hint: 'e.g., 20',
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

                    // Vendor Submitted Categories (during registration)
                    if (_latestVendor?.vendorCategories != null && _latestVendor.vendorCategories!.isNotEmpty) ...[
                      Text(
                        'Vendor Submitted Categories',
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
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: VendorCategories.displayList(
                                VendorCategories.normalizeList(_latestVendor.vendorCategories),
                              ).map((displayCat) => Chip(
                                label: Text(displayCat),
                                backgroundColor: Colors.blue.withOpacity(0.15),
                                labelStyle: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              )).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // A. Current Approved Categories (Read-only)
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
                          ? Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: VendorCategories.displayList(
                                VendorCategories.normalizeList(_latestVendor.allowedCategories),
                              ).map((displayCat) => Chip(
                                label: Text(displayCat),
                                backgroundColor: AppColors.success.withOpacity(0.15),
                                labelStyle: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              )).toList(),
                            )
                          : Text(
                              'No approved categories',
                              style: AppTextStyles.bodySmall(secondaryText),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // B. Vendor Requested Categories
                    Text(
                      'Vendor Requested Categories',
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
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: VendorCategories.displayList(
                                VendorCategories.normalizeList(_latestVendor.requestedCategories),
                              ).map((displayCat) => Chip(
                                label: Text(displayCat),
                                backgroundColor: Colors.orange.withOpacity(0.15),
                                labelStyle: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              )).toList(),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    debugPrint('[CategoryLogic] Before add requested: $_selectedCategories');
                                    debugPrint('[CategoryLogic] Requested categories: ${_latestVendor.requestedCategories}');
                                    
                                    // Merge current selected + requested categories
                                    final merged = VendorCategories.normalizeList([
                                      ..._selectedCategories,
                                      ..._latestVendor.requestedCategories!,
                                    ]);
                                    
                                    _selectedCategories = merged;
                                    debugPrint('[CategoryLogic] After add requested merged: $_selectedCategories');
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

                    // C. Allowed Categories (Admin Selector)
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
                      children: VendorCategories.displayNames
                          .map(
                            (displayCat) {
                              final normalized = VendorCategories.normalize(displayCat);
                              
                              return FilterChip(
                                label: Text(displayCat),
                                selected: _selectedCategories.contains(normalized),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      if (!_selectedCategories.contains(normalized)) {
                                        _selectedCategories.add(normalized);
                                        debugPrint('[CategoryLogic] CHIP SELECTED: $displayCat ($normalized), list now: $_selectedCategories');
                                      }
                                    } else {
                                      _selectedCategories.remove(normalized);
                                      debugPrint('[CategoryLogic] CHIP DESELECTED: $displayCat ($normalized), list now: $_selectedCategories');
                                    }
                                  });
                                },
                                selectedColor: AppColors.adminColor,
                                labelStyle: TextStyle(
                                  color: _selectedCategories.contains(normalized)
                                      ? Colors.white
                                      : primaryText,
                                ),
                              );
                            },
                          )
                          .toList(),
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

                    // Save button
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
    );
  }
}
