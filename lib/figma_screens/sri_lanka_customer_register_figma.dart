import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:latlong2/latlong.dart';

class SrilankacustomerregisteraccountWidget extends StatefulWidget {
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

  const SrilankacustomerregisteraccountWidget({
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
  State<SrilankacustomerregisteraccountWidget> createState() =>
      _SrilankacustomerregisteraccountWidgetState();
}

class _SrilankacustomerregisteraccountWidgetState
    extends State<SrilankacustomerregisteraccountWidget> {
  static const String _assetBase =
      'assets/images/figma/sri_lanka_customer_register/';

  final TextEditingController _nicController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _deliveryNoteController = TextEditingController();
  final FocusNode _nicFocusNode = FocusNode();
  final FocusNode _fullNameFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _addressFocusNode = FocusNode();
  final FocusNode _deliveryNoteFocusNode = FocusNode();

  final MapController _mapController = MapController();
  final _mapKey = GlobalKey();
  LatLng? _pinPoint;
  LatLng? _gpsPoint;
  double? _lastMovedLat;
  double? _lastMovedLng;

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
  void didUpdateWidget(covariant SrilankacustomerregisteraccountWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lat = widget.initialLatitude;
    final lng = widget.initialLongitude;
    if (lat != null && lng != null &&
        (lat != _lastMovedLat || lng != _lastMovedLng)) {
      _lastMovedLat = lat;
      _lastMovedLng = lng;
      final newPoint = LatLng(lat, lng);
      _pinPoint = newPoint;
      _gpsPoint = newPoint;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(newPoint, 14.0);
      });
    }
  }

  @override
  void dispose() {
    _nicController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _deliveryNoteController.dispose();

    _nicFocusNode.dispose();
    _fullNameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _emailFocusNode.dispose();
    _addressFocusNode.dispose();
    _deliveryNoteFocusNode.dispose();
    _mapController.dispose();

    super.dispose();
  }

  void _handleCreateAccount() {
    if (widget.onCreateAccountWithData != null) {
      widget.onCreateAccountWithData!({
        'fullName': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'nic': _nicController.text.trim().toUpperCase(),
        'province': widget.selectedProvince?.trim() ?? '',
        'district': widget.selectedDistrict?.trim() ?? '',
        'preciseAddress': _addressController.text.trim(),
        'deliveryNote': _deliveryNoteController.text.trim(),
        'country': 'Sri Lanka',
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

    debugPrint('Sri Lanka Create Account clicked');
  }

  void _handleCountryTap() => widget.onCountryTap?.call();

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;

    final scale = w / 360;
    final fontScale = scale.clamp(0.76, 1.0).toDouble();

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
      bool isRequired = false,
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
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: controller,
                        builder: (context, value, child) {
                          if (value.text.isNotEmpty) return const SizedBox.shrink();
                          return IgnorePointer(
                            child: RichText(
                              text: TextSpan(
                                text: hint,
                                style: TextStyle(
                                  color: const Color(0xFF4F4F4F),
                                  fontFamily: 'Inter',
                                  fontSize: fs(14.5),
                                  fontWeight: FontWeight.w600,
                                  height: 1.1,
                                ),
                                children: [
                                  if (isRequired)
                                    const TextSpan(
                                      text: ' *',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      Material(
                        color: Colors.transparent,
                        child: TextField(
                      focusNode: focusNode,
                      controller: controller,
                      keyboardType: keyboardType,
                      textCapitalization: textCapitalization,
                      inputFormatters: inputFormatters,
                      maxLines: maxLines,
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
                        hintText: '',
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
                    ],
                  ),
                ),
                SizedBox(width: x(8)),
              ],
            ),
          ),
        ),
      );
    }

    Widget countryCard() {
      return Positioned(
        top: y(38),
        left: x(10),
        child: GestureDetector(
          onTap: _handleCountryTap,
          child: Container(
            width: x(142),
            height: y(75),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 141, 40, 0.12),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(x(11)),
                bottomRight: Radius.circular(x(11)),
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
                  left: x(11),
                  child: Icon(
                    Icons.public_rounded,
                    color: const Color(0xFF4F4F4F),
                    size: x(19),
                  ),
                ),
                Positioned(
                  top: y(11),
                  left: x(47),
                  child: Text(
                    'Country',
                    style: TextStyle(
                      color: const Color(0xFF4F4F4F),
                      fontFamily: 'Inter',
                      fontSize: fs(15),
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),
                Positioned(
                  top: y(38),
                  left: x(9),
                  child: Text(
                    '🇱🇰',
                    style: TextStyle(
                      fontSize: fs(18),
                      height: 1,
                    ),
                  ),
                ),
                Positioned(
                  top: y(40),
                  left: x(46),
                  child: Text(
                    'Sri Lanka',
                    style: TextStyle(
                      color: const Color(0xFF2960D6),
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
        ),
      );
    }

    Widget nicCard() {
      return Positioned(
        top: y(38),
        left: x(162),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _nicFocusNode.requestFocus();
          },
          child: Container(
            width: x(173),
            height: y(75),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 141, 40, 0.05),
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
                  left: x(9),
                  child: Icon(
                    Icons.badge_outlined,
                    color: const Color(0xFF4F4F4F),
                    size: x(18),
                  ),
                ),
                Positioned(
                  top: y(12),
                  left: x(39),
                  child: Text(
                    'NIC (Optional)',
                    style: TextStyle(
                      color: const Color(0xFF4F4F4F),
                      fontFamily: 'Inter',
                      fontSize: fs(15),
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),
                Positioned(
                  top: y(39),
                  left: x(36),
                  right: x(8),
                  child: Material(
                    color: Colors.transparent,
                    child: TextField(
                      focusNode: _nicFocusNode,
                      controller: _nicController,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        _NicTextFormatter(),
                      ],
                      cursorColor: const Color(0xFFFF8213),
                      scrollPadding: EdgeInsets.only(
                        bottom: media.viewInsets.bottom + y(120),
                      ),
                      style: TextStyle(
                        color: Colors.black,
                        fontFamily: 'Inter',
                        fontSize: fs(15.5),
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter your NIC',
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
      bool isRequired = false,
      bool hasValue = false,
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
                  child: RichText(
                    text: TextSpan(
                      text: title,
                      style: TextStyle(
                        color: const Color(0xFF4F4F4F),
                        fontFamily: 'Inter',
                        fontSize: fs(14.5),
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                      children: [
                        if (isRequired && !hasValue)
                          const TextSpan(
                            text: ' *',
                            style: TextStyle(color: Colors.red),
                          ),
                      ],
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
      final mapCenter = pinPoint ?? const LatLng(7.8731, 80.7718);

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
                  initialZoom: hasLocation ? 14.0 : 7.5,
                  minZoom: 6,
                  maxZoom: 19,
                  onTap: (_, point) {
                    setState(() => _pinPoint = point);
                    widget.onLocationPinChanged?.call(point.latitude, point.longitude);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.speedmart.lanka',
                    retinaMode: RetinaMode.isHighDensity(context),
                  ),
                  MarkerLayer(
                      markers: [
                        if (_gpsPoint != null)
                          Marker(
                            point: _gpsPoint!,
                            width: x(34),
                            height: x(34),
                            child: Container(
                              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.withValues(alpha: 0.18), border: Border.all(color: Colors.blue, width: 2)),
                              child: const Icon(Icons.my_location, color: Colors.blue, size: 16),
                            ),
                          ),
                        if (pinPoint != null)
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
              // Centered "Use My Location" button — shown only before first detection
              if (!hasLocation)
                Center(
                  child: ElevatedButton.icon(
                    onPressed: widget.isDetectingLocation
                        ? null
                        : (widget.onUseCurrentLocation ?? () {}),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFFB6F02),
                      elevation: 4,
                      padding: EdgeInsets.symmetric(
                          horizontal: x(16), vertical: y(10)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(x(24)),
                      ),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: widget.isDetectingLocation
                        ? SizedBox(
                            width: x(16),
                            height: x(16),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFB6F02),
                            ),
                          )
                        : const Icon(Icons.my_location_rounded, size: 18),
                    label: Text(
                      widget.isDetectingLocation ? 'Detecting…' : 'Use My Location',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: fs(13),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFB6F02),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: x(10),
                top: y(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (hasLocation)
                      FloatingActionButton.small(
                        heroTag: 'cust-reg-map-recenter',
                        onPressed: () => _mapController.move(pinPoint, 14.0),
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFFB6F02),
                        child: const Icon(Icons.center_focus_strong_rounded),
                      ),
                    if (hasLocation) SizedBox(height: y(8)),
                    Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'cust-reg-map-detect',
                          onPressed: widget.isDetectingLocation
                              ? null
                              : (widget.onUseCurrentLocation ?? () {}),
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
                        SizedBox(height: y(2)),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: x(5), vertical: y(2)),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(x(4)),
                          ),
                          child: Text(
                            'My Location',
                            style: TextStyle(
                              color: const Color(0xFFFB6F02),
                              fontFamily: 'Inter',
                              fontSize: fs(9),
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
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
                        : 'Tap "Use My Location" to pin your location',
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
        child: PopScope(
          // Intercept back gesture: dismiss keyboard first if it is open,
          // only allow navigation away when the keyboard is already closed.
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
            if (isKeyboardOpen) {
              FocusScope.of(context).unfocus();
            } else {
              Navigator.of(context).maybePop();
            }
          },
          child: Scaffold(
          backgroundColor: const Color(0xFFFDFDFC),
          resizeToAvoidBottomInset: true,
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                width: w,
                height: y(1240),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: y(203),
                      child: Image.asset(
                        '${_assetBase}Heroimageofregisterpagecustomer2.png',
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
                            countryCard(),
                            nicCard(),
                            normalField(
                              top: 124,
                              left: 10,
                              width: 325,
                              height: 45,
                              icon: Icons.person_outline_rounded,
                              hint: 'Full Name',
                              isRequired: true,
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
                              isRequired: true,
                              controller: _phoneController,
                              focusNode: _phoneFocusNode,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                            ),
                            normalField(
                              top: 236,
                              left: 10,
                              width: 325,
                              height: 45,
                              icon: Icons.email_outlined,
                              hint: 'Email Address',
                              isRequired: true,
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
                              isRequired: true,
                              hasValue: widget.selectedProvince?.isNotEmpty == true,
                            ),
                            dropdownField(
                              top: 357,
                              title: widget.selectedDistrict?.isNotEmpty == true
                                  ? widget.selectedDistrict!
                                  : 'District',
                              icon: Icons.travel_explore_rounded,
                              onTap: widget.onDistrictTap,
                              isRequired: true,
                              hasValue: widget.selectedDistrict?.isNotEmpty == true,
                            ),
                            normalField(
                              top: 408,
                              left: 0,
                              width: 325,
                              height: 74.5,
                              icon: Icons.place_outlined,
                              hint: 'Precise Delivery Address',
                              isRequired: true,
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
                      top: y(1171),
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
                                () => debugPrint('Sri Lanka Sign In clicked'),
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
        ), // Scaffold
        ), // PopScope
      ),
    );
  }
}


class _NicTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.toUpperCase();

    // Build valid NIC string: up to 9 digits, then optionally one V at the end
    final buffer = StringBuffer();
    int digitCount = 0;
    bool hasV = false;

    for (final ch in raw.split('')) {
      if (ch == 'V' && !hasV && digitCount == 9) {
        buffer.write('V');
        hasV = true;
      } else if (RegExp(r'\d').hasMatch(ch) && !hasV && digitCount < 12) {
        buffer.write(ch);
        digitCount++;
      }
      // anything else (X, misplaced V, extra digits after V) is dropped
    }

    final result = buffer.toString();
    return newValue.copyWith(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}
