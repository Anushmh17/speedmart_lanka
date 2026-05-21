# Reusable Sri Lanka Location Module

I have successfully built out the entire production-ready Sri Lanka location module under `lib/features/location/`. This module provides a clean architecture that can be reused across all features (customer/vendor registration, requests, delivery tracking).

## Module Structure Overview

```
features/location/
  ├─ data/            -> Static province/district dataset
  ├─ models/          -> Domain entities (DeliveryLocation, etc.)
  ├─ providers/       -> State management (Riverpod)
  ├─ repositories/    -> Abstract interface & local SharedPreferences impl
  ├─ services/        -> GPS, Geocoding, Distance, Orchestrator
  ├─ utils/           -> Haversine calculation
  ├─ widgets/         -> Reusable UI components
  └─ location.dart    -> Barrel export file
```

## Key Achievements

1. **Centralized Data:**
   Created `sri_lanka_data.dart` with all 9 provinces and 25 districts using stable IDs.
2. **Clean Services:**
   - `GpsLocationService`: Handles device permissions and fetching coordinates (no fake fallbacks).
   - `ReverseGeocodingService`: Resolves coordinates to provinces/districts/suburbs using the local dataset (within a 50km threshold).
   - `DistanceCalculationService`: A wrapper over Haversine calculations for finding nearest vendors or calculating delivery radius.
   - `SriLankaLocationService`: Orchestrates the GPS + geocoding pipeline.
3. **Robust State Management:**
   Built a comprehensive Riverpod `locationProvider` that tracks GPS loading state, selected dropdowns, manually typed areas, the precise street address, and recent searches.
4. **Resilient Location Model:**
   Updated `DeliveryLocation` to explicitly separate `approximateAreaText`, `preciseAddress`, and `formattedAddress`. GPS fetching **never overwrites** the `preciseAddress` typed by the user.
5. **Reusable Widgets:**
   Built `ProvinceDropdown`, `DistrictDropdown`, and `SearchableLocationField`. These use Material 3 design and automatically react to/update the Riverpod state without boilerplate.
6. **No Mock Data / Fakes:**
   All services accurately represent reality; if reverse geocoding fails, it gracefully degrades and asks the user to manually enter their area.

> [!TIP]
> **Next Steps**
> The module is now ready to be integrated into the customer registration, request creation, or any other feature requiring precise or approximate Sri Lankan locations! You can import `package:speedmart_lanka/features/location/location.dart` to access all classes.
