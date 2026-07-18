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
        title: Text('Item Details', style: AppTextStyles.h2(primaryText)),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryText),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image gallery (compact, padded) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _ImageGallery(imageUrls: item.imageUrls, borderColor: borderColor),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Category chip ──
                  if (item.category != null && item.category!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.customerColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.customerColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.category_rounded, size: 13, color: AppColors.customerColor),
                          const SizedBox(width: 6),
                          Text(item.category!, style: AppTextStyles.caption(AppColors.customerColor).copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),

                  // ── Item name ──
                  Text(item.itemName, style: AppTextStyles.h2(primaryText)),
                  const SizedBox(height: 20),

                  // ── Details card ──
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        _DetailRow(
                          icon: Icons.production_quantity_limits_rounded,
                          label: 'Quantity',
                          value: '${item.quantity}${item.unit != null && item.unit!.isNotEmpty ? ' ${item.unit}' : ''}',
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          borderColor: borderColor,
                          isFirst: true,
                        ),
                        if (item.preferredBrand != null && item.preferredBrand!.isNotEmpty)
                          _DetailRow(
                            icon: Icons.label_rounded,
                            label: 'Preferred Brand / Model',
                            value: item.preferredBrand!,
                            primaryText: primaryText,
                            secondaryText: secondaryText,
                            borderColor: borderColor,
                          ),
                        if (item.description != null && item.description!.isNotEmpty)
                          _DetailRow(
                            icon: Icons.notes_rounded,
                            label: 'Description / Remarks',
                            value: item.description!,
                            primaryText: primaryText,
                            secondaryText: secondaryText,
                            borderColor: borderColor,
                          ),
                        _DetailRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Requested On',
                          value: _formatDateTime(requestCreatedAt),
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          borderColor: borderColor,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),

                  // ── Request notes ──
                  if (requestNotes != null && requestNotes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.sticky_note_2_outlined, size: 16, color: AppColors.info),
                            const SizedBox(width: 8),
                            Text('Request Notes', style: AppTextStyles.caption(AppColors.info).copyWith(fontWeight: FontWeight.w600)),
                          ]),
                          const SizedBox(height: 8),
                          Text(requestNotes!, style: AppTextStyles.bodyMedium(primaryText)),
                        ],
                      ),
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

  static String _formatDateTime(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  ·  $h:$min $ampm';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.primaryText,
    required this.secondaryText,
    required this.borderColor,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color primaryText;
  final Color secondaryText;
  final Color borderColor;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!isFirst) Divider(height: 1, color: borderColor),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: AppColors.customerColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: AppColors.customerColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.caption(secondaryText)),
                    const SizedBox(height: 4),
                    Text(value, style: AppTextStyles.bodyMedium(primaryText)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Image gallery ─────────────────────────────────────────────────────────────

class _ImageGallery extends StatefulWidget {
  const _ImageGallery({required this.imageUrls, required this.borderColor});
  final List<String> imageUrls;
  final Color borderColor;

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  int _index = 0;

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FullScreenImageViewer(
        imageUrls: widget.imageUrls,
        initialIndex: _index,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return Container(
        width: double.infinity,
        height: 280,
        color: Colors.grey.shade100,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.image_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text('No reference images', style: AppTextStyles.bodySmall(Colors.grey.shade500)),
        ]),
      );
    }

    return Stack(
      children: [
        // Main image — fixed height preview, tappable to expand
        GestureDetector(
          onTap: () => _openFullScreen(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: double.infinity,
              height: 220,
              child: SafeRequestImage(
                path: widget.imageUrls[_index],
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),

        // Tap-to-expand hint
        Positioned(
          top: 12, right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fullscreen_rounded, size: 16, color: Colors.white),
                SizedBox(width: 4),
                Text('Tap to expand', style: TextStyle(fontSize: 11, color: Colors.white)),
              ],
            ),
          ),
        ),

        // Thumbnail strip at bottom (if multiple images)
        if (widget.imageUrls.length > 1)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              color: Colors.black45,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(widget.imageUrls.length, (i) {
                          final selected = i == _index;
                          return GestureDetector(
                            onTap: () => setState(() => _index = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 48, height: 48,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: selected ? AppColors.customerColor : Colors.white38,
                                  width: selected ? 2.5 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SafeRequestImage(
                                  path: widget.imageUrls[i],
                                  width: 48, height: 48,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_index + 1}/${widget.imageUrls.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Full-screen image viewer ──────────────────────────────────────────────────

class _FullScreenImageViewer extends StatefulWidget {
  const _FullScreenImageViewer({required this.imageUrls, required this.initialIndex});
  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_current + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.imageUrls.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: SafeRequestImage(
              path: widget.imageUrls[i],
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

