import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/routes/route_names.dart';

import '../../models/request_item.dart';
import '../../providers/request_provider.dart';
import '../../providers/draft_provider.dart';
import '../../../../core/providers/notification_provider.dart';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:speedmart_lanka/features/location/providers/location_provider.dart';
import 'package:speedmart_lanka/features/location/models/delivery_location.dart';
import 'package:speedmart_lanka/features/location/services/location_service.dart';
import 'package:speedmart_lanka/features/location/widgets/searchable_location_field.dart';

// Import Reusable Presentation Widgets
import '../widgets/request_type_toggle.dart';
import '../widgets/category_selector.dart';
import '../widgets/quantity_unit_selector.dart';
import '../widgets/image_upload_grid.dart';
import '../widgets/manual_add_sheet.dart';
import '../widgets/shopping_list_builder.dart';
import '../widgets/sticky_submit_bar.dart';
import '../widgets/review_request_sheet.dart';
import 'package:speedmart_lanka/features/requests/presentation/widgets/phone_verification_sheet.dart';
import 'package:speedmart_lanka/features/auth/providers/auth_provider.dart';
import 'package:speedmart_lanka/features/requests/data/sri_lanka_delivery_detector.dart';
import 'package:speedmart_lanka/features/customer/delivery_address/providers/customer_delivery_address_provider.dart';
import 'package:speedmart_lanka/features/customer/delivery_address/presentation/widgets/delivery_address_summary_card.dart';
import 'package:speedmart_lanka/features/customer/delivery_address/presentation/widgets/confirm_delivery_address_sheet.dart';



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
  late final TextEditingController _suburbSearchController;
  late final TextEditingController _addressController;
  late final FocusNode _suburbFocusNode;

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
  bool _isSubmitting = false;
  bool _deliveryAddressReady = false;

  @override
  void initState() {
    super.initState();
    _suburbFocusNode = FocusNode();
    _suburbFocusNode.addListener(() {
      if (!_suburbFocusNode.hasFocus) {
        // Delay hiding suggestions so tap events on suggestions can fire first
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_suburbFocusNode.hasFocus) {
            // Suggestion state removed
          }
        });
      }
    });
    final locationState = ref.read(deliveryLocationProvider);
    _suburbSearchController = TextEditingController(
      text: locationState.currentLocation != null ? locationState.displayArea : '',
    );
    _addressController = TextEditingController(
      text: locationState.streetAddress,
    );
    _addressController.addListener(() {
      final text = _addressController.text.trim();
      ref.read(deliveryLocationProvider.notifier).updateStreetAddress(text);
      _saveDraft();
    });
    _singleNameController.addListener(() {
      if (mounted) {
        setState(() {});
      }
      _saveDraft();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkAndLoadDraft();
      await _loadDefaultDeliveryAddress();
    });
  }

  @override
  void dispose() {
    _suburbSearchController.dispose();
    _addressController.dispose();
    _suburbFocusNode.dispose();
    _singleNameController.dispose();
    _singleBrandController.dispose();
    _singleDescController.dispose();
    super.dispose();
  }

  // ── Draft Local Storage Methods ──────────────────────────────────────────

  bool _isFormDirty() {
    return DraftService.isFormDirty(
      deliveryLocation: ref.read(deliveryLocationProvider).currentLocation,
      suburbText: _suburbSearchController.text.trim(),
      addressText: _addressController.text.trim(),
      requestTypeName: _requestType.name,
      singleCategory: _singleCategory,
      singleName: _singleNameController.text.trim(),
      singleQuantity: _singleQuantity,
      singleBrand: _singleBrandController.text.trim(),
      singleDesc: _singleDescController.text.trim(),
      singleImageUrls: _singleImageUrls,
      multipleItems: _multipleItemsList,
    );
  }

  Future<void> _checkAndLoadDraft() async {
    try {
      final draft = await DraftService.loadDraft();
      if (draft != null && DraftService.hasValidDraft(draft) && mounted) {
        final String? action = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) {
            final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
            final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
            final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              icon: Icon(
                Icons.restore_page_rounded,
                size: 40,
                color: AppColors.customerColor,
              ),
              title: Text(
                'Resume draft?',
                style: TextStyle(color: primaryText, fontWeight: FontWeight.bold),
              ),
              content: Text(
                'You have an unfinished shopping request. Do you want to continue where you left off?',
                style: TextStyle(color: secondaryText),
                textAlign: TextAlign.center,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, 'new'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Start New'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogCtx, 'resume'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.customerColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Resume Draft'),
                ),
              ],
            );
          },
        );

        if (action == 'resume' && mounted) {
          _restoreDraftState(draft);
        } else if (action == 'new' && mounted) {
          await DraftService.clearDraft();
          if (!mounted) return;
          ref.read(deliveryLocationProvider.notifier).clearLocation();
          setState(() {
            _suburbSearchController.clear();
            _addressController.clear();
            _singleCategory = null;
            _singleNameController.clear();
            _singleQuantity = 1;
            _singleUnit = 'kg';
            _singleCustomUnitNote = null;
            _singleBrandController.clear();
            _singleDescController.clear();
            _singleImageUrls = [];
            _multipleItemsList = [];
            _isMixedCategory = false;
            _globalCategory = 'Groceries';
          });
        }
      } else {
        if (draft != null) {
          await DraftService.clearDraft();
        }
      }
    } catch (_) {}
  }

  void _saveDraft() {
    // Only save when editing step is active
    if (_progressStep != 0) return;

    if (!_isFormDirty()) {
      DraftService.clearDraft();
      return;
    }

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

    final locationState = ref.read(deliveryLocationProvider);
    // Only persist location data when the user has actually entered an area.
    // This prevents empty/mock location objects from being saved to the draft.
    final hasRealArea = _suburbSearchController.text.trim().isNotEmpty ||
        (locationState.currentLocation != null &&
            (locationState.suburb.isNotEmpty ||
                locationState.currentLocation!.approximateAreaText.isNotEmpty));
    final hasRealAddress = _addressController.text.trim().isNotEmpty;
    final draftMap = {
      'requestType': _requestType.name,
      'deliveryLocation': hasRealArea ? locationState.currentLocation?.toJson() : null,
      'deliveryAddress': hasRealAddress ? _addressController.text.trim() : null,
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

    DraftService.saveDraft(draftMap);
  }

  void _restoreDraftState(Map<String, dynamic> draft) {
    setState(() {
      _requestType = draft['requestType'] == 'multiple' ? RequestType.multiple : RequestType.single;
      
      DeliveryLocation? loadedLocation;
      if (draft['deliveryLocation'] != null) {
        loadedLocation = DeliveryLocation.fromJson(draft['deliveryLocation'] as Map<String, dynamic>);
      } else {
        final locName = draft['locationName'] as String?;
        if (locName != null && locName.isNotEmpty) {
          // Try to match against known suburbs; if not found, use the name as manual text
          final matches = LocationService.sriLankanLocations.where(
            (loc) => loc.name == locName,
          );
          if (matches.isNotEmpty) {
            loadedLocation = LocationService.selectSuburb(matches.first);
          } else {
            // Unknown area — create a manual-source location
            loadedLocation = DeliveryLocation(
              province: '',
              district: '',
              city: '',
              suburb: locName,
              formattedAddress: locName,
              streetAddress: '',
              approximateAreaText: locName,
              source: 'manual',
              isManualOverride: true,
            );
          }
        }
      }

      if (loadedLocation != null) {
        ref.read(deliveryLocationProvider.notifier).setLocation(loadedLocation);
        _suburbSearchController.text = loadedLocation.displayArea;
        _addressController.text = draft['deliveryAddress'] as String? ?? loadedLocation.streetAddress;
      } else {
        _suburbSearchController.text = '';
        _addressController.text = '';
      }

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

  Future<void> _loadDefaultDeliveryAddress() async {
    await ref.read(customerDeliveryAddressProvider.notifier).loadForCurrentUser();
    final addrState = ref.read(customerDeliveryAddressProvider);
    if (addrState.hasSavedAddress && ref.read(deliveryLocationProvider).currentLocation == null) {
      await ref.read(customerDeliveryAddressProvider.notifier).applyActiveLocationToProvider();
      final loc = ref.read(deliveryLocationProvider).currentLocation;
      if (loc != null) {
        _suburbSearchController.text = loc.approximateAreaText.isNotEmpty
            ? loc.approximateAreaText
            : loc.displayArea;
        _addressController.text = loc.streetAddress;
      }
    }
    if (mounted) setState(() => _deliveryAddressReady = true);
  }

  Future<void> _openDeliveryAddressEditor() async {
    final result = await context.push<DeliveryLocation>(
      RouteNames.customerDeliveryAddress,
      extra: {'fromCreateRequest': true},
    );
    if (result != null && mounted) {
      ref.read(deliveryLocationProvider.notifier).setLocation(result);
      _suburbSearchController.text = result.approximateAreaText.isNotEmpty
          ? result.approximateAreaText
          : result.displayArea;
      _addressController.text = result.streetAddress;
      _saveDraft();
      setState(() {});
    }
  }

  // ── Form Submissions & Review Sheets ──────────────────────────────────────

  bool _hasLocation() {
    final loc = ref.read(deliveryLocationProvider).currentLocation;
    if (loc == null) return false;
    final area = loc.approximateAreaText.isNotEmpty
        ? loc.approximateAreaText
        : loc.displayArea;
    return loc.province.trim().isNotEmpty &&
        loc.district.trim().isNotEmpty &&
        area.trim().isNotEmpty &&
        loc.streetAddress.trim().isNotEmpty;
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

  String _reviewSuburbOrCity() {
    final typed = _suburbSearchController.text.trim();
    if (typed.isNotEmpty) return typed;

    final locationState = ref.read(deliveryLocationProvider);
    final display = locationState.displayArea.trim();
    if (display.isNotEmpty) return display;

    final suburb = locationState.suburb.trim();
    if (suburb.isNotEmpty) return suburb;

    return 'Not provided';
  }

  void _triggerReviewSheet() {
    if (!_hasLocation()) return;

    setState(() {
      _progressStep = 1;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReviewRequestSheet(
        suburbOrCity: _reviewSuburbOrCity(),
        items: _getActiveItems(),
        isLoading: _isSubmitting,
        onConfirm: () {
          Navigator.pop(context);
          _showConfirmDeliveryAddress();
        },
      ),
    ).then((_) {
      if (mounted && _progressStep == 1) {
        setState(() => _progressStep = 0);
      }
    });
  }

  void _showConfirmDeliveryAddress() {
    final loc = ref.read(deliveryLocationProvider).currentLocation;
    if (loc == null) return;

    ConfirmDeliveryAddressSheet.show(
      context,
      location: loc,
      isLoading: _isSubmitting,
      onChangeAddress: () {
        Navigator.pop(context);
        _openDeliveryAddressEditor();
      },
      onConfirm: () {
        Navigator.pop(context);
        _submitRequest();
      },
    );
  }

  Widget _buildDeliveryLocationSection({
    required Color cardColor,
    required Color borderColor,
    required Color primaryText,
    required Color secondaryText,
  }) {
    final addrState = ref.watch(customerDeliveryAddressProvider);
    final loc = ref.watch(deliveryLocationProvider).currentLocation;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  color: AppColors.customerColor, size: 20),
              const SizedBox(width: 8),
              Text('Delivery Location',
                  style: AppTextStyles.subtitle(primaryText)),
            ],
          ),
          const SizedBox(height: 12),
          if (!_deliveryAddressReady || addrState.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (loc != null && _hasLocation())
            DeliveryAddressSummaryCard(
              location: loc,
              isRequestOnly: addrState.requestOnlyLocation != null,
              onChange: _openDeliveryAddressEditor,
            )
          else ...[
            Text(
              'Add your delivery address to continue.',
              style: AppTextStyles.bodyMedium(secondaryText),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openDeliveryAddressEditor,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Add Delivery Address'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.customerColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (_isSubmitting) return;

    final activeItems = _getActiveItems();
    if (activeItems.isEmpty || !_hasLocation()) return;

    // ── Phone verification gatekeeping ──────────────────────────────────────
    // International / country-override customers must verify a phone number
    // before submitting shopping requests for Sri Lankan delivery addresses.
    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null) {
      final isOtherCountry = currentUser.selectedCountry == 'OTHER';
      final needsPhoneVerification = isOtherCountry;

      if (needsPhoneVerification && currentUser.verifiedPhone != true) {
        final locationState = ref.read(deliveryLocationProvider);
        final isSriLankanDelivery =
            SriLankaDeliveryDetector.isSriLankanDelivery(
                locationState.currentLocation);

        if (isSriLankanDelivery) {
          // Block submission — show phone verification dialog
          final verified = await _showPhoneVerificationGate();
          if (!mounted) return; // widget may have been disposed during dialog
          if (!verified) return; // User cancelled
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
      _progressStep = 2; // Submitting step
    });

    final requestNotifier = ref.read(requestProvider.notifier);
    final deliveryNotifier = ref.read(deliveryLocationProvider.notifier);
    final notifNotifier = ref.read(notificationProvider.notifier);

    try {
      final locationState = ref.read(deliveryLocationProvider);
      final location = locationState.currentLocation;
      if (location == null) {
        throw Exception('Delivery location is missing.');
      }

      final updatedLocation = location.copyWith(
        streetAddress: _addressController.text.trim(),
      );
      deliveryNotifier.setLocation(updatedLocation);

      final suburbName = updatedLocation.suburb.isNotEmpty
          ? updatedLocation.suburb
          : updatedLocation.approximateAreaText;
      final itemCount = activeItems.length;

      await requestNotifier.createRequest(
        items: activeItems,
        customerArea: suburbName,
        deliveryAddress: updatedLocation.streetAddress,
        latitude: updatedLocation.latitude ?? 0.0,
        longitude: updatedLocation.longitude ?? 0.0,
        deliveryLocation: updatedLocation,
      );

      if (!mounted) return;

      await DraftService.clearDraft();

      if (!mounted) return;

      setState(() {
        _progressStep = 3; // Finished step
        _isSubmitting = false;
      });

      Navigator.pop(context);

      notifNotifier.triggerNotification(
        title: 'Request Active!',
        body: 'Your list has been dispatched to nearby vendors within 20km.',
        icon: Icons.check_circle_rounded,
        color: AppColors.customerColor,
      );

      Future.delayed(const Duration(seconds: 2), () {
        notifNotifier.triggerNotification(
          title: 'New Request Nearby!',
          body: 'A customer in $suburbName submitted a list of $itemCount items.',
          icon: Icons.storefront_rounded,
          color: AppColors.vendorColor,
        );
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request dispatched successfully!')),
      );
      deliveryNotifier.clearLocation();
      context.go(RouteNames.customerHome);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _progressStep = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<bool> _showPhoneVerificationGate() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
        final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Icon(
            Icons.phone_locked_rounded,
            size: 40,
            color: AppColors.customerColor,
          ),
          title: Text(
            'Phone verification required',
            style: TextStyle(color: primaryText, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'To submit shopping requests for delivery in Sri Lanka, please verify a mobile phone number.',
            style: TextStyle(color: secondaryText),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              style: TextButton.styleFrom(foregroundColor: secondaryText),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.customerColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Verify Phone Number'),
            ),
          ],
        );
      },
    );

    if (result != true) return false;

    // Show bottom sheet
    if (!mounted) return false;
    if (!mounted) return false;
    final verified = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => PhoneVerificationSheet(
        onVerified: (_) {
          if (Navigator.of(sheetCtx).canPop()) {
            Navigator.of(sheetCtx).pop(true);
          }
        },
      ),
    );

    return verified == true;
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
    if (!_isFormDirty()) {
      ref.read(deliveryLocationProvider.notifier).clearLocation();
      if (mounted) context.go(RouteNames.customerHome);
      return;
    }

    final String? action = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
        final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Icon(
            Icons.drafts_rounded,
            size: 40,
            color: AppColors.customerColor,
          ),
          title: Text(
            'Save this request as draft?',
            style: TextStyle(color: primaryText, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'You have added request details. Do you want to save them and continue later?',
            style: TextStyle(color: secondaryText),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.end,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, 'cancel'),
              style: TextButton.styleFrom(foregroundColor: secondaryText),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, 'discard'),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text("Don't Save"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, 'save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.customerColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Save as Draft'),
            ),
          ],
        );
      },
    );

    if (action == 'save') {
      _saveDraft();
      ref.read(deliveryLocationProvider.notifier).clearLocation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft saved.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go(RouteNames.customerHome);
      }
    } else if (action == 'discard') {
      await DraftService.clearDraft();
      ref.read(deliveryLocationProvider.notifier).clearLocation();
      if (mounted) {
        context.go(RouteNames.customerHome);
      }
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
    final isLoading = _isSubmitting || ref.watch(requestProvider).isLoading;

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
                   SliverToBoxAdapter(
                     child: _buildDeliveryLocationSection(
                       cardColor: cardColor,
                       borderColor: borderColor,
                       primaryText: primaryText,
                       secondaryText: secondaryText,
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
                                onChanged: (_) {}, // Handled by listener in initState
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
