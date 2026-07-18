import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

enum RequestType { single, multiple }

class RequestTypeToggle extends StatelessWidget {
  final RequestType? selectedType;
  final ValueChanged<RequestType> onChanged;

  const RequestTypeToggle({
    super.key,
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'What would you like to create?',
            style: AppTextStyles.subtitle(
              isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        _RequestTypeCard(
          icon: Icons.shopping_bag_rounded,
          title: 'Single Item',
          description: 'Request one specific product',
          isSelected: selectedType == RequestType.single,
          isDark: isDark,
          accentColor: AppColors.customerColor,
          onTap: () => onChanged(RequestType.single),
        ),
        const SizedBox(height: 14),
        _RequestTypeCard(
          icon: Icons.format_list_bulleted_rounded,
          title: 'Shopping List',
          description: 'Request multiple products',
          isSelected: selectedType == RequestType.multiple,
          isDark: isDark,
          accentColor: AppColors.vendorColor,
          onTap: () => onChanged(RequestType.multiple),
        ),
      ],
    );
  }
}

class _RequestTypeCard extends StatefulWidget {
  const _RequestTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.isDark,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isSelected;
  final bool isDark;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  State<_RequestTypeCard> createState() => _RequestTypeCardState();
}

class _RequestTypeCardState extends State<_RequestTypeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final primaryText = widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardBg = widget.isDark ? AppColors.cardDark : Colors.white;
    final borderColor = widget.isDark ? AppColors.borderDark : AppColors.borderLight;

    final selectedBg = widget.accentColor.withOpacity(widget.isDark ? 0.12 : 0.06);
    final selectedBorder = widget.accentColor;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: widget.isSelected ? selectedBg : cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected ? selectedBorder : borderColor,
              width: widget.isSelected ? 2 : 1,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: widget.accentColor.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(widget.isDark ? 0.15 : 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Icon container
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? widget.accentColor
                      : (widget.isDark ? Colors.white10 : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: widget.isSelected
                      ? [
                          BoxShadow(
                            color: widget.accentColor.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  widget.icon,
                  size: 24,
                  color: widget.isSelected
                      ? Colors.white
                      : (widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                ),
              ),
              const SizedBox(width: 14),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppTextStyles.bodyMedium(primaryText).copyWith(
                        fontWeight: FontWeight.w700,
                        color: widget.isSelected ? widget.accentColor : primaryText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.description,
                      style: AppTextStyles.caption(secondaryText),
                    ),
                  ],
                ),
              ),

              // Selection indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isSelected ? widget.accentColor : Colors.transparent,
                  border: Border.all(
                    color: widget.isSelected
                        ? widget.accentColor
                        : (widget.isDark ? AppColors.borderDark : AppColors.borderLight),
                    width: 2,
                  ),
                ),
                child: widget.isSelected
                    ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

