import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum OtpChannel { phone }

class OtpSendResult {
  const OtpSendResult({
    required this.success,
    this.message,
    this.maskedContact,
    this.verificationId,
  });

  final bool success;
  final String? message;
  final String? maskedContact;
  // Phone auth only — needed to confirm the SMS code
  final String? verificationId;

  factory OtpSendResult.success({String? maskedContact, String? verificationId}) =>
      OtpSendResult(
        success: true,
        message: 'OTP sent successfully',
        maskedContact: maskedContact,
        verificationId: verificationId,
      );

  factory OtpSendResult.failure(String message) =>
      OtpSendResult(success: false, message: message);
}

abstract class OtpService {
  Future<OtpSendResult> sendOtp({
    required OtpChannel channel,
    required String destination,
  });

  Future<bool> verifyOtp({
    required OtpChannel channel,
    required String destination,
    required String code,
    String? verificationId,
  });
}

// ── Firebase Phone Auth ────────────────────────────────────────────────────

class FirebasePhoneOtpService implements OtpService {
  FirebasePhoneOtpService();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stores verificationId per phone number
  final Map<String, String> _verificationIds = {};
  // Stores auto-resolved credential (instant verification on some devices)
  final Map<String, PhoneAuthCredential> _autoCredentials = {};

  static String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length == 9) return '+94$digits';
    if (digits.length == 10 && digits.startsWith('0')) return '+94${digits.substring(1)}';
    if (digits.length == 11 && digits.startsWith('94')) return '+$digits';
    if (phone.startsWith('+')) return phone;
    return '+94$digits';
  }

  static String _maskPhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.length < 4) return phone;
    return '**** **** ${clean.substring(clean.length - 4)}';
  }

  @override
  Future<OtpSendResult> sendOtp({
    required OtpChannel channel,
    required String destination,
  }) async {
    assert(channel == OtpChannel.phone, 'FirebasePhoneOtpService only handles phone');

    final phone = _normalizePhone(destination);
    final completer = Completer<OtpSendResult>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) {
        // Auto-resolved (Android instant verification)
        _autoCredentials[destination] = credential;
        if (!completer.isCompleted) {
          completer.complete(OtpSendResult.success(
            maskedContact: _maskPhone(destination),
            verificationId: credential.verificationId,
          ));
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        debugPrint('[FirebasePhone] verificationFailed: ${e.code} ${e.message}');
        if (!completer.isCompleted) {
          completer.complete(OtpSendResult.failure(
            _friendlyError(e.code),
          ));
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationIds[destination] = verificationId;
        if (!completer.isCompleted) {
          completer.complete(OtpSendResult.success(
            maskedContact: _maskPhone(destination),
            verificationId: verificationId,
          ));
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationIds[destination] = verificationId;
      },
    );

    return completer.future;
  }

  @override
  Future<bool> verifyOtp({
    required OtpChannel channel,
    required String destination,
    required String code,
    String? verificationId,
  }) async {
    // Use auto-credential if available (instant verification)
    final autoCredential = _autoCredentials.remove(destination);
    if (autoCredential != null) {
      try {
        await _auth.signInWithCredential(autoCredential);
        return true;
      } catch (e) {
        debugPrint('[FirebasePhone] auto credential sign-in failed: $e');
      }
    }

    final vid = verificationId ?? _verificationIds[destination];
    if (vid == null) return false;

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: vid,
        smsCode: code.trim(),
      );
      await _auth.signInWithCredential(credential);
      _verificationIds.remove(destination);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('[FirebasePhone] verifyOtp failed: ${e.code}');
      return false;
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Invalid phone number. Please check and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      default:
        return 'Failed to send OTP. Please try again.';
    }
  }
}

// ── Local mock (debug only) ────────────────────────────────────────────────

class LocalOtpService implements OtpService {
  LocalOtpService({this.validCode = '123456'});
  final String validCode;

  void resetLimits() {}

  @override
  Future<OtpSendResult> sendOtp({
    required OtpChannel channel,
    required String destination,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    debugPrint('[LocalOTP] Code for $destination: $validCode');
    return OtpSendResult.success(maskedContact: destination);
  }

  @override
  Future<bool> verifyOtp({
    required OtpChannel channel,
    required String destination,
    required String code,
    String? verificationId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return code.trim() == validCode;
  }
}
