import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manages theme transition animation state
class ThemeAnimationNotifier extends StateNotifier<bool> {
  ThemeAnimationNotifier() : super(false);

  void show() => state = true;
  
  void hide() => state = false;
}

final themeAnimationProvider = StateNotifierProvider<ThemeAnimationNotifier, bool>(
  (ref) => ThemeAnimationNotifier(),
);
