import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/connectivity_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class VendorLocationMapPicker extends ConsumerStatefulWidget {
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
  ConsumerState<VendorLocationMapPicker> createState() => _VendorLocationMapPickerState();
}

class _VendorLocationMapPickerState extends ConsumerState<VendorLocationMapPicker> {
  final _mapController = MapController();
  final _mapKey = GlobalKey();
  LatLng? _pinPoint;
  LatLng? _gpsPoint;
  Timer? _dragDebounce;

  @override
  void initState() {
    super.initState();
    if (_hasValidCoordinates(widget.initialLatitude, widget.initialLongitude)) {
      _pinPoint = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _gpsPoint = _pinPoint;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pinPoint != null) _mapController.move(_pinPoint!, 17);
      });
    }
  }

  @override
  void didUpdateWidget(VendorLocationMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_hasValidCoordinates(widget.initialLatitude, widget.initialLongitude) &&
        !_hasValidCoordinates(oldWidget.initialLatitude, oldWidget.initialLongitude)) {
      final point = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      setState(() {
        _pinPoint = point;
        _gpsPoint = point;
      });
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
    return latitude != null && longitude != null && latitude != 0.0 && longitude != 0.0;
  }

  void _recenter() {
    if (_pinPoint == null) return;
    _mapController.move(_pinPoint!, 17);
  }

  void _movePinTo(LatLng point, {bool immediate = false}) {
    setState(() => _pinPoint = point);
    _dragDebounce?.cancel();

    if (immediate) {
      widget.onLocationSelected(point.latitude, point.longitude, 'map_pin');
      return;
    }

    _dragDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      widget.onLocationSelected(point.latitude, point.longitude, 'map_pin');
    });
  }

  LatLng? _latLngFromGlobal(Offset globalPosition) {
    final context = _mapKey.currentContext;
    if (context == null) return null;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(globalPosition);
    return _mapController.camera.pointToLatLng(math.Point<double>(local.dx, local.dy));
  }

  static const _sriLankaCenter = LatLng(7.8731, 80.7718);

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    final pinPoint = _pinPoint;
    final hasPin = pinPoint != null;
    final center = pinPoint ?? _sriLankaCenter;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

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
                      onTap: (_, point) => _movePinTo(point, immediate: true),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.speedmart.lanka',
                        retinaMode: false,
                      ),
                      MarkerLayer(
                          markers: [
                            if (_gpsPoint != null)
                              Marker(
                                point: _gpsPoint!,
                                width: 34,
                                height: 34,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.blue.withValues(alpha: 0.18),
                                    border: Border.all(color: Colors.blue, width: 2),
                                  ),
                                  child: const Icon(Icons.my_location, color: Colors.blue, size: 16),
                                ),
                              ),
                            if (pinPoint != null)
                            Marker(
                              point: pinPoint,
                              width: 58,
                              height: 58,
                              alignment: Alignment.topCenter,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanUpdate: (details) {
                                  final next = _latLngFromGlobal(details.globalPosition);
                                  if (next != null) _movePinTo(next);
                                },
                                onPanEnd: (_) {
                                  final latest = _pinPoint;
                                  if (latest != null) _movePinTo(latest, immediate: true);
                                },
                                child: const Icon(Icons.location_pin, color: AppColors.vendorColor, size: 52),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (!isOnline) _OfflineMapOverlay(isDark: isDark),
                  if (!hasPin)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: ElevatedButton.icon(
                          onPressed: null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cardColor,
                            foregroundColor: AppColors.vendorColor,
                            elevation: 4,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          icon: const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          label: const Text('Detecting GPS…', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  if (hasPin)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FloatingActionButton.small(
                            heroTag: 'vendor-map-recenter',
                            onPressed: _recenter,
                            backgroundColor: cardColor,
                            foregroundColor: AppColors.vendorColor,
                            child: const Icon(Icons.center_focus_strong_rounded),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: cardColor.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: AppColors.vendorColor
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'Re-center',
                              style: TextStyle(
                                color: AppColors.vendorColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
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

class _OfflineMapOverlay extends StatelessWidget {
  const _OfflineMapOverlay({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: (isDark ? AppColors.surfaceDark : AppColors.surfaceLight).withOpacity(0.92),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 36,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: 10),
            Text(
              'Map unavailable offline',
              style: AppTextStyles.bodyMedium(
                isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
