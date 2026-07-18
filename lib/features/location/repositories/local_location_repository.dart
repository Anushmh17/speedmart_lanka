import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/delivery_location.dart';
import '../models/location_suggestion.dart';
import '../services/gps_location_service.dart';
import '../services/sri_lanka_location_service.dart';
import 'location_repository.dart';

/// Concrete local implementation of [LocationRepository].
///
/// - GPS detection via [SriLankaLocationService].
/// - Recent searches persisted in [SharedPreferences].
/// - Max 10 recent searches stored (oldest dropped when full).
class LocalLocationRepository implements LocationRepository {
  static const String _recentSearchesKey = 'location_recent_searches';
  static const int _maxRecentSearches = 10;

  final SriLankaLocationService _locationService;

  LocalLocationRepository({SriLankaLocationService? locationService})
      : _locationService = locationService ?? SriLankaLocationService();

  // ── GPS ────────────────────────────────────────────────────────────────────

  @override
  Future<DeliveryLocation?> detectCurrentLocation() async {
    try {
      final result = await _locationService.detectCurrentLocation();
      return result.location;
    } on LocationException {
      rethrow; // Let provider handle typed errors
    } catch (_) {
      return null;
    }
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  @override
  Future<List<LocationSuggestion>> searchLocations(String query) async {
    // Synchronous local search — wrapped in Future for interface compliance
    return _locationService.search(query);
  }

  // ── Recent Searches (SharedPreferences) ────────────────────────────────────

  @override
  Future<List<LocationSuggestion>> loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_recentSearchesKey) ?? [];
      return raw
          .map((s) {
            try {
              return LocationSuggestion.fromJson(
                  json.decode(s) as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<LocationSuggestion>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveRecentSearch(LocationSuggestion suggestion) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await loadRecentSearches();

      // Remove duplicate if already present
      existing.removeWhere((s) => s.display == suggestion.display);

      // Prepend newest
      existing.insert(0, suggestion);

      // Trim to max
      final trimmed = existing.take(_maxRecentSearches).toList();

      await prefs.setStringList(
        _recentSearchesKey,
        trimmed.map((s) => json.encode(s.toJson())).toList(),
      );
    } catch (_) {
      // Fail silently — recent searches are non-critical
    }
  }

  @override
  Future<void> clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
    } catch (_) {}
  }

  // ── Delivery Location Persistence ──────────────────────────────────────────

  static const String _deliveryLocationKey = 'saved_delivery_location';

  @override
  Future<void> saveDeliveryLocation(DeliveryLocation location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deliveryLocationKey, json.encode(location.toJson()));
    } catch (_) {
      // Fail silently — the location can be re-entered manually
    }
  }

  @override
  Future<DeliveryLocation?> loadDeliveryLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_deliveryLocationKey);
      if (raw == null) return null;
      return DeliveryLocation.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

