import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Converts raw exceptions into short, user-friendly messages.
///
/// Usage:
///   catch (e) {
///     setState(() => _error = ErrorTranslator.friendly(e));
///   }
class ErrorTranslator {
  ErrorTranslator._();

  static String friendly(Object e) {
    // ── Firebase Auth ────────────────────────────────────────────────────────
    if (e is FirebaseAuthException) {
      return _fromAuthCode(e.code);
    }

    // ── Firestore ────────────────────────────────────────────────────────────
    if (e is FirebaseException && e.plugin == 'cloud_firestore') {
      return _fromFirestoreCode(e.code);
    }

    // ── Firebase Storage ─────────────────────────────────────────────────────
    if (e is FirebaseException && e.plugin == 'firebase_storage') {
      return _fromStorageCode(e.code);
    }

    // ── Network / Socket ─────────────────────────────────────────────────────
    if (e is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    }

    // ── Timeout ──────────────────────────────────────────────────────────────
    if (e is TimeoutException) {
      return 'The request timed out. Please try again.';
    }

    // ── FormatException ──────────────────────────────────────────────────────
    if (e is FormatException) {
      return 'Something went wrong while processing the data. Please try again.';
    }

    // ── Generic / Unknown ────────────────────────────────────────────────────
    final raw = e.toString().toLowerCase();

    if (raw.contains('network') || raw.contains('socket') || raw.contains('connection')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (raw.contains('timeout')) {
      return 'The request timed out. Please try again.';
    }
    if (raw.contains('permission') || raw.contains('permission-denied')) {
      return 'You don\'t have permission to perform this action.';
    }
    if (raw.contains('not-found')) {
      return 'The requested data was not found. It may have been removed.';
    }
    if (raw.contains('unavailable') || raw.contains('server')) {
      return 'The server is temporarily unavailable. Please try again shortly.';
    }
    if (raw.contains('unauthenticated') || raw.contains('sign in')) {
      return 'Your session has expired. Please sign in again.';
    }

    // Absolute fallback — never show raw internal errors to users
    return 'Something went wrong. Please try again.';
  }

  // ── Firebase Auth codes ───────────────────────────────────────────────────

  static String _fromAuthCode(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this phone number or email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Your password is too weak. Please use a stronger password.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network and try again.';
      case 'session-expired':
        return 'Your verification code has expired. Please request a new one.';
      case 'invalid-verification-code':
        return 'The verification code is incorrect. Please try again.';
      case 'credential-already-in-use':
        return 'This phone number is already linked to another account.';
      case 'requires-recent-login':
        return 'Please sign out and sign back in to perform this action.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please contact support.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  // ── Firestore codes ───────────────────────────────────────────────────────

  static String _fromFirestoreCode(String code) {
    switch (code) {
      case 'permission-denied':
        return 'You don\'t have permission to perform this action.';
      case 'not-found':
        return 'The requested data was not found. It may have been removed.';
      case 'already-exists':
        return 'This record already exists.';
      case 'resource-exhausted':
        return 'Service is temporarily busy. Please try again in a moment.';
      case 'failed-precondition':
        return 'This action cannot be performed right now. Please try again.';
      case 'unavailable':
        return 'The server is temporarily unavailable. Please try again shortly.';
      case 'deadline-exceeded':
        return 'The request took too long. Please check your connection and try again.';
      case 'unauthenticated':
        return 'Your session has expired. Please sign in again.';
      case 'cancelled':
        return 'The operation was cancelled. Please try again.';
      case 'data-loss':
        return 'An unexpected error occurred. Please try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  // ── Firebase Storage codes ────────────────────────────────────────────────

  static String _fromStorageCode(String code) {
    switch (code) {
      case 'object-not-found':
        return 'The file was not found. It may have been deleted.';
      case 'bucket-not-found':
        return 'Storage is not configured correctly. Please contact support.';
      case 'unauthorized':
        return 'You don\'t have permission to access this file.';
      case 'canceled':
        return 'Upload was cancelled.';
      case 'unknown':
        return 'An unknown storage error occurred. Please try again.';
      case 'quota-exceeded':
        return 'Storage quota exceeded. Please contact support.';
      case 'unauthenticated':
        return 'Your session has expired. Please sign in again.';
      case 'retry-limit-exceeded':
        return 'Upload failed after multiple attempts. Please check your connection.';
      case 'invalid-checksum':
        return 'The file was corrupted during upload. Please try again.';
      default:
        return 'File upload failed. Please try again.';
    }
  }
}
