import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Central Firestore helper used by repository classes.
class FirestoreService {
  FirestoreService._();

  static FirebaseFirestore get instance => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> collection(String path) {
    return instance.collection(path);
  }

  /// Waits until Firebase Auth has an authenticated user, then runs [action].
  /// Gives up after [timeout] and skips the action silently.
  static Future<void> runAuthenticated(
    Future<void> Function() action, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (FirebaseAuth.instance.currentUser != null) {
      await action();
      return;
    }
    try {
      await FirebaseAuth.instance
          .authStateChanges()
          .firstWhere((user) => user != null)
          .timeout(timeout);
      await action();
    } catch (_) {
      // Timed out or unauthenticated — skip sync silently
    }
  }
}
