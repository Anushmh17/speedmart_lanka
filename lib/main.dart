import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_api_availability/google_api_availability.dart';

import 'core/routes/app_router.dart';
import 'core/services/fcm_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/network_fallback_wrapper.dart';
import 'features/auth/providers/theme_provider.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Block unsupported devices (Huawei without GMS) before Firebase init.
  if (!kIsWeb) {
    final gmsStatus = await GoogleApiAvailability.instance
        .checkGooglePlayServicesAvailability();
    if (gmsStatus != GooglePlayServicesAvailability.success) {
      runApp(const _UnsupportedDeviceApp());
      return;
    }
  }

  // Only Firebase must be initialized before the first frame.
  // Everything else is deferred to the splash screen so the native
  // loading screen disappears immediately and Flutter takes over.
  await FcmService.initialize();

  // Lock to portrait on mobile only; web/desktop should be free.
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top],
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
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
  static const _channel = MethodChannel('com.speedmart.lk/system_ui');
  bool _keyboardWasOpen = false;

  static Future<void> _hideNavBar() async {
    try {
      await _channel.invokeMethod('hideNavBar');
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _hideNavBar());
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding
        .instance.platformDispatcher.views.first.viewInsets.bottom;
    final keyboardOpen = bottomInset > 0;
    if (_keyboardWasOpen && !keyboardOpen) _hideNavBar();
    _keyboardWasOpen = keyboardOpen;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _hideNavBar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _UnsupportedDeviceApp extends StatelessWidget {
  const _UnsupportedDeviceApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0A1628),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png', width: 160),
                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phonelink_erase_rounded,
                      color: Colors.redAccent, size: 56),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Device Not Supported',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Speedmart Lanka requires Google Play Services, which is not available on this device.\n\nPlease use a device with Google Play Services to continue.',
                  style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.6),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
