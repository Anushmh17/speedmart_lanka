import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum SpeedmartCountryMode {
  sriLanka,
  international,
}

enum SpeedmartAuthFlow {
  login,
  register,
}

enum SpeedmartUserRole {
  customer,
  vendor,
}

Future<bool?> showSpeedmartCountrySwitchPopup({
  required BuildContext context,
  required SpeedmartCountryMode targetMode,
  required SpeedmartAuthFlow flow,
  required SpeedmartUserRole role,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.78),
    builder: (_) {
      return SpeedmartCountrySwitchPopup(
        targetMode: targetMode,
        flow: flow,
        role: role,
      );
    },
  );
}

class SpeedmartCountrySwitchPopup extends StatelessWidget {
  final SpeedmartCountryMode targetMode;
  final SpeedmartAuthFlow flow;
  final SpeedmartUserRole role;

  const SpeedmartCountrySwitchPopup({
    super.key,
    required this.targetMode,
    required this.flow,
    required this.role,
  });

  String get _flowText {
    return flow == SpeedmartAuthFlow.login ? 'Login' : 'Register';
  }

  String get _roleSingle {
    return role == SpeedmartUserRole.customer ? 'customer' : 'shop owner';
  }

  String get _rolePlural {
    return role == SpeedmartUserRole.customer ? 'customers' : 'shop owners';
  }

  String get _title {
    if (targetMode == SpeedmartCountryMode.international) {
      return 'Use International $_flowText?';
    }

    return 'Use Sri Lanka $_flowText?';
  }

  String get _message {
    if (targetMode == SpeedmartCountryMode.international) {
      return 'We detected that you may be in Sri Lanka. International ${_flowText.toLowerCase()} is intended for $_rolePlural outside Sri Lanka.';
    }

    if (role == SpeedmartUserRole.customer) {
      return 'We detected that you are not in Sri Lanka. Customer ${_flowText.toLowerCase()} requires Sri Lanka mobile number verification.';
    }

    return 'We detected that you are not in Sri Lanka. Sri Lanka shop owner ${_flowText.toLowerCase()} is intended for shop owners in Sri Lanka.';
  }

  String get _primaryText {
    if (targetMode == SpeedmartCountryMode.international) {
      return 'Change as International';
    }

    return 'Change as Sri Lanka $_flowText';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 34),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 310,
          minWidth: 270,
        ),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.20),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _title,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                color: Colors.black,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),

            const SizedBox(height: 13),

            Text(
              _message,
              textAlign: TextAlign.center,
              style: GoogleFonts.openSans(
                color: const Color(0xFF222222),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.28,
              ),
            ),

            const SizedBox(height: 16),

            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF6F00),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _primaryText,
                textAlign: TextAlign.center,
                style: GoogleFonts.openSans(
                  color: const Color(0xFFFF6F00),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),

            const SizedBox(height: 14),

            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF6F00),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Cancel',
                textAlign: TextAlign.center,
                style: GoogleFonts.openSans(
                  color: const Color(0xFFFF6F00),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
