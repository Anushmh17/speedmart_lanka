import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/storage/storage_service.dart';

class SrilankacustomerloginWidget extends StatefulWidget {
  final ValueChanged<bool>? onSendOtp;
  final VoidCallback? onRegister;
  final VoidCallback? onVendorLogin;
  final VoidCallback? onCountryTap;
  final TextEditingController? phoneController;

  const SrilankacustomerloginWidget({
    super.key,
    this.onSendOtp,
    this.onRegister,
    this.onVendorLogin,
    this.onCountryTap,
    this.phoneController,
  });

  @override
  State<SrilankacustomerloginWidget> createState() =>
      _SrilankacustomerloginWidgetState();
}

class _SrilankacustomerloginWidgetState
    extends State<SrilankacustomerloginWidget> {
  bool _rememberMe = false;

  late final TextEditingController _phoneController;
  late final bool _ownsController;

  final FocusNode _phoneFocusNode = FocusNode();

  static const String _assetBase =
      'assets/images/figma/sri_lanka_customer_login/';

  @override
  void initState() {
    super.initState();
    _ownsController = widget.phoneController == null;
    _phoneController = widget.phoneController ?? TextEditingController();
    _loadRememberMe();
  }

  Future<void> _loadRememberMe() async {
    final saved = await StorageService.getCustomerRememberMe();
    if (mounted) setState(() => _rememberMe = saved);
  }

  @override
  void dispose() {
    _phoneFocusNode.dispose();

    if (_ownsController) {
      _phoneController.dispose();
    }
    super.dispose();
  }

  void _handleSendOtp() {
    if (widget.onSendOtp != null) {
      widget.onSendOtp!(_rememberMe);
      return;
    }
    debugPrint('Sri Lanka customer Send OTP clicked: +94 ${_phoneController.text}');
  }

  void _handleCountryTap() => widget.onCountryTap?.call();

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final h = media.size.height;

    final keyboardOpen = media.viewInsets.bottom > 0;

    final sx = w / 360;
    final sy = h / 820;
    final fontScale = sx.clamp(0.92, 1.08).toDouble();

    double x(double value) => value * sx;
    double y(double value) => value * sy;
    double fs(double value) => value * fontScale;

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
            filled: false,
            fillColor: Colors.transparent,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
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
                offset: Offset(0, keyboardOpen ? -0.08 : 0),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: y(336),
                      child: Image.asset(
                        '${_assetBase}Customerheroimagespeedmart1.png',
                        fit: BoxFit.fill,
                      ),
                    ),

                    Positioned(
                      top: y(57.5),
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: x(199),
                          height: y(42),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161616),
                            borderRadius: BorderRadius.circular(x(10)),
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(66.5),
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Image.asset(
                          '${_assetBase}Speedmart_lk_transparent_logo_cropped1.png',
                          width: x(173),
                          height: y(24),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(347),
                      left: 0,
                      right: 0,
                      child: Column(
                        children: [
                          Text(
                            'Welcome back',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              color: Colors.black,
                              fontSize: fs(33),
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              height: 1,
                            ),
                          ),
                          SizedBox(height: y(17)),
                          Text(
                            'Sign in as Customer',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              color: const Color(0xFFFF8213),
                              fontSize: fs(18),
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Positioned(
                      top: y(436),
                      left: x(42),
                      child: Container(
                        width: x(275),
                        height: y(60),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F5F1),
                          borderRadius: BorderRadius.circular(x(10)),
                          border: Border.all(
                            color: const Color(0xFFFF8213),
                            width: x(2),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: x(15)),
                            Container(
                              width: x(45),
                              height: x(45),
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(255, 141, 40, 0.11),
                                border: Border.all(
                                  color: const Color(0xFFFF8213),
                                  width: x(2),
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.phone_android_rounded,
                                color: const Color(0xFFFF8213),
                                size: x(22),
                              ),
                            ),
                            SizedBox(width: x(12)),
                            Expanded(
                              child: Text(
                                'Enter your mobile number\nand we’ll send you an OTP',
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  color: const Color(0xFF373737),
                                  fontFamily: 'OpenSans',
                                  fontSize: fs(16),
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                ),
                              ),
                            ),
                            SizedBox(width: x(8)),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(510),
                      left: x(16),
                      right: x(15),
                      child: SizedBox(
                        height: y(96),
                        child: Stack(
                          children: [
                            Positioned(
                              top: y(18),
                              left: x(4),
                              child: Text(
                                'Mobile Number',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontFamily: 'OpenSans',
                                  fontSize: fs(15),
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                            ),

                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _handleCountryTap,
                                child: Container(
                                  width: x(130),
                                  height: y(40),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(x(11)),
                                      bottomRight: Radius.circular(x(11)),
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFF17A2F8),
                                      width: x(2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Sri Lanka',
                                        style: TextStyle(
                                          color: const Color(0xFF0042D2),
                                          fontFamily: 'OpenSans',
                                          fontSize: fs(15),
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
                              top: y(46),
                              left: 0,
                              right: x(4),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  _phoneFocusNode.requestFocus();
                                },
                                child: Container(
                                  height: y(50),
                                  decoration: BoxDecoration(
                                    color: const Color.fromRGBO(255, 141, 40, 0.05),
                                    borderRadius: BorderRadius.circular(x(11)),
                                    border: Border.all(
                                      color: const Color(0xFFFF8213),
                                      width: x(1),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(width: x(14)),
                                      Text(
                                        '+94',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontFamily: 'Inter',
                                          fontSize: fs(16),
                                          fontWeight: FontWeight.w700,
                                          height: 1,
                                        ),
                                      ),
                                      SizedBox(width: x(18)),
                                      Expanded(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: TextField(
                                            focusNode: _phoneFocusNode,
                                            controller: _phoneController,
                                            keyboardType: TextInputType.phone,
                                            textInputAction: TextInputAction.done,
                                            inputFormatters: [
                                              FilteringTextInputFormatter.digitsOnly,
                                              LengthLimitingTextInputFormatter(10),
                                            ],
                                            cursorColor: const Color(0xFFFF8213),
                                            cursorWidth: 2,
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontFamily: 'Inter',
                                              fontSize: fs(16),
                                              fontWeight: FontWeight.w600,
                                              height: 1,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'Enter your mobile number',
                                              hintStyle: TextStyle(
                                                color: const Color(0xFF4F4F4F),
                                                fontFamily: 'Inter',
                                                fontSize: fs(16),
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
                                      ),
                                      SizedBox(width: x(14)),
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
                      top: y(606),
                      left: x(22),
                      child: GestureDetector(
                        onTap: () => setState(() => _rememberMe = !_rememberMe),
                        child: Row(
                          children: [
                            SizedBox(
                              width: x(20),
                              height: y(26),
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: (v) => setState(() => _rememberMe = v ?? false),
                                activeColor: const Color(0xFF2E8CFF),
                                checkColor: Colors.white,
                                side: const BorderSide(color: Color(0xFF373737), width: 1),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            SizedBox(width: x(5)),
                            Text(
                              'Remember me',
                              style: TextStyle(
                                color: const Color(0xFF373737),
                                fontFamily: 'OpenSans',
                                fontSize: fs(14),
                                fontWeight: FontWeight.w600,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(640),
                      left: x(22),
                      right: x(22),
                      child: SizedBox(
                        height: y(49),
                        child: ElevatedButton(
                          onPressed: _handleSendOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF8213),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(x(20)),
                            ),
                          ),
                          child: Text(
                            'Send OTP',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'OpenSans',
                              fontSize: fs(20),
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(719),
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Don’t have an account?',
                            style: TextStyle(
                              color: const Color(0xFF373737),
                              fontFamily: 'OpenSans',
                              fontSize: fs(15),
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                          SizedBox(width: x(8)),
                          GestureDetector(
                            onTap: widget.onRegister ??
                                () => debugPrint('Sri Lanka Register Now clicked'),
                            child: Text(
                              'Register Now',
                              style: TextStyle(
                                color: const Color(0xFF0D1B56),
                                fontFamily: 'OpenSans',
                                fontSize: fs(15),
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Positioned(
                      top: y(753),
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Are you a shop owner?',
                            style: TextStyle(
                              color: const Color(0xFF373737),
                              fontFamily: 'OpenSans',
                              fontSize: fs(15),
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                          SizedBox(width: x(8)),
                          GestureDetector(
                            onTap: widget.onVendorLogin ??
                                () => debugPrint('Sri Lanka vendor login clicked'),
                            child: Text(
                              'Click here',
                              style: TextStyle(
                                color: const Color(0xFF0D1B56),
                                fontFamily: 'OpenSans',
                                fontSize: fs(15),
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
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

