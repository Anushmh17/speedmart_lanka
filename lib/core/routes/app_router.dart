import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/role_selection_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/customer_registration/screens/otp_verification_screen.dart';
import '../../features/customer/presentation/screens/customer_home_screen.dart';
import '../../features/requests/presentation/screens/create_request_screen.dart';
import '../../features/requests/models/shopping_request.dart';
import '../../features/proposals/models/proposal.dart';
import '../../features/proposals/presentation/screens/customer_proposal_details_screen.dart';
import '../../features/payments/models/payment.dart';
import '../../features/payments/presentation/screens/customer_payment_history_screen.dart';
import '../../features/payments/presentation/screens/payment_screen.dart';
import '../../features/payments/presentation/screens/payment_receipt_screen.dart';
import '../../features/orders/models/order_model.dart';
import '../../features/orders/presentation/screens/order_tracking_screen.dart';
import '../../features/orders/presentation/screens/vendor_order_details_screen.dart';
import '../../features/vendor/presentation/screens/vendor_home_screen.dart';
import '../../features/vendor/presentation/screens/vendor_shopfront_screen.dart';
import '../../features/vendor/proposals/presentation/vendor_request_detail_screen.dart';
import '../../features/vendor/proposals/presentation/vendor_proposal_form_screen.dart';
import '../../features/vendor/proposals/presentation/vendor_proposal_detail_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/admin/presentation/screens/admin_home_screen.dart';
import '../../features/admin/presentation/screens/admin_vendor_management_screen.dart';
import '../../features/admin/presentation/screens/admin_vendor_assignment_screen.dart';
import '../../features/requests/presentation/screens/request_list_screen.dart';
import '../../shared/presentation/screens/profile_screen.dart';
import '../../features/customer/delivery_address/presentation/screens/customer_delivery_address_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../shared/models/user_role.dart';
import 'route_names.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Provider to watch the current route location
final currentRouteLocationProvider = Provider<String>((ref) {
  final router = ref.watch(appRouterProvider);
  return router.routeInformationProvider.value.location;
});

/// GoRouter instance exposed as a Riverpod provider.
/// Auth-based redirects are handled here — roles cannot access each other's routes.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ValueNotifier<AuthState>(const AuthState.initial());

  ref.listen<AuthState>(authProvider, (_, next) {
    authNotifier.value = next;
  });

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RouteNames.splash,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final auth = authNotifier.value;

      // While loading, stay on splash
      if (auth.isLoading) return RouteNames.splash;

      final location = state.matchedLocation;
      final isOnAuthRoute = location == RouteNames.splash ||
          location == RouteNames.roleSelection ||
          location.startsWith('/auth');

      // Not authenticated → send to role selection
      if (!auth.isAuthenticated) {
        if (isOnAuthRoute) return null;
        return RouteNames.roleSelection;
      }

      // Authenticated → prevent going back to auth screens
      if (isOnAuthRoute) {
        return _homeForRole(auth.user!.role);
      }

      // Role-based access guard
      final role = auth.user!.role;
      if (location.startsWith('/customer') && role != UserRole.customer) {
        return _homeForRole(role);
      }
      if (location.startsWith('/vendor') && role != UserRole.vendor) {
        return _homeForRole(role);
      }
      if (location.startsWith('/admin') && role != UserRole.admin) {
        return _homeForRole(role);
      }

      return null;
    },
    routes: [
      // ── Core ─────────────────────────────────────────────────────────────
      GoRoute(
        path: RouteNames.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.roleSelection,
        builder: (_, __) => const RoleSelectionScreen(),
      ),

      // ── Auth Routes (Role-Specific) ──────────────────────────────────────
      GoRoute(
        path: RouteNames.customerLogin,
        builder: (_, __) => const LoginScreen(role: UserRole.customer),
      ),
      GoRoute(
        path: RouteNames.customerRegister,
        builder: (_, __) => const RegisterScreen(role: UserRole.customer),
      ),
      GoRoute(
        path: RouteNames.customerOtp,
        builder: (_, __) => const OtpVerificationScreen(),
      ),
      GoRoute(
        path: RouteNames.vendorLogin,
        builder: (_, __) => const LoginScreen(role: UserRole.vendor),
      ),
      GoRoute(
        path: RouteNames.vendorRegister,
        builder: (_, __) => const RegisterScreen(role: UserRole.vendor),
      ),
      GoRoute(
        path: RouteNames.adminLogin,
        builder: (_, __) => const LoginScreen(role: UserRole.admin),
      ),
      GoRoute(
        path: RouteNames.adminRegister,
        builder: (_, __) => const RegisterScreen(role: UserRole.admin),
      ),

      // ── Customer Shell ───────────────────────────────────────────────────
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          return CustomerHomeScreen(child: child);
        },
        routes: [
          GoRoute(
            path: RouteNames.customerHome,
            builder: (_, __) => const CustomerHomeTab(),
          ),
          GoRoute(
            path: RouteNames.customerRequests,
            builder: (_, __) => const RequestListScreen(),
          ),
          GoRoute(
            path: RouteNames.customerOrders,
            builder: (_, __) => const CustomerOrdersTab(),
          ),
          GoRoute(
            path: RouteNames.customerProfile,
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),

      // ── Customer Full-Screen Workflows (Outside Shell) ───────────────────
      GoRoute(
        path: RouteNames.customerCreateRequest,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const CreateRequestScreen(),
      ),
      GoRoute(
        path: '/customer/proposals/detail',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) {
          final extraMap = state.extra as Map<String, dynamic>;
          final proposal = extraMap['proposal'] as Proposal;
          final requestId = extraMap['requestId'] as String;
          return CustomerProposalDetailsScreen(
            proposal: proposal,
            requestId: requestId,
          );
        },
      ),
      GoRoute(
        path: '/customer/payment',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) {
          final extraMap = state.extra as Map<String, dynamic>;
          final proposal = extraMap['proposal'] as Proposal;
          final requestId = extraMap['requestId'] as String;
          return PaymentScreen(
            proposal: proposal,
            requestId: requestId,
          );
        },
      ),
      GoRoute(
        path: RouteNames.customerPaymentReceipt,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) {
          final extraMap = state.extra as Map<String, dynamic>;
          final order = extraMap['order'] as OrderModel;
          final payment = extraMap['payment'];
          if (payment is! PaymentModel) {
            return const Scaffold(
              body: Center(child: Text('Receipt data not found.')),
            );
          }
          return PaymentReceiptScreen(order: order, payment: payment);
        },
      ),
      GoRoute(
        path: RouteNames.customerPaymentHistory,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const CustomerPaymentHistoryScreen(),
      ),
      GoRoute(
        path: RouteNames.customerDeliveryAddress,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) {
          final fromCreateRequest = (state.extra as Map<String, dynamic>?)
                  ?['fromCreateRequest'] as bool? ??
              false;
          return CustomerDeliveryAddressScreen(
            fromCreateRequest: fromCreateRequest,
          );
        },
      ),
      GoRoute(
        path: '/customer/orders/track',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) {
          final order = state.extra as OrderModel;
          return OrderTrackingScreen(order: order);
        },
      ),
      GoRoute(
        path: '/customer/vendor/shopfront',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) {
          final extraMap = state.extra as Map<String, dynamic>;
          final vendorName = extraMap['vendorName'] as String;
          final vendorPhone = extraMap['vendorPhone'] as String;
          return VendorShopfrontScreen(
            vendorName: vendorName,
            vendorPhone: vendorPhone,
          );
        },
      ),
      GoRoute(
        path: '/chat',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) {
          final extraMap = state.extra as Map<String, dynamic>;
          final proposalId = extraMap['proposalId'] as String;
          final vendorName = extraMap['vendorName'] as String;
          final isUnlocked = extraMap['isUnlocked'] as bool;
          return ChatScreen(
            proposalId: proposalId,
            vendorName: vendorName,
            isUnlocked: isUnlocked,
          );
        },
      ),

      // ── Vendor ───────────────────────────────────────────────────────────
      GoRoute(
        path: RouteNames.vendorHome,
        builder: (_, __) => const VendorHomeScreen(),
      ),
      GoRoute(
        path: RouteNames.vendorRequestDetail,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) {
          final request = state.extra as ShoppingRequest?;
          if (request == null) {
            return const Scaffold(
              body: Center(
                child: Text('Request not found. Please select again from your vendor dashboard.'),
              ),
            );
          }
          return VendorRequestDetailScreen(request: request);
        },
      ),
      GoRoute(
        path: RouteNames.vendorProposalCreate,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) {
          final request = state.extra as ShoppingRequest?;
          if (request == null) {
            return const Scaffold(
              body: Center(
                child: Text('Request not found. Please select a request to create a proposal.'),
              ),
            );
          }
          return VendorProposalFormScreen(request: request);
        },
      ),
      GoRoute(
        path: RouteNames.vendorProposalDetail,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) {
          final proposal = state.extra as Proposal?;
          if (proposal == null) {
            return const Scaffold(
              body: Center(
                child: Text('Proposal not found. Please open it again from your proposals list.'),
              ),
            );
          }
          return VendorProposalDetailScreen(proposal: proposal);
        },
      ),
      GoRoute(
        path: RouteNames.vendorProposalEdit,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) {
          final extraMap = state.extra as Map<String, dynamic>?;
          final proposal = extraMap?['proposal'] as Proposal?;
          final request = extraMap?['request'] as ShoppingRequest?;

          if (proposal == null || request == null) {
            return const Scaffold(
              body: Center(
                child: Text('Proposal or request not found. Please open it again from your proposals list.'),
              ),
            );
          }
          return VendorProposalFormScreen(
            request: request,
            existingProposal: proposal,
          );
        },
      ),
      GoRoute(
        path: '/vendor/orders/manage',
        builder: (_, state) {
          final order = state.extra as OrderModel;
          return VendorOrderDetailsScreen(order: order);
        },
      ),

      // ── Admin ─────────────────────────────────────────────────────────────
      GoRoute(
        path: RouteNames.adminDashboard,
        builder: (_, __) => const AdminHomeScreen(),
      ),
      GoRoute(
        path: RouteNames.adminVendorManagement,
        builder: (_, __) => const AdminVendorManagementScreen(),
      ),
      GoRoute(
        path: RouteNames.adminVendorAssignment,
        builder: (context, state) {
          final vendor = state.extra;
          return AdminVendorAssignmentScreen(vendor: vendor);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.matchedLocation}'),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go(RouteNames.splash),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

String _homeForRole(UserRole role) {
  switch (role) {
    case UserRole.customer: return RouteNames.customerHome;
    case UserRole.vendor:   return RouteNames.vendorHome;
    case UserRole.admin:    return RouteNames.adminDashboard;
  }
}
