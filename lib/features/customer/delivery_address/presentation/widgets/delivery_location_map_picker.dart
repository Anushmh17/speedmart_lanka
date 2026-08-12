import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/services/connectivity_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../location/providers/location_provider.dart';

class DeliveryLocationMapPicker extends ConsumerStatefulWidget {
  const DeliveryLocationMapPicker({super.key});

  @override
  ConsumerState<DeliveryLocationMapPicker> createState() =>
      _DeliveryLocationMapPickerState();
}

class _DeliveryLocationMapPickerState
    extends ConsumerState<DeliveryLocationMapPicker> {
  final _mapController = MapController();
  final _mapKey = GlobalKey();
  LatLng? _pinPoint;
  LatLng? _gpsPoint;
  Timer? _dragDebounce;

  @override
  void dispose() {
    _dragDebounce?.cancel();
    super.dispose();
  }

  LatLng? _lastSyncedGps;

  void _maybeFlyToNewGps(LocationState state) {
    final point = _pointFromState(state);
    if (point == null || point == _lastSyncedGps) return;
    _lastSyncedGps = point;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mapController.move(point, 17);
    });
  }

  bool _hasValidCoordinates(double? latitude, double? longitude) {
    return latitude != null &&
        longitude != null &&
        latitude != 0.0 &&
        longitude != 0.0;
  }

  LatLng? _pointFromState(LocationState state) {
    final loc = state.currentLocation;
    if (!_hasValidCoordinates(loc?.latitude, loc?.longitude)) return null;
    return LatLng(loc!.latitude!, loc.longitude!);
  }

  void _syncPointFromState(LocationState state) {
    final point = _pointFromState(state);
    if (point == null) return;

    // Only update _gpsPoint (blue dot) from provider — never overwrite a
    // user-placed pin. _pinPoint is only set on first load or GPS detect.
    final shouldUpdateGps = _gpsPoint == null || _gpsPoint != point;
    if (shouldUpdateGps) {
      _gpsPoint = point;
      // Only move _pinPoint if the user hasn't placed one yet
      if (_pinPoint == null) {
        _pinPoint = point;
        _maybeFlyToNewGps(state);
      }
    }
  }

  Future<void> _detectAgain() async {
    await ref.read(deliveryLocationProvider.notifier).fetchCurrentLocation();
    final point = _pointFromState(ref.read(deliveryLocationProvider));
    if (point == null || !mounted) return;
    setState(() {
      _pinPoint = point;
      _gpsPoint = point;
      _lastSyncedGps = point;
    });
    _mapController.move(point, 17);
  }

  void _recenter() {
    final target = _gpsPoint ?? _pinPoint;
    if (target == null) return;
    _mapController.move(target, 17);
  }

  void _movePinTo(LatLng point, {bool immediate = false}) {
    setState(() => _pinPoint = point);
    _dragDebounce?.cancel();

    if (immediate) {
      ref.read(deliveryLocationProvider.notifier).updateDeliveryPin(
            latitude: point.latitude,
            longitude: point.longitude,
          );
      return;
    }

    _dragDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      ref.read(deliveryLocationProvider.notifier).updateDeliveryPin(
            latitude: point.latitude,
            longitude: point.longitude,
          );
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
    final locationState = ref.watch(deliveryLocationProvider);
    final isOnline = ref.watch(isOnlineProvider);
    _syncPointFromState(locationState);

    final pinPoint = _pinPoint;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    const sriLankaCenter = LatLng(7.8731, 80.7718);
    final hasPin = pinPoint != null;
    final center = pinPoint ?? sriLankaCenter;
    final loc = locationState.currentLocation;

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
                                  child: const Icon(Icons.location_pin, color: AppColors.customerColor, size: 52),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                  if (!isOnline) _OfflineMapOverlay(isDark: isDark),
                  // Centered "Use My Location" button — shown only before first pin
                  if (!hasPin && !locationState.isGpsLoading)
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _detectAgain,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cardColor,
                          foregroundColor: AppColors.customerColor,
                          elevation: 4,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        icon: const Icon(Icons.my_location_rounded, size: 18),
                        label: const Text(
                          'Use My Location',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  if (locationState.isGpsLoading)
                    Container(
                      color: Colors.black38,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: AppColors.customerColor),
                          const SizedBox(height: 12),
                          Text('Detecting GPS location…', style: AppTextStyles.bodySmall(Colors.white)),
                        ],
                      ),
                    ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (hasPin)
                          FloatingActionButton.small(
                            heroTag: 'delivery-map-recenter',
                            onPressed: _recenter,
                            backgroundColor: cardColor,
                            foregroundColor: AppColors.customerColor,
                            child: const Icon(Icons.center_focus_strong_rounded),
                          ),
                        if (hasPin) const SizedBox(height: 8),
                        Column(
                          children: [
                            FloatingActionButton.small(
                              heroTag: 'delivery-map-detect-again',
                              onPressed: locationState.isGpsLoading ? null : _detectAgain,
                              backgroundColor: cardColor,
                              foregroundColor: AppColors.customerColor,
                              child: locationState.isGpsLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.my_location_rounded),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: cardColor.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: AppColors.customerColor
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                'My Location',
                                style: TextStyle(
                                  color: AppColors.customerColor,
                                  fontSize: 9,
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
                        ? 'Drag the red pin to your gate, lobby, or shop entrance.'
                        : 'Use current location first, then drag the pin to your exact entrance.',
                    style: AppTextStyles.bodyMedium(primaryText),
                  ),
                  if (hasPin) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Lat ${pinPoint.latitude.toStringAsFixed(6)} • Lng ${pinPoint.longitude.toStringAsFixed(6)}',
                      style: AppTextStyles.caption(secondaryText),
                    ),
                    if (loc?.formattedAddress.isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text(loc!.formattedAddress, style: AppTextStyles.caption(secondaryText)),
                    ],
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
