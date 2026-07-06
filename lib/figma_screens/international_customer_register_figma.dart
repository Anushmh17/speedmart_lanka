import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:latlong2/latlong.dart';

class InternationalcustomerregisteraccountWidget extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onCreateAccount;
  final VoidCallback? onSignIn;
  final VoidCallback? onCountryTap;
  final VoidCallback? onProvinceTap;
  final VoidCallback? onDistrictTap;
  final VoidCallback? onUseCurrentLocation;
  final ValueChanged<Map<String, String>>? onCreateAccountWithData;
  final String? selectedProvince;
  final String? selectedDistrict;
  final double? initialLatitude;
  final double? initialLongitude;
  final void Function(double latitude, double longitude)? onLocationPinChanged;
  final bool isDetectingLocation;

  const InternationalcustomerregisteraccountWidget({
    super.key,
    this.onBack,
    this.onCreateAccount,
    this.onSignIn,
    this.onCountryTap,
    this.onProvinceTap,
    this.onDistrictTap,
    this.onUseCurrentLocation,
    this.onCreateAccountWithData,
    this.selectedProvince,
    this.selectedDistrict,
    this.initialLatitude,
    this.initialLongitude,
    this.onLocationPinChanged,
    this.isDetectingLocation = false,
  });

  @override
  State<InternationalcustomerregisteraccountWidget> createState() =>
      _InternationalcustomerregisteraccountWidgetState();
}

class _InternationalcustomerregisteraccountWidgetState
    extends State<InternationalcustomerregisteraccountWidget> {
  static const String _assetBase =
      'assets/images/figma/international_customer_register/';

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _deliveryNoteController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final FocusNode _fullNameFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _addressFocusNode = FocusNode();
  final FocusNode _deliveryNoteFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  final MapController _mapController = MapController();
  final _mapKey = GlobalKey();
  LatLng? _pinPoint;

  LatLng? _latLngFromGlobal(Offset globalPosition) {
    final ctx = _mapKey.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(globalPosition);
    return _mapController.camera.pointToLatLng(
      math.Point<double>(local.dx, local.dy),
    );
  }

  @override
  void didUpdateWidget(covariant InternationalcustomerregisteraccountWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialLatitude != null &&
        widget.initialLongitude != null &&
        (widget.initialLatitude != oldWidget.initialLatitude ||
            widget.initialLongitude != oldWidget.initialLongitude)) {
      final newPoint = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      final current = _pinPoint;
      final isDragEcho = current != null &&
          (widget.initialLatitude! - current.latitude).abs() < 0.00001 &&
          (widget.initialLongitude! - current.longitude).abs() < 0.00001;
      setState(() => _pinPoint = newPoint);
      if (!isDragEcho) _mapController.move(newPoint, 14.0);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _deliveryNoteController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    _fullNameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _emailFocusNode.dispose();
    _addressFocusNode.dispose();
    _deliveryNoteFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _mapController.dispose();

    super.dispose();
  }

  void _handleCreateAccount() {
    if (widget.onCreateAccountWithData != null) {
      widget.onCreateAccountWithData!({
        'fullName': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'preciseAddress': _addressController.text.trim(),
        'deliveryNote': _deliveryNoteController.text.trim(),
        'password': _passwordController.text,
        'confirmPassword': _confirmPasswordController.text,
        'country': 'International',
        if (widget.initialLatitude != null)
          'latitude': widget.initialLatitude.toString(),
        if (widget.initialLongitude != null)
          'longitude': widget.initialLongitude.toString(),
      });
      return;
    }
    if (widget.onCreateAccount != null) {
      widget.onCreateAccount!();
      return;
    }
    debugPrint('International Create Account clicked');
  }

  void _handleCountryTap() => widget.onCountryTap?.call();

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;

    final scale = w / 360;

    double x(double value) => value * scale;
    double y(double value) => value * scale;
    double fs(double value) => value * scale.clamp(0.92, 1.08);

    Widget sectionTitle({
      required double top,
      required double left,
      required IconData icon,
      required String title,
    }) {
      return Positioned(
        top: y(top),
        left: x(left),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFFFB6F02),
              size: x(20),
            ),
            SizedBox(width: x(8)),
            Text(
              title,
              style: TextStyle(
                color: Colors.black,
                fontFamily: 'OpenSans',
                fontSize: fs(15),
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ],
        ),
      );
    }

    Widget normalField({
      required double top,
      required double left,
      required double width,
      required double height,
      required IconData icon,
      required String hint,
      required TextEditingController controller,
      required FocusNode focusNode,
      TextInputType keyboardType = TextInputType.text,
      TextCapitalization textCapitalization = TextCapitalization.none,
      List<TextInputFormatter>? inputFormatters,
      int maxLines = 1,
      bool obscureText = false,
      Widget? suffix,
    }) {
      return Positioned(
        top: y(top),
        left: x(left),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            focusNode.requestFocus();
          },
          child: Container(
            width: x(width),
            height: y(height),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 141, 40, 0.05),
              borderRadius: BorderRadius.circular(x(11)),
              border: Border.all(
                color: const Color(0xFFFF8213),
                width: x(1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: x(9)),
                Icon(
                  icon,
                  color: const Color(0xFF4F4F4F),
                  size: x(18),
                ),
                SizedBox(width: x(12)),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: TextField(
                      focusNode: focusNode,
                      controller: controller,
                      keyboardType: keyboardType,
                      textCapitalization: textCapitalization,
                      inputFormatters: inputFormatters,
                      maxLines: maxLines,
                      obscureText: obscureText,
                      obscuringCharacter: '●',
                      cursorColor: const Color(0xFFFF8213),
                      scrollPadding: EdgeInsets.only(
                        bottom: media.viewInsets.bottom + y(120),
                      ),
                      style: TextStyle(
                        color: Colors.black,
                        fontFamily: 'Inter',
                        fontSize: fs(16),
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: TextStyle(
                          color: const Color(0xFF4F4F4F),
                          fontFamily: 'Inter',
                          fontSize: fs(14.5),
                          fontWeight: FontWeight.w600,
                          height: 1.1,
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
                if (suffix != null) ...[
                  SizedBox(width: x(8)),
                  suffix,
                  SizedBox(width: x(10)),
                ] else
                  SizedBox(width: x(8)),
              ],
            ),
          ),
        ),
      );
    }

    Widget countryModeCard() {
      return Positioned(
        top: y(38),
        left: x(10),
        child: GestureDetector(
          onTap: _handleCountryTap,
          child: Container(
            width: x(161),
            height: y(75),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 141, 40, 0.12),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(x(11)),
                bottomLeft: Radius.circular(x(11)),
              ),
              border: Border.all(
                color: const Color(0xFFFF8213),
                width: x(1),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: y(10),
                  left: x(8),
                  child: Icon(
                    Icons.public_rounded,
                    color: const Color(0xFF4F4F4F),
                    size: x(20),
                  ),
                ),
                Positioned(
                  top: y(12),
                  left: x(39),
                  child: Text(
                    'Country mode',
                    style: TextStyle(
                      color: const Color(0xFF4F4F4F),
                      fontFamily: 'Inter',
                      fontSize: fs(14.5),
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),
                Positioned(
                  top: y(42),
                  left: x(31),
                  child: Text(
                    'International',
                    style: TextStyle(
                      color: const Color(0xFFFF0000),
                      fontFamily: 'OpenSans',
                      fontSize: fs(15),
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
                Positioned(
                  top: y(34),
                  right: x(10),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.black,
                    size: x(22),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget dropdownField({
      required double top,
      required String title,
      required IconData icon,
      required VoidCallback? onTap,
    }) {
      return Positioned(
        top: y(top),
        left: 0,
        child: GestureDetector(
          onTap: onTap ?? () => debugPrint('$title clicked'),
          child: Container(
            width: x(325),
            height: y(40),
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
                SizedBox(width: x(11)),
                Icon(
                  icon,
                  color: const Color(0xFF4F4F4F),
                  size: x(17),
                ),
                SizedBox(width: x(12)),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: const Color(0xFF4F4F4F),
                      fontFamily: 'Inter',
                      fontSize: fs(14.5),
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.black,
                  size: x(22),
                ),
                SizedBox(width: x(11)),
              ],
            ),
          ),
        ),
      );
    }

    Widget locationBox() {
      final pinPoint = _pinPoint ??
          (widget.initialLatitude != null && widget.initialLongitude != null
              ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
              : null);
      final hasLocation = pinPoint != null;
      final mapCenter = pinPoint ?? const LatLng(20.0, 0.0);

      return Positioned(
        top: y(32),
        left: x(0),
        width: x(325),
        height: y(260),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(x(10)),
          child: Stack(
            children: [
              FlutterMap(
                key: _mapKey,
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: mapCenter,
                  initialZoom: hasLocation ? 14.0 : 2.0,
                  minZoom: 2,
                  maxZoom: 19,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.speedmart.lanka',
                    retinaMode: RetinaMode.isHighDensity(context),
                  ),
                  if (hasLocation)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: pinPoint,
                          width: x(52),
                          height: x(52),
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanUpdate: (details) {
                              final next = _latLngFromGlobal(
                                  details.globalPosition);
                              if (next != null) {
                                setState(() => _pinPoint = next);
                              }
                            },
                            onPanEnd: (_) {
                              if (_pinPoint != null) {
                                widget.onLocationPinChanged?.call(
                                  _pinPoint!.latitude,
                                  _pinPoint!.longitude,
                                );
                              }
                            },
                            child: Icon(
                              Icons.location_pin,
                              color: const Color(0xFFFB6F02),
                              size: x(48),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              Positioned(
                right: x(10),
                top: y(10),
                child: Column(
                  children: [
                    if (hasLocation)
                      FloatingActionButton.small(
                        heroTag: 'intl-cust-reg-map-recenter',
                        onPressed: () => _mapController.move(pinPoint, 14.0),
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFFB6F02),
                        child: const Icon(Icons.center_focus_strong_rounded),
                      ),
                    if (hasLocation) SizedBox(height: y(8)),
                    FloatingActionButton.small(
                      heroTag: 'intl-cust-reg-map-detect',
                      onPressed: widget.isDetectingLocation
                          ? null
                          : (widget.onUseCurrentLocation ??
                              () => debugPrint('Use Current Location clicked')),
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFFB6F02),
                      child: widget.isDetectingLocation
                          ? SizedBox(
                              width: x(18),
                              height: x(18),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFB6F02),
                              ),
                            )
                          : const Icon(Icons.my_location_rounded),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  padding: EdgeInsets.symmetric(
                      horizontal: x(10), vertical: y(6)),
                  child: Text(
                    hasLocation
                        ? 'Lat ${pinPoint.latitude.toStringAsFixed(5)}  Lng ${pinPoint.longitude.toStringAsFixed(5)}'
                        : 'Tap the location button to pin your location',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontSize: fs(11),
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
          backgroundColor: const Color(0xFFFDFDFC),
          resizeToAvoidBottomInset: true,
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                width: w,
                height: y(1370),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: y(203),
                      child: Image.asset(
                        '${_assetBase}Heroimageofregisterpagecustomer3.png',
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
                      top: y(223),
                      left: x(7),
                      child: SizedBox(
                        width: x(335),
                        height: y(281),
                        child: Stack(
                          children: [
                            sectionTitle(
                              top: 0,
                              left: 0,
                              icon: Icons.person_rounded,
                              title: 'Personal Information',
                            ),
                            countryModeCard(),
                            normalField(
                              top: 124,
                              left: 10,
                              width: 325,
                              height: 45,
                              icon: Icons.person_outline_rounded,
                              hint: 'Full Name',
                              controller: _fullNameController,
                              focusNode: _fullNameFocusNode,
                              textCapitalization: TextCapitalization.words,
                            ),
                            normalField(
                              top: 180,
                              left: 10,
                              width: 325,
                              height: 45,
                              icon: Icons.phone_outlined,
                              hint: 'Phone Number',
                              controller: _phoneController,
                              focusNode: _phoneFocusNode,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                            normalField(
                              top: 236,
                              left: 10,
                              width: 325,
                              height: 45,
                              icon: Icons.email_outlined,
                              hint: 'Email Address',
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(519),
                      left: x(17),
                      child: SizedBox(
                        width: x(325),
                        height: y(544),
                        child: Stack(
                          children: [
                            sectionTitle(
                              top: 0,
                              left: 0,
                              icon: Icons.location_on_rounded,
                              title: 'Delivery Information',
                            ),
                            locationBox(),
                            dropdownField(
                              top: 306,
                              title: widget.selectedProvince?.isNotEmpty == true
                                  ? widget.selectedProvince!
                                  : 'Province',
                              icon: Icons.map_outlined,
                              onTap: widget.onProvinceTap,
                            ),
                            dropdownField(
                              top: 357,
                              title: widget.selectedDistrict?.isNotEmpty == true
                                  ? widget.selectedDistrict!
                                  : 'District',
                              icon: Icons.travel_explore_rounded,
                              onTap: widget.onDistrictTap,
                            ),
                            normalField(
                              top: 408,
                              left: 0,
                              width: 325,
                              height: 74.5,
                              icon: Icons.place_outlined,
                              hint: 'Precise Delivery Address',
                              controller: _addressController,
                              focusNode: _addressFocusNode,
                              maxLines: 2,
                              textCapitalization: TextCapitalization.sentences,
                            ),
                            normalField(
                              top: 494,
                              left: 0,
                              width: 325,
                              height: 50,
                              icon: Icons.note_alt_outlined,
                              hint: 'Delivery Note (Optional)',
                              controller: _deliveryNoteController,
                              focusNode: _deliveryNoteFocusNode,
                              textCapitalization: TextCapitalization.sentences,
                            ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(1098),
                      left: x(17),
                      child: SizedBox(
                        width: x(325),
                        height: y(140),
                        child: Stack(
                          children: [
                            sectionTitle(
                              top: 0,
                              left: 0,
                              icon: Icons.lock_rounded,
                              title: 'Security',
                            ),
                            normalField(
                              top: 31,
                              left: 0,
                              width: 325,
                              height: 45,
                              icon: Icons.lock_outline_rounded,
                              hint: 'Password',
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              obscureText: !_passwordVisible,
                              suffix: GestureDetector(
                                onTap: () => setState(() => _passwordVisible = !_passwordVisible),
                                child: Icon(
                                  _passwordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: const Color(0xFF4F4F4F),
                                  size: x(18),
                                ),
                              ),
                            ),
                            normalField(
                              top: 87,
                              left: 0,
                              width: 325,
                              height: 45,
                              icon: Icons.lock_outline_rounded,
                              hint: 'Confirm Password',
                              controller: _confirmPasswordController,
                              focusNode: _confirmPasswordFocusNode,
                              obscureText: !_confirmPasswordVisible,
                              suffix: GestureDetector(
                                onTap: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
                                child: Icon(
                                  _confirmPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: const Color(0xFF4F4F4F),
                                  size: x(18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(1255),
                      left: x(21),
                      child: SizedBox(
                        width: x(318),
                        height: y(43.12),
                        child: ElevatedButton(
                          onPressed: _handleCreateAccount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFB6F02),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(x(19)),
                            ),
                          ),
                          child: Text(
                            'Create Account',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'OpenSans',
                              fontSize: fs(18),
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(1328),
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account?',
                            style: TextStyle(
                              color: const Color(0xFF373737),
                              fontFamily: 'OpenSans',
                              fontSize: fs(13),
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                          SizedBox(width: x(6)),
                          GestureDetector(
                            onTap: widget.onSignIn ??
                                () => debugPrint('International Sign In clicked'),
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                color: const Color(0xFFFF8213),
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
