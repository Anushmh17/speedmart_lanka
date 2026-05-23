import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../../location/models/delivery_location.dart';
import '../../../location/providers/location_provider.dart';
import '../../../../shared/models/user_model.dart';
import '../data/customer_delivery_address_repository.dart';
import '../models/customer_delivery_address.dart';

class CustomerDeliveryAddressState {
  const CustomerDeliveryAddressState({
    this.isLoading = false,
    this.savedAddress,
    this.requestOnlyLocation,
    this.error,
  });

  final bool isLoading;
  final CustomerDeliveryAddress? savedAddress;
  final DeliveryLocation? requestOnlyLocation;
  final String? error;

  DeliveryLocation? get activeLocation =>
      requestOnlyLocation ?? savedAddress?.toDeliveryLocation();

  bool get hasSavedAddress =>
      savedAddress != null && savedAddress!.isComplete;

  CustomerDeliveryAddressState copyWith({
    bool? isLoading,
    CustomerDeliveryAddress? savedAddress,
    DeliveryLocation? requestOnlyLocation,
    String? error,
    bool clearRequestOnly = false,
    bool clearError = false,
  }) {
    return CustomerDeliveryAddressState(
      isLoading: isLoading ?? this.isLoading,
      savedAddress: savedAddress ?? this.savedAddress,
      requestOnlyLocation: clearRequestOnly
          ? null
          : (requestOnlyLocation ?? this.requestOnlyLocation),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CustomerDeliveryAddressNotifier
    extends StateNotifier<CustomerDeliveryAddressState> {
  CustomerDeliveryAddressNotifier(this.ref)
      : super(const CustomerDeliveryAddressState());

  final Ref ref;
  final _repo = CustomerDeliveryAddressRepository.instance;

  bool _loadInProgress = false;
  bool _hasLoadedForUser = false;
  String? _loadedUserId;

  Future<void> loadForCurrentUser({bool force = false}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = state.copyWith(isLoading: false);
      return;
    }

    if (_loadInProgress) return;

    final sameUser = _loadedUserId == user.id;
    if (!force && sameUser && _hasLoadedForUser) return;

    _loadInProgress = true;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      var address = await _repo.load(user.id);
      address ??= await _migrateFromUserProfile(user);

      state = state.copyWith(
        isLoading: false,
        savedAddress: address,
      );

      _hasLoadedForUser = true;
      _loadedUserId = user.id;

      debugPrint(
        '[DeliveryAddress] Address loaded for user: ${user.id} '
        '(complete=${address?.isComplete ?? false})',
      );
    } catch (e) {
      debugPrint('[DeliveryAddress] Address load failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load delivery address.',
      );
    } finally {
      _loadInProgress = false;
    }
  }

  Future<CustomerDeliveryAddress?> _migrateFromUserProfile(
    UserModel user,
  ) async {
    final hasProfileFields = (user.deliveryPreciseAddress?.trim().isNotEmpty ??
            false) ||
        (user.deliveryApproxArea?.trim().isNotEmpty ?? false);
    if (!hasProfileFields) return null;

    final migrated = CustomerDeliveryAddress.fromUserFields(
      customerId: user.id,
      deliveryProvince: user.deliveryProvince,
      deliveryDistrict: user.deliveryDistrict,
      deliveryApproxArea: user.deliveryApproxArea,
      deliveryPreciseAddress: user.deliveryPreciseAddress,
      deliveryNote: user.deliveryNote,
    );
    if (migrated.isComplete) {
      await _repo.save(migrated);
      return migrated;
    }
    return migrated.streetAddress.isNotEmpty || migrated.approximateArea.isNotEmpty
        ? migrated
        : null;
  }

  Future<void> saveDefaultAddress(CustomerDeliveryAddress address) async {
    final saved = address.copyWith(updatedAt: DateTime.now());
    await _repo.save(saved);
    state = state.copyWith(
      savedAddress: saved,
      clearRequestOnly: true,
    );
    debugPrint(
      '[DeliveryAddress] Address save successful for user: ${address.customerId}',
    );
  }

  void setRequestOnlyLocation(DeliveryLocation location) {
    state = state.copyWith(requestOnlyLocation: location);
  }

  void clearRequestOnlyLocation() {
    state = state.copyWith(clearRequestOnly: true);
  }

  Future<void> applyActiveLocationToProvider() async {
    final loc = state.activeLocation;
    if (loc == null) return;
    ref.read(deliveryLocationProvider.notifier).setLocation(loc);
    if (loc.deliveryNote.isNotEmpty) {
      ref
          .read(deliveryLocationProvider.notifier)
          .setDeliveryNote(loc.deliveryNote);
    }
  }
}

final customerDeliveryAddressProvider = StateNotifierProvider<
    CustomerDeliveryAddressNotifier, CustomerDeliveryAddressState>((ref) {
  return CustomerDeliveryAddressNotifier(ref);
});