import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/safe_request_image.dart';
import '../../models/request_item.dart';

class RequestItemDetailsScreen extends StatelessWidget {
  const RequestItemDetailsScreen({
    super.key,
    required this.item,
    required this.requestCreatedAt,
    this.requestNotes,
  });

  final RequestItem item;
  final DateTime requestCreatedAt;
  final String? requestNotes;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Item Details'),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ImageGallery(imageUrls: item.imageUrls, borderColor: borderColor),
            const SizedBox(height: 20),
            Text(item.itemName, style: AppTextStyles.h2(primaryText)),
            const SizedBox(height: 8),
            Text(item.category ?? 'General', style: AppTextStyles.labelMedium(AppColors.customerColor)),
            const SizedBox(height: 20),
            _infoCard(cardColor, borderColor, primaryText, secondaryText),
            if (requestNotes != null && requestNotes!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Request notes', style: AppTextStyles.labelMedium(secondaryText)),
                  const SizedBox(height: 6),
                  Text(requestNotes!, style: AppTextStyles.bodyMedium(primaryText)),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoCard(Color cardColor, Color borderColor, Color primaryText, Color secondaryText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _row('Quantity', '${item.quantity}${item.unit != null && item.unit!.isNotEmpty ? ' ${item.unit}' : ''}', primaryText, secondaryText),
        if (item.preferredBrand != null && item.preferredBrand!.isNotEmpty)
          _row('Preferred brand / model', item.preferredBrand!, primaryText, secondaryText),
        if (item.description != null && item.description!.isNotEmpty)
          _row('Item description', item.description!, primaryText, secondaryText),
        _row('Requested on', _formatDateTime(requestCreatedAt), primaryText, secondaryText),
      ]),
    );
  }

  Widget _row(String label, String value, Color primaryText, Color secondaryText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTextStyles.caption(secondaryText)),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.bodyMedium(primaryText)),
      ]),
    );
  }

  static String _formatDateTime(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} - $h:$min $ampm';
  }
}

class _ImageGallery extends StatefulWidget {
  const _ImageGallery({required this.imageUrls, required this.borderColor});
  final List<String> imageUrls;
  final Color borderColor;
  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16), border: Border.all(color: widget.borderColor)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.image_outlined, size: 48, color: Colors.grey.shade500),
          const SizedBox(height: 8),
          Text('No reference images', style: AppTextStyles.bodySmall(Colors.grey.shade600)),
        ]),
      );
    }
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SafeRequestImage(path: widget.imageUrls[_index], width: double.infinity, height: 220, fit: BoxFit.cover),
      ),
      if (widget.imageUrls.length > 1) ...[
        const SizedBox(height: 12),
        Text('${_index + 1} of ${widget.imageUrls.length}', style: AppTextStyles.caption(Colors.grey.shade600)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.imageUrls.length, (i) => GestureDetector(
            onTap: () => setState(() => _index = i),
            child: Container(
              width: 8, height: 8, margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(shape: BoxShape.circle, color: i == _index ? AppColors.customerColor : Colors.grey.shade400),
            ),
          )),
        ),
      ],
    ]);
  }
}