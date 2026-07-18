/// User roles in the Speedmart Lanka platform.
/// Add new roles here without touching other files.
enum UserRole {
  customer,
  vendor,
  admin;

  /// Display label for the role
  String get label {
    switch (this) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.vendor:
        return 'Shop Owner';
      case UserRole.admin:
        return 'Admin';
    }
  }

  /// Convert from raw string (e.g. from API / storage)
  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'vendor':
        return UserRole.vendor;
      case 'admin':
        return UserRole.admin;
      case 'customer':
      default:
        return UserRole.customer;
    }
  }
}

