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
      // Auto-center on pin after widget builds
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pinPoint != null) {
          _mapController.move(_pinPoint!, 17);
        }
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

  @override
  Widget build(BuildContext context) {
    final pinPoint = _pinPoint;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    if (pinPoint == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Shop Location Map', style: AppTextStyles.subtitle(primaryText)),
            const SizedBox(height: 8),
            Text(
              'Detect your GPS location first, then drag the pin to your exact shop entrance.',
              style: AppTextStyles.bodySmall(secondaryText),
            ),
          ],
        ),
      );
    }

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
                      initialCenter: pinPoint,
                      initialZoom: 17,
                      minZoom: 6,
                      maxZoom: 19,
                      onTap: (_, point) => _movePinTo(point, immediate: true),
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
                    'Drag the purple pin to your shop entrance.',
                    style: AppTextStyles.bodyMedium(primaryText),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lat ${pinPoint.latitude.toStringAsFixed(6)} • Lng ${pinPoint.longitude.toStringAsFixed(6)}',
                    style: AppTextStyles.caption(secondaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
