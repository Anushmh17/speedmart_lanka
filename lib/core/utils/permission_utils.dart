import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class AppPermissionUtils {
  static Permission getGalleryPermissionForSdkInt(int androidSdkInt) {
    return androidSdkInt >= 33 ? Permission.photos : Permission.storage;
  }

  static Future<bool> ensureCameraPermission(
    BuildContext context, {
    String permissionLabel = 'Camera',
  }) async {
    final status = await Permission.camera.status;
    if (status.isGranted || status.isLimited) return true;

    if (status.isPermanentlyDenied) {
      if (context.mounted) {
        await _showPermissionDialog(context, permissionLabel);
      }
      return false;
    }

    final result = await Permission.camera.request();
    if (result.isGranted || result.isLimited) return true;

    if (result.isPermanentlyDenied && context.mounted) {
      await _showPermissionDialog(context, permissionLabel);
    }
    return false;
  }

  static Future<bool> ensureGalleryPermission(
    BuildContext context, {
    String permissionLabel = 'Gallery',
    int? androidSdkInt,
  }) async {
    final primaryPermission = getGalleryPermissionForSdkInt(androidSdkInt ?? 33);
    final primaryStatus = await primaryPermission.status;
    if (primaryStatus.isGranted || primaryStatus.isLimited) return true;

    final primaryResult = await primaryPermission.request();
    if (primaryResult.isGranted || primaryResult.isLimited) return true;

    Permission? fallbackPermission;
    if (primaryPermission == Permission.photos) {
      fallbackPermission = Permission.storage;
    }

    if (fallbackPermission != null) {
      final fallbackStatus = await fallbackPermission.status;
      if (fallbackStatus.isGranted || fallbackStatus.isLimited) return true;

      if (fallbackStatus.isPermanentlyDenied) {
        if (context.mounted) {
          await _showPermissionDialog(context, permissionLabel);
        }
        return false;
      }

      final fallbackResult = await fallbackPermission.request();
      if (fallbackResult.isGranted || fallbackResult.isLimited) return true;

      if (fallbackResult.isPermanentlyDenied && context.mounted) {
        await _showPermissionDialog(context, permissionLabel);
      }
      return false;
    }

    if (primaryResult.isPermanentlyDenied && context.mounted) {
      await _showPermissionDialog(context, permissionLabel);
    }
    return false;
  }

  static Future<bool> ensureLocationPermission(
    BuildContext context, {
    String permissionLabel = 'Location',
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        await _showPermissionDialog(context, permissionLabel, message: 'Location services are disabled. Please enable GPS in device settings to continue.');
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      return true;
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        await _showPermissionDialog(context, permissionLabel, message: 'Location access is permanently denied. Please enable it in app settings.');
      }
      return false;
    }

    final result = await Geolocator.requestPermission();
    if (result == LocationPermission.always || result == LocationPermission.whileInUse) {
      return true;
    }

    if (result == LocationPermission.deniedForever && context.mounted) {
      await _showPermissionDialog(context, permissionLabel, message: 'Location access is permanently denied. Please enable it in app settings.');
    }
    return false;
  }

  static Future<void> _showPermissionDialog(
    BuildContext context,
    String permissionLabel, {
    String? message,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$permissionLabel Permission Required'),
        content: Text(
          message ??
              'This app needs $permissionLabel permission to continue. Please enable it in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
