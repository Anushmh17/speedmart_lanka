import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BottomNavVisibilityNotifier extends AutoDisposeNotifier<bool> {
  bool _manualHidden = false;
  String? _lastLocation;

  void setManualHidden(bool hidden) {
    if (_manualHidden != hidden) {
      _manualHidden = hidden;
      ref.notifyListeners();
    }
  }

  void updateLocation(String location) {
    debugPrint('[BottomNav] route=$location');
    
    // Reset manual override automatically when route location changes
    if (_lastLocation != location) {
      _lastLocation = location;
      _manualHidden = false;
      debugPrint('[BottomNav] route changed, reset manual hidden');
    }

    // CRITICAL FIX: Parse the location to get the actual path
    final uri = Uri.tryParse(location);
    final cleanPath = uri?.path ?? location;

    // Only show bottom navigation on MAIN dashboard tabs
    final mainDashboardRoutes = {
      '/customer',
      '/customer/requests',
      '/customer/orders',
      '/customer/profile',
      '/vendor',
      '/admin',
    };

    final routeVisible = mainDashboardRoutes.contains(cleanPath);
    final newState = routeVisible && !_manualHidden;
    
    debugPrint('[BottomNav] cleanPath=$cleanPath, visible=$newState (routeVisible=$routeVisible, manualHidden=$_manualHidden)');

    if (state != newState) {
      state = newState;
    }
  }

  @override
  bool build() {
    // Initial state
    return false;
  }
}

final bottomNavVisibilityProvider = AutoDisposeNotifierProvider<BottomNavVisibilityNotifier, bool>(
  BottomNavVisibilityNotifier.new,
);

/// A premium animated wrapper for bottom navigation bars that slides and fades them
/// out of view and collapses the layout space cleanly when not visible.
class AnimatedBottomNavWrapper extends StatefulWidget {
  final Widget child;
  final bool visible;

  const AnimatedBottomNavWrapper({
    super.key,
    required this.child,
    required this.visible,
  });

  @override
  State<AnimatedBottomNavWrapper> createState() => _AnimatedBottomNavWrapperState();
}

class _AnimatedBottomNavWrapperState extends State<AnimatedBottomNavWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _heightAnimation;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );
    _heightAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    if (widget.visible) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedBottomNavWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.isDismissed) {
          return const SizedBox.shrink();
        }
        return Opacity(
          opacity: _opacityAnimation.value,
          child: FractionalTranslation(
            translation: Offset(0.0, _slideAnimation.value),
            child: SizeTransition(
              sizeFactor: _heightAnimation,
              axisAlignment: -1.0,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

