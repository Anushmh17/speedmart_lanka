import 'package:flutter/material.dart';

class NewpasswordupdatesrilankavendorWidget extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onUpdatePassword;
  final TextEditingController? passwordController;
  final TextEditingController? confirmPasswordController;
  final bool isLoading;
  final String? previousPassword;

  const NewpasswordupdatesrilankavendorWidget({
    super.key,
    this.onBack,
    this.onUpdatePassword,
    this.passwordController,
    this.confirmPasswordController,
    this.isLoading = false,
    this.previousPassword,
  });

  @override
  State<NewpasswordupdatesrilankavendorWidget> createState() =>
      _NewpasswordupdatesrilankavendorWidgetState();
}

class _NewpasswordupdatesrilankavendorWidgetState
    extends State<NewpasswordupdatesrilankavendorWidget> {
  static const String _assetBase =
      'assets/images/figma/new_password_update_sri_lanka_vendor/';

  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;

  late final bool _ownsPasswordController;
  late final bool _ownsConfirmPasswordController;

  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();

    _ownsPasswordController = widget.passwordController == null;
    _ownsConfirmPasswordController = widget.confirmPasswordController == null;

    _passwordController = widget.passwordController ?? TextEditingController();
    _confirmPasswordController =
        widget.confirmPasswordController ?? TextEditingController();

    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _passwordController.removeListener(() => setState(() {}));

    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();

    if (_ownsPasswordController) {
      _passwordController.dispose();
    }

    if (_ownsConfirmPasswordController) {
      _confirmPasswordController.dispose();
    }

    super.dispose();
  }

  bool get _hasEightCharacters => _passwordController.text.length >= 8;

  bool get _isSameAsPrevious =>
      widget.previousPassword != null &&
      widget.previousPassword!.isNotEmpty &&
      _passwordController.text == widget.previousPassword;

  bool get _hasUppercase =>
      RegExp(r'[A-Z]').hasMatch(_passwordController.text);

  bool get _hasLowercase =>
      RegExp(r'[a-z]').hasMatch(_passwordController.text);

  bool get _hasSpecial =>
      RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=/\\[\]~`]').hasMatch(
        _passwordController.text,
      );

  int get _strengthCount {
    final password = _passwordController.text;

    if (password.isEmpty) return 0;

    int count = 0;

    if (_hasEightCharacters) count++;
    if (_hasUppercase) count++;
    if (_hasLowercase) count++;
    if (_hasSpecial) count++;

    // 5th bar active only when password is more than 10 characters
    if (password.length > 10) count++;

    return count;
  }

  void _handleUpdatePassword() {
    if (widget.onUpdatePassword != null) {
      widget.onUpdatePassword!();
      return;
    }

    debugPrint(
      'Sri Lanka vendor update password clicked: ${_passwordController.text}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final h = media.size.height;

    final keyboardOpen = media.viewInsets.bottom > 0;

    final sx = w / 360;
    final sy = h / 870;
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
          backgroundColor: const Color(0xFF020201),
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
                      height: y(203),
                      child: Image.asset(
                        '${_assetBase}Vendornewpasswordupdateheroimage1.png',
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
                      top: y(219),
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

                            Positioned(
                              top: 0,
                              left: x(235),
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
                                  child: Image.asset(
                                    '${_assetBase}Securityshieldicon.png',
                                    width: x(35),
                                    height: x(25),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
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
                              left: 0,
                              right: 0,
                              child: Text(
                                'Your new password must be different from\nyour previous passwords.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFFCACACA),
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
                      top: y(374),
                      left: x(17),
                      right: x(18),
                      child: _PasswordInput(
                        label: 'New Password',
                        hint: 'Enter your new password',
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        obscureText: !_passwordVisible,
                        onToggleVisibility: () {
                          setState(() => _passwordVisible = !_passwordVisible);
                        },
                        isVisible: _passwordVisible,
                        x: x,
                        y: y,
                        fs: fs,
                      ),
                    ),

                    if (_isSameAsPrevious)
                      Positioned(
                        top: y(452),
                        left: x(20),
                        right: x(18),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: const Color(0xFFFF4444), size: x(14)),
                            SizedBox(width: x(5)),
                            Text(
                              'Cannot use your previous password',
                              style: TextStyle(
                                color: const Color(0xFFFF4444),
                                fontFamily: 'OpenSans',
                                fontSize: fs(12),
                                fontWeight: FontWeight.w600,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),

                    Positioned(
                      top: y(459),
                      left: x(20),
                      right: x(22),
                      child: _StrengthBar(
                        activeCount: _strengthCount,
                        x: x,
                        y: y,
                        fs: fs,
                      ),
                    ),

                    Positioned(
                      top: y(497),
                      left: x(17),
                      right: x(18),
                      child: _PasswordInput(
                        label: 'Confirm New Password',
                        hint: 'Enter your new password',
                        controller: _confirmPasswordController,
                        focusNode: _confirmPasswordFocusNode,
                        obscureText: !_confirmPasswordVisible,
                        onToggleVisibility: () {
                          setState(
                            () => _confirmPasswordVisible =
                                !_confirmPasswordVisible,
                          );
                        },
                        isVisible: _confirmPasswordVisible,
                        x: x,
                        y: y,
                        fs: fs,
                      ),
                    ),

                    Positioned(
                      top: y(591),
                      left: x(17),
                      right: x(18),
                      child: Container(
                        height: y(94),
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(0, 0, 0, 0.05),
                          borderRadius: BorderRadius.circular(x(11)),
                          border: Border.all(
                            color: Colors.white,
                            width: x(1),
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: y(9),
                              left: x(15),
                              child: Row(
                                children: [
                                  Image.asset(
                                    '${_assetBase}Protectedicon.png',
                                    width: x(24),
                                    height: x(20),
                                    fit: BoxFit.contain,
                                  ),
                                  SizedBox(width: x(12)),
                                  Text(
                                    'Password must contain:',
                                    style: TextStyle(
                                      color: const Color(0xFFEEB556),
                                      fontFamily: 'OpenSans',
                                      fontSize: fs(13),
                                      fontWeight: FontWeight.w800,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Positioned(
                              top: y(40),
                              left: x(19),
                              right: x(15),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _RuleItem(
                                          text: 'At least 8 characters',
                                          isValid: _hasEightCharacters,
                                          x: x,
                                          fs: fs,
                                        ),
                                      ),
                                      Expanded(
                                        child: _RuleItem(
                                          text: 'One Lowercase',
                                          isValid: _hasLowercase,
                                          x: x,
                                          fs: fs,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: y(9)),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _RuleItem(
                                          text: 'One uppercase letter',
                                          isValid: _hasUppercase,
                                          x: x,
                                          fs: fs,
                                        ),
                                      ),
                                      Expanded(
                                        child: _RuleItem(
                                          text: 'One Special Character',
                                          isValid: _hasSpecial,
                                          x: x,
                                          fs: fs,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(713),
                      left: x(21),
                      right: x(21),
                      child: SizedBox(
                        height: y(50),
                        child: ElevatedButton(
                          onPressed: widget.isLoading ? null : _handleUpdatePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFB6F02),
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
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      '${_assetBase}Lock.png',
                                      width: x(26),
                                      height: x(24),
                                      fit: BoxFit.contain,
                                    ),
                                    SizedBox(width: x(10)),
                                    Text(
                                      'Update Password',
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
                      top: y(798),
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            '${_assetBase}Securityshield.png',
                            width: x(16),
                            height: x(16),
                            fit: BoxFit.contain,
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

class _PasswordInput extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool obscureText;
  final VoidCallback onToggleVisibility;
  final bool isVisible;
  final double Function(double) x;
  final double Function(double) y;
  final double Function(double) fs;

  const _PasswordInput({
    required this.label,
    required this.hint,
    required this.controller,
    required this.focusNode,
    required this.obscureText,
    required this.onToggleVisibility,
    required this.isVisible,
    required this.x,
    required this.y,
    required this.fs,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: y(76),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: x(3),
            child: Text(
              label,
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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                focusNode.requestFocus();
              },
              child: Container(
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
                    SizedBox(width: x(12)),
                    Icon(
                      Icons.lock_outline_rounded,
                      color: const Color(0xFFCACACA),
                      size: x(21),
                    ),
                    SizedBox(width: x(12)),
                    Expanded(
                      child: TextField(
                        focusNode: focusNode,
                        controller: controller,
                        obscureText: obscureText,
                        textInputAction: TextInputAction.next,
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
                          hintText: hint,
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
                    GestureDetector(
                      onTap: onToggleVisibility,
                      child: Icon(
                        isVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: const Color(0xFFCACACA),
                        size: x(19),
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
    );
  }
}

class _StrengthBar extends StatelessWidget {
  final int activeCount;
  final double Function(double) x;
  final double Function(double) y;
  final double Function(double) fs;

  const _StrengthBar({
    required this.activeCount,
    required this.x,
    required this.y,
    required this.fs,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: y(18),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Text(
              'Strength',
              style: TextStyle(
                color: const Color(0xFFBBBABB),
                fontFamily: 'OpenSans',
                fontSize: fs(13),
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
          Positioned(
            top: y(12),
            left: 0,
            child: Row(
              children: List.generate(5, (index) {
                final safeActiveCount = activeCount.clamp(0, 5).toInt();
                final isActive = index < safeActiveCount;

                return Container(
                  width: x(41),
                  height: y(5),
                  margin: EdgeInsets.only(right: x(4)),
                  color: isActive
                      ? const Color(0xFFFF8213)
                      : const Color(0xFFBBBABB),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  final String text;
  final bool isValid;
  final double Function(double) x;
  final double Function(double) fs;

  const _RuleItem({
    required this.text,
    required this.isValid,
    required this.x,
    required this.fs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isValid ? Icons.check_rounded : Icons.check_rounded,
          color: isValid ? const Color(0xFFEEB556) : const Color(0xFFBBBABB),
          size: x(15),
        ),
        SizedBox(width: x(8)),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.visible,
            style: TextStyle(
              color: const Color(0xFFBBBABB),
              fontFamily: 'OpenSans',
              fontSize: fs(11),
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ),
      ],
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
