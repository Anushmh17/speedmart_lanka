import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'otp_service.dart';

/// Brevo (formerly Sendinblue) transactional email OTP service.
///
/// ## Setup
/// 1. Sign up at https://brevo.com (free — 300 emails/day)
/// 2. Go to SMTP & API → API Keys → Generate a new key
/// 3. Go to Senders & Domains → add + verify your sender email
/// 4. Replace the placeholder values in [customer_registration_provider.dart]
///
/// ## Notes
/// - Only handles [OtpChannel.email] — do not call with phone channel
/// - OTP generated locally, stored in-memory with [otpValidDuration] expiry
class BrevoEmailOtpService implements OtpService {
  BrevoEmailOtpService({
    required this.apiKey,
    required this.senderEmail,
    this.senderName = 'SpeedMart Lanka',
    this.otpValidDuration = const Duration(minutes: 5),
    this.maxVerifyAttempts = 5,
    this.maxSendsPerDestination = 5,
    this.baseBlockDuration = const Duration(minutes: 10),
  });

  final String apiKey;
  final String senderEmail;
  final String senderName;
  final Duration otpValidDuration;
  final int maxVerifyAttempts;
  final int maxSendsPerDestination;
  final Duration baseBlockDuration;

  static const _apiUrl = 'https://api.brevo.com/v3/smtp/email';

  final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));

  final Map<String, _OtpEntry> _otpStore = {};
  final Map<String, int> _sendCounts = {};
  final Map<String, int> _verifyAttempts = {};
  final Map<String, DateTime> _blockUntil = {};
  final Map<String, int> _blockCount = {};

  bool _isBlocked(String dest) {
    final until = _blockUntil[dest];
    if (until == null) return false;
    if (DateTime.now().isBefore(until)) return true;
    _blockUntil.remove(dest);
    return false;
  }

  Duration _remainingBlock(String dest) {
    final until = _blockUntil[dest];
    if (until == null) return Duration.zero;
    final r = until.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  void _block(String dest) {
    final count = (_blockCount[dest] ?? 0) + 1;
    _blockCount[dest] = count;
    _blockUntil[dest] = DateTime.now().add(baseBlockDuration * count);
    _sendCounts.remove(dest);
    _verifyAttempts.remove(dest);
    _otpStore.remove(dest);
  }

  String _generateOtp() =>
      (100000 + Random.secure().nextInt(900000)).toString();

  @override
  Future<OtpSendResult> sendOtp({
    required OtpChannel channel,
    required String destination,
  }) async {
    assert(channel == OtpChannel.email,
        'BrevoEmailOtpService only handles OtpChannel.email');

    if (_isBlocked(destination)) {
      final mins = _remainingBlock(destination).inMinutes + 1;
      return OtpSendResult.failure(
        'Too many OTP requests. Please try again in $mins minute${mins == 1 ? '' : 's'}.',
      );
    }

    final sends = _sendCounts[destination] ?? 0;
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

    try {
      final response = await _dio.post(
        _apiUrl,
        data: {
          'sender': {'name': senderName, 'email': senderEmail},
          'to': [
            {'email': destination}
          ],
          'subject': 'Your SpeedMart Lanka Verification Code',
          'htmlContent': _buildEmailHtml(otp),
        },
        options: Options(headers: {
          'api-key': apiKey,
          'Content-Type': 'application/json',
        }),
      );

      debugPrint('[Brevo] Response: ${response.statusCode}');

      // Brevo returns 201 on success
      if (response.statusCode == 201) {
        return OtpSendResult.success(maskedContact: _maskEmail(destination));
      } else {
        _otpStore.remove(destination);
        return OtpSendResult.failure('Failed to send OTP email. Please try again.');
      }
    } on DioException catch (e) {
      _otpStore.remove(destination);
      debugPrint('[Brevo] DioException: ${e.response?.data}');
      final msg = e.response?.data is Map ? e.response?.data['message'] : null;
      return OtpSendResult.failure(
        msg != null
            ? 'Email error: $msg'
            : 'Failed to send OTP. Check your connection and try again.',
      );
    } catch (e) {
      _otpStore.remove(destination);
      debugPrint('[Brevo] Error: $e');
      return OtpSendResult.failure('Failed to send OTP. Please try again.');
    }
  }

  @override
  Future<bool> verifyOtp({
    required OtpChannel channel,
    required String destination,
    required String code,
  }) async {
    if (_isBlocked(destination)) return false;

    final attempts = _verifyAttempts[destination] ?? 0;
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

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final masked =
        name.length > 3 ? '${name.substring(0, 3)}***' : '${name[0]}***';
    return '$masked@${parts[1]}';
  }

  String _buildEmailHtml(String otp) => '''
<!DOCTYPE html>
<html>
<body style="margin:0;padding:0;background:#f4f4f4;font-family:Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0">
    <tr><td align="center" style="padding:40px 0;">
      <table width="480" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.08);">
        <tr><td style="background:#2563EB;padding:28px 32px;text-align:center;">
          <h1 style="margin:0;color:#ffffff;font-size:22px;font-weight:700;">SpeedMart Lanka</h1>
          <p style="margin:6px 0 0;color:rgba(255,255,255,0.8);font-size:13px;">Vendor Verification</p>
        </td></tr>
        <tr><td style="padding:36px 32px;text-align:center;">
          <p style="margin:0 0 8px;color:#374151;font-size:16px;font-weight:600;">Your Verification Code</p>
          <p style="margin:0 0 28px;color:#6B7280;font-size:14px;">Use this code to verify your email. It expires in ${otpValidDuration.inMinutes} minutes.</p>
          <div style="display:inline-block;background:#EFF6FF;border:2px dashed #2563EB;border-radius:10px;padding:18px 40px;">
            <span style="font-size:36px;font-weight:800;letter-spacing:10px;color:#2563EB;">$otp</span>
          </div>
          <p style="margin:28px 0 0;color:#9CA3AF;font-size:12px;">Do not share this code with anyone. SpeedMart Lanka will never ask for your OTP.</p>
        </td></tr>
        <tr><td style="background:#F9FAFB;padding:16px 32px;text-align:center;border-top:1px solid #E5E7EB;">
          <p style="margin:0;color:#9CA3AF;font-size:11px;">© 2025 SpeedMart Lanka. All rights reserved.</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>
''';
}

class _OtpEntry {
  const _OtpEntry({required this.code, required this.expiresAt});
  final String code;
  final DateTime expiresAt;
}
