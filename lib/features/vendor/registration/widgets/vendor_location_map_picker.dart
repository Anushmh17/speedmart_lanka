import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class VendorLocationMapPicker extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final Function(double latitude, double longitude, String source) onLocationSelected;

  const VendorLocationMapPicker({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    required this.onLocationSelected,
  });

  @override
  State<VendorLocationMapPicker> createState() => _VendorLocationMapPickerState();
}

class _VendorLocationMapPickerState extends State<VendorLocationMapPicker> {
  final _mapController = MapController();
  final _mapKey = GlobalKey();
  LatLng? _pinPoint;
  Timer? _dragDebounce;

  @override
  void initState() {
    super.initState();
    if (_hasValidCoordinates(widget.initialLatitude, widget.initialLongitude)) {
      _pinPoint = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      debugPrint('[VendorLocation] map initialized lat/lng: ${widget.initialLatitude}, ${widget.initialLongitude}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pinPoint != null) _mapController.move(_pinPoint!, 17);
      });
    }
  }

  @override
  void didUpdateWidget(VendorLocationMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // GPS coordinates arrived after initial build — fly to pin
    if (_hasValidCoordinates(widget.initialLatitude, widget.initialLongitude) &&
        !_hasValidCoordinates(
            oldWidget.initialLatitude, oldWidget.initialLongitude)) {
      final point = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      setState(() => _pinPoint = point);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(point, 17);
      });
    }
  }

  @override
  void dispose() {
    _dragDebounce?.cancel();
    super.dispose();
  }

  bool _hasValidCoordinates(double? latitude, double? longitude) {
    return latitude != null &&
        longitude != null &&
        latitude != 0.0 &&
        longitude != 0.0;
  }

  void _recenter() {
    if (_pinPoint == null) return;
    _mapController.move(_pinPoint!, 17);
  }

  void _movePinTo(LatLng point, {bool immediate = false}) {
    debugPrint('[VendorLocation] pin moved lat/lng: ${point.latitude}, ${point.longitude}');
    setState(() => _pinPoint = point);
    _dragDebounce?.cancel();

    if (immediate) {
      debugPrint('[VendorLocation] final saved lat/lng: ${point.latitude}, ${point.longitude}');
      debugPrint('[VendorLocation] is valid: ${_hasValidCoordinates(point.latitude, point.longitude)}');
      widget.onLocationSelected(point.latitude, point.longitude, 'map_pin');
      return;
    }

    _dragDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      debugPrint('[VendorLocation] final saved lat/lng: ${point.latitude}, ${point.longitude}');
      debugPrint('[VendorLocation] is valid: ${_hasValidCoordinates(point.latitude, point.longitude)}');
      widget.onLocationSelected(point.latitude, point.longitude, 'map_pin');
    });
  }

  LatLng? _latLngFromGlobal(Offset globalPosition) {
    final context = _mapKey.currentContext;
    if (context == null) return null;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;

    final local = box.globalToLocal(globalPosition);
    return _mapController.camera.pointToLatLng(
      math.Point<double>(local.dx, local.dy),
    );
  }

  // Sri Lanka geographic center — used as fallback before GPS resolves
  static const _sriLankaCenter = LatLng(7.8731, 80.7718);

  @override
  Widget build(BuildContext context) {
    final pinPoint = _pinPoint;
    final hasPin = pinPoint != null;
    final center = pinPoint ?? _sriLankaCenter;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              key: _mapKey,
              height: 300,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: hasPin ? 17 : 8,
                      minZoom: 6,
                      maxZoom: 19,
                      onTap: hasPin
                          ? (_, point) => _movePinTo(point, immediate: true)
                          : null,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.speedmart.lanka',
                        retinaMode: false,
                      ),
                      if (hasPin)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: pinPoint,
                              width: 58,
                              height: 58,
                              alignment: Alignment.topCenter,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanUpdate: (details) {
                                  final next =
                                      _latLngFromGlobal(details.globalPosition);
                                  if (next != null) _movePinTo(next);
                                },
                                onPanEnd: (_) {
                                  final latest = _pinPoint;
                                  if (latest != null) {
                                    _movePinTo(latest, immediate: true);
                                  }
                                },
                                child: const Icon(
                                  Icons.location_pin,
                                  color: AppColors.vendorColor,
                                  size: 52,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (!hasPin)
                    Container(
                      color: Colors.black38,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: AppColors.vendorColor,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Detecting GPS location…',
                            style: AppTextStyles.bodySmall(Colors.white),
                          ),
                        ],
                      ),
                    ),
                  if (hasPin)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: FloatingActionButton.small(
                        heroTag: 'vendor-map-recenter',
                        onPressed: _recenter,
                        backgroundColor: cardColor,
                        foregroundColor: AppColors.vendorColor,
                        child: const Icon(Icons.center_focus_strong_rounded),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasPin
                        ? 'Drag the purple pin to your shop entrance.'
                        : 'Detect your GPS location first, then drag the pin to your exact shop entrance.',
                    style: AppTextStyles.bodyMedium(primaryText),
                  ),
                  if (hasPin) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Lat ${pinPoint.latitude.toStringAsFixed(6)} • Lng ${pinPoint.longitude.toStringAsFixed(6)}',
                      style: AppTextStyles.caption(secondaryText),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

