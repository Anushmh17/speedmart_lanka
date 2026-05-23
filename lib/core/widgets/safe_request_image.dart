import 'dart:io';

import 'package:flutter/material.dart';

/// Renders a request item image from a network URL or local file path without crashing.
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
      if (RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed) || trimmed.startsWith('/')) {
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
      child: Icon(Icons.image_outlined, size: w * 0.45, color: Colors.grey.shade500),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = width;
    final h = height;
    final trimmed = path.trim();

    Widget child;
    if (trimmed.isEmpty) {
      child = placeholder(width: w, height: h);
    } else if (isNetworkUrl(trimmed)) {
      child = Image.network(
        trimmed,
        width: w,
        height: h,
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder(width: w, height: h),
      );
    } else {
      final file = fileFromPath(trimmed);
      if (file != null) {
        child = Image.file(
          file,
          width: w,
          height: h,
          fit: fit,
          errorBuilder: (_, __, ___) => placeholder(width: w, height: h),
        );
      } else {
        child = placeholder(width: w, height: h);
      }
    }

    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }
}