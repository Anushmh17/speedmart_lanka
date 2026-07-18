import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class OrderTrackingMap extends StatelessWidget {
  const OrderTrackingMap({
    super.key,
    required this.customerLatitude,
    required this.customerLongitude,
    required this.vendorLatitude,
    required this.vendorLongitude,
    required this.riderProgress,
    required this.vendorBusinessName,
  });

  final double customerLatitude;
  final double customerLongitude;
  final double vendorLatitude;
  final double vendorLongitude;
  final double riderProgress;
  final String vendorBusinessName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    // Linear interpolation for rider path
    final double riderLat = vendorLatitude + (customerLatitude - vendorLatitude) * riderProgress;
    final double riderLon = vendorLongitude + (customerLongitude - vendorLongitude) * riderProgress;
    final LatLng riderLatLng = LatLng(riderLat, riderLon);
    final LatLng vendorLatLng = LatLng(vendorLatitude, vendorLongitude);
    final LatLng customerLatLng = LatLng(customerLatitude, customerLongitude);

    // Compute bounds/midpoint to center the map
    final double midLat = (vendorLatitude + customerLatitude) / 2;
    final double midLon = (vendorLongitude + customerLongitude) / 2;
    final LatLng centerLatLng = LatLng(midLat, midLon);

    // Premium CartoDB basemaps matching the app theme
    final String tileUrlTemplate = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // FlutterMap interactive view
          FlutterMap(
            options: MapOptions(
              initialCenter: centerLatLng,
              initialZoom: 13.2,
              minZoom: 10,
              maxZoom: 17,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              // Beautiful Vector Map Tiles
              TileLayer(
                urlTemplate: tileUrlTemplate,
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.speedmart.lanka',
                retinaMode: RetinaMode.isHighDensity(context),
              ),

              // Polyline route representation
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [vendorLatLng, customerLatLng],
                    strokeWidth: 3.5,
                    color: AppColors.customerColor.withOpacity(0.4),
                    pattern: const StrokePattern.dotted(),
                  ),
                ],
              ),

              // Custom Map Pins (Shop Owner, Rider, Customer)
              MarkerLayer(
                markers: [
                  // 1. Shop Owner Marker
                  Marker(
                    point: vendorLatLng,
                    width: 100,
                    height: 60,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceDark : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.vendorColor, width: 1),
                            boxShadow: [
                              BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                            ],
                          ),
                          child: Text(
                            vendorBusinessName.length > 12
                                ? '${vendorBusinessName.substring(0, 10)}..'
                                : vendorBusinessName,
                            style: AppTextStyles.caption(primaryText).copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                          ),
                        ),
                        const Icon(
                          Icons.storefront_rounded,
                          color: AppColors.vendorColor,
                          size: 26,
                        ),
                      ],
                    ),
                  ),

                  // 2. Customer Home Marker
                  Marker(
                    point: customerLatLng,
                    width: 50,
                    height: 50,
                    child: const Icon(
                      Icons.location_pin,
                      color: AppColors.customerColor,
                      size: 36,
                    ),
                  ),

                  // 3. Live Animated Rider Marker (Only visible when route progress exists)
                  Marker(
                    point: riderLatLng,
                    width: 44,
                    height: 44,
                    child: _AnimatedRiderPin(isDark: isDark),
                  ),
                ],
              ),
            ],
          ),

          // Custom visual overlay details
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.directions_bike_rounded,
                      color: AppColors.customerColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        riderProgress == 0.0
                            ? 'Rider waiting at store...'
                            : riderProgress >= 1.0
                                ? 'Delivered to your home!'
                                : 'Rider on the way: ${(riderProgress * 100).toStringAsFixed(0)}% completed',
                        style: AppTextStyles.caption(primaryText).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
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

class _AnimatedRiderPin extends StatefulWidget {
  const _AnimatedRiderPin({required this.isDark});
  final bool isDark;

  @override
  State<_AnimatedRiderPin> createState() => _AnimatedRiderPinState();
}

class _AnimatedRiderPinState extends State<_AnimatedRiderPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -6 * _controller.value),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.customerColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.customerColor.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.delivery_dining_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        );
      },
    );
  }
}

