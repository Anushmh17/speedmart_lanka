import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Central Firestore helper used by repository classes.
class FirestoreService {
  FirestoreService._();

  static FirebaseFirestore get instance => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> collection(String path) {
    return instance.collection(path);
  }

  /// Runs [action] only if Firebase Auth has an authenticated user.
  /// If not authenticated, fires and forgets after auth state arrives (non-blocking).
  static Future<void> runAuthenticated(
    Future<void> Function() action, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (FirebaseAuth.instance.currentUser != null) {
      await action();
      return;
    }
    // Not authenticated yet — run non-blocking in background
    FirebaseAuth.instance
        .authStateChanges()
        .firstWhere((user) => user != null)
        .timeout(timeout)
        .then((_) => action())
        .catchError((_) {}); // Timed out or unauthenticated — skip silently
  }
}
