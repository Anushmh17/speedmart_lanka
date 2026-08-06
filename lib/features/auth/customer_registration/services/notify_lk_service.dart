import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'otp_service.dart';

/// Notify.lk SMS gateway OTP implementation.
///
/// ## Setup
/// 1. Register at https://app.notify.lk
/// 2. Get your User ID and API Key from the dashboard
/// 3. Register a Sender ID (e.g. SPEDMART) — or use the default
/// 4. Replace the placeholder values below with your real credentials
///
/// ## Notes
/// - OTP is generated locally and stored in-memory with a 5-minute expiry
/// - Email channel falls back to [LocalOtpService] behaviour (mock) since
///   Notify.lk is SMS-only. Wire up an email provider separately if needed.
class NotifyLkOtpService implements OtpService {
  NotifyLkOtpService({
    required this.userId,
    required this.apiKey,
    required this.senderId,
    this.otpValidDuration = const Duration(minutes: 5),
    this.maxVerifyAttempts = 5,
    this.maxSendsPerDestination = 5,
    this.baseBlockDuration = const Duration(minutes: 10),
  });

  final String userId;
  final String apiKey;
  final String senderId;
  final Duration otpValidDuration;
  final int maxVerifyAttempts;
  final int maxSendsPerDestination;
  final Duration baseBlockDuration;

  static const _apiUrl = 'https://app.notify.lk/api/v1/send';

  final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));

  // In-memory OTP store: destination → {code, expiresAt}
  final Map<String, _OtpEntry> _otpStore = {};

  // Rate limiting
  final Map<String, int> _sendCounts = {};
  final Map<String, DateTime> _blockUntil = {};
  final Map<String, int> _blockCount = {};
  final Map<String, int> _verifyAttempts = {};

  bool _isBlocked(String destination) {
    final until = _blockUntil[destination];
    if (until == null) return false;
    if (DateTime.now().isBefore(until)) return true;
    _blockUntil.remove(destination);
    return false;
  }

  Duration _remainingBlock(String destination) {
    final until = _blockUntil[destination];
    if (until == null) return Duration.zero;
    final r = until.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  void _block(String destination) {
    final count = (_blockCount[destination] ?? 0) + 1;
    _blockCount[destination] = count;
    _blockUntil[destination] =
        DateTime.now().add(baseBlockDuration * count);
    _sendCounts.remove(destination);
    _verifyAttempts.remove(destination);
    _otpStore.remove(destination);
  }

  String _generateOtp() =>
      (100000 + Random.secure().nextInt(900000)).toString();

  String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    // Convert local 07XXXXXXXX → 947XXXXXXXX
    if (digits.startsWith('0') && digits.length == 10) {
      return '94${digits.substring(1)}';
    }
    // Already international without +
    if (digits.startsWith('94') && digits.length == 11) return digits;
    return digits;
  }

  @override
  Future<OtpSendResult> sendOtp({
    required OtpChannel channel,
    required String destination,
  }) async {
    if (_isBlocked(destination)) {
      final mins = _remainingBlock(destination).inMinutes + 1;
      return OtpSendResult.failure(
        'Too many OTP requests. Please try again in $mins minute${mins == 1 ? '' : 's'}.',
      );
    }

    final sends = (_sendCounts[destination] ?? 0);
    if (sends >= maxSendsPerDestination) {
      _block(destination);
      final mins = _remainingBlock(destination).inMinutes + 1;
      return OtpSendResult.failure(
        'Too many OTP requests. Please try again in $mins minute${mins == 1 ? '' : 's'}.',
      );
    }

    final otp = _generateOtp();
    _otpStore[destination] = _OtpEntry(
      code: otp,
      expiresAt: DateTime.now().add(otpValidDuration),
    );
    _sendCounts[destination] = sends + 1;

    if (channel == OtpChannel.phone) {
      try {
        final phone = _normalizePhone(destination);
        final message =
            'Your Speedmart Lanka OTP is $otp. Valid for ${otpValidDuration.inMinutes} minutes. Do not share this code.';

        final response = await _dio.post(
          _apiUrl,
          data: {
            'user_id': userId,
            'api_key': apiKey,
            'sender_id': senderId,
            'to': phone,
            'message': message,
          },
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );

        debugPrint('[NotifyLk] Response: ${response.data}');

        final status = response.data is Map
            ? response.data['status']
            : null;

        if (status == 'success') {
          return OtpSendResult.success(maskedContact: _maskPhone(destination));
        } else {
          final msg = response.data is Map
              ? response.data['message'] ?? 'SMS delivery failed.'
              : 'SMS delivery failed.';
          _otpStore.remove(destination);
          return OtpSendResult.failure(msg.toString());
        }
      } on DioException catch (e) {
        _otpStore.remove(destination);
        debugPrint('[NotifyLk] DioException: $e');
        return OtpSendResult.failure(
          'Failed to send OTP. Please check your connection and try again.',
        );
      } catch (e) {
        _otpStore.remove(destination);
        debugPrint('[NotifyLk] Error: $e');
        return OtpSendResult.failure('Failed to send OTP. Please try again.');
      }
    } else {
      // Email channel — OTP is stored, caller must deliver via email provider
      debugPrint('[NotifyLk] Email OTP generated for $destination (not sent — wire up email provider)');
      return OtpSendResult.success(maskedContact: _maskEmail(destination));
    }
  }

  @override
  Future<bool> verifyOtp({
    required OtpChannel channel,
    required String destination,
    required String code,
  }) async {
    if (_isBlocked(destination)) return false;

    final attempts = (_verifyAttempts[destination] ?? 0);
    if (attempts >= maxVerifyAttempts) {
      _block(destination);
      return false;
    }

    final entry = _otpStore[destination];
    if (entry == null) return false;

    if (DateTime.now().isAfter(entry.expiresAt)) {
      _otpStore.remove(destination);
      return false;
    }

    if (code.trim() == entry.code) {
      _otpStore.remove(destination);
      _sendCounts.remove(destination);
      _verifyAttempts.remove(destination);
      return true;
    }

    final newAttempts = attempts + 1;
    _verifyAttempts[destination] = newAttempts;
    if (newAttempts >= maxVerifyAttempts) _block(destination);
    return false;
  }

  String _maskPhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.length < 4) return phone;
    return '**** **** ${clean.substring(clean.length - 4)}';
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final masked =
        name.length > 3 ? '${name.substring(0, 3)}***' : '${name[0]}***';
    return '$masked@${parts[1]}';
  }
}

class _OtpEntry {
  const _OtpEntry({required this.code, required this.expiresAt});
  final String code;
  final DateTime expiresAt;
}
