/// All named route paths in one place.
/// Change a route name here and it updates everywhere.
class RouteNames {
  RouteNames._();

  // ── Core ──────────────────────────────────────────────────────────────────
  static const String splash = '/';
  static const String roleSelection = '/role-select';

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String login = '/login';
  static const String register = '/register';

  // ── Customer Shell (with bottom nav) ───────────────────────────────────────
  static const String customerHome = '/customer';
  static const String customerRequests = '/customer/requests';
  static const String customerRequestDetail = '/customer/requests/:id';
  static const String customerOrders = '/customer/orders';
  static const String customerProfile = '/customer/profile';

  // ── Customer Full-Screen Routes (without bottom nav) ────────────────────────
  static const String customerCreateRequest = '/customer/requests/create';
  // Additional full-screen routes defined directly in router:
  // - /customer/payment
  // - /customer/orders/track
  // - /customer/proposals/detail
  // - /customer/vendor/shopfront
  // - /chat

  static const String customerProposals = '/customer/proposals';

  // ── Vendor Shell ──────────────────────────────────────────────────────────
  static const String vendorHome = '/vendor';
  static const String vendorNearbyRequests = '/vendor/requests';
  static const String vendorRequestDetail = '/vendor/requests/:id';
  static const String vendorProposals = '/vendor/proposals';
  static const String vendorOrders = '/vendor/orders';
  static const String vendorEarnings = '/vendor/earnings';
  static const String vendorProfile = '/vendor/profile';

  // ── Admin Shell ───────────────────────────────────────────────────────────
  static const String adminDashboard = '/admin';
  static const String adminVendorApprovals = '/admin/vendor-approvals';
  static const String adminUsers = '/admin/users';
  static const String adminCategories = '/admin/categories';
  static const String adminRequests = '/admin/requests';
  static const String adminOrders = '/admin/orders';
  static const String adminPayments = '/admin/payments';
  static const String adminDisputes = '/admin/disputes';
  static const String adminSettings = '/admin/settings';
}

