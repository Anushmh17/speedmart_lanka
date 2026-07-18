import 'package:flutter/material.dart';

class SrilankavendorforgetpasswordWidget extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onSendResetCode;
  final VoidCallback? onSignIn;
  final TextEditingController? emailController;
  final bool isLoading;

  const SrilankavendorforgetpasswordWidget({
    super.key,
    this.onBack,
    this.onSendResetCode,
    this.onSignIn,
    this.emailController,
    this.isLoading = false,
  });

  @override
  State<SrilankavendorforgetpasswordWidget> createState() =>
      _SrilankavendorforgetpasswordWidgetState();
}

class _SrilankavendorforgetpasswordWidgetState
    extends State<SrilankavendorforgetpasswordWidget> {
  static const String _assetBase =
      'assets/images/figma/sri_lanka_vendor_forget_password/';

  late final TextEditingController _emailController;
  late final bool _ownsEmailController;

  final FocusNode _emailFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _ownsEmailController = widget.emailController == null;
    _emailController = widget.emailController ?? TextEditingController();
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();

    if (_ownsEmailController) {
      _emailController.dispose();
    }
    super.dispose();
  }

  void _handleSendResetCode() {
    if (widget.onSendResetCode != null) {
      widget.onSendResetCode!();
      return;
    }

    debugPrint('Sri Lanka vendor reset code clicked: ${_emailController.text}');
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
                      height: y(255),
                      child: Image.asset(
                        '${_assetBase}Vendorforgetpasswordscreen1.png',
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
                      top: y(271),
                      left: x(32),
                      child: SizedBox(
                        width: x(296),
                        height: y(107),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Text(
                                'Reset your password in 3 simple steps',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFFBBBABB),
                                  fontFamily: 'OpenSans',
                                  fontSize: fs(14),
                                  fontWeight: FontWeight.w600,
                                  height: 1,
                                ),
                              ),
                            ),

                            _StepCircle(
                              top: y(41),
                              left: x(15),
                              size: x(45),
                              active: true,
                              icon: Icons.email_outlined,
                              iconSize: x(23),
                            ),

                            Positioned(
                              top: y(52),
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
                              top: y(41),
                              left: x(125),
                              child: Container(
                                width: x(45),
                                height: x(45),
                                decoration: const BoxDecoration(
                                  color: Color.fromRGBO(187, 186, 187, 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Transform.rotate(
                                    angle: 0.1,
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
                              top: y(52),
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
                              top: y(41),
                              left: x(235),
                              size: x(45),
                              active: false,
                              icon: Icons.verified_user_outlined,
                              iconSize: x(23),
                            ),

                            Positioned(
                              top: y(93),
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
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(412),
                      left: x(16),
                      child: SizedBox(
                        width: x(327),
                        height: y(110),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 0,
                              left: 0,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.mail_outline_rounded,
                                    color: const Color(0xFFFF8213),
                                    size: x(25),
                                  ),
                                  SizedBox(width: x(8)),
                                  Text(
                                    'Registered Email Address',
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
                              top: y(35),
                              left: x(7),
                              child: Text(
                                'Enter the email address you used to register your',
                                style: TextStyle(
                                  color: const Color(0xFFBBBABB),
                                  fontFamily: 'OpenSans',
                                  fontSize: fs(12.5),
                                  fontWeight: FontWeight.w600,
                                  height: 1,
                                ),
                              ),
                            ),

                            Positioned(
                              top: y(65),
                              left: x(2),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  _emailFocusNode.requestFocus();
                                },
                                child: Container(
                                  width: x(325),
                                  height: y(45),
                                  decoration: BoxDecoration(
                                    color: const Color.fromRGBO(0, 0, 0, 0.05),
                                    borderRadius: BorderRadius.circular(x(11)),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: x(1),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(width: x(17)),
                                      Icon(
                                        Icons.email_outlined,
                                        color: const Color(0xFFCACACA),
                                        size: x(22),
                                      ),
                                      SizedBox(width: x(15)),
                                      Expanded(
                                        child: TextField(
                                          focusNode: _emailFocusNode,
                                          controller: _emailController,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          textInputAction: TextInputAction.done,
                                          cursorColor: const Color(0xFFFF8213),
                                          cursorWidth: 2,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'Inter',
                                            fontSize: fs(15),
                                            fontWeight: FontWeight.w600,
                                            height: 1,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'Enter your email',
                                            hintStyle: TextStyle(
                                              color: const Color(0xFFCACACA),
                                              fontFamily: 'Inter',
                                              fontSize: fs(15),
                                              fontWeight: FontWeight.w500,
                                              height: 1,
                                            ),
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: x(12)),
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
                      top: y(546),
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
                              child: Icon(
                                Icons.person_outline_rounded,
                                color: const Color(0xFFEEB556),
                                size: x(28),
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
                                  SizedBox(height: y(7)),
                                  Text(
                                    'Password reset option is only for shop\nowner accounts. if you’re a customer,\nplease contact support.',
                                    style: TextStyle(
                                      color: const Color(0xFFBBBABB),
                                      fontFamily: 'OpenSans',
                                      fontSize: fs(13.5),
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

                    Positioned(
                      top: y(660),
                      left: x(22),
                      right: x(22),
                      child: SizedBox(
                        height: y(49),
                        child: ElevatedButton(
                          onPressed: widget.isLoading ? null : _handleSendResetCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFB6F02),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(x(20)),
                            ),
                          ),
                          child: widget.isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Transform.rotate(
                                      angle: 0.1,
                                      child: Image.asset(
                                        '${_assetBase}Paperplane.png',
                                        width: x(23),
                                        height: x(21),
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    SizedBox(width: x(12)),
                                    Text(
                                      'Send Reset Code',
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
                              fontSize: fs(14),
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
