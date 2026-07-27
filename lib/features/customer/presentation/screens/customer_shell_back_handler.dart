import 'package:speedmart_lanka/core/routes/route_names.dart';

class CustomerShellBackHandler {
  static const Set<String> _customerShellRoutes = {
    RouteNames.customerHome,
    RouteNames.customerRequests,
    RouteNames.customerOrders,
    RouteNames.customerProfile,
  };

  static bool shouldHandle(String? location) {
    return location != null && _customerShellRoutes.contains(location);
  }

  static String? destinationFor(String? location) {
    if (!shouldHandle(location)) return null;
    if (location == RouteNames.customerHome) return null;
    return RouteNames.customerHome;
  }
}
