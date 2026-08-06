import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'core/routes/app_router.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/fcm_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/network_fallback_wrapper.dart';
import 'features/auth/providers/theme_provider.dart';
import 'features/orders/data/order_repository.dart';
import 'features/proposals/data/proposal_repository.dart';
import 'features/requests/data/request_repository.dart';
import 'core/routes/route_names.dart';
import 'core/theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase must be initialized before any Firestore access
  await FcmService.initialize();

  await Future.wait([
    LocalNotificationService.initialize(),
    RequestRepository.instance.ensureInitialized(),
    ProposalRepository.instance.ensureInitialized(),
    OrderRepository.instance.ensureInitialized(),
  ]);

  // Lock to portrait on mobile only; web/desktop should be free.
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
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

class _SpeedmartAppState extends ConsumerState<SpeedmartApp> {

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final router = ref.watch(appRouterProvider);

    final resolvedTheme = themeMode == ThemeMode.dark
        ? AppTheme.darkTheme
        : AppTheme.lightTheme;

    debugPrint('[Theme] MaterialApp building with themeMode=${themeMode.name}');

    return _AppLifecycleManager(
      child: MaterialApp.router(
        title: 'Speedmart Lanka',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        routerConfig: router,
        builder: (context, child) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            SystemChrome.setSystemUIOverlayStyle(
              SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness:
                    isDark ? Brightness.light : Brightness.dark,
                systemNavigationBarColor: Colors.transparent,
              ),
            );
          });

          if (child == null) return const SizedBox.shrink();

          return NetworkFallbackWrapper(
            child: AnimatedTheme(
              data: resolvedTheme,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              child: SizedBox.expand(child: child),
            ),
          );
        },
      ),
    );
  }
}

class _AppLifecycleManager extends StatefulWidget {
  final Widget child;

  const _AppLifecycleManager({required this.child});

  @override
  State<_AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<_AppLifecycleManager>
    with WidgetsBindingObserver {
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
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
