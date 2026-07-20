import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speedmart_lanka/features/auth/domain/auth_state.dart';
import 'package:speedmart_lanka/features/auth/presentation/screens/splash_screen.dart';
import 'package:speedmart_lanka/features/auth/presentation/screens/login_screen.dart';
import 'package:speedmart_lanka/features/auth/presentation/screens/register_screen.dart';
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
import 'package:speedmart_lanka/features/orders/presentation/screens/vendor_orders_screen.dart';
import 'package:speedmart_lanka/features/vendor/presentation/screens/vendor_home_screen.dart';
import 'package:speedmart_lanka/features/vendor/presentation/screens/vendor_shopfront_screen.dart';
import 'package:speedmart_lanka/features/vendor/proposals/presentation/vendor_request_detail_screen.dart';
import 'package:speedmart_lanka/features/vendor/proposals/presentation/vendor_proposal_form_screen.dart';
import 'package:speedmart_lanka/features/vendor/proposals/presentation/vendor_proposal_detail_screen.dart';
import 'package:speedmart_lanka/features/chat/presentation/screens/chat_screen.dart';
import 'package:speedmart_lanka/features/requests/presentation/screens/request_list_screen.dart';
import 'package:speedmart_lanka/shared/presentation/screens/profile_screen.dart';
import 'package:speedmart_lanka/features/customer/delivery_address/presentation/screens/customer_delivery_address_screen.dart';
import 'package:speedmart_lanka/features/auth/providers/auth_provider.dart';
import 'package:speedmart_lanka/shared/models/user_role.dart';
import 'package:speedmart_lanka/core/routes/route_names.dart';
import 'package:speedmart_lanka/core/storage/storage_service.dart';
import 'package:speedmart_lanka/figma_screens/figma_auth_flow.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Smooth fade + slight upward slide page transition used across all routes.
Page<T> _buildPage<T>(BuildContext context, GoRouterState state, Widget child) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      final slide = Tween<Offset>(
        begin: const Offset(0.0, 0.04),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}

/// Provider to watch the current route location
final currentRouteLocationProvider = Provider<String>((ref) {
  final router = ref.watch(appRouterProvider);
  try {
    final configuration = router.routerDelegate.currentConfiguration;
    if (configuration.isEmpty) return '/';
    return configuration.last.matchedLocation;
  } catch (e) {
    return '/';
  }
});

/// GoRouter instance exposed as a Riverpod provider.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ValueNotifier<AuthState>(const AuthState.initial());

  ref.listen<AuthState>(authProvider, (_, next) {
    authNotifier.value = next;
  });

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RouteNames.splash,
    refreshListenable: authNotifier,
    redirect: (context, state) async {
      final auth = authNotifier.value;
      final location = state.matchedLocation;

      debugPrint('[Router] === Auth Check ===');
      debugPrint('[Router] location: $location');
      debugPrint('[Router] auth.isLoading: ${auth.isLoading}, auth.isAuthenticated: ${auth.isAuthenticated}, auth.hasError: ${auth.hasError}');

      final isOnAuthRoute = location == RouteNames.splash ||
          location.startsWith('/auth');

      debugPrint('[Router] isOnAuthRoute: $isOnAuthRoute');

      if (auth.isLoading) {
        debugPrint('[Router] → Action: Loading, STAY ON CURRENT ROUTE');
        return null;
      }

      if (isOnAuthRoute && auth.hasError) {
        debugPrint('[Router] → Action: ERROR ON AUTH ROUTE: ${auth.error}');
        return null;
      }

      if (isOnAuthRoute && !auth.isAuthenticated) {
        debugPrint('[Router] → Action: Unauthenticated but on auth route, allow form');
        return null;
      }

      if (auth.isAuthenticated && auth.user != null) {
        if (isOnAuthRoute) {
          debugPrint('[Router] → Action: Authenticated user on auth route, redirect to ${auth.user!.role} home');
          return _homeForRole(auth.user!.role);
        }

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

        debugPrint('[Router] → Action: Authenticated on correct route, no redirect');
        return null;
      }

      if (!auth.isAuthenticated && !isOnAuthRoute) {
        debugPrint('[Router] → Action: Unauthenticated on protected route, redirect to login');
        final savedRole = await StorageService.getRole();
        if (savedRole == UserRole.vendor.name) return RouteNames.vendorLogin;
        return RouteNames.customerLogin;
      }

      debugPrint('[Router] → Action: No redirect needed');
      return null;
    },
    routes: [
      // ── Core ─────────────────────────────────────────────────────────────
      GoRoute(
        path: RouteNames.splash,
        pageBuilder: (context, state) => _buildPage(context, state, const SplashScreen()),
      ),

      // ── Auth Routes ──────────────────────────────────────────────────────
      GoRoute(
        path: RouteNames.customerLogin,
        pageBuilder: (context, state) => _buildPage(context, state,
            const FigmaAuthFlow(role: FigmaAuthRole.customer)),
      ),
      GoRoute(
        path: RouteNames.customerRegister,
        pageBuilder: (context, state) => _buildPage(context, state,
            const FigmaAuthFlow(role: FigmaAuthRole.customer)),
      ),
      GoRoute(
        path: RouteNames.vendorLogin,
        pageBuilder: (context, state) => _buildPage(context, state,
            const FigmaAuthFlow(role: FigmaAuthRole.vendor)),
      ),
      GoRoute(
        path: RouteNames.vendorRegister,
        pageBuilder: (context, state) => _buildPage(context, state,
            const FigmaAuthFlow(role: FigmaAuthRole.vendor)),
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
            pageBuilder: (context, state) => _buildPage(context, state, const CustomerHomeTab()),
          ),
          GoRoute(
            path: RouteNames.customerRequests,
            pageBuilder: (context, state) => _buildPage(context, state, const RequestListScreen()),
          ),
          GoRoute(
            path: RouteNames.customerOrders,
            pageBuilder: (context, state) => _buildPage(context, state, const CustomerOrdersTab()),
          ),
          GoRoute(
            path: RouteNames.customerProfile,
            pageBuilder: (context, state) => _buildPage(context, state, const ProfileScreen()),
          ),
        ],
      ),

      // ── Customer Full-Screen Workflows ───────────────────────────────────
      GoRoute(
        path: RouteNames.customerCreateRequest,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final openCategory = (state.extra as Map<String, dynamic>?)?['openCategoryPicker'] as bool? ?? false;
          return _buildPage(context, state, CreateRequestScreen(openCategoryPicker: openCategory));
        },
      ),
      GoRoute(
        path: '/customer/proposals/detail',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final extraMap = state.extra as Map<String, dynamic>;
          final proposal = extraMap['proposal'] as Proposal;
          final requestId = extraMap['requestId'] as String;
          return _buildPage(context, state, CustomerProposalDetailsScreen(
            proposal: proposal,
            requestId: requestId,
          ));
        },
      ),
      GoRoute(
        path: '/customer/payment',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final extraMap = state.extra as Map<String, dynamic>;
          final proposal = extraMap['proposal'] as Proposal;
          final requestId = extraMap['requestId'] as String;
          return _buildPage(context, state, PaymentScreen(
            proposal: proposal,
            requestId: requestId,
          ));
        },
      ),
      GoRoute(
        path: RouteNames.customerPaymentReceipt,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final extraMap = state.extra as Map<String, dynamic>;
          final order = extraMap['order'] as OrderModel;
          final payment = extraMap['payment'];
          if (payment is! PaymentModel) {
            return _buildPage(context, state, const Scaffold(
              body: Center(child: Text('Receipt data not found.')),
            ));
          }
          return _buildPage(context, state, PaymentReceiptScreen(order: order, payment: payment));
        },
      ),
      GoRoute(
        path: RouteNames.customerPaymentHistory,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _buildPage(context, state, const CustomerPaymentHistoryScreen()),
      ),
      GoRoute(
        path: RouteNames.customerDeliveryAddress,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final fromCreateRequest = (state.extra as Map<String, dynamic>?)?['fromCreateRequest'] as bool? ?? false;
          final startWithGpsDetection = (state.extra as Map<String, dynamic>?)?['startWithGpsDetection'] as bool? ?? false;
          return _buildPage(context, state, CustomerDeliveryAddressScreen(
            fromCreateRequest: fromCreateRequest,
            startWithGpsDetection: startWithGpsDetection,
          ));
        },
      ),
      GoRoute(
        path: '/customer/orders/track',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final order = state.extra as OrderModel;
          return _buildPage(context, state, OrderTrackingScreen(order: order));
        },
      ),
      GoRoute(
        path: '/customer/vendor/shopfront',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final extraMap = state.extra as Map<String, dynamic>;
          final vendorName = extraMap['vendorName'] as String;
          final vendorPhone = extraMap['vendorPhone'] as String;
          return _buildPage(context, state, VendorShopfrontScreen(
            vendorName: vendorName,
            vendorPhone: vendorPhone,
          ));
        },
      ),
      GoRoute(
        path: '/chat',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final extraMap = state.extra as Map<String, dynamic>;
          final proposalId = extraMap['proposalId'] as String;
          final vendorName = extraMap['vendorName'] as String;
          final isUnlocked = extraMap['isUnlocked'] as bool;
          final autoMessage = extraMap['autoMessage'] as String?;
          return _buildPage(context, state, ChatScreen(
            proposalId: proposalId,
            vendorName: vendorName,
            isUnlocked: isUnlocked,
            autoMessage: autoMessage,
          ));
        },
      ),

      // ── Vendor ───────────────────────────────────────────────────────────
      GoRoute(
        path: RouteNames.vendorHome,
        pageBuilder: (context, state) => _buildPage(context, state, const VendorHomeScreen()),
      ),
      GoRoute(
        path: RouteNames.vendorRequestDetail,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final request = state.extra as ShoppingRequest?;
          if (request == null) {
            return _buildPage(context, state, const Scaffold(
              body: Center(child: Text('Request not found. Please select again from your vendor dashboard.')),
            ));
          }
          return _buildPage(context, state, VendorRequestDetailScreen(request: request));
        },
      ),
      GoRoute(
        path: RouteNames.vendorProposalCreate,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final request = state.extra as ShoppingRequest?;
          if (request == null) {
            return _buildPage(context, state, const Scaffold(
              body: Center(child: Text('Request not found. Please select a request to create a proposal.')),
            ));
          }
          return _buildPage(context, state, VendorProposalFormScreen(request: request));
        },
      ),
      GoRoute(
        path: RouteNames.vendorProposalDetail,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final proposal = state.extra as Proposal?;
          if (proposal == null) {
            return _buildPage(context, state, const Scaffold(
              body: Center(child: Text('Proposal not found. Please open it again from your proposals list.')),
            ));
          }
          return _buildPage(context, state, VendorProposalDetailScreen(proposal: proposal));
        },
      ),
      GoRoute(
        path: RouteNames.vendorProposalEdit,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final extraMap = state.extra as Map<String, dynamic>?;
          final proposal = extraMap?['proposal'] as Proposal?;
          final request = extraMap?['request'] as ShoppingRequest?;
          if (proposal == null || request == null) {
            return _buildPage(context, state, const Scaffold(
              body: Center(child: Text('Proposal or request not found.')),
            ));
          }
          return _buildPage(context, state, VendorProposalFormScreen(
            request: request,
            existingProposal: proposal,
          ));
        },
      ),
      GoRoute(
        path: '/vendor/orders',
        pageBuilder: (context, state) {
          final extra = state.extra;
          int initialTabIndex = 0;
          if (extra is Map) {
            initialTabIndex = extra['initialTabIndex'] as int? ?? 0;
          }
          return _buildPage(context, state, VendorOrdersScreen(initialTabIndex: initialTabIndex));
        },
      ),
      GoRoute(
        path: '/vendor/orders/manage',
        pageBuilder: (context, state) {
          final order = state.extra as OrderModel;
          return _buildPage(context, state, VendorOrderDetailsScreen(order: order));
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
    case UserRole.admin:    return RouteNames.customerHome;
  }
}
