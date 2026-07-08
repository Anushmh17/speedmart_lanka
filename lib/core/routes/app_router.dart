import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speedmart_lanka/features/auth/domain/auth_state.dart';
import 'package:speedmart_lanka/features/auth/presentation/screens/splash_screen.dart';
import 'package:speedmart_lanka/features/auth/presentation/screens/role_selection_screen.dart';
import 'package:speedmart_lanka/features/auth/presentation/screens/login_screen.dart';
import 'package:speedmart_lanka/features/customer/presentation/screens/customer_home_screen.dart';
import 'package:speedmart_lanka/features/requests/presentation/screens/create_request_screen.dart';
import 'package:speedmart_lanka/features/requests/models/shopping_request.dart';
import 'package:speedmart_lanka/features/proposals/models/proposal.dart';
import 'package:speedmart_lanka/features/proposals/presentation/screens/customer_proposal_details_screen.dart';
import 'package:speedmart_lanka/features/payments/models/payment.dart';
import 'package:speedmart_lanka/features/payments/presentation/screens/customer_payment_history_screen.dart';
import 'package:speedmart_lanka/features/payments/presentation/screens/payment_screen.dart';
import 'package:speedmart_lanka/features/payments/presentation/screens/payment_receipt_screen.dart';
import 'package:speedmart_lanka/features/orders/models/order_model.dart';
import 'package:speedmart_lanka/features/orders/presentation/screens/order_tracking_screen.dart';
import 'package:speedmart_lanka/features/orders/presentation/screens/vendor_order_details_screen.dart';
import 'package:speedmart_lanka/features/vendor/presentation/screens/vendor_home_screen.dart';
import 'package:speedmart_lanka/features/vendor/presentation/screens/vendor_shopfront_screen.dart';
import 'package:speedmart_lanka/features/vendor/proposals/presentation/vendor_request_detail_screen.dart';
import 'package:speedmart_lanka/features/vendor/proposals/presentation/vendor_proposal_form_screen.dart';
import 'package:speedmart_lanka/features/vendor/proposals/presentation/vendor_proposal_detail_screen.dart';
import 'package:speedmart_lanka/features/chat/presentation/screens/chat_screen.dart';
import 'package:speedmart_lanka/features/admin/presentation/screens/admin_home_screen.dart';
import 'package:speedmart_lanka/features/admin/presentation/screens/admin_vendor_management_screen.dart';
import 'package:speedmart_lanka/features/admin/presentation/screens/admin_vendor_assignment_screen.dart';
import 'package:speedmart_lanka/features/admin/presentation/screens/admin_category_management_screen.dart';
import 'package:speedmart_lanka/features/requests/presentation/screens/request_list_screen.dart';
import 'package:speedmart_lanka/shared/presentation/screens/profile_screen.dart';
import 'package:speedmart_lanka/features/customer/delivery_address/presentation/screens/customer_delivery_address_screen.dart';
import 'package:speedmart_lanka/features/auth/providers/auth_provider.dart';
import 'package:speedmart_lanka/shared/models/user_role.dart';
import 'package:speedmart_lanka/core/routes/route_names.dart';
import 'package:speedmart_lanka/figma_screens/figma_auth_flow.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Provider to watch the current route location
/// This provider listens to GoRouter's route changes and returns the current matched location
final currentRouteLocationProvider = Provider<String>((ref) {
  final router = ref.watch(appRouterProvider);
  
  try {
    // Get the current configuration from the router delegate
    final configuration = router.routerDelegate.currentConfiguration;
    
    if (configuration.isEmpty) {
      debugPrint('[RouteProvider] currentRouteLocationProvider = / (empty configuration)');
      return '/';
    }
    
    // Get the last route match which represents the current screen
    final lastMatch = configuration.last;
    final location = lastMatch.matchedLocation;
    
    debugPrint('[RouteProvider] currentRouteLocationProvider = $location');
    return location;
  } catch (e) {
    debugPrint('[RouteProvider] Error getting location: $e, returning /');
    return '/';
  }
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
      final location = state.matchedLocation;

      debugPrint('[Router] === Auth Check ===');
      debugPrint('[Router] location: $location');
      debugPrint('[Router] auth.isLoading: ${auth.isLoading}, auth.isAuthenticated: ${auth.isAuthenticated}, auth.hasError: ${auth.hasError}');

      final isOnAuthRoute = location == RouteNames.splash ||
          location == RouteNames.roleSelection ||
          location.startsWith('/auth');

      debugPrint('[Router] isOnAuthRoute: $isOnAuthRoute');

      // *** WHILE LOADING: Stay on current route (don't redirect) ***
      if (auth.isLoading) {
        debugPrint('[Router] → Action: Loading, STAY ON CURRENT ROUTE');
        return null;
      }

      // *** CRITICAL: If on auth form and has error, NEVER redirect ***
      if (isOnAuthRoute && auth.hasError) {
        debugPrint('[Router] → Action: *** ERROR ON AUTH ROUTE ***: ${auth.error}');
        debugPrint('[Router] → NO REDIRECT - Keep user on form to fix error');
        return null;
      }

      // *** If on auth route and NOT authenticated, stay on form (don't redirect to role selection) ***
      if (isOnAuthRoute && !auth.isAuthenticated) {
        debugPrint('[Router] → Action: Unauthenticated but on auth route, allow form');
        return null;
      }

      // If authenticated, redirect away from auth screens to role home
      if (auth.isAuthenticated && auth.user != null) {
        if (isOnAuthRoute) {
          debugPrint('[Router] → Action: Authenticated user on auth route, redirect to ${auth.user!.role} home');
          return _homeForRole(auth.user!.role);
        }

        // Role-based access control
        final role = auth.user!.role;
        if (location.startsWith('/customer') && role != UserRole.customer) {
          debugPrint('[Router] → Action: Role mismatch (customer route but $role user), redirect');
          return _homeForRole(role);
        }
        if (location.startsWith('/vendor') && role != UserRole.vendor) {
          debugPrint('[Router] → Action: Role mismatch (vendor route but $role user), redirect');
          return _homeForRole(role);
        }
        if (location.startsWith('/admin') && role != UserRole.admin) {
          debugPrint('[Router] → Action: Role mismatch (admin route but $role user), redirect');
          return _homeForRole(role);
        }

        // User is authenticated and on correct role route
        debugPrint('[Router] → Action: Authenticated on correct route, no redirect');
        return null;
      }

      // Not authenticated and NOT on auth route → send to role selection
      if (!auth.isAuthenticated && !isOnAuthRoute) {
        debugPrint('[Router] → Action: Unauthenticated on protected route, redirect to role selection');
        return RouteNames.roleSelection;
      }

      debugPrint('[Router] → Action: No redirect needed');
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
        builder: (_, __) =>
            const FigmaAuthFlow(role: FigmaAuthRole.customer),
      ),
      GoRoute(
        path: RouteNames.customerRegister,
        builder: (_, __) =>
            const FigmaAuthFlow(role: FigmaAuthRole.customer),
      ),
      GoRoute(
        path: RouteNames.vendorLogin,
        builder: (_, __) =>
            const FigmaAuthFlow(role: FigmaAuthRole.vendor),
      ),
      GoRoute(
        path: RouteNames.vendorRegister,
        builder: (_, __) =>
            const FigmaAuthFlow(role: FigmaAuthRole.vendor),
      ),
      GoRoute(
        path: RouteNames.adminLogin,
        builder: (_, __) => const LoginScreen(role: UserRole.admin),
      ),
      GoRoute(
        path: RouteNames.adminRegister,
        builder: (_, __) => const LoginScreen(role: UserRole.admin),
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
        builder: (_, state) {
          final openCategory = (state.extra as Map<String, dynamic>?)?['openCategoryPicker'] as bool? ?? false;
          return CreateRequestScreen(openCategoryPicker: openCategory);
        },
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
          final startWithGpsDetection = (state.extra as Map<String, dynamic>?)
                  ?['startWithGpsDetection'] as bool? ??
              false;
          return CustomerDeliveryAddressScreen(
            fromCreateRequest: fromCreateRequest,
            startWithGpsDetection: startWithGpsDetection,
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
      GoRoute(
        path: '/admin/categories',
        builder: (_, __) => const AdminCategoryManagementScreen(),
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
