import 'package:flutter/material.dart';

/// Warning when [selectedCountry] is OTHER but GPS/locale detected Sri Lanka.
class CountryMismatchDialog extends StatelessWidget {
  const CountryMismatchDialog({
    super.key,
    required this.onContinueInternational,
    required this.onUseSriLankaOtp,
  });

  final VoidCallback onContinueInternational;
  final VoidCallback onUseSriLankaOtp;

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onContinueInternational,
    required VoidCallback onUseSriLankaOtp,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CountryMismatchDialog(
        onContinueInternational: () {
          onContinueInternational();
          Navigator.of(ctx).pop();
        },
        onUseSriLankaOtp: () {
          onUseSriLankaOtp();
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Use international registration?'),
      content: const Text(
        'We detected that you may be in Sri Lanka. International registration is '
        'intended for customers outside Sri Lanka. Some features may require phone '
        'verification.',
      ),
      actions: [
        TextButton(
          onPressed: onContinueInternational,
          child: const Text('Continue as International'),
        ),
        TextButton(
          onPressed: onUseSriLankaOtp,
          child: const Text('Use Sri Lanka Phone OTP'),
        ),
      ],
    );
  }
}