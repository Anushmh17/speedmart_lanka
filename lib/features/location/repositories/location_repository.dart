import '../models/delivery_location.dart';
import '../models/location_suggestion.dart';

/// Abstract interface for the location repository.
///
/// Provides a clean boundary between business logic and data sources.
/// The local implementation uses GPS + static data.
/// Future implementations can swap in a remote API without touching callers.
abstract class LocationRepository {
  /// Detect the current GPS location and reverse geocode it.
  /// Returns null if location cannot be determined.
  Future<DeliveryLocation?> detectCurrentLocation();

  /// Search for location suggestions matching [query].
  Future<List<LocationSuggestion>> searchLocations(String query);

  /// Load recent location searches from local storage.
  Future<List<LocationSuggestion>> loadRecentSearches();

  /// Save a location suggestion to recent searches.
  Future<void> saveRecentSearch(LocationSuggestion suggestion);

  /// Clear all recent searches.
  Future<void> clearRecentSearches();

  /// Persist the current delivery location so it survives app restarts.
  Future<void> saveDeliveryLocation(DeliveryLocation location);

  /// Load the previously saved delivery location. Returns null if none saved.
  Future<DeliveryLocation?> loadDeliveryLocation();
}

