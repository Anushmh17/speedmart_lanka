/// Represents the current step in the customer registration flow.
enum RegistrationStep {
  /// Step 1 — User fills in personal + delivery details.
  details,

  /// Transitional — OTP is being sent (loading state).
  sendingOtp,

  /// Step 2 — User enters the 6-digit OTP code.
  verifyOtp,

  /// Step 3 — Registration complete; showing success state.
  success,
}

