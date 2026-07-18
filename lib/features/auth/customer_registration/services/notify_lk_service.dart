// ignore_for_file: avoid_print

/// Placeholder for the Notify.lk SMS gateway integration.
///
/// ## TODO — Real Integration
/// When integrating the live Notify.lk API:
/// 1. Add your API key to `flutter_secure_storage` (never hardcode it).
/// 2. Use `dio` to POST to `https://app.notify.lk/api/v1/send`.
/// 3. Implement rate-limiting and retry logic.
/// 4. Handle Notify.lk error codes (see their API docs).
/// 5. Wire this class into [OtpService] as [NotifyLkOtpService].
///
/// ## API Reference
/// - Documentation: https://notify.lk/api
/// - Required fields: `user_id`, `api_key`, `sender_id`, `to`, `message`
///
/// ## Sender ID
/// Register a sender ID (e.g. "SPEDMART") with Notify.lk to use instead
/// of the default numeric sender. This improves delivery trust.
class NotifyLkService {
  // TODO: inject via constructor once DI is wired up
  // final String _apiKey;
  // final String _userId;
  // final String _senderId;

  /// Sends an OTP SMS to [phoneNumber] via Notify.lk.
  ///
  /// [phoneNumber] must be in international format without '+': `94XXXXXXXXX`
  /// [otp]         is the 6-digit code to embed in the message template.
  ///
  /// Throws [UnimplementedError] until the real integration is in place.
  Future<void> sendSms({
    required String phoneNumber,
    required String otp,
  }) async {
    throw UnimplementedError(
      'NotifyLkService.sendSms() is not yet implemented.\n'
      'Use MockOtpService during development.\n'
      'See notify_lk_service.dart for integration instructions.',
    );

    // ── Future implementation skeleton ──────────────────────────────────
    // final response = await _dio.post(
    //   'https://app.notify.lk/api/v1/send',
    //   data: {
    //     'user_id': _userId,
    //     'api_key': _apiKey,
    //     'sender_id': _senderId,
    //     'to': phoneNumber,
    //     'message': 'Your Speedmart Lanka OTP is $otp. Valid for 5 minutes.',
    //   },
    // );
    // if (response.data['status'] != 'success') {
    //   throw Exception('Notify.lk error: ${response.data['message']}');
    // }
  }

  /// Verifies an OTP code for [phoneNumber].
  ///
  /// NOTE: Notify.lk does not provide a server-side verification endpoint.
  /// Verification must be handled by your own backend (compare against
  /// stored OTP with expiry check).
  ///
  /// This method is a placeholder to document that pattern.
  Future<bool> verifyOtp({
    required String phoneNumber,
    required String userCode,
    required String sentCode,
    required DateTime sentAt,
    Duration validFor = const Duration(minutes: 5),
  }) async {
    throw UnimplementedError(
      'NotifyLkService.verifyOtp() requires a backend OTP store.\n'
      'Implement server-side OTP storage + expiry check.',
    );
  }
}

