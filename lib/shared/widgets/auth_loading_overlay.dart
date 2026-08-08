import 'package:flutter/material.dart';

/// Full-screen semi-transparent overlay with the orange pulsing 3-dots
/// animation — same style as the splash screen loading indicator.
class AuthLoadingOverlay extends StatefulWidget {
  const AuthLoadingOverlay({super.key});

  @override
  State<AuthLoadingOverlay> createState() => _AuthLoadingOverlayState();
}

class _AuthLoadingOverlayState extends State<AuthLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = ((_ctrl.value + i * 0.33) % 1.0);
              final scale = 0.6 + 0.4 * (1.0 - (2 * t - 1).abs().clamp(0.0, 1.0));
              final opacity = 0.35 + 0.65 * scale;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF8213),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
