/// Tracks country detection vs user selection for anti-abuse purposes.
///
/// When a user detected in Sri Lanka manually selects "Other Country",
/// [isCountryOverride] is set to `true` and [riskFlag] is set to
/// `'country_mismatch'`. These fields are persisted on the user account
/// and sent to the backend for fraud analysis.
class CountryOverrideInfo {
  const CountryOverrideInfo({
    this.detectedCountry,
    this.selectedCountry,
    this.detectionSource = 'fallback',
    this.isCountryOverride = false,
    this.riskFlag,
    this.verifiedPhone = false,
    this.verifiedEmail = false,
  });

  /// ISO-3166 alpha-2 code detected by the device (e.g. "LK"), or null.
  final String? detectedCountry;

  /// The country the user actually selected: "LK" or "OTHER".
  final String? selectedCountry;

  /// How the country was detected: "gps", "locale", or "fallback".
  final String detectionSource;

  /// True if the user overrode a confident LK detection to use international.
  final bool isCountryOverride;

  /// Risk flag for backend analysis. Set to `'country_mismatch'` when
  /// [isCountryOverride] is true.
  final String? riskFlag;

  /// True once the user has verified their phone via OTP.
  final bool verifiedPhone;

  /// True once the user has verified their email via OTP.
  final bool verifiedEmail;

  /// Creates a fresh instance with no detection data.
  factory CountryOverrideInfo.empty() => const CountryOverrideInfo();

  CountryOverrideInfo copyWith({
    String? detectedCountry,
    String? selectedCountry,
    String? detectionSource,
    bool? isCountryOverride,
    String? riskFlag,
    bool? verifiedPhone,
    bool? verifiedEmail,
    bool clearRiskFlag = false,
  }) {
    return CountryOverrideInfo(
      detectedCountry: detectedCountry ?? this.detectedCountry,
      selectedCountry: selectedCountry ?? this.selectedCountry,
      detectionSource: detectionSource ?? this.detectionSource,
      isCountryOverride: isCountryOverride ?? this.isCountryOverride,
      riskFlag: clearRiskFlag ? null : (riskFlag ?? this.riskFlag),
      verifiedPhone: verifiedPhone ?? this.verifiedPhone,
      verifiedEmail: verifiedEmail ?? this.verifiedEmail,
    );
  }

  Map<String, dynamic> toJson() => {
        'detected_country': detectedCountry,
        'selected_country': selectedCountry,
        'detection_source': detectionSource,
        'country_override': isCountryOverride,
        'risk_flag': riskFlag,
        'verified_phone': verifiedPhone,
        'verified_email': verifiedEmail,
      };

  factory CountryOverrideInfo.fromJson(Map<String, dynamic> json) {
    return CountryOverrideInfo(
      detectedCountry: json['detected_country'] as String?,
      selectedCountry: json['selected_country'] as String?,
      detectionSource: json['detection_source'] as String? ?? 'fallback',
      isCountryOverride: json['country_override'] as bool? ?? false,
      riskFlag: json['risk_flag'] as String?,
      verifiedPhone: json['verified_phone'] as bool? ?? false,
      verifiedEmail: json['verified_email'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'CountryOverrideInfo(detected: $detectedCountry, selected: $selectedCountry, '
      'override: $isCountryOverride, risk: $riskFlag)';
}

