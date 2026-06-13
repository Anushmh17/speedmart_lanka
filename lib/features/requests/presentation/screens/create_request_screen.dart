import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/theme3/theme3_widgets.dart';
import '../../../../core/routes/route_names.dart';

import '../../models/request_item.dart';
import '../../providers/request_provider.dart';
import '../../providers/draft_provider.dart';
import '../../../../core/providers/notification_provider.dart';

import 'package:speedmart_lanka/features/location/providers/location_provider.dart';
import 'package:speedmart_lanka/features/location/models/delivery_location.dart';
import 'package:speedmart_lanka/features/location/services/location_service.dart';

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
  int _progressStep = 0;

  RequestType _requestType = RequestType.single;
  late final TextEditingController _suburbSearchController;
  late final TextEditingController _addressController;
  late final FocusNode _suburbFocusNode;

  String? _singleCategory;
  final _singleNameController = TextEditingController();
  int _singleQuantity = 1;
  String? _singleUnit = 'kg';
  String? _singleCustomUnitNote;
  final _singleBrandController = TextEditingController();
  final _singleDescController = TextEditingController();
  List<String> _singleImageUrls = [];

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
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_suburbFocusNode.hasFocus) {
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
              shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
              icon: Icon(
                Icons.restore_page_rounded,
                size: 40,
                color: isDark ? AppColors.primaryDark : AppColors.primary,
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
                    backgroundColor: isDark ? AppColors.primaryDark : AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
                    elevation: 0,
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
          final matches = LocationService.sriLankanLocations.where(
            (loc) => loc.name == locName,
          );
          if (matches.isNotEmpty) {
            loadedLocation = LocationService.selectSuburb(matches.first);
          } else {
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

      _singleCategory = draft['singleCategory'] as String?;
      _singleNameController.text = draft['singleName'] as String? ?? '';
      _singleQuantity = draft['singleQty'] as int? ?? 1;
      _singleUnit = draft['singleUnit'] as String? ?? 'kg';
      _singleCustomUnitNote = draft['singleCustomUnitNote'] as String?;
      _singleBrandController.text = draft['singleBrand'] as String? ?? '';
      _singleDescController.text = draft['singleDesc'] as String? ?? '';
      _singleImageUrls = List<String>.from(draft['singleImageUrls'] as List? ?? []);

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

  bool _hasLocation() {
    final loc = ref.read(deliveryLocationProvider).currentLocation;
    if (loc == null) return false;
    final area = loc.approximateAreaText.isNotEmpty
        ? loc.approximateAreaText
        : loc.displayArea;
    return loc.province.trim().isNotEmpty &&
        loc.district.trim().isNotEmpty &&
        area.trim().isNotEmpty &&
        loc.streetAddress.trim().isNotEmpty &&
        loc.latitude != null &&
        loc.longitude != null &&
        loc.latitude != 0.0 &&
        loc.longitude != 0.0;
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

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Widget _buildDeliveryLocationSection({
    required Color cardColor,
    required Color borderColor,
    required Color primaryText,
    required Color secondaryText,
  }) {
    final addrState = ref.watch(customerDeliveryAddressProvider);
    final loc = ref.watch(deliveryLocationProvider).currentLocation;

    return Theme3AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      margin: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                color: isDark ? AppColors.primaryDark : AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Delivery Location',
                style: AppTextStyles.subtitle(primaryText),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (!_deliveryAddressReady || addrState.isLoading)
            const Center(child: Theme3InlineLoading())
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
            const SizedBox(height: AppSpacing.lg),
            Theme3AppButton(
              label: 'Add Delivery Address',
              onPressed: _openDeliveryAddressEditor,
              icon: Icons.add_location_alt_outlined,
              width: double.infinity,
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
          final verified = await _showPhoneVerificationGate();
          if (!mounted) return;
          if (!verified) return;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
      _progressStep = 2;
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
      if (location.latitude == null ||
          location.longitude == null ||
          location.latitude == 0.0 ||
          location.longitude == 0.0) {
        throw Exception('Please select a valid delivery location.');
      }

      final updatedLocation = location.copyWith(
        streetAddress: _addressController.text.trim(),
      );
      deliveryNotifier.setLocation(updatedLocation);

      final suburbName = updatedLocation.suburb.isNotEmpty
          ? updatedLocation.suburb
          : updatedLocation.approximateAreaText;
      final itemCount = activeItems.length;

      debugPrint('[RequestCreate] Submitting request with:');
      debugPrint('[RequestCreate] approximateArea: ${updatedLocation.approximateAreaText}');
      debugPrint('[RequestCreate] streetAddress: ${updatedLocation.streetAddress}');
      debugPrint('[RequestCreate] province: ${updatedLocation.province}');
      debugPrint('[RequestCreate] district: ${updatedLocation.district}');
      debugPrint('[RequestCreate] latitude: ${updatedLocation.latitude}');
      debugPrint('[RequestCreate] longitude: ${updatedLocation.longitude}');
      debugPrint('[RequestCreate] accuracy: ${updatedLocation.accuracy}');

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
        _progressStep = 3;
        _isSubmitting = false;
      });

      Navigator.pop(context);

      final notifIsDark = Theme.of(context).brightness == Brightness.dark;
      notifNotifier.triggerNotification(
        title: 'Request Active!',
        body: 'Your list has been dispatched to nearby vendors within 20km.',
        icon: Icons.check_circle_rounded,
        color: notifIsDark ? AppColors.primaryDark : AppColors.primary,
      );

      Future.delayed(const Duration(seconds: 2), () {
        notifNotifier.triggerNotification(
          title: 'New Request Nearby!',
          body: 'A customer in $suburbName submitted a list of $itemCount items.',
          icon: Icons.storefront_rounded,
          color: AppColors.info,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
          icon: Icon(
            Icons.phone_locked_rounded,
            size: 40,
            color: isDark ? AppColors.primaryDark : AppColors.primary,
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
                backgroundColor: isDark ? AppColors.primaryDark : AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
                elevation: 0,
              ),
              child: const Text('Verify Phone Number'),
            ),
          ],
        );
      },
    );

    if (result != true) return false;

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

  Future<void> _confirmPop() async {
    if (!_isFormDirty()) {
      ref.read(deliveryLocationProvider.notifier).clearLocation();
      if (mounted) context.go(RouteNames.customerHome);
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final String? action = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
          icon: Icon(
            Icons.drafts_rounded,
            size: 40,
            color: isDark ? AppColors.primaryDark : AppColors.primary,
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
                backgroundColor: isDark ? AppColors.primaryDark : AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
                elevation: 0,
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

  Widget _buildProgressBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildProgressNode(0, 'Location', true, isDark, primaryText, secondaryText),
          _buildProgressLine(true, isDark),
          _buildProgressNode(1, 'Items', _getActiveItems().isNotEmpty, isDark, primaryText, secondaryText),
          _buildProgressLine(_getActiveItems().isNotEmpty, isDark),
          _buildProgressNode(2, 'Review', _progressStep >= 1, isDark, primaryText, secondaryText),
          _buildProgressLine(_progressStep >= 2, isDark),
          _buildProgressNode(3, 'Submit', _progressStep == 3, isDark, primaryText, secondaryText),
        ],
      ),
    );
  }

  Widget _buildProgressNode(int index, String label, bool active, bool isDark, Color primaryText, Color secondaryText) {
    final nodeColor = active 
        ? (isDark ? AppColors.primaryDark : AppColors.primary)
        : (isDark ? AppColors.borderDark : AppColors.borderLight);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: active ? nodeColor : Colors.transparent,
            border: Border.all(color: nodeColor, width: 2),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: active
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: secondaryText,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.caption(active ? nodeColor : secondaryText).copyWith(
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressLine(bool active, bool isDark) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 18),
        color: active ? (isDark ? AppColors.primaryDark : AppColors.primary) : AppColors.borderLight,
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
              title: Text(
                'Create Shopping Request',
                style: AppTextStyles.h2(primaryText),
              ),
              backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: _confirmPop,
              ),
            ),
            body: Column(
              children: [
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
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                          child: RequestTypeToggle(
                            selectedType: _requestType,
                            onChanged: (type) {
                              setState(() {
                                _requestType = type;
                                _singleCategory = null;
                                _multipleItemsList = [];
                              });
                              _saveDraft();
                            },
                          ),
                        ),
                      ),
                      if (_requestType == RequestType.single) ...[ 
                        SliverToBoxAdapter(
                          child: Theme3AppCard(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            margin: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Step 1: Choose Item Category',
                                  style: AppTextStyles.subtitle(primaryText),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Select the main category before typing item specifications.',
                                  style: AppTextStyles.caption(secondaryText),
                                ),
                                const SizedBox(height: AppSpacing.lg),
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
                                  compact: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_singleCategory != null)
                          SliverToBoxAdapter(
                            child: Theme3AppCard(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              margin: const EdgeInsets.all(AppSpacing.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Step 2: Enter Item Details',
                                        style: AppTextStyles.subtitle(primaryText),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  AppTextField(
                                    controller: _singleNameController,
                                    label: 'Item Name',
                                    hint: 'e.g. Red onions 500g, Exide Battery...',
                                    onChanged: (_) {},
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
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
                                  const SizedBox(height: AppSpacing.lg),
                                  AppTextField(
                                    controller: _singleBrandController,
                                    label: 'Preferred Brand / Model (Optional)',
                                    hint: 'e.g. Prima, Singer, Anchor',
                                    onChanged: (_) => _saveDraft(),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  AppTextField(
                                    controller: _singleDescController,
                                    label: 'Description / Remarks (Optional)',
                                    hint: 'Any specific instructions...',
                                    maxLines: 3,
                                    onChanged: (_) => _saveDraft(),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
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
                      if (_requestType == RequestType.multiple) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Shopping List',
                                  style: AppTextStyles.bodySmall(secondaryText),
                                ),
                                Theme3AppButton(
                                  label: 'Add Item',
                                  onPressed: _showAddItemManualSheet,
                                  icon: Icons.add_rounded,
                                  type: Theme3ButtonType.primary,
                                  width: 120,
                                  height: 36,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
