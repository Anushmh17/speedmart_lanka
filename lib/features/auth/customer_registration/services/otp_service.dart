enum OtpChannel { phone, email }

/// Result object returned by [OtpService.sendOtp].
class OtpSendResult {
  const OtpSendResult({
    required this.success,
    this.message,
    this.maskedContact,
  });

  final bool success;

  /// Human-readable status message.
  final String? message;

  /// Masked version of the contact for display (e.g. "+94 07X XXX X234").
  final String? maskedContact;

  factory OtpSendResult.success({String? maskedContact}) => OtpSendResult(
        success: true,
        message: 'OTP sent successfully',
        maskedContact: maskedContact,
      );

  factory OtpSendResult.failure(String message) =>
      OtpSendResult(success: false, message: message);
}

/// Abstract OTP service interface.
///
/// Swap [MockOtpService] for [NotifyLkOtpService] (or any other real
/// implementation) without changing calling code.
abstract class OtpService {
  /// Sends a one-time password to [destination] via [channel].
  Future<OtpSendResult> sendOtp({
    required OtpChannel channel,
    required String destination,
  });

  /// Verifies that [code] is the correct OTP for [destination] via [channel].
  ///
  /// Returns `true` on success, `false` on mismatch / expiry.
  Future<bool> verifyOtp({
    required OtpChannel channel,
    required String destination,
    required String code,
  });
}

// ── Mock implementation ────────────────────────────────────────────────────

/// Development-only mock OTP service.
///
/// - [sendOtp]   → always succeeds after a 1.5-second delay, up to [maxSendsPerDestination].
/// - [verifyOtp] → accepts [mockValidCode] as the valid code, up to [maxVerifyAttemptsPerDestination].
///
/// Replace with [NotifyLkOtpService] when integrating production SMS.
class MockOtpService implements OtpService {
  MockOtpService({
    this.mockValidCode = '123456',
    this.maxSendsPerDestination = 5,
    this.maxVerifyAttemptsPerDestination = 5,
  });

  /// The code that will be accepted as valid in [verifyOtp].
  final String mockValidCode;

  /// Max number of times OTP can be sent to a single destination.
  final int maxSendsPerDestination;

  /// Max number of failed OTP verification attempts for a single destination.
  final int maxVerifyAttemptsPerDestination;

  // Trackers per destination
  final Map<String, int> _sendCounts = {};
  final Map<String, int> _verifyAttempts = {};

  /// Resets the rate limiting counters for testing/dev ease.
  void resetLimits() {
    _sendCounts.clear();
    _verifyAttempts.clear();
  }

  @override
  Future<OtpSendResult> sendOtp({
    required OtpChannel channel,
    required String destination,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 1500));

    final currentSends = _sendCounts[destination] ?? 0;
    if (currentSends >= maxSendsPerDestination) {
      return OtpSendResult.failure(
        'Too many OTP requests for this contact. Please wait or contact support.',
      );
    }

    _sendCounts[destination] = currentSends + 1;
    final masked = _maskContact(destination);
    return OtpSendResult.success(maskedContact: masked);
  }

  @override
  Future<bool> verifyOtp({
    required OtpChannel channel,
    required String destination,
    required String code,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final currentAttempts = _verifyAttempts[destination] ?? 0;
    if (currentAttempts >= maxVerifyAttemptsPerDestination) {
      // Exceeded max verification attempts
      return false;
    }

    final isValid = code.trim() == mockValidCode;
    if (!isValid) {
      _verifyAttempts[destination] = currentAttempts + 1;
    }
    return isValid;
  }

  String _maskContact(String contact) {
    if (contact.isEmpty) return contact;
    if (contact.contains('@')) {
      // Email masking: abc***@domain.com
      final parts = contact.split('@');
      final name = parts[0];
      final masked = name.length > 3
          ? '${name.substring(0, 3)}***'
          : '${name[0]}***';
      return '$masked@${parts[1]}';
    } else {
      // Phone masking: show last 4 digits
      final clean = contact.replaceAll(RegExp(r'[^\d+]'), '');
      if (clean.length < 4) return contact;
      final suffix = clean.substring(clean.length - 4);
      return '**** **** $suffix';
    }
  }
}

