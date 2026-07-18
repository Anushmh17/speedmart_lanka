import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';

// ── NetworkFallbackImage ──────────────────────────────────────────────────────

/// Renders a network image with:
/// - Shimmer placeholder while loading
/// - Automatic retry (up to [maxRetries] times) on failure
/// - Offline-aware error state: shows a "No connection" icon when offline,
///   a "Tap to retry" icon when online but load failed
class NetworkFallbackImage extends ConsumerStatefulWidget {
  const NetworkFallbackImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.maxRetries = 2,
    this.fallbackWidget,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final int maxRetries;
  final Widget? fallbackWidget;

  @override
  ConsumerState<NetworkFallbackImage> createState() =>
      _NetworkFallbackImageState();
}

class _NetworkFallbackImageState extends ConsumerState<NetworkFallbackImage> {
  int _attempt = 0;
  late Key _imageKey;

  @override
  void initState() {
    super.initState();
    _imageKey = ValueKey('${widget.url}_$_attempt');
  }

  void _retry() {
    if (_attempt >= widget.maxRetries) return;
    setState(() {
      _attempt++;
      _imageKey = ValueKey('${widget.url}_$_attempt');
    });
  }

  Widget _shimmer() {
    final w = widget.width ?? double.infinity;
    final h = widget.height ?? double.infinity;
    return _ShimmerBox(width: w, height: h);
  }

  Widget _errorWidget(bool isOnline) {
    if (widget.fallbackWidget != null) return widget.fallbackWidget!;
    final w = widget.width ?? 48;
    final h = widget.height ?? 48;
    final canRetry = isOnline && _attempt < widget.maxRetries;
    return GestureDetector(
      onTap: canRetry ? _retry : null,
      child: Container(
        width: w,
        height: h,
        color: Colors.grey.shade200,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOnline ? Icons.refresh_rounded : Icons.wifi_off_rounded,
              color: Colors.grey.shade500,
              size: (w < 48 ? w : 48) * 0.45,
            ),
            if (w >= 60 && h >= 60) ...[
              const SizedBox(height: 4),
              Text(
                isOnline ? 'Tap to retry' : 'No connection',
                style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);

    Widget image = Image.network(
      widget.url,
      key: _imageKey,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return _shimmer();
      },
      errorBuilder: (_, __, ___) {
        if (isOnline && _attempt < widget.maxRetries) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _retry();
          });
          return _shimmer();
        }
        return _errorWidget(isOnline);
      },
    );

    if (widget.borderRadius != null) {
      image = ClipRRect(borderRadius: widget.borderRadius!, child: image);
    }
    return image;
  }
}

// ── Shimmer placeholder ───────────────────────────────────────────────────────

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({required this.width, required this.height});
  final double width;
  final double height;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey.withValues(alpha: _anim.value),
      ),
    );
  }
}

// ── SafeRequestImage ──────────────────────────────────────────────────────────

/// Renders a request item image from a network URL or local file path.
/// Network images use [NetworkFallbackImage] for retry and offline handling.
class SafeRequestImage extends StatelessWidget {
  const SafeRequestImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  static bool isNetworkUrl(String raw) {
    final lower = raw.trim().toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  static File? fileFromPath(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    try {
      if (trimmed.startsWith('file://')) {
        return File(Uri.parse(trimmed).toFilePath());
      }
      if (trimmed.startsWith('/data/') ||
          trimmed.startsWith('/storage/') ||
          trimmed.startsWith('/var/')) {
        return File(trimmed);
      }
      if (RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed) ||
          trimmed.startsWith('/')) {
        final file = File(trimmed);
        if (file.existsSync()) return file;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static Widget placeholder({double? width, double? height}) {
    final w = width ?? 36;
    final h = height ?? 36;
    return Container(
      width: w,
      height: h,
      alignment: Alignment.center,
      color: Colors.grey.shade200,
      child: Icon(
        Icons.image_outlined,
        size: w * 0.45,
        color: Colors.grey.shade500,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = path.trim();

    if (trimmed.isEmpty) {
      return placeholder(width: width, height: height);
    }

    if (isNetworkUrl(trimmed)) {
      return NetworkFallbackImage(
        url: trimmed,
        width: width,
        height: height,
        fit: fit,
        borderRadius: borderRadius,
        fallbackWidget: placeholder(width: width, height: height),
      );
    }

    final file = fileFromPath(trimmed);
    Widget child;
    if (file != null) {
      child = Image.file(
        file,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder(width: width, height: height),
      );
    } else {
      child = placeholder(width: width, height: height);
    }

    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }
}

