import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SrilankavendorregistrationotpWidget extends StatefulWidget {
  final VoidCallback? onBack;
  final ValueChanged<String>? onVerifyOtp;
  final VoidCallback? onResend;
  final String maskedEmail;

  const SrilankavendorregistrationotpWidget({
    super.key,
    this.onBack,
    this.onVerifyOtp,
    this.onResend,
    this.maskedEmail = 'abc***@gmail.com',
  });

  @override
  State<SrilankavendorregistrationotpWidget> createState() =>
      _SrilankavendorregistrationotpWidgetState();
}

class _SrilankavendorregistrationotpWidgetState
    extends State<SrilankavendorregistrationotpWidget> {
  static const String _assetBase =
      'assets/images/figma/sri_lanka_vendor_register_otp/';

  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  final List<FocusNode> _otpFocusNodes = List.generate(
    6,
    (_) => FocusNode(),
  );

  String _errorMessage = '';
  bool _isSubmitting = false;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _addBackspaceListeners();
  }

  void _addBackspaceListeners() {
    for (int i = 0; i < 6; i++) {
      final index = i;
      _otpFocusNodes[index].onKeyEvent = (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _otpControllers[index].text.isEmpty &&
            index > 0) {
          _otpFocusNodes[index - 1].requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 6) {
      setState(() { _errorMessage = 'Please enter the 6 digit OTP.'; });
      return;
    }
    if (_isSubmitting || _isSuccess) return;
    setState(() { _errorMessage = ''; _isSubmitting = true; });
    FocusScope.of(context).unfocus();
    widget.onVerifyOtp?.call(otp);
    if (mounted) setState(() { _isSubmitting = false; _isSuccess = true; });
  }

  void _handleResend() {
    if (widget.onResend != null) {
      widget.onResend!();
      return;
    }
    debugPrint('Sri Lanka vendor register Resend OTP clicked');
  }

  @override
  void dispose() {
    for (final c in _otpControllers) c.dispose();
    for (final f in _otpFocusNodes) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final h = media.size.height;
    final keyboardOpen = media.viewInsets.bottom > 0;
    final sx = w / 360;
    final sy = h / 800;
    final fontScale = sx.clamp(0.76, 1.0).toDouble();
    double x(double v) => v * sx;
    double y(double v) => v * sy;
    double fs(double v) => v * fontScale;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: MediaQuery(
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
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            fillColor: Colors.transparent,
          ),
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFF010101),
          resizeToAvoidBottomInset: false,
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SizedBox(
              width: w,
              height: h,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                offset: Offset(0, keyboardOpen ? -0.05 : 0),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0, left: 0, right: 0, height: y(360),
                      child: Image.asset('${_assetBase}Vendorloginuinewhero1.png', fit: BoxFit.fill),
                    ),
                    Positioned(
                      top: y(37.5), left: 0, right: 0,
                      child: Center(
                        child: Container(
                          width: x(213), height: y(45),
                          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(x(10))),
                        ),
                      ),
                    ),
                    Positioned(
                      top: y(58), left: 0, right: 0,
                      child: Center(
                        child: Image.asset('${_assetBase}Speedmart_lk_transparent_logo_cropped1.png',
                            width: x(185), height: y(26), fit: BoxFit.contain),
                      ),
                    ),
                    Positioned(
                      top: y(45), left: x(15),
                      child: GestureDetector(
                        onTap: widget.onBack ?? () => Navigator.maybePop(context),
                        child: Container(
                          width: x(30), height: x(30),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: x(2.5)),
                          ),
                          child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: x(20)),
                        ),
                      ),
                    ),
                    Positioned(
                      top: y(363), left: x(18), right: x(18),
                      child: Column(
                        children: [
                          Text('Verify OTP',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: const Color(0xFFFFEBFF), fontSize: fs(33),
                              fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1,
                            ),
                          ),
                          SizedBox(height: y(20)),
                          Text('Enter the code sent to your email',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: const Color(0xFFEEB556), fontSize: fs(18),
                              fontWeight: FontWeight.w700, height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: y(460), left: x(43), right: x(42),
                      child: Container(
                        height: y(60),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(x(10)),
                          border: Border.all(color: const Color(0xFFFF8213), width: x(1)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: x(11)),
                            Container(
                              width: x(45), height: x(45),
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(224, 105, 0, 0.05),
                                border: Border.all(color: const Color(0xFFFF8D28), width: x(1.4)),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.email_outlined, color: const Color(0xFFEEB556), size: x(23)),
                            ),
                            SizedBox(width: x(12)),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('We\u2019ve sent a 6-digit code to',
                                    style: TextStyle(color: const Color(0xFFFFEBFF), fontFamily: 'OpenSans',
                                        fontSize: fs(16), fontWeight: FontWeight.w700, height: 1)),
                                  SizedBox(height: y(8)),
                                  Text(widget.maskedEmail,
                                    style: TextStyle(color: const Color(0xFFFFEBFF), fontFamily: 'OpenSans',
                                        fontSize: fs(16), fontWeight: FontWeight.w800, height: 1)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: y(547), left: x(20), right: x(19),
                      child: SizedBox(
                        height: y(48),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) {
                            return _VendorOtpBox(
                              width: x(46), height: y(48), radius: x(10), fontSize: fs(20),
                              controller: _otpControllers[index],
                              focusNode: _otpFocusNodes[index],
                              onTap: () {
                                final target = _otpControllers.indexWhere((c) => c.text.isEmpty);
                                final node = _otpFocusNodes[target == -1 ? 5 : target];
                                node.requestFocus();
                                SystemChannels.textInput.invokeMethod('TextInput.show');
                              },
                              onChanged: (value) {
                                if (value.isNotEmpty && index < 5) _otpFocusNodes[index + 1].requestFocus();
                                if (value.isEmpty && index > 0) _otpFocusNodes[index - 1].requestFocus();
                              },
                            );
                          }),
                        ),
                      ),
                    ),
                    if (_errorMessage.isNotEmpty)
                      Positioned(
                        top: y(600), left: x(22), right: x(22),
                        child: Text(_errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red, fontFamily: 'OpenSans',
                              fontSize: fs(13), fontWeight: FontWeight.w600, height: 1)),
                      ),
                    if (_isSuccess)
                      Positioned(
                        top: y(600), left: x(22), right: x(22),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 20),
                            SizedBox(width: x(6)),
                            Text('OTP Verified! Creating your account…',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: const Color(0xFF4CAF50), fontFamily: 'OpenSans',
                                  fontSize: fs(13), fontWeight: FontWeight.w700, height: 1)),
                          ],
                        ),
                      ),
                    Positioned(
                      top: y(624), left: x(22), right: x(22),
                      child: SizedBox(
                        height: y(49),
                        child: ElevatedButton(
                          onPressed: (_isSubmitting || _isSuccess) ? null : _handleVerifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFFF8213),
                            foregroundColor: Colors.white,
                            elevation: 0, padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(x(20))),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : _isSuccess
                                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      const Icon(Icons.check_rounded, color: Colors.white, size: 22),
                                      SizedBox(width: x(6)),
                                      Text('Verified', style: TextStyle(color: Colors.white, fontFamily: 'OpenSans', fontSize: fs(18), fontWeight: FontWeight.w700, height: 1)),
                                    ])
                                  : Text('Verify OTP',
                                      style: TextStyle(color: Colors.white, fontFamily: 'OpenSans',
                                          fontSize: fs(18), fontWeight: FontWeight.w700, height: 1)),
                        ),
                      ),
                    ),
                    Positioned(
                      top: y(703), left: 0, right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Didn\u2019t receive the code?',
                            style: TextStyle(color: const Color(0xFFBBBABB), fontFamily: 'OpenSans',
                                fontSize: fs(14), fontWeight: FontWeight.w600, height: 1)),
                          SizedBox(width: x(5)),
                          GestureDetector(
                            onTap: _handleResend,
                            child: Text('Resend in 27s',
                              style: TextStyle(color: const Color(0xFFEEB556), fontFamily: 'OpenSans',
                                  fontSize: fs(14), fontWeight: FontWeight.w700, height: 1)),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: y(738), left: 0, right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified_user_outlined, color: const Color(0xFFBBBABB), size: x(16)),
                          SizedBox(width: x(6)),
                          Text('Secure and encrypted login',
                            style: TextStyle(color: const Color(0xFFBBBABB), fontFamily: 'OpenSans',
                                fontSize: fs(13), fontWeight: FontWeight.w500, height: 1)),
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
    ),
    );
  }
}

class _VendorOtpBox extends StatelessWidget {
  final double width, height, radius, fontSize;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onTap;

  const _VendorOtpBox({
    required this.width, required this.height, required this.radius,
    required this.fontSize, required this.controller,
    required this.focusNode, required this.onChanged, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color.fromRGBO(224, 105, 0, 0.05),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: const Color(0xFFFF8D28), width: 1),
        ),
        child: IgnorePointer(
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
            cursorColor: const Color(0xFFEEB556),
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
      ),
    );
  }
}

