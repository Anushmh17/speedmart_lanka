import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class AdminVendorLocationPreview extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final String? shopAddress;
  final String? locationSource;
  final double? accuracyMeters;

  const AdminVendorLocationPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    this.shopAddress,
    this.locationSource,
    this.accuracyMeters,
  });

  bool get _hasValidCoordinates {
    return latitude != null &&
        longitude != null &&
        latitude != 0.0 &&
        longitude != 0.0;
  }

  String get _sourceLabel {
    if (locationSource == null) return 'Unknown';
    switch (locationSource) {
      case 'gps':
        return 'GPS';
      case 'map_pin':
        return 'Map Pin';
      case 'manual':
        return 'Manual';
      default:
        return locationSource!;
    }
  }

  Future<void> _openInGoogleMaps() async {
    if (!_hasValidCoordinates) return;
    
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      debugPrint('[AdminVendorLocation] Opened Google Maps: $latitude, $longitude');
    } else {
      debugPrint('[AdminVendorLocation] Could not launch Google Maps');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    if (!_hasValidCoordinates) {
      debugPrint('[AdminVendorLocation] invalid coordinates: lat=$latitude, lng=$longitude');
      
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_off_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No valid location submitted',
                    style: AppTextStyles.labelLarge(AppColors.error),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Shop owner has not provided a valid shop location.',
                    style: AppTextStyles.caption(AppColors.error),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    debugPrint('[AdminVendorLocation] lat/lng: $latitude, $longitude');
    debugPrint('[AdminVendorLocation] source: $_sourceLabel');
    debugPrint('[AdminVendorLocation] map rendered: true');

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.location_on_rounded, color: AppColors.adminColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Shop Location',
                  style: AppTextStyles.subtitle(primaryText),
                ),
              ],
            ),
          ),
          
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: SizedBox(
              height: 200,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(latitude!, longitude!),
                  initialZoom: 16,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.speedmart.lanka',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(latitude!, longitude!),
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.location_pin,
                          color: AppColors.adminColor,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (shopAddress != null && shopAddress!.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.home_rounded, size: 16, color: secondaryText),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          shopAddress!,
                          style: AppTextStyles.bodySmall(primaryText),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                
                Row(
                  children: [
                    Icon(Icons.pin_drop_outlined, size: 16, color: secondaryText),
                    const SizedBox(width: 8),
                    Text(
                      'Lat ${latitude!.toStringAsFixed(6)} • Lng ${longitude!.toStringAsFixed(6)}',
                      style: AppTextStyles.caption(secondaryText),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                
                Row(
                  children: [
                    Icon(Icons.source_rounded, size: 16, color: secondaryText),
                    const SizedBox(width: 8),
                    Text(
                      'Source: $_sourceLabel',
                      style: AppTextStyles.caption(secondaryText),
                    ),
                    if (accuracyMeters != null) ...[
                      Text(
                        ' • Accuracy: ${accuracyMeters!.toStringAsFixed(0)}m',
                        style: AppTextStyles.caption(secondaryText),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openInGoogleMaps,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open in Google Maps'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.adminColor,
                      side: const BorderSide(color: AppColors.adminColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
