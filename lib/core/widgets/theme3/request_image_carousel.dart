import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../theme/app_radius.dart';
import '../safe_request_image.dart';

/// A small auto-cycling image carousel for request/order thumbnails.
///
/// - Shows the first image immediately.
/// - Cycles through [images] every 2 s when there are multiple images.
/// - Falls back to [fallback] when the list is empty or an image fails to load.
/// - Dots indicator is shown only when there are 2+ images.
class RequestImageCarousel extends StatefulWidget {
  const RequestImageCarousel({
    super.key,
    required this.images,
    required this.fallback,
    required this.size,
  });

  final List<String> images;
  final Widget fallback;
  final double size;

  @override
  State<RequestImageCarousel> createState() => _RequestImageCarouselState();
}

class _RequestImageCarouselState extends State<RequestImageCarousel> {
  int _current = 0;
  Timer? _timer;

  List<String> get _valid =>
      widget.images.where((p) => p.trim().isNotEmpty).toList();

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(RequestImageCarousel old) {
    super.didUpdateWidget(old);
    if (old.images != widget.images) {
      _current = 0;
      _timer?.cancel();
      _startTimer();
    }
  }

  void _startTimer() {
    if (_valid.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() => _current = (_current + 1) % _valid.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = _valid;
    if (images.isEmpty) return widget.fallback;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _buildImage(images[_current], key: ValueKey(_current)),
            ),
          ),
          // Dots (only when multiple images)
          if (images.length > 1)
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    width: i == _current ? 6 : 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white
                          .withValues(alpha: i == _current ? 0.95 : 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage(String path, {required Key key}) {
    final s = widget.size;
    final fallback = SizedBox(width: s, height: s, child: widget.fallback);

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkFallbackImage(
        key: key,
        url: path,
        width: s,
        height: s,
        fit: BoxFit.cover,
        fallbackWidget: fallback,
      );
    }

    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        key: key,
        width: s,
        height: s,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    return Image.file(
      File(path),
      key: key,
      width: s,
      height: s,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

