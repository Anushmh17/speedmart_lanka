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
    this.baseBlockDuration = const Duration(minutes: 10),
  });

  final String mockValidCode;
  final int maxSendsPerDestination;
  final int maxVerifyAttemptsPerDestination;
  final Duration baseBlockDuration;

  // Per destination trackers
  final Map<String, int> _sendCounts = {};
  final Map<String, int> _verifyAttempts = {};
  final Map<String, DateTime> _sessionStart = {};  // start of current send window
  final Map<String, DateTime> _blockUntil = {};    // absolute time block expires
  final Map<String, int> _blockCount = {};

  Duration _nextBlockDuration(String destination) {
    final blocks = _blockCount[destination] ?? 0;
    return baseBlockDuration * (blocks + 1);
  }

  bool _isBlocked(String destination) {
    final until = _blockUntil[destination];
    if (until == null) return false;
    if (DateTime.now().isBefore(until)) return true;
    // Block expired — clean up
    _blockUntil.remove(destination);
    return false;
  }

  Duration _remainingBlockDuration(String destination) {
    final until = _blockUntil[destination];
    if (until == null) return Duration.zero;
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _onLimitExceeded(String destination) {
    final blocks = _blockCount[destination] ?? 0;
    _blockCount[destination] = blocks + 1;
    _blockUntil[destination] = DateTime.now().add(_nextBlockDuration(destination));
    _sendCounts.remove(destination);
    _verifyAttempts.remove(destination);
    _sessionStart.remove(destination);
  }

  void resetLimits() {
    _sendCounts.clear();
    _verifyAttempts.clear();
    _sessionStart.clear();
    _blockUntil.clear();
    _blockCount.clear();
  }

  @override
  Future<OtpSendResult> sendOtp({
    required OtpChannel channel,
    required String destination,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1500));

    if (_isBlocked(destination)) {
      final remaining = _remainingBlockDuration(destination);
      final mins = remaining.inMinutes + 1;
      return OtpSendResult.failure(
        'Too many OTP requests. Please try again in $mins minute${mins == 1 ? '' : 's'}.',
      );
    }

    // Start session window on first send
    _sessionStart[destination] ??= DateTime.now();

    final currentSends = _sendCounts[destination] ?? 0;
    if (currentSends >= maxSendsPerDestination) {
      _onLimitExceeded(destination);
      final mins = _remainingBlockDuration(destination).inMinutes + 1;
      return OtpSendResult.failure(
        'Too many OTP requests. Please try again in $mins minute${mins == 1 ? '' : 's'}.',
      );
    }

    _sendCounts[destination] = currentSends + 1;
    return OtpSendResult.success(maskedContact: _maskContact(destination));
  }

  @override
  Future<bool> verifyOtp({
    required OtpChannel channel,
    required String destination,
    required String code,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (_isBlocked(destination)) return false;

    final currentAttempts = _verifyAttempts[destination] ?? 0;
    if (currentAttempts >= maxVerifyAttemptsPerDestination) {
      _onLimitExceeded(destination);
      return false;
    }

    final isValid = code.trim() == mockValidCode;
    if (!isValid) {
      final newAttempts = currentAttempts + 1;
      _verifyAttempts[destination] = newAttempts;
      if (newAttempts >= maxVerifyAttemptsPerDestination) {
        _onLimitExceeded(destination);
      }
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


