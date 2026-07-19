import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:latlong2/latlong.dart';

class SrilankavendorregistrationWidget extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onCreateAccount;
  final VoidCallback? onSignIn;
  final VoidCallback? onCountryTap;
  final VoidCallback? onDistrictTap;
  final VoidCallback? onProvinceTap;
  final VoidCallback? onUseCurrentLocation;
  final ValueChanged<Map<String, String>>? onCreateAccountWithData;

  final String? selectedProvince;
  final String? selectedDistrict;
  final double? initialLatitude;
  final double? initialLongitude;
  final void Function(double latitude, double longitude)? onLocationPinChanged;
  final bool isDetectingLocation;
  final LatLng? externalPinPoint;
  final bool isLoading;

  const SrilankavendorregistrationWidget({
    super.key,
    this.onBack,
    this.onCreateAccount,
    this.onSignIn,
    this.onCountryTap,
    this.onDistrictTap,
    this.onProvinceTap,
    this.onUseCurrentLocation,
    this.onCreateAccountWithData,
    this.selectedProvince,
    this.selectedDistrict,
    this.initialLatitude,
    this.initialLongitude,
    this.onLocationPinChanged,
    this.isDetectingLocation = false,
    this.externalPinPoint,
    this.isLoading = false,
  });

  @override
  State<SrilankavendorregistrationWidget> createState() =>
      _SrilankavendorregistrationWidgetState();
}

class _SrilankavendorregistrationWidgetState
    extends State<SrilankavendorregistrationWidget> {
  static const String _assetBase =
      'assets/images/figma/sri_lanka_vendor_register/';

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nicController = TextEditingController();

  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _businessRegController = TextEditingController();
  final TextEditingController _shopAddressController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _fullNameFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _nicFocusNode = FocusNode();

  final FocusNode _shopNameFocusNode = FocusNode();
  final FocusNode _businessRegFocusNode = FocusNode();
  final FocusNode _shopAddressFocusNode = FocusNode();

  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  final Set<String> _selectedCategories = {};

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  final MapController _mapController = MapController();
  final _mapKey = GlobalKey();
  LatLng? _pinPoint;

  double? _lastMovedLat;
  double? _lastMovedLng;

  LatLng? get _effectivePin => _pinPoint ?? widget.externalPinPoint ??
      (widget.initialLatitude != null && widget.initialLongitude != null
          ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
          : null);

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
  void didUpdateWidget(covariant SrilankavendorregistrationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lat = widget.initialLatitude;
    final lng = widget.initialLongitude;
    if (lat != null && lng != null &&
        (lat != _lastMovedLat || lng != _lastMovedLng)) {
      _lastMovedLat = lat;
      _lastMovedLng = lng;
      final newPoint = LatLng(lat, lng);
      _pinPoint = newPoint;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(newPoint, 14.0);
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _nicController.dispose();

    _shopNameController.dispose();
    _businessRegController.dispose();
    _shopAddressController.dispose();

    _passwordController.dispose();
    _confirmPasswordController.dispose();

    _emailFocusNode.dispose();
    _fullNameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _nicFocusNode.dispose();

    _shopNameFocusNode.dispose();
    _businessRegFocusNode.dispose();
    _shopAddressFocusNode.dispose();

    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _mapController.dispose();

    super.dispose();
  }

  void _handleCountryTap() => widget.onCountryTap?.call();

  void _handleCreateAccount() {
    if (widget.onCreateAccountWithData != null) {
      final pin = _effectivePin;
      widget.onCreateAccountWithData!({
        'email': _emailController.text.trim(),
        'fullName': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'nic': _nicController.text.trim(),
        'shopName': _shopNameController.text.trim(),
        'businessRegNo': _businessRegController.text.trim(),
        'shopAddress': _shopAddressController.text.trim(),
        'province': widget.selectedProvince?.trim() ?? '',
        'district': widget.selectedDistrict?.trim() ?? '',
        'categories': _selectedCategories.join(','),
        'password': _passwordController.text,
        'confirmPassword': _confirmPasswordController.text,
        'country': 'Sri Lanka',
        if (pin != null) 'latitude': pin.latitude.toString(),
        if (pin != null) 'longitude': pin.longitude.toString(),
      });
      return;
    }

    if (widget.onCreateAccount != null) {
      widget.onCreateAccount!();
      return;
    }

    debugPrint('Sri Lanka vendor Create Account clicked');
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;

    final scale = w / 360;
    final fontScale = scale.clamp(0.92, 1.08).toDouble();

    double x(double value) => value * scale;
    double y(double value) => value * scale;
    double fs(double value) => value * fontScale;

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
              color: const Color(0xFFFF8213),
              size: x(22),
            ),
            SizedBox(width: x(9)),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'OpenSans',
                fontSize: fs(15.5),
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ],
        ),
      );
    }

    Widget darkField({
      required double top,
      required double left,
      required double width,
      required double height,
      required String hint,
      required TextEditingController controller,
      required FocusNode focusNode,
      TextInputType keyboardType = TextInputType.text,
      TextCapitalization textCapitalization = TextCapitalization.none,
      List<TextInputFormatter>? inputFormatters,
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
              color: const Color.fromRGBO(0, 0, 0, 0.05),
              borderRadius: BorderRadius.circular(x(11)),
              border: Border.all(
                color: Colors.white,
                width: x(1),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: x(23),
                right: suffix == null ? x(23) : x(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: TextField(
                        focusNode: focusNode,
                        controller: controller,
                        keyboardType: keyboardType,
                        textCapitalization: textCapitalization,
                        inputFormatters: inputFormatters,
                        obscureText: obscureText,
                        obscuringCharacter: '●',
                        cursorColor: const Color(0xFFFF8213),
                        textAlignVertical: TextAlignVertical.center,
                        scrollPadding: EdgeInsets.only(
                          bottom: media.viewInsets.bottom + y(120),
                        ),
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Inter',
                          fontSize: fs(16.5),
                          fontWeight: FontWeight.w700,
                          height: 1,
                          letterSpacing: obscureText ? 1.5 : 0,
                        ),
                        decoration: InputDecoration(
                          hintText: hint,
                          hintStyle: TextStyle(
                            color: const Color(0xFFCACACA),
                            fontFamily: 'Inter',
                            fontSize: fs(15),
                            fontWeight: FontWeight.w600,
                            height: 1,
                            letterSpacing: 0,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  if (suffix != null) ...[
                    SizedBox(width: x(8)),
                    suffix,
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget dropdownField({
      required double top,
      required double left,
      required double width,
      required String title,
      required VoidCallback? onTap,
      bool isSriLanka = false,
      bool showArrow = true,
    }) {
      return Positioned(
        top: y(top),
        left: x(left),
        child: GestureDetector(
          onTap: onTap ?? () => debugPrint('$title clicked'),
          child: Container(
            width: x(width),
            height: y(40),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(0, 0, 0, 0.05),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(x(11)),
                bottomRight: Radius.circular(x(11)),
                topRight: Radius.circular(
                  width > 150 && !isSriLanka ? x(11) : 0,
                ),
                bottomLeft: Radius.circular(
                  width > 150 && !isSriLanka ? x(11) : 0,
                ),
              ),
              border: Border.all(
                color: isSriLanka ? const Color(0xFF18A3F9) : Colors.white,
                width: isSriLanka ? x(1.5) : x(1),
              ),
            ),
            child: Row(
              children: [
                SizedBox(width: x(13)),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFCACACA),
                      fontFamily: 'Inter',
                      fontSize: fs(15),
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),
                if (showArrow)
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white,
                    size: x(22),
                  ),
                SizedBox(width: x(9)),
              ],
            ),
          ),
        ),
      );
    }

    Widget locationBox() {
      final pinPoint = _effectivePin;
      final hasLocation = pinPoint != null;
      final mapCenter = pinPoint ?? const LatLng(7.8731, 80.7718);

      return Positioned(
        top: y(134),
        left: x(0),
        width: x(325),
        height: y(260),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(x(10)),
          child: Stack(
            children: [
              SizedBox(
                key: _mapKey,
                width: x(325),
                height: y(260),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: hasLocation ? 14.0 : 7.5,
                    minZoom: 6,
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
                                final next =
                                    _latLngFromGlobal(details.globalPosition);
                                if (next != null) {
                                  setState(() => _pinPoint = next);
                                }
                              },
                              onPanEnd: (_) {
                                final pin = _effectivePin;
                                if (pin != null) {
                                  widget.onLocationPinChanged?.call(
                                    pin.latitude,
                                    pin.longitude,
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
              ),
              Positioned(
                right: x(10),
                top: y(10),
                child: Column(
                  children: [
                    if (hasLocation)
                      FloatingActionButton.small(
                        heroTag: 'slv-reg-map-recenter',
                        onPressed: () => _mapController.move(pinPoint, 14.0),
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFFB6F02),
                        child: const Icon(Icons.center_focus_strong_rounded),
                      ),
                    if (hasLocation) SizedBox(height: y(8)),
                    FloatingActionButton.small(
                      heroTag: 'slv-reg-map-detect',
                      onPressed: widget.isDetectingLocation
                          ? null
                          : (widget.onUseCurrentLocation ??
                              () => debugPrint(
                                    'Vendor Use Current Location clicked',
                                  )),
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
                        : 'Tap the location button to pin your shop',
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

    Widget categoryChip({
      required double top,
      required double left,
      required String title,
    }) {
      final selected = _selectedCategories.contains(title);

      return Positioned(
        top: y(top),
        left: x(left),
        child: GestureDetector(
          onTap: () {
            setState(() {
              if (selected) {
                _selectedCategories.remove(title);
              } else {
                _selectedCategories.add(title);
              }
            });
          },
          child: Container(
            width: x(159),
            height: y(40),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? const Color.fromRGBO(255, 130, 19, 0.20)
                  : const Color.fromRGBO(0, 0, 0, 0.05),
              borderRadius: BorderRadius.circular(x(11)),
              border: Border.all(
                color: selected ? const Color(0xFFFF8213) : Colors.white,
                width: x(1),
              ),
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontSize: fs(15),
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
        ),
      );
    }

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
          backgroundColor: const Color(0xFF020304),
          resizeToAvoidBottomInset: true,
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                width: w,
                height: y(1620),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: y(203),
                      child: Image.asset(
                        '${_assetBase}Heroimageofregisterpagevendor1.png',
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
                      top: y(211),
                      left: x(17),
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
                            SizedBox(width: x(12)),
                            Icon(
                              Icons.verified_user_outlined,
                              color: const Color(0xFFFF8213),
                              size: x(26),
                            ),
                            SizedBox(width: x(10)),
                            Expanded(
                              child: Text(
                                'Shop Owner accounts require admin approval\nbefore you can start selling',
                                style: TextStyle(
                                  color: const Color(0xFFFF8213),
                                  fontFamily: 'Inter',
                                  fontSize: fs(13),
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(268),
                      left: x(10),
                      child: SizedBox(
                        width: x(332),
                        height: y(276),
                        child: Stack(
                          children: [
                            sectionTitle(
                              top: 0,
                              left: 0,
                              icon: Icons.person_rounded,
                              title: 'Account Details',
                            ),
                            dropdownField(
                              top: 32,
                              left: 7,
                              width: 130,
                              title: 'Sri Lanka',
                              onTap: _handleCountryTap,
                              isSriLanka: true,
                              showArrow: false,
                            ),
                            darkField(
                              top: 83,
                              left: 7,
                              width: 325,
                              height: 40,
                              hint: 'Email Address',
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            darkField(
                              top: 134,
                              left: 7,
                              width: 325,
                              height: 40,
                              hint: 'Full Name',
                              controller: _fullNameController,
                              focusNode: _fullNameFocusNode,
                              textCapitalization: TextCapitalization.words,
                            ),
                            darkField(
                              top: 185,
                              left: 6,
                              width: 325,
                              height: 40,
                              hint: 'Phone Number',
                              controller: _phoneController,
                              focusNode: _phoneFocusNode,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                            ),
                            darkField(
                              top: 236,
                              left: 7,
                              width: 325,
                              height: 40,
                              hint: 'NIC',
                              controller: _nicController,
                              focusNode: _nicFocusNode,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9VvXx]')),
                                LengthLimitingTextInputFormatter(12),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(562),
                      left: x(10),
                      child: SizedBox(
                        width: x(332),
                        height: y(510),
                        child: Stack(
                          children: [
                            sectionTitle(
                              top: 0,
                              left: 0,
                              icon: Icons.location_on_rounded,
                              title: 'Shop Details',
                            ),
                            darkField(
                              top: 31,
                              left: 7,
                              width: 325,
                              height: 40,
                              hint: 'Shop Name',
                              controller: _shopNameController,
                              focusNode: _shopNameFocusNode,
                            ),
                            darkField(
                              top: 82,
                              left: 7,
                              width: 325,
                              height: 40,
                              hint: 'Business Registration Number (Optional)',
                              controller: _businessRegController,
                              focusNode: _businessRegFocusNode,
                            ),
                            locationBox(),
                            dropdownField(
                              top: 408,
                              left: 7,
                              width: 161,
                              title: widget.selectedDistrict?.isNotEmpty == true
                                  ? widget.selectedDistrict!
                                  : 'District',
                              onTap: widget.onDistrictTap,
                            ),
                            dropdownField(
                              top: 408,
                              left: 177,
                              width: 155,
                              title: widget.selectedProvince?.isNotEmpty == true
                                  ? widget.selectedProvince!
                                  : 'Province',
                              onTap: widget.onProvinceTap,
                            ),
                            darkField(
                              top: 459,
                              left: 7,
                              width: 325,
                              height: 40,
                              hint: 'Shop Address / Location',
                              controller: _shopAddressController,
                              focusNode: _shopAddressFocusNode,
                            ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(1082),
                      left: x(10),
                      child: SizedBox(
                        width: x(332),
                        height: y(271),
                        child: Stack(
                          children: [
                            sectionTitle(
                              top: 0,
                              left: 0,
                              icon: Icons.category_rounded,
                              title: 'Product Categories',
                            ),
                            categoryChip(top: 31, left: 7, title: 'Groceries'),
                            categoryChip(
                              top: 31,
                              left: 173,
                              title: 'Electronics',
                            ),
                            categoryChip(top: 81, left: 7, title: 'Hardware'),
                            categoryChip(top: 81, left: 173, title: 'Furniture'),
                            categoryChip(top: 131, left: 7, title: 'Pharmacy'),
                            categoryChip(top: 131, left: 173, title: 'Clothing'),
                            categoryChip(
                              top: 181,
                              left: 7,
                              title: 'Vehicle Parts',
                            ),
                            categoryChip(
                              top: 181,
                              left: 173,
                              title: 'Home Appliances',
                            ),
                            categoryChip(
                              top: 231,
                              left: 7,
                              title: 'Stationery',
                            ),
                            categoryChip(top: 231, left: 173, title: 'Other'),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(1369),
                      left: x(17),
                      child: SizedBox(
                        width: x(329),
                        height: y(122),
                        child: Stack(
                          children: [
                            sectionTitle(
                              top: 0,
                              left: 0,
                              icon: Icons.lock_rounded,
                              title: 'Security',
                            ),
                            darkField(
                              top: 31,
                              left: 4,
                              width: 325,
                              height: 40,
                              hint: 'Password',
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              obscureText: !_passwordVisible,
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
                                  size: x(19),
                                ),
                              ),
                            ),
                            darkField(
                              top: 82,
                              left: 4,
                              width: 325,
                              height: 40,
                              hint: 'Confirm Password',
                              controller: _confirmPasswordController,
                              focusNode: _confirmPasswordFocusNode,
                              obscureText: !_confirmPasswordVisible,
                              suffix: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _confirmPasswordVisible =
                                        !_confirmPasswordVisible;
                                  });
                                },
                                child: Icon(
                                  _confirmPasswordVisible
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: const Color(0xFFCACACA),
                                  size: x(19),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      top: y(1516),
                      left: x(21),
                      child: SizedBox(
                        width: x(318),
                        height: y(43.12),
                        child: ElevatedButton(
                          onPressed: widget.isLoading ? null : _handleCreateAccount,
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
                              : Text(
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
                      top: y(1589),
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account?',
                            style: TextStyle(
                              color: Colors.white,
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


