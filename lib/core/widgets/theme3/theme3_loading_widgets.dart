import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Full screen loading indicator
class Theme3FullScreenLoading extends StatelessWidget {
  final String? message;

  const Theme3FullScreenLoading({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              isDark ? AppColors.primaryDark : AppColors.primary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              message!,
              style: AppTextStyles.bodyMedium(
                isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Inline loading indicator
class Theme3InlineLoading extends StatelessWidget {
  final String? message;
  final double size;

  const Theme3InlineLoading({
    super.key,
    this.message,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              isDark ? AppColors.primaryDark : AppColors.primary,
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(width: AppSpacing.md),
          Text(
            message!,
            style: AppTextStyles.bodySmall(
              isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ],
    );
  }
}

/// Skeleton card placeholder
class Theme3SkeletonCard extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const Theme3SkeletonCard({
    super.key,
    this.width,
    this.height = 100,
    this.borderRadius,
  });

  @override
  State<Theme3SkeletonCard> createState() => _Theme3SkeletonCardState();
}

class _Theme3SkeletonCardState extends State<Theme3SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: (isDark ? AppColors.shimmerBaseDark : AppColors.shimmerBase)
                .withValues(alpha: _animation.value),
            borderRadius: widget.borderRadius ?? AppRadius.lgRadius,
          ),
        );
      },
    );
  }
}

/// Skeleton text placeholder
class Theme3SkeletonText extends StatelessWidget {
  final double width;
  final double height;

  const Theme3SkeletonText({
    super.key,
    required this.width,
    this.height = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Theme3SkeletonCard(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(4),
    );
  }
}

/// Skeleton list item
class Theme3SkeletonListItem extends StatelessWidget {
  const Theme3SkeletonListItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          const Theme3SkeletonCard(
            width: 60,
            height: 60,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Theme3SkeletonText(width: MediaQuery.of(context).size.width * 0.5),
                const SizedBox(height: AppSpacing.sm),
                Theme3SkeletonText(width: MediaQuery.of(context).size.width * 0.3),
                const SizedBox(height: AppSpacing.sm),
                Theme3SkeletonText(width: MediaQuery.of(context).size.width * 0.4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

