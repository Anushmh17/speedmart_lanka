import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class GlobalNotificationOverlay extends ConsumerWidget {
  const GlobalNotificationOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationProvider);
    final active = state.activeBanner;

    if (active == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : Colors.black;
    final secondaryText = isDark ? Colors.white70 : Colors.black54;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: animation.drive(
                Tween<Offset>(
                  begin: const Offset(0, -1.5),
                  end: Offset.zero,
                ).chain(CurveTween(curve: Curves.easeOutBack)),
              ),
              child: child,
            );
          },
          child: Dismissible(
            key: ValueKey(active.id),
            direction: DismissDirection.up,
            onDismissed: (_) {
              ref.read(notificationProvider.notifier).dismissActiveBanner();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active.color.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: active.color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(active.icon, color: active.color, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active.title,
                          style: AppTextStyles.bodyLarge(primaryText).copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          active.body,
                          style: AppTextStyles.bodySmall(secondaryText),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: secondaryText, size: 18),
                    onPressed: () {
                      ref.read(notificationProvider.notifier).dismissActiveBanner();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

