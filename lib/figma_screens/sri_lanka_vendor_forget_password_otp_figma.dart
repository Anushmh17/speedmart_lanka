import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'new_password_update_sri_lanka_vendor_figma.dart';

class SrilankavendorforgetpasswordotpWidget extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onSignIn;
  final VoidCallback? onResendCode;
  final ValueChanged<String>? onVerifyCode;

  const SrilankavendorforgetpasswordotpWidget({
    super.key,
    this.onBack,
    this.onSignIn,
    this.onResendCode,
    this.onVerifyCode,
  });

  @override
  State<SrilankavendorforgetpasswordotpWidget> createState() =>
      _SrilankavendorforgetpasswordotpWidgetState();
}

class _SrilankavendorforgetpasswordotpWidgetState
    extends State<SrilankavendorforgetpasswordotpWidget> {
  static const String _assetBase =
      'assets/images/figma/sri_lanka_vendor_forget_password_otp/';

  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  final List<FocusNode> _otpFocusNodes = List.generate(
    6,
    (_) => FocusNode(),
  );

  String _errorMessage = '';

  void _handleVerifyCode() {
    final code = _otpControllers.map((controller) => controller.text).join();

    if (code.length < 6) {
      setState(() => _errorMessage = 'Please enter the 6 digit OTP.');
      return;
    }
    if (code != '123456') {
      setState(() => _errorMessage = 'Invalid OTP. Please try again.');
      return;
    }
    setState(() => _errorMessage = '');
    if (widget.onVerifyCode != null) {
      widget.onVerifyCode!(code);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const NewpasswordupdatesrilankavendorWidget(),
      ),
    );
  }

  void _handleResendCode() {
    if (widget.onResendCode != null) {
      widget.onResendCode!();
      return;
    }

    debugPrint('Sri Lanka vendor forget password resend code clicked');
  }

  @override
  void dispose() {
    for (final controller in _otpControllers) {
      controller.dispose();
    }

    for (final focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final h = media.size.height;

    final keyboardOpen = media.viewInsets.bottom > 0;

    final sx = w / 360;
    final sy = h / 850;
    final fontScale = sx.clamp(0.92, 1.08).toDouble();

    double x(double value) => value * sx;
    double y(double value) => value * sy;
    double fs(double value) => value * fontScale;

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.noScaling),
      child: Theme(
        data: Theme.of(context).copyWith(
          brightness: Brightness.dark,
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: Color(0xFFFF8213),
            selectionColor: Color.fromRGBO(255, 130, 19, 0.25),
            selectionHandleColor: Color(0xFFFF8213),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            filled: false,
            fillColor: Colors.transparent,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFF040504),
          resizeToAvoidBottomInset: false,
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SizedBox(
              width: w,
              height: h,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                offset: Offset(0, keyboardOpen ? -0.10 : 0),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: y(240),
                      child: Image.asset(
                        '${_assetBase}Vendorforgetpasswordotpscreenheroimage1.png',
                        fit: BoxFit.fill,
                      ),
                    ),

                    Positioned(
                      top: y(35),
                      left: x(15),
                      child: GestureDetector(
                        onTap:
                            widget.onBack ?? () => Navigator.maybePop(context),
                        child: Container(
                          width: x(30),
                          height: x(30),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: x(2.5),
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: x(20),
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(248),
                      left: x(32),
                      child: SizedBox(
                        width: x(296),
                        height: y(119),
                        child: Stack(
                          children: [
                            _StepCircle(
                              top: 0,
                              left: x(15),
                              size: x(45),
                              active: false,
                              icon: Icons.email_outlined,
                              iconSize: x(23),
                            ),

                            Positioned(
                              top: y(11),
                              left: x(68),
                              child: Text(
                                '-----------',
                                style: TextStyle(
                                  color: const Color(0xFF373737),
                                  fontFamily: 'OpenSans',
                                  fontSize: fs(14),
                                  fontWeight: FontWeight.w600,
                                  height: 1,
                                ),
                              ),
                            ),

                            Positioned(
                              top: 0,
                              left: x(125),
                              child: Container(
                                width: x(45),
                                height: x(45),
                                decoration: BoxDecoration(
                                  color:
                                      const Color.fromRGBO(224, 105, 0, 0.05),
                                  border: Border.all(
                                    color: const Color(0xFFFF8D28),
                                    width: x(1.4),
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Transform.rotate(
                                    angle: 0.18,
                                    child: Image.asset(
                                      '${_assetBase}Paperplaneicon.png',
                                      width: x(25),
                                      height: x(20),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            Positioned(
                              top: y(11),
                              left: x(178),
                              child: Text(
                                '-----------',
                                style: TextStyle(
                                  color: const Color(0xFF373737),
                                  fontFamily: 'OpenSans',
                                  fontSize: fs(14),
                                  fontWeight: FontWeight.w600,
                                  height: 1,
                                ),
                              ),
                            ),

                            _StepCircle(
                              top: 0,
                              left: x(235),
                              size: x(45),
                              active: false,
                              icon: Icons.verified_user_outlined,
                              iconSize: x(23),
                            ),

                            Positioned(
                              top: y(52),
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _StepLabel(
                                    number: '1.',
                                    label: 'Enter Email',
                                    fontSize: fs(12),
                                  ),
                                  _StepLabel(
                                    number: '2.',
                                    label: 'Check Email',
                                    fontSize: fs(12),
                                  ),
                                  _StepLabel(
                                    number: '3.',
                                    label: 'Reset Password',
                                    fontSize: fs(12),
                                  ),
                                ],
                              ),
                            ),

                            Positioned(
                              top: y(87),
                              left: x(6),
                              right: x(6),
                              child: Text(
                                'We sent a 6 digit verification code to\nyour registered email. Enter it below to continue.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFFBBBABB),
                                  fontFamily: 'OpenSans',
                                  fontSize: fs(14),
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(395),
                      left: x(19),
                      child: SizedBox(
                        width: x(321),
                        height: y(127),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 0,
                              left: 0,
                              child: Row(
                                children: [
                                  Image.asset(
                                    '${_assetBase}Approvedlockicon.png',
                                    width: x(24),
                                    height: x(20),
                                    fit: BoxFit.contain,
                                  ),
                                  SizedBox(width: x(9)),
                                  Text(
                                    'Verification Code',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'OpenSans',
                                      fontSize: fs(14),
                                      fontWeight: FontWeight.w800,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Positioned(
                              top: y(45),
                              left: 0,
                              right: 0,
                              child: SizedBox(
                                height: y(48),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: List.generate(6, (index) {
                                    return _OtpBox(
                                      width: x(46),
                                      height: y(48),
                                      radius: x(10),
                                      fontSize: fs(20),
                                      controller: _otpControllers[index],
                                      focusNode: _otpFocusNodes[index],
                                      onChanged: (value) {
                                        if (value.isNotEmpty && index < 5) {
                                          _otpFocusNodes[index + 1]
                                              .requestFocus();
                                        }

                                        if (value.isEmpty && index > 0) {
                                          _otpFocusNodes[index - 1]
                                              .requestFocus();
                                        }
                                      },
                                    );
                                  }),
                                ),
                              ),
                            ),

                            Positioned(
                              top: y(111),
                              left: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _handleResendCode,
                                child: RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text:
                                            'Didn’t receive the code? Resend code in ',
                                        style: TextStyle(
                                          color: const Color(0xFFBBBABB),
                                          fontFamily: 'OpenSans',
                                          fontSize: fs(12.5),
                                          fontWeight: FontWeight.w600,
                                          height: 1,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '24s',
                                        style: TextStyle(
                                          color: const Color(0xFFEEB556),
                                          fontFamily: 'OpenSans',
                                          fontSize: fs(12),
                                          fontWeight: FontWeight.w800,
                                          height: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(544),
                      left: x(18),
                      child: Container(
                        width: x(325),
                        height: y(87),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(x(10)),
                          border: Border.all(
                            color: const Color(0xFFFF8213),
                            width: x(1),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: x(18)),
                            Container(
                              width: x(45),
                              height: x(45),
                              decoration: BoxDecoration(
                                color:
                                    const Color.fromRGBO(224, 105, 0, 0.05),
                                border: Border.all(
                                  color: const Color(0xFFFF8D28),
                                  width: x(1.4),
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Image.asset(
                                  '${_assetBase}Shopicon.png',
                                  width: x(35),
                                  height: x(25),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            SizedBox(width: x(14)),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'For Shop Owners',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'OpenSans',
                                      fontSize: fs(14),
                                      fontWeight: FontWeight.w800,
                                      height: 1,
                                    ),
                                  ),
                                  SizedBox(height: y(9)),
                                  Text(
                                    'Use the code sent to your registered\nshop email address.',
                                    style: TextStyle(
                                      color: const Color(0xFFBBBABB),
                                      fontFamily: 'OpenSans',
                                      fontSize: fs(14),
                                      fontWeight: FontWeight.w600,
                                      height: 1.15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: x(10)),
                          ],
                        ),
                      ),
                    ),

                    if (_errorMessage.isNotEmpty)
                      Positioned(
                        top: y(635),
                        left: x(22),
                        right: x(22),
                        child: Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red,
                            fontFamily: 'OpenSans',
                            fontSize: fs(13),
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                      ),

                    Positioned(
                      top: y(660),
                      left: x(22),
                      right: x(22),
                      child: SizedBox(
                        height: y(49),
                        child: ElevatedButton(
                          onPressed: _handleVerifyCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFB6F02),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(x(20)),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                '${_assetBase}Protect.png',
                                width: x(20),
                                height: x(20),
                                fit: BoxFit.contain,
                              ),
                              SizedBox(width: x(10)),
                              Text(
                                'Verify Code',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'OpenSans',
                                  fontSize: fs(18),
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(739),
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Remember your password?',
                            style: TextStyle(
                              color: const Color(0xFFBBBABB),
                              fontFamily: 'OpenSans',
                              fontSize: fs(13),
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                          SizedBox(width: x(6)),
                          GestureDetector(
                            onTap: widget.onSignIn ??
                                () => debugPrint('Vendor Sign In clicked'),
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                color: const Color(0xFFEEB556),
                                fontFamily: 'OpenSans',
                                fontSize: fs(13),
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Positioned(
                      top: y(777),
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: const Color(0xFFBBBABB),
                            size: x(16),
                          ),
                          SizedBox(width: x(6)),
                          Text(
                            'Secure and encrypted login',
                            style: TextStyle(
                              color: const Color(0xFFBBBABB),
                              fontFamily: 'OpenSans',
                              fontSize: fs(13),
                              fontWeight: FontWeight.w500,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final double fontSize;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.width,
    required this.height,
    required this.radius,
    required this.fontSize,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        focusNode.requestFocus();
      },
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: const Color(0xFFBBBABB),
            width: 1,
          ),
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          textAlign: TextAlign.center,
          maxLength: 1,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          cursorColor: const Color(0xFFFF8213),
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isCollapsed: true,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  final double top;
  final double left;
  final double size;
  final bool active;
  final IconData icon;
  final double iconSize;

  const _StepCircle({
    required this.top,
    required this.left,
    required this.size,
    required this.active,
    required this.icon,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: active
              ? const Color.fromRGBO(224, 105, 0, 0.05)
              : const Color.fromRGBO(187, 186, 187, 0.05),
          border: active
              ? Border.all(
                  color: const Color(0xFFFF8D28),
                  width: 1.4,
                )
              : null,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            icon,
            color: active ? const Color(0xFFEEB556) : const Color(0xFFBBBABB),
            size: iconSize,
          ),
        ),
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  final String number;
  final String label;
  final double fontSize;

  const _StepLabel({
    required this.number,
    required this.label,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          number,
          style: TextStyle(
            color: const Color(0xFFFF8213),
            fontFamily: 'OpenSans',
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFFBBBABB),
            fontFamily: 'OpenSans',
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ],
    );
  }
}
