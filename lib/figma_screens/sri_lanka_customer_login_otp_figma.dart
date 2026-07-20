import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SrilankacustomerloginotpWidget extends StatefulWidget {
  final VoidCallback? onBack;
  final ValueChanged<String>? onVerifyOtp;
  final VoidCallback? onResend;
  final String maskedPhone;

  const SrilankacustomerloginotpWidget({
    super.key,
    this.onBack,
    this.onVerifyOtp,
    this.onResend,
    this.maskedPhone = '+94 . . . . . . 4567',
  });

  @override
  State<SrilankacustomerloginotpWidget> createState() =>
      _SrilankacustomerloginotpWidgetState();
}

class _SrilankacustomerloginotpWidgetState
    extends State<SrilankacustomerloginotpWidget> {
  static const String _assetBase =
      'assets/images/figma/sri_lanka_customer_login_otp/';
  static const int _resendSeconds = 30;

  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());

  String _errorMessage = '';
  bool _isSubmitting = false;
  int _secondsLeft = _resendSeconds;
  bool _canResend = false;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _otpFocusNodes[0].requestFocus(),
    );
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _otpControllers) { c.dispose(); }
    for (final f in _otpFocusNodes) { f.dispose(); }
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _secondsLeft = _resendSeconds;
      _canResend = false;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          _canResend = true;
          t.cancel();
        }
      });
    });
  }

  String get _enteredOtp =>
      _otpControllers.map((c) => c.text.trim()).join();

  void _clearBoxes() {
    for (final c in _otpControllers) { c.clear(); }
    if (mounted && _otpFocusNodes[0].canRequestFocus) {
      _otpFocusNodes[0].requestFocus();
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _enteredOtp;
    if (otp.length < 6) {
      setState(() => _errorMessage = 'Please enter the 6 digit OTP.');
      return;
    }
    setState(() { _errorMessage = ''; _isSubmitting = true; });
    if (widget.onVerifyOtp != null) {
      widget.onVerifyOtp!(otp);
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  void _handleResend() {
    if (!_canResend) return;
    setState(() => _errorMessage = '');
    _clearBoxes();
    _startResendTimer();
    widget.onResend?.call();
  }

  /// Called by the parent flow to report a wrong OTP back into this widget.
  void reportError(String message) {
    if (!mounted) return;
    setState(() { _errorMessage = message; _isSubmitting = false; });
    _clearBoxes();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final h = media.size.height;
    final keyboardOpen = media.viewInsets.bottom > 0;
    final sx = w / 360;
    final sy = h / 800;
    double x(double v) => v * sx;
    double y(double v) => v * sy;
    double fs(double v) => v * sx.clamp(0.92, 1.08);

    final resendLabel = _canResend ? 'Resend OTP' : 'Resend in ${_secondsLeft}s';

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.noScaling),
      child: Theme(
        data: Theme.of(context).copyWith(
          brightness: Brightness.light,
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
          backgroundColor: const Color(0xFFF8F5F1),
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
                      top: 0, left: 0, right: 0, height: y(336),
                      child: Image.asset(
                        '${_assetBase}Customerheroimagespeedmart1.png',
                        fit: BoxFit.fill,
                      ),
                    ),
                    Positioned(
                      top: y(57.5), left: 0, right: 0,
                      child: Center(
                        child: Container(
                          width: x(199), height: y(42),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161616),
                            borderRadius: BorderRadius.circular(x(10)),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: y(66.5), left: 0, right: 0,
                      child: Center(
                        child: Image.asset(
                          '${_assetBase}Speedmart_lk_transparent_logo_cropped1.png',
                          width: x(173), height: y(24), fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Positioned(
                      top: y(50), left: x(15),
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
                      top: y(337), left: x(18), right: x(18),
                      child: Column(
                        children: [
                          Text(
                            'Verify OTP',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.black, fontSize: fs(33),
                              fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1,
                            ),
                          ),
                          SizedBox(height: y(17)),
                          Text(
                            'Enter the code sent to your mobile number',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: const Color(0xFFFF8213), fontSize: fs(18),
                              fontWeight: FontWeight.w700, height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: y(432), left: x(43), right: x(42),
                      child: Container(
                        height: y(60),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F5F1),
                          borderRadius: BorderRadius.circular(x(10)),
                          border: Border.all(color: const Color(0xFFFF8213), width: x(2)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: x(11)),
                            Container(
                              width: x(45), height: x(45),
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(255, 141, 40, 0.11),
                                border: Border.all(color: const Color(0xFFFF8213), width: x(1.4)),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.phone_android_rounded, color: const Color(0xFFFF8213), size: x(23)),
                            ),
                            SizedBox(width: x(12)),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('We\u2019ve sent a 6-digit OTP to',
                                    style: TextStyle(color: const Color(0xFF373737), fontFamily: 'OpenSans', fontSize: fs(16), fontWeight: FontWeight.w700, height: 1)),
                                  SizedBox(height: y(8)),
                                  Text(widget.maskedPhone,
                                    style: TextStyle(color: Colors.black, fontFamily: 'OpenSans', fontSize: fs(16), fontWeight: FontWeight.w800, height: 1)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: y(530), left: x(20), right: x(19),
                      child: SizedBox(
                        height: y(48),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) {
                            return _OtpBox(
                              width: x(46), height: y(48), radius: x(10), fontSize: fs(20),
                              controller: _otpControllers[index],
                              focusNode: _otpFocusNodes[index],
                              onChanged: (value) {
                                if (value.isNotEmpty && index < 5) {
                                  _otpFocusNodes[index + 1].requestFocus();
                                }
                                if (value.isEmpty && index > 0) {
                                  _otpFocusNodes[index - 1].requestFocus();
                                }
                                if (_enteredOtp.length == 6) { _handleVerifyOtp(); }
                              },
                            );
                          }),
                        ),
                      ),
                    ),
                    if (_errorMessage.isNotEmpty)
                      Positioned(
                        top: y(590), left: x(22), right: x(22),
                        child: Text(_errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red, fontFamily: 'OpenSans', fontSize: fs(13), fontWeight: FontWeight.w600, height: 1)),
                      ),
                    Positioned(
                      top: y(615), left: x(22), right: x(22),
                      child: SizedBox(
                        height: y(49),
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _handleVerifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF8213),
                            foregroundColor: Colors.white,
                            elevation: 0, padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(x(20))),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : Text('Verify OTP',
                                  style: TextStyle(color: Colors.white, fontFamily: 'OpenSans', fontSize: fs(20), fontWeight: FontWeight.w700, height: 1)),
                        ),
                      ),
                    ),
                    Positioned(
                      top: y(694), left: 0, right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Didn\u2019t receive the code?',
                            style: TextStyle(color: const Color(0xFF373737), fontFamily: 'OpenSans', fontSize: fs(15), fontWeight: FontWeight.w600, height: 1)),
                          SizedBox(width: x(5)),
                          GestureDetector(
                            onTap: _canResend ? _handleResend : null,
                            child: Text(resendLabel,
                              style: TextStyle(
                                color: _canResend ? const Color(0xFFFF8213) : const Color(0xFFAAAAAA),
                                fontFamily: 'OpenSans', fontSize: fs(15), fontWeight: FontWeight.w700, height: 1)),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: y(732), left: 0, right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified_user_outlined, color: const Color(0xFF373737), size: x(16)),
                          SizedBox(width: x(6)),
                          Text('Secure and encrypted login',
                            style: TextStyle(color: const Color(0xFF373737), fontFamily: 'OpenSans', fontSize: fs(15), fontWeight: FontWeight.w500, height: 1)),
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
    required this.width, required this.height, required this.radius,
    required this.fontSize, required this.controller,
    required this.focusNode, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => focusNode.requestFocus(),
      child: Container(
        width: width, height: height, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color.fromRGBO(255, 141, 40, 0.05),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: const Color(0xFFFF8213), width: 1),
        ),
        child: TextField(
          controller: controller, focusNode: focusNode,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          textAlign: TextAlign.center, maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)],
          cursorColor: const Color(0xFFFF8213),
          style: TextStyle(color: Colors.black, fontFamily: 'Inter', fontSize: fontSize, fontWeight: FontWeight.w700, height: 1),
          decoration: const InputDecoration(
            counterText: '', border: InputBorder.none,
            enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
            isCollapsed: true, contentPadding: EdgeInsets.zero,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

