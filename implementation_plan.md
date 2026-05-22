# Implementation Plan — Automatic Country Detection & Popup Logic

This plan addresses the country detection reliability and fixes the persistent country selection popup.

## Proposed Changes

### 1. Persistent Storage (Saved Preference)
- Add a new Riverpod provider `sharedPreferencesProvider` to access local storage.
- Update `CustomerRegistrationState` to include:
  - `hasSavedCountryPreference` (bool)
  - `shouldShowCountryDialog` (bool)
- Update `CustomerRegistrationNotifier` to:
  - Check `SharedPreferences` for a saved country key (e.g. `speedmart_country_preference`) *before* running GPS/Locale detection.
  - When the user manually taps "Change" or selects a country in the dialog, save their selection to `SharedPreferences`.

### 2. Country Detection Service (Robust Logic & Logging)
- Update `CountryDetectionService.detect()` to run with robust debug logs printing the status of: GPS permission, GPS result, SIM result, Locale result, and Final decision.
- **GPS**: Check bounding box (Lat 5.8 - 10.0, Lon 79.3 - 82.1). If true, return `LK` confidently.
- **SIM/Network**: (Requires adding the `carrier_info` package to `pubspec.yaml` to read the SIM ISO code). If SIM ISO matches `LK`, return confidently.
- **Locale**: Check `Platform.localeName`. If it indicates LK, return confidently.
- Any confident result (or a saved preference) will entirely prevent the popup from showing.

### 3. State & Popup Rules
- **Production Mode**: `shouldShowCountryDialog` is set to `true` **only if** there is no saved preference AND GPS/SIM/Locale all fail to confidently detect the country.
- **Development Mode**: If detection is completely ambiguous and there's no saved preference, automatically default to Sri Lanka (`LK`) without showing the popup. The user can still manually change it.
- Remove the old `isCountryAmbiguous` listener trigger in `LoginScreen` and `CustomerRegistrationScreen`, replacing it with `shouldShowCountryDialog`.

### Open Questions for User
> [!IMPORTANT]
> To read the physical SIM/Network ISO country code in Flutter, we need to add a native plugin like `carrier_info` to `pubspec.yaml`. Are you okay with me adding this package, or would you prefer I skip the SIM check and rely only on GPS and Device Locale (which are already supported natively)?
