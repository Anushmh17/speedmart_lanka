import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/delivery_location.dart';

class LocationNotifier extends StateNotifier<DeliveryLocation?> {
  LocationNotifier() : super(null);

  void setLocation(DeliveryLocation? location) {
    state = location;
  }

  void updateStreetAddress(String streetAddress) {
    if (state != null) {
      state = state!.copyWith(
        streetAddress: streetAddress,
        isManualOverride: true,
      );
    }
  }

  void updateDeliveryNote(String note) {
    if (state != null) {
      state = state!.copyWith(
        deliveryNote: note,
      );
    }
  }

  /// Update the approximate area text (typed manually by the customer).
  /// Creates a manual-source location if none exists yet.
  void setManualArea(String areaText) {
    if (state != null) {
      state = state!.copyWith(
        approximateAreaText: areaText,
        source: 'manual',
        isManualOverride: true,
      );
    } else {
      state = DeliveryLocation(
        province: '',
        district: '',
        city: '',
        suburb: '',
        formattedAddress: '',
        streetAddress: '',
        approximateAreaText: areaText,
        source: 'manual',
        isManualOverride: true,
      );
    }
  }

  void clearLocation() {
    state = null;
  }
}

final deliveryLocationProvider = StateNotifierProvider<LocationNotifier, DeliveryLocation?>((ref) {
  return LocationNotifier();
});
