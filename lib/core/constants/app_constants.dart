/// Global application constants.
/// All configurable values live here — change once, affect everywhere.
class AppConstants {
  AppConstants._();

  static const String appName = 'Speedmart Lanka';
  static const String appTagline = 'Your Smart Marketplace';
  static const String appVersion = '1.0.0';
  static const int buildNumber = 1;

  /// Delivery radius in kilometers (configurable from admin)
  static const double defaultDeliveryRadius = 5.0;

  /// Cooldown in minutes before same vendor can accept the same rejected item
  static const int vendorCooldownMinutes = 120;

  /// Request expiry duration in hours
  static const int requestExpiryHours = 24;

  /// Currency
  static const String currencySymbol = 'LKR';
  static const String currencyCode = 'LKR';

  /// Max images allowed per request item
  static const int maxImagesPerItem = 5;

  /// Max items per request
  static const int maxItemsPerRequest = 20;

  /// Secure storage keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String themeKey = 'theme_mode';
  static const String roleKey = 'user_role';

  /// Local auth user registry (until backend API is ready).
  static const String registeredUsersKey = 'registered_users';

  /// Local shopping requests (until backend API is ready).
  static const String shoppingRequestsKey = 'shopping_requests';

  /// Local vendor proposals (until backend API is ready).
  static const String vendorProposalsKey = 'vendor_proposals';

  /// Local orders (until backend API is ready).
  static const String ordersKey = 'orders';

  /// Local payments (until backend API is ready).
  static const String paymentsKey = 'payments';

  /// Local notifications (until backend API / Firebase is ready).
  static const String notificationsKey = 'notifications';

  /// Per-customer saved delivery address: `customer_delivery_address_{customerId}`.
  static const String customerDeliveryAddressPrefix = 'customer_delivery_address_';

  /// Animation durations
  static const Duration shortAnim = Duration(milliseconds: 200);
  static const Duration mediumAnim = Duration(milliseconds: 350);
  static const Duration longAnim = Duration(milliseconds: 500);
  static const Duration splashDuration = Duration(seconds: 2);

  /// Pagination
  static const int pageSize = 20;
}

