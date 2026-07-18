import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Exposes the current network connectivity state as a Riverpod provider.
/// Consumers can watch [connectivityProvider] to reactively respond to
/// online/offline transitions anywhere in the widget tree.
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();

  /// Returns true if at least one non-none connectivity type is active.
  static bool _isOnline(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// One-shot check — use for guards before network calls.
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return _isOnline(results);
  }

  /// Stream of online/offline booleans — use for reactive UI.
  Stream<bool> get onlineStream => _connectivity.onConnectivityChanged
      .map(_isOnline)
      .distinct();
}

// ── Riverpod providers ────────────────────────────────────────────────────────

/// Provides the current online state as a [StreamProvider].
/// Automatically rebuilds widgets when connectivity changes.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  // Emit the current state immediately so widgets don't wait for the first event.
  yield await ConnectivityService.instance.isOnline();
  yield* ConnectivityService.instance.onlineStream;
});

/// Synchronous convenience — true when online, defaults to true while loading
/// so we don't block UI unnecessarily.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).maybeWhen(
        data: (online) => online,
        orElse: () => true,
      );
});

