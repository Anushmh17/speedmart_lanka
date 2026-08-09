import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SrilankavendorloginWidget extends StatefulWidget {
  final ValueChanged<bool>? onSignIn;
  final VoidCallback? onRegister;
  final VoidCallback? onCustomerLogin;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onCountryTap;
  final TextEditingController? emailController;
  final TextEditingController? passwordController;
  final bool isLoading;

  const SrilankavendorloginWidget({
    super.key,
    this.onSignIn,
    this.onRegister,
    this.onCustomerLogin,
    this.onForgotPassword,
    this.onCountryTap,
    this.emailController,
    this.passwordController,
    this.isLoading = false,
  });

  @override
  State<SrilankavendorloginWidget> createState() =>
      _SrilankavendorloginWidgetState();
}

class _SrilankavendorloginWidgetState extends State<SrilankavendorloginWidget>
    with WidgetsBindingObserver {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final bool _ownsEmailController;
  late final bool _ownsPasswordController;

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  double _keyboardHeight = 0;

  bool _rememberMe = true;
  bool _passwordVisible = false;

  static const String _assetBase =
      'assets/images/figma/sri_lanka_vendor_login/';

  @override
  void initState() {
    super.initState();

    _ownsEmailController = widget.emailController == null;
    _ownsPasswordController = widget.passwordController == null;

    _emailController = widget.emailController ?? TextEditingController();
    _passwordController = widget.passwordController ?? TextEditingController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    if (mounted) setState(() => _keyboardHeight = bottomInset);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();

    if (_ownsEmailController) {
      _emailController.dispose();
    }

    if (_ownsPasswordController) {
      _passwordController.dispose();
    }

    super.dispose();
  }

  void _handleSignIn() {
    if (widget.onSignIn != null) {
      widget.onSignIn!(_rememberMe);
      return;
    }
    debugPrint('Sri Lanka vendor Sign In clicked: ${_emailController.text}');
  }

  void _handleCountryTap() => widget.onCountryTap?.call();

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final h = media.size.height;

    final keyboardHeight = _keyboardHeight;

    final sx = w / 360;
    final sy = h / 850;
    final fontScale = sx.clamp(0.76, 1.0).toDouble();

    double x(double value) => value * sx;
    double y(double value) => value * sy;
    double fs(double value) => value * fontScale;

    // Use the focused field's bottom edge, or password field as fallback
    final emailFieldTop = y(461) + y(31);
    final emailFieldBottom = emailFieldTop + y(45);
    final passwordFieldTop = y(551) + y(30);
    final passwordFieldBottom = passwordFieldTop + y(45);

    final double activeFieldTop;
    final double activeFieldBottom;
    if (_passwordFocusNode.hasFocus) {
      activeFieldTop = passwordFieldTop;
      activeFieldBottom = passwordFieldBottom;
    } else {
      activeFieldTop = emailFieldTop;
      activeFieldBottom = emailFieldBottom;
    }

    // How much the keyboard covers the active field
    final coveredBy = (activeFieldBottom - (h - keyboardHeight)).clamp(0.0, double.infinity);
    // Clamp so the field never slides above the screen top
    final maxSlide = activeFieldTop - 8.0;
    final slidePixels = coveredBy.clamp(0.0, maxSlide);

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
            filled: false,
            fillColor: Colors.transparent,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFF020201),
          resizeToAvoidBottomInset: false,
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    top: -slidePixels,
                    left: 0,
                    right: 0,
                    height: h,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: y(360),
                      child: Image.asset(
                        '${_assetBase}Vendorloginuinewhero1.png',
                        fit: BoxFit.fill,
                      ),
                    ),

                    Positioned(
                      top: y(37.5),
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: x(213),
                          height: y(45),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(x(10)),
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(58),
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Image.asset(
                          '${_assetBase}Speedmart_lk_transparent_logo_cropped1.png',
                          width: x(185),
                          height: y(26),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(359),
                      left: 0,
                      right: 0,
                      child: Column(
                        children: [
                          Text(
                            'Welcome back',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              color: const Color(0xFFFFEBFF),
                              fontSize: fs(33),
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              height: 1,
                            ),
                          ),
                          SizedBox(height: y(13)),
                          Text(
                            'Sign in as Shop Owner',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              color: const Color(0xFFEEB556),
                              fontSize: fs(18),
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Positioned(
                      top: y(445),
                      right: x(14),
                      child: GestureDetector(
                        onTap: _handleCountryTap,
                        child: Container(
                          width: x(130),
                          height: y(40),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(0, 0, 0, 0.05),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(x(11)),
                              bottomRight: Radius.circular(x(11)),
                            ),
                            border: Border.all(
                              color: const Color(0xFF17A2F8),
                              width: x(1.5),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Sri Lanka',
                                style: TextStyle(
                                  color: const Color(0xFFCACACA),
                                  fontFamily: 'Inter',
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
                      top: y(461),
                      left: x(17),
                      right: x(18),
                      child: SizedBox(
                        height: y(76),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 0,
                              left: x(3),
                              child: Text(
                                'Email Address',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'OpenSans',
                                  fontSize: fs(14),
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                            ),
                            Positioned(
                              top: y(31),
                              left: 0,
                              right: 0,
                              child: _DarkInputField(
                                height: y(45),
                                icon: Icons.email_outlined,
                                hint: 'Enter your email',
                                controller: _emailController,
                                focusNode: _emailFocusNode,
                                keyboardType: TextInputType.emailAddress,
                                fontSize: fs(15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(551),
                      left: x(17),
                      right: x(18),
                      child: SizedBox(
                        height: y(75),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 0,
                              left: x(4),
                              child: Text(
                                'Password',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'OpenSans',
                                  fontSize: fs(14),
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                            ),
                            Positioned(
                              top: y(30),
                              left: 0,
                              right: 0,
                              child: _DarkInputField(
                                height: y(45),
                                icon: Icons.lock_outline_rounded,
                                hint: 'Enter your password',
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                obscureText: !_passwordVisible,
                                obscuringCharacter: '●',
                                fontSize: fs(15),
                                suffix: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _passwordVisible = !_passwordVisible;
                                    });
                                  },
                                  child: Icon(
                                    _passwordVisible
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: const Color(0xFFCACACA),
                                    size: x(18),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(638),
                      left: x(21),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _rememberMe = !_rememberMe;
                          });
                        },
                        child: Row(
                          children: [
                            SizedBox(
                              width: x(20),
                              height: y(26),
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                                activeColor: const Color(0xFF2E8CFF),
                                checkColor: Colors.white,
                                side: const BorderSide(
                                  color: Colors.white,
                                  width: 1,
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            SizedBox(width: x(5)),
                            Text(
                              'Remember me',
                              style: TextStyle(
                                color: Colors.white,
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
                      top: y(642),
                      right: x(21),
                      child: GestureDetector(
                        onTap: widget.onForgotPassword ??
                            () => debugPrint(
                                  'Sri Lanka vendor forgot password clicked',
                                ),
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: const Color(0xFFEEB556),
                            fontFamily: 'OpenSans',
                            fontSize: fs(13),
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(684),
                      left: x(21),
                      right: x(21),
                      child: SizedBox(
                        height: y(50),
                        child: ElevatedButton(
                          onPressed: widget.isLoading ? null : _handleSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF8213),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(x(19)),
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
                              : Text(
                                  'Sign In',
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
                      top: y(764),
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Don’t have an account?',
                            style: TextStyle(
                              color: const Color(0xFFBBBABB),
                              fontFamily: 'OpenSans',
                              fontSize: fs(14),
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                          SizedBox(width: x(8)),
                          GestureDetector(
                            onTap: widget.onRegister ??
                                () => debugPrint(
                                      'Sri Lanka vendor Register Now clicked',
                                    ),
                            child: Text(
                              'Register Now',
                              style: TextStyle(
                                color: const Color(0xFFEEB556),
                                fontFamily: 'OpenSans',
                                fontSize: fs(14),
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Positioned(
                      top: y(802),
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Are you a Customer?',
                            style: TextStyle(
                              color: const Color(0xFFBBBABB),
                              fontFamily: 'OpenSans',
                              fontSize: fs(14),
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                          SizedBox(width: x(8)),
                          GestureDetector(
                            onTap: widget.onCustomerLogin ??
                                () => debugPrint('Customer login clicked'),
                            child: Text(
                              'Click here',
                              style: TextStyle(
                                color: const Color(0xFFEEB556),
                                fontFamily: 'OpenSans',
                                fontSize: fs(14),
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

class _DarkInputField extends StatelessWidget {
  final double height;
  final IconData icon;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputType keyboardType;
  final bool obscureText;
  final String obscuringCharacter;
  final double fontSize;
  final Widget? suffix;

  const _DarkInputField({
    required this.height,
    required this.icon,
    required this.hint,
    required this.controller,
    required this.focusNode,
    required this.fontSize,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.obscuringCharacter = '•',
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        focusNode.requestFocus();
      },
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color.fromRGBO(0, 0, 0, 0.05),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: Colors.white,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(
              icon,
              color: const Color(0xFFCACACA),
              size: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                focusNode: focusNode,
                controller: controller,
                keyboardType: keyboardType,
                obscureText: obscureText,
                obscuringCharacter: obscuringCharacter,
                textInputAction: TextInputAction.done,
                cursorColor: const Color(0xFFFF8213),
                cursorWidth: 2,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  letterSpacing: obscureText ? 1.5 : 0,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: const Color(0xFFCACACA),
                    fontFamily: 'Inter',
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    height: 1,
                    letterSpacing: 0,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (suffix != null) ...[
              const SizedBox(width: 8),
              suffix!,
              const SizedBox(width: 12),
            ] else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}


