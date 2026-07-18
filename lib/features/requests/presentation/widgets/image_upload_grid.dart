import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/safe_request_image.dart';

class ImageUploadGrid extends StatelessWidget {
  final String? category;
  final List<String> imageUrls;
  final ValueChanged<List<String>> onImagesChanged;

  const ImageUploadGrid({
    super.key,
    required this.category,
    required this.imageUrls,
    required this.onImagesChanged,
  });

  void _showImageSourceActionSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select Image Source',
                  style: AppTextStyles.subtitle(primaryText),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: AppColors.customerColor),
                  title: Text('Take Photo', style: AppTextStyles.bodyLarge(primaryText)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(context, ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: AppColors.customerColor),
                  title: Text('Choose from Gallery', style: AppTextStyles.bodyLarge(primaryText)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(context, ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cancel_outlined, color: AppColors.error),
                  title: Text('Cancel', style: AppTextStyles.bodyLarge(AppColors.error)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPermanentlyDeniedDialog(BuildContext context, String permissionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('$permissionName Permission Required'),
        content: Text(
          'This app needs $permissionName permission to select/capture reference images. '
          'Please enable it in the app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.customerColor),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<bool> _requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      if (context.mounted) _showPermanentlyDeniedDialog(context, 'Camera');
      return false;
    }

    final result = await Permission.camera.request();
    if (result.isGranted) return true;

    if (result.isPermanentlyDenied) {
      if (context.mounted) _showPermanentlyDeniedDialog(context, 'Camera');
    }
    return false;
  }

  Future<bool> _requestGalleryPermission(BuildContext context) async {
    // 1. Try Permission.photos (Android 13+ / iOS)
    final photosStatus = await Permission.photos.status;
    if (photosStatus.isGranted) return true;

    final photosResult = await Permission.photos.request();
    if (photosResult.isGranted) return true;

    // 2. Fallback to Permission.storage (Android < 13)
    final storageStatus = await Permission.storage.status;
    if (storageStatus.isGranted) return true;

    if (storageStatus.isPermanentlyDenied) {
      if (context.mounted) _showPermanentlyDeniedDialog(context, 'Gallery');
      return false;
    }

    final storageResult = await Permission.storage.request();
    if (storageResult.isGranted) return true;

    if (storageResult.isPermanentlyDenied) {
      if (context.mounted) _showPermanentlyDeniedDialog(context, 'Gallery');
    }
    return false;
  }

  void _showPermissionDeniedSnackBar(BuildContext context, String permissionName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Text('$permissionName permission is required to select images.', style: AppTextStyles.bodyMedium(Colors.white)),
          ],
        ),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    bool hasPermission = false;
    if (source == ImageSource.camera) {
      hasPermission = await _requestCameraPermission(context);
      if (!hasPermission) {
        _showPermissionDeniedSnackBar(context, 'Camera');
        return;
      }
    } else {
      hasPermission = await _requestGalleryPermission(context);
      if (!hasPermission) {
        _showPermissionDeniedSnackBar(context, 'Gallery');
        return;
      }
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      final newList = List<String>.from(imageUrls)..add(image.path);
      onImagesChanged(newList);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.success),
                const SizedBox(width: 8),
                Text('Image attached successfully.', style: AppTextStyles.bodyMedium(Colors.white)),
              ],
            ),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    final newList = List<String>.from(imageUrls)..removeAt(index);
    onImagesChanged(newList);
  }

  void _showPreviewDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SafeRequestImage(
                path: url,
                height: 250,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Item Reference Image Preview',
              style: AppTextStyles.subtitle(Colors.white),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Reference Images (Optional)',
              style: AppTextStyles.labelMedium(isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(width: 4),
            Text(
              '(${imageUrls.length} added)',
              style: AppTextStyles.caption(secondaryText),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Add reference images to help vendors identify the exact product.',
          style: AppTextStyles.caption(secondaryText),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: imageUrls.length + 1,
            itemBuilder: (context, index) {
              if (index == imageUrls.length) {
                // "+" Add Image Button
                return GestureDetector(
                  onTap: () => _showImageSourceActionSheet(context),
                  child: Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, style: BorderStyle.solid),
                    ),
                    child: const Icon(
                      Icons.add_a_photo_outlined,
                      color: AppColors.customerColor,
                      size: 26,
                    ),
                  ),
                );
              }

              final url = imageUrls[index];
              return Stack(
                children: [
                  GestureDetector(
                    onTap: () => _showPreviewDialog(context, url),
                    child: Container(
                      width: 80,
                      height: 80,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: SafeRequestImage(
                        path: url,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 10,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

