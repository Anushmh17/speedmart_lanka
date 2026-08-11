import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Exposes the current network connectivity state as a Riverpod provider.
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();

  static bool _hasInterface(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// True reachability check — verifies actual internet, not just network interface.
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    if (!_hasInterface(results)) return false;
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Stream of online/offline booleans — emits on connectivity change then
  /// re-checks real reachability.
  Stream<bool> get onlineStream async* {
    await for (final results in _connectivity.onConnectivityChanged) {
      if (!_hasInterface(results)) {
        yield false;
      } else {
        yield await isOnline();
      }
    }
  }
}

// ── Riverpod providers ────────────────────────────────────────────────────────

final connectivityProvider = StreamProvider<bool>((ref) async* {
  yield await ConnectivityService.instance.isOnline();
  yield* ConnectivityService.instance.onlineStream;
});

/// Synchronous convenience — true when online, defaults to true while loading.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).maybeWhen(
        data: (online) => online,
        orElse: () => true,
      );
});

