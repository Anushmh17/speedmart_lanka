/// All named route paths in one place.
/// Change a route name here and it updates everywhere.
class RouteNames {
  RouteNames._();

  // ── Core ──────────────────────────────────────────────────────────────────
  static const String splash = '/';

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String customerLogin = '/auth/customer/login';
  static const String customerRegister = '/auth/customer/register';
  static const String customerOtp = '/auth/customer/otp';

  static const String vendorLogin = '/auth/vendor/login';
  static const String vendorRegister = '/auth/vendor/register';

  static const String adminLogin = '/auth/admin/login';

  // ── Customer Shell (with bottom nav) ───────────────────────────────────────
  static const String customerHome = '/customer';
  static const String customerRequests = '/customer/requests';
  static const String customerRequestDetail = '/customer/requests/:id';
  static const String customerOrders = '/customer/orders';
  static const String customerProfile = '/customer/profile';
  static const String customerDeliveryAddress = '/customer/delivery-address';
  static const String customerPaymentReceipt = '/customer/payment/receipt';
  static const String customerPaymentHistory = '/customer/payments';

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
  static const String vendorRequestDetail = '/vendor/requests/detail';
  static const String vendorProposals = '/vendor/proposals';
  static const String vendorProposalCreate = '/vendor/proposals/create';
  static const String vendorProposalDetail = '/vendor/proposals/detail';
  static const String vendorProposalEdit = '/vendor/proposals/edit';
  static const String vendorOrders = '/vendor/orders';
  static const String vendorEarnings = '/vendor/earnings';
  static const String vendorProfile = '/vendor/profile';

  // ── Admin ─────────────────────────────────────────────────────────────────
  static const String adminHome = '/admin';
  static const String adminDashboard = '/admin';
  static const String adminRegister = '/auth/admin/register';
  static const String adminVendorApprovals = '/admin/vendor-approvals';
  static const String adminVendorManagement = '/admin/vendor-management';
  static const String adminVendorAssignment = '/admin/vendor-assignment/:id';
  static const String adminUsers = '/admin/users';
  static const String adminCategories = '/admin/categories';
  static const String adminRequests = '/admin/requests';
  static const String adminOrders = '/admin/orders';
  static const String adminPayments = '/admin/payments';
  static const String adminDisputes = '/admin/disputes';
  static const String adminSettings = '/admin/settings';

}


