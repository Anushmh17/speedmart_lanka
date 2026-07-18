import '../../../core/storage/storage_service.dart';
import '../../location/models/delivery_location.dart';

class DraftService {
  DraftService._();

  /// Saves the given draft JSON to local storage.
  static Future<void> saveDraft(Map<String, dynamic> draftJson) async {
    await StorageService.saveDraftRequest(draftJson);
  }

  /// Loads the draft JSON from local storage.
  static Future<Map<String, dynamic>?> loadDraft() async {
    return await StorageService.getDraftRequest();
  }

  /// Clears the draft JSON from local storage.
  static Future<void> clearDraft() async {
    await StorageService.clearDraftRequest();
  }

  /// Checks if a stored draft JSON contains meaningful data.
  static bool hasValidDraft(Map<String, dynamic>? draft) {
    if (draft == null) return false;

    // Check delivery location
    if (draft['deliveryLocation'] != null) {
      final loc = draft['deliveryLocation'];
      final suburb = loc['suburb'] as String? ?? '';
      final city = loc['city'] as String? ?? '';
      final street = loc['streetAddress'] as String? ?? '';
      if (suburb.isNotEmpty || city.isNotEmpty || street.isNotEmpty) {
        return true;
      }
    }

    final deliveryAddress = draft['deliveryAddress'] as String? ?? '';
    if (deliveryAddress.isNotEmpty) return true;

    // Check single item fields
    if (draft['singleCategory'] != null) return true;
    final singleName = draft['singleName'] as String? ?? '';
    if (singleName.isNotEmpty) return true;

    final singleQty = draft['singleQty'] as int? ?? 1;
    if (singleQty != 1) return true;

    final singleDesc = draft['singleDesc'] as String? ?? '';
    if (singleDesc.isNotEmpty) return true;

    final singleBrand = draft['singleBrand'] as String? ?? '';
    if (singleBrand.isNotEmpty) return true;

    final singleImageUrls = draft['singleImageUrls'] as List? ?? [];
    if (singleImageUrls.isNotEmpty) return true;

    // Check multiple items
    final multipleItems = draft['multipleItems'] as List? ?? [];
    if (multipleItems.isNotEmpty) return true;

    return false;
  }

  /// Checks if the current form state is dirty (has meaningful data entered by the user).
  static bool isFormDirty({
    required DeliveryLocation? deliveryLocation,
    required String suburbText,
    required String addressText,
    required String requestTypeName,
    required String? singleCategory,
    required String singleName,
    required int singleQuantity,
    required String singleBrand,
    required String singleDesc,
    required List<String> singleImageUrls,
    required List<dynamic> multipleItems,
  }) {
    // 1. Delivery Location Entered
    final hasLoc = deliveryLocation != null &&
        (deliveryLocation.suburb.isNotEmpty ||
            deliveryLocation.city.isNotEmpty ||
            deliveryLocation.streetAddress.isNotEmpty);
    if (hasLoc || suburbText.isNotEmpty || addressText.isNotEmpty) {
      return true;
    }

    // 2. Multiple Items
    if (requestTypeName == 'multiple') {
      if (multipleItems.isNotEmpty) return true;
    } else {
      // 3. Single Item Fields
      if (singleCategory != null) return true;
      if (singleName.isNotEmpty) return true;
      if (singleQuantity != 1) return true;
      if (singleImageUrls.isNotEmpty) return true;
      if (singleDesc.isNotEmpty) return true;
      if (singleBrand.isNotEmpty) return true;
    }

    return false;
  }
}

