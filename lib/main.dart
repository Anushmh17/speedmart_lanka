import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routes/app_router.dart';
import 'core/services/local_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/global_notification_overlay.dart';
import 'features/auth/providers/theme_provider.dart';
import 'features/orders/data/mock_order_repository.dart';
import 'features/proposals/data/mock_proposal_repository.dart';
import 'features/requests/data/mock_request_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocalNotificationService.initialize();

  // Load persisted mock request/proposal/order data before UI.
  // TODO: Replace with backend API sync on app start.
  await Future.wait([
    MockRequestRepository.instance.ensureInitialized(),
    MockProposalRepository.instance.ensureInitialized(),
    MockOrderRepository.instance.ensureInitialized(),
  ]);

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Show status bar with transparent background.
  // Edge-to-edge allows Flutter to draw behind the status/nav bars while
  // MediaQuery.padding (via SafeArea) ensures content is never obscured.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // overridden per-screen
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  runApp(
    const ProviderScope(
      child: SpeedmartApp(),
    ),
  );
}

class SpeedmartApp extends ConsumerStatefulWidget {
  const SpeedmartApp({super.key});

  @override
  ConsumerState<SpeedmartApp> createState() => _SpeedmartAppState();
}

class _SpeedmartAppState extends ConsumerState<SpeedmartApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Restore edge-to-edge if the system reverts it (e.g. after a permission dialog)
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _updateStatusBarBrightness(ThemeMode mode) {
    final isDark = mode == ThemeMode.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final router = ref.watch(appRouterProvider);

    // Keep status bar icon style in sync with theme
    _updateStatusBarBrightness(themeMode);

    return MaterialApp.router(
      title: 'Speedmart Lanka',
      debugShowCheckedModeBanner: false,

      // Themes
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,

      // Router
      routerConfig: router,

      // Global Notification Overlay Layer
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const GlobalNotificationOverlay(),
          ],
        );
      },
    );
  }
}
