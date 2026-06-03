import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../shared/models/location_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../location/data/sri_lanka_data.dart';
import '../../../location/models/sri_lanka_district.dart';
import '../../../location/models/sri_lanka_province.dart';

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

  late SriLankaProvince? _selectedProvince;
  late SriLankaDistrict? _selectedDistrict;
  late List<String> _selectedCategories;
  late bool _isApproved;
  bool _isSaving = false;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Prefill from vendor-submitted data
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

    _selectedProvince = null;
    _selectedDistrict = null;
    _selectedCategories = List<String>.from(widget.vendor.vendorCategories ?? []);
    _isApproved = widget.vendor.vendorApproved ?? false;
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

    debugPrint('[AdminVendor] Submitted categories: ${widget.vendor.vendorCategories}');
    debugPrint('[AdminVendor] Selected categories before save: $_selectedCategories');

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
      debugPrint('[AdminVendor] Saving allowedCategories: $_selectedCategories');

      // Update vendor fields
      final authNotifier = ref.read(authProvider.notifier);
      await authNotifier.updateVendorShopAssignment(
        vendorId: widget.vendor.id,
        shopName: _shopNameCtrl.text.trim(),
        shopAddress: _shopAddressCtrl.text.trim(),
        shopLatitude: double.parse(_latitudeCtrl.text.trim()),
        shopLongitude: double.parse(_longitudeCtrl.text.trim()),
        assignedRadiusKm: double.parse(_radiusCtrl.text.trim()),
        vendorApproved: _isApproved,
        allowedCategories: _selectedCategories,
      );

      debugPrint('[AdminVendor] Saved vendor allowedCategories: $_selectedCategories');

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
      body: _isSaving
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

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _latitudeCtrl.text = '6.9271';
                          _longitudeCtrl.text = '80.7789';
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Test coordinates (Colombo) set'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.my_location_rounded),
                        label: const Text('Use Test Coordinates'),
                      ),
                    ),
                    const SizedBox(height: 16),

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

                    // Categories
                    Text(
                      'Allowed Categories',
                      style: AppTextStyles.h3(primaryText),
                    ),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'Groceries',
                        'Electronics',
                        'Hardware',
                        'Furniture',
                        'Pharmacy',
                        'Clothing',
                        'Vehicle Parts',
                        'Home Appliances',
                      ]
                          .map(
                            (cat) => FilterChip(
                              label: Text(cat.toLowerCase()),
                              selected:
                                  _selectedCategories.contains(cat.toLowerCase()),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedCategories.add(cat.toLowerCase());
                                  } else {
                                    _selectedCategories.remove(cat.toLowerCase());
                                  }
                                });
                              },
                              selectedColor: AppColors.adminColor,
                              labelStyle: TextStyle(
                                color: _selectedCategories
                                        .contains(cat.toLowerCase())
                                    ? Colors.white
                                    : primaryText,
                              ),
                            ),
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
