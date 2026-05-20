import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../shared/models/location_model.dart';
import '../../models/request_item.dart';
import '../../providers/request_provider.dart';
import '../../../../core/providers/notification_provider.dart';
import '../../../../core/storage/storage_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

// Import Reusable Presentation Widgets
import '../widgets/request_type_toggle.dart';
import '../widgets/category_selector.dart';
import '../widgets/quantity_unit_selector.dart';
import '../widgets/image_upload_grid.dart';
import '../widgets/manual_add_sheet.dart';
import '../widgets/shopping_list_builder.dart';
import '../widgets/sticky_submit_bar.dart';
import '../widgets/review_request_sheet.dart';



class CreateRequestScreen extends ConsumerStatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  ConsumerState<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends ConsumerState<CreateRequestScreen> {
  // Navigation Steps Progress Indicator: Location -> Items -> Review -> Submit
  // progress index: 0 = Editing, 1 = Review Sheet Active, 2 = Submitting, 3 = Finished
  int _progressStep = 0;

  // Form Fields State
  RequestType _requestType = RequestType.single;
  LocationModel _selectedLocation = LocationModel.sriLankanLocations[1]; // Colombo 03 default
  final _addressController = TextEditingController(text: '45 Galle Rd, Colombo 03');
  
  // Single Item Form State
  String? _singleCategory;
  final _singleNameController = TextEditingController();
  int _singleQuantity = 1;
  String? _singleUnit = 'kg';
  String? _singleCustomUnitNote;
  final _singleBrandController = TextEditingController();
  final _singleDescController = TextEditingController();
  List<String> _singleImageUrls = [];

  // Multiple Items Form State
  List<RequestItem> _multipleItemsList = [];
  bool _isMixedCategory = false;
  String _globalCategory = 'Groceries';
  bool _isDetectingLocation = false;

  Future<void> _detectLocationWithGPS() async {
    setState(() => _isDetectingLocation = true);

    try {
      final status = await ph.Permission.location.request();
      if (status.isGranted) {
        // Retrieve dynamic GPS coordinates with a 5-second timeout to prevent emulator hangs
        final Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );

        final nearest = LocationModel.findNearest(position.latitude, position.longitude);

        setState(() {
          _selectedLocation = nearest;
          _addressController.text = 'GPS Located: Lat ${position.latitude.toStringAsFixed(4)}, Lon ${position.longitude.toStringAsFixed(4)}';
        });

        _saveDraft();

        if (mounted) {
          ref.read(notificationProvider.notifier).triggerNotification(
            title: 'GPS Location Detected!',
            body: 'Matched closest delivery suburb: ${nearest.name}',
            icon: Icons.gps_fixed_rounded,
            color: AppColors.customerColor,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied. Please enable location settings.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      // Fallback for emulators/systems without direct GPS access to Galle Face coordinates (Colombo 03)
      final nearest = LocationModel.findNearest(6.9271, 79.8485);
      setState(() {
        _selectedLocation = nearest;
        _addressController.text = 'Colombo 03 (GPS Simulated Fallback)';
      });
      _saveDraft();

      if (mounted) {
        ref.read(notificationProvider.notifier).triggerNotification(
          title: 'GPS Location Simulated!',
          body: 'System simulated high-accuracy location at Colombo 03.',
          icon: Icons.location_searching_rounded,
          color: AppColors.customerColor,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDetectingLocation = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Load local draft on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoadDraft();
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    _singleNameController.dispose();
    _singleBrandController.dispose();
    _singleDescController.dispose();
    super.dispose();
  }

  // ── Draft Local Storage Methods ──────────────────────────────────────────

  Future<void> _checkAndLoadDraft() async {
    try {
      final draft = await StorageService.getDraftRequest();
      if (draft != null && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Resume Draft?'),
            content: const Text('You have an unfinished shopping request. Would you like to restore it?'),
            actions: [
              TextButton(
                onPressed: () {
                  StorageService.clearDraftRequest();
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Discard'),
              ),
              TextButton(
                onPressed: () {
                  _restoreDraftState(draft);
                  Navigator.pop(context);
                },
                child: const Text('Resume'),
              ),
            ],
          ),
        );
      }
    } catch (_) {}
  }

  void _saveDraft() {
    // Only save when editing step is active
    if (_progressStep != 0) return;

    List<Map<String, dynamic>> itemsJson = [];
    if (_requestType == RequestType.single) {
      if (_singleCategory != null && _singleNameController.text.trim().isNotEmpty) {
        String finalUnit = _singleUnit ?? 'pieces';
        if (_singleUnit == 'size-based note' || _singleUnit == 'custom unit') {
          if (_singleCustomUnitNote != null && _singleCustomUnitNote!.trim().isNotEmpty) {
            finalUnit = '$_singleUnit: ${_singleCustomUnitNote!.trim()}';
          }
        }

        final singleItem = RequestItem(
          id: const Uuid().v4(),
          itemName: _singleNameController.text.trim(),
          quantity: _singleQuantity,
          unit: finalUnit,
          category: _singleCategory,
          preferredBrand: _singleBrandController.text.trim(),
          description: _singleDescController.text.trim(),
          imageUrls: _singleImageUrls,
        );
        itemsJson.add(singleItem.toJson());
      }
    } else {
      itemsJson = _multipleItemsList.map((i) => i.toJson()).toList();
    }

    final draftMap = {
      'requestType': _requestType.name,
      'locationName': _selectedLocation.name,
      'deliveryAddress': _addressController.text.trim(),
      'singleCategory': _singleCategory,
      'singleName': _singleNameController.text.trim(),
      'singleQty': _singleQuantity,
      'singleUnit': _singleUnit,
      'singleCustomUnitNote': _singleCustomUnitNote,
      'singleBrand': _singleBrandController.text.trim(),
      'singleDesc': _singleDescController.text.trim(),
      'singleImageUrls': _singleImageUrls,
      'multipleItems': itemsJson,
      'isMixedCategory': _isMixedCategory,
      'globalCategory': _globalCategory,
    };

    StorageService.saveDraftRequest(draftMap);
  }

  void _restoreDraftState(Map<String, dynamic> draft) {
    setState(() {
      _requestType = draft['requestType'] == 'multiple' ? RequestType.multiple : RequestType.single;
      
      final locName = draft['locationName'] as String?;
      if (locName != null) {
        _selectedLocation = LocationModel.sriLankanLocations.firstWhere(
          (loc) => loc.name == locName,
          orElse: () => LocationModel.sriLankanLocations[1],
        );
      }
      _addressController.text = draft['deliveryAddress'] as String? ?? '';

      // Restore Single Item fields
      _singleCategory = draft['singleCategory'] as String?;
      _singleNameController.text = draft['singleName'] as String? ?? '';
      _singleQuantity = draft['singleQty'] as int? ?? 1;
      _singleUnit = draft['singleUnit'] as String? ?? 'kg';
      _singleCustomUnitNote = draft['singleCustomUnitNote'] as String?;
      _singleBrandController.text = draft['singleBrand'] as String? ?? '';
      _singleDescController.text = draft['singleDesc'] as String? ?? '';
      _singleImageUrls = List<String>.from(draft['singleImageUrls'] as List? ?? []);

      // Restore Multiple Item fields
      _isMixedCategory = draft['isMixedCategory'] as bool? ?? false;
      _globalCategory = draft['globalCategory'] as String? ?? 'Groceries';
      
      final multItems = draft['multipleItems'] as List? ?? [];
      _multipleItemsList = multItems.map((itemJson) => RequestItem.fromJson(itemJson as Map<String, dynamic>)).toList();
    });
  }

  // ── Form Submissions & Review Sheets ──────────────────────────────────────

  bool _hasLocation() {
    return _selectedLocation.name.isNotEmpty && _addressController.text.trim().isNotEmpty;
  }

  List<RequestItem> _getActiveItems() {
    if (_requestType == RequestType.single) {
      if (_singleCategory == null || _singleNameController.text.trim().isEmpty) {
        return [];
      }
      String finalUnit = _singleUnit ?? 'pieces';
      if (_singleUnit == 'size-based note' || _singleUnit == 'custom unit') {
        if (_singleCustomUnitNote != null && _singleCustomUnitNote!.trim().isNotEmpty) {
          finalUnit = '$_singleUnit: ${_singleCustomUnitNote!.trim()}';
        }
      }

      return [
        RequestItem(
          id: const Uuid().v4(),
          itemName: _singleNameController.text.trim(),
          quantity: _singleQuantity,
          unit: finalUnit,
          category: _singleCategory,
          preferredBrand: _singleBrandController.text.trim(),
          description: _singleDescController.text.trim(),
          imageUrls: _singleImageUrls,
        )
      ];
    } else {
      return _multipleItemsList;
    }
  }

  bool _hasMissingRequiredFields() {
    final items = _getActiveItems();
    if (items.isEmpty) return true;
    for (final i in items) {
      if (i.itemName.trim().isEmpty || i.quantity <= 0) return true;
    }
    return false;
  }

  void _triggerReviewSheet() {
    setState(() {
      _progressStep = 1; // Review Step
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReviewRequestSheet(
        customerArea: _selectedLocation.name,
        deliveryAddress: _addressController.text.trim(),
        items: _getActiveItems(),
        isLoading: ref.watch(requestProvider).isLoading,
        onConfirm: _submitRequest,
      ),
    ).then((_) {
      if (mounted && _progressStep == 1) {
        setState(() {
          _progressStep = 0; // Return to editing
        });
      }
    });
  }

  Future<void> _submitRequest() async {
    final activeItems = _getActiveItems();
    if (activeItems.isEmpty || !_hasLocation()) return;

    setState(() {
      _progressStep = 2; // Submitting step
    });

    try {
      await ref.read(requestProvider.notifier).createRequest(
        items: activeItems,
        customerArea: _selectedLocation.name,
        deliveryAddress: _addressController.text.trim(),
        latitude: _selectedLocation.latitude,
        longitude: _selectedLocation.longitude,
      );

      // Clear draft since it is successfully submitted
      StorageService.clearDraftRequest();

      if (mounted) {
        setState(() {
          _progressStep = 3; // Finished step
        });

        // Dismiss the Review Modal Sheet
        Navigator.pop(context);

        // Trigger in-app notifications
        ref.read(notificationProvider.notifier).triggerNotification(
          title: 'Request Active!',
          body: 'Your list has been dispatched to nearby vendors within 20km.',
          icon: Icons.check_circle_rounded,
          color: AppColors.customerColor,
        );

        // Simulate vendor dispatch after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          ref.read(notificationProvider.notifier).triggerNotification(
            title: 'New Request Nearby!',
            body: 'A customer in ${_selectedLocation.name} submitted a list of ${activeItems.length} items.',
            icon: Icons.storefront_rounded,
            color: AppColors.vendorColor,
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request dispatched successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _progressStep = 0; // Reset back to editing
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }



  void _showAddItemManualSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ManualAddSheet(
        onAdd: (item) {
          setState(() {
            _multipleItemsList = [..._multipleItemsList, item];
          });
          _saveDraft();
        },
      ),
    );
  }

  // ── Back Navigation Confirm Pop ──────────────────────────────────────────

  Future<void> _confirmPop() async {
    final activeItems = _getActiveItems();
    if (activeItems.isEmpty) {
      if (mounted) context.pop();
      return;
    }
    final nav = Navigator.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Unsaved Changes Exist'),
        content: const Text('Would you like to save this request as a draft or discard it?'),
        actions: [
          TextButton(
            onPressed: () {
              StorageService.clearDraftRequest();
              Navigator.pop(dialogCtx, true);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () {
              _saveDraft();
              Navigator.pop(dialogCtx, true);
            },
            child: const Text('Save Draft'),
          ),
        ],
      ),
    );
    if ((confirm ?? false) && mounted) {
      nav.pop();
    }
  }

  // ── Build Progress Bar Widget ─────────────────────────────────────────────

  Widget _buildProgressBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isDark ? AppColors.surfaceDark : Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildProgressNode(0, 'Location', true),
          _buildProgressLine(true),
          _buildProgressNode(1, 'Items', _getActiveItems().isNotEmpty),
          _buildProgressLine(_getActiveItems().isNotEmpty),
          _buildProgressNode(2, 'Review', _progressStep >= 1),
          _buildProgressLine(_progressStep >= 2),
          _buildProgressNode(3, 'Submit', _progressStep == 3),
        ],
      ),
    );
  }

  Widget _buildProgressNode(int index, String label, bool active) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final nodeColor = active ? AppColors.customerColor : (isDark ? Colors.grey.shade800 : Colors.grey.shade300);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: active ? AppColors.customerColor : Colors.transparent,
            border: Border.all(color: nodeColor, width: 2),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: active
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
                  '${index + 1}',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: secondaryText),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.caption(active ? AppColors.customerColor : secondaryText).copyWith(
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressLine(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 14, left: 4, right: 4),
        color: active ? AppColors.customerColor : Colors.grey.shade300,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final isLoading = ref.watch(requestProvider).isLoading;

    // Configure system status bar colors & icons dynamically
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    ));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmPop();
      },
      child: Container(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        child: SafeArea(
          bottom: false,
          child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        appBar: AppBar(
          title: const Text('Create Shopping Request'),
          backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _confirmPop,
          ),
        ),
        body: Column(
          children: [
            // STEP PROGRESS INDICATOR
            _buildProgressBar(),
            const Divider(height: 1),

            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Geolocation compact card section
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, color: AppColors.customerColor, size: 20),
                              const SizedBox(width: 8),
                              Text('Delivery Location', style: AppTextStyles.subtitle(primaryText)),
                              const Spacer(),
                              if (_isDetectingLocation)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.customerColor,
                                  ),
                                )
                              else
                                TextButton.icon(
                                  onPressed: _detectLocationWithGPS,
                                  icon: const Icon(Icons.my_location_rounded, size: 14, color: AppColors.customerColor),
                                  label: const Text('Detect GPS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.customerColor)),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    backgroundColor: AppColors.customerColor.withOpacity(0.08),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<LocationModel>(
                            initialValue: _selectedLocation,
                            dropdownColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                            decoration: InputDecoration(
                              labelText: 'Nearest Suburb / City (approximate area shown to vendors)',
                              labelStyle: TextStyle(color: secondaryText, fontSize: 12),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              filled: true,
                              fillColor: isDark ? Colors.black12 : Colors.grey.shade50,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                            ),
                            items: LocationModel.sriLankanLocations.map((loc) {
                              return DropdownMenuItem<LocationModel>(
                                value: loc,
                                child: Text(loc.name, style: AppTextStyles.bodyMedium(primaryText)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedLocation = val;
                                  _addressController.text = 'Galle Face Green Residences, ${val.name}';
                                });
                                _saveDraft();
                              }
                            },
                          ),
                          const SizedBox(height: 10),
                          AppTextField(
                            controller: _addressController,
                            label: 'Precise Delivery Address (hidden until payment/order confirmation)',
                            hint: 'e.g. House No 45, Flower Street...',
                            onChanged: (_) => _saveDraft(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Request Type Segmented Toggle
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: RequestTypeToggle(
                        selectedType: _requestType,
                        onChanged: (type) {
                          setState(() {
                            _requestType = type;
                            // Clean catalog toggles
                            _singleCategory = null;
                            _multipleItemsList = [];
                          });
                          _saveDraft();
                        },
                      ),
                    ),
                  ),

                  // SINGLE ITEM FLOW
                  if (_requestType == RequestType.single) ...[
                    // Category First Selector
                    if (_singleCategory == null)
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Step 1: Choose Item Category', style: AppTextStyles.subtitle(primaryText)),
                              const SizedBox(height: 4),
                              Text('Select the main category before typing item specifications.', style: AppTextStyles.caption(secondaryText)),
                              const SizedBox(height: 16),
                              CategorySelector(
                                selectedCategory: _singleCategory,
                                onSelected: (cat) {
                                  setState(() {
                                    _singleCategory = cat;
                                    _singleUnit = cat == 'Groceries' ? 'kg' : 'pieces';
                                    _singleCustomUnitNote = null;
                                  });
                                  _saveDraft();
                                },
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverToBoxAdapter(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top selected category summary (with Reset Button to achieve Category First requirement)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: AppColors.customerColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _singleCategory!,
                                          style: AppTextStyles.labelMedium(AppColors.customerColor).copyWith(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.refresh, size: 14),
                                    label: const Text('Change Category'),
                                    onPressed: () {
                                      setState(() {
                                        _singleCategory = null;
                                        _singleNameController.clear();
                                        _singleImageUrls = [];
                                      });
                                      _saveDraft();
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: secondaryText,
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),

                              Text('Step 2: Enter Item Details', style: AppTextStyles.subtitle(primaryText)),
                              const SizedBox(height: 12),

                              AppTextField(
                                controller: _singleNameController,
                                label: 'Item Name',
                                hint: 'e.g. Red onions 500g, Exide Battery...',
                                onChanged: (_) => _saveDraft(),
                              ),
                              const SizedBox(height: 16),

                              QuantityUnitSelector(
                                category: _singleCategory,
                                quantity: _singleQuantity,
                                unit: _singleUnit,
                                customUnitNote: _singleCustomUnitNote,
                                onQuantityChanged: (val) {
                                  setState(() => _singleQuantity = val);
                                  _saveDraft();
                                },
                                onUnitChanged: (val) {
                                  setState(() => _singleUnit = val);
                                  _saveDraft();
                                },
                                onCustomUnitNoteChanged: (val) {
                                  setState(() => _singleCustomUnitNote = val);
                                  _saveDraft();
                                },
                              ),
                              const SizedBox(height: 16),

                              AppTextField(
                                controller: _singleBrandController,
                                label: 'Preferred Brand / Model (Optional)',
                                hint: 'e.g. Prima, Singer, Anchor',
                                onChanged: (_) => _saveDraft(),
                              ),
                              const SizedBox(height: 16),

                              AppTextField(
                                controller: _singleDescController,
                                label: 'Description / Remarks (Optional)',
                                hint: 'Any specific instructions...',
                                maxLines: 3,
                                onChanged: (_) => _saveDraft(),
                              ),
                              const SizedBox(height: 16),

                              ImageUploadGrid(
                                category: _singleCategory,
                                imageUrls: _singleImageUrls,
                                onImagesChanged: (list) {
                                  setState(() => _singleImageUrls = list);
                                  _saveDraft();
                                },
                              ),
                            ],
                          ),
                        ),
                      )
                  ],

                  // MULTIPLE ITEMS FLOW
                  if (_requestType == RequestType.multiple) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Shopping List builder',
                              style: AppTextStyles.caption(secondaryText),
                            ),
                            TextButton.icon(
                              onPressed: _showAddItemManualSheet,
                              icon: const Icon(Icons.add_rounded, color: AppColors.customerColor, size: 20),
                              label: Text('Manual Add', style: AppTextStyles.button(AppColors.customerColor)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                backgroundColor: AppColors.customerColor.withOpacity(0.08),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ShoppingListBuilder(
                          items: _multipleItemsList,
                          isMixedCategory: _isMixedCategory,
                          globalCategory: _globalCategory,
                          onItemsChanged: (list) {
                            setState(() {
                              _multipleItemsList = list;
                            });
                            _saveDraft();
                          },
                          onModeChanged: (val) {
                            setState(() {
                              _isMixedCategory = val;
                            });
                            _saveDraft();
                          },
                          onGlobalCategoryChanged: (cat) {
                            setState(() {
                              _globalCategory = cat;
                            });
                            _saveDraft();
                          },
                        ),
                      ),
                    ),
                  ],

                  // Bottom spacing to clear the sticky submit bar
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),

                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: StickySubmitBar(
          totalItems: _getActiveItems().length,
          hasLocation: _hasLocation(),
          hasMissingRequiredFields: _hasMissingRequiredFields(),
          isLoading: isLoading,
          onSubmit: _triggerReviewSheet,
        ),
      ),
    ),
  ),
);
}
}
