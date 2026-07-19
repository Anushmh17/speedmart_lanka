import 'package:flutter/material.dart';

/// Wraps admin screen content with a max-width constraint and centered layout.
/// Use this inside every admin screen's scrollable/list area.
class AdminWebContent extends StatelessWidget {
  const AdminWebContent({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.maxWidth = 1100,
  });

  final Widget child;
  final EdgeInsets padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
