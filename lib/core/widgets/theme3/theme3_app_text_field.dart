import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_radius.dart';

enum Theme3TextFieldType { normal, password, search }

class Theme3AppTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final Theme3TextFieldType type;
  final bool readOnly;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconTap;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final TextInputType? keyboardType;

  const Theme3AppTextField({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.controller,
    this.type = Theme3TextFieldType.normal,
    this.readOnly = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.onChanged,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  State<Theme3AppTextField> createState() => _Theme3AppTextFieldState();
}

class _Theme3AppTextFieldState extends State<Theme3AppTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPassword = widget.type == Theme3TextFieldType.password;
    final isSearch = widget.type == Theme3TextFieldType.search;

    Color getFillColor() {
      if (widget.readOnly) {
        return isDark ? AppColors.borderDark : AppColors.backgroundLight;
      }
      return isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight;
    }

    Color getBorderColor() {
      if (widget.errorText != null) {
        return AppColors.error;
      }
      return isDark ? AppColors.borderDark : AppColors.borderLight;
    }

    Widget? getPrefixIcon() {
      if (widget.prefixIcon != null) {
        return Icon(
          widget.prefixIcon,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          size: 20,
        );
      }
      if (isSearch) {
        return Icon(
          Icons.search,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          size: 20,
        );
      }
      return null;
    }

    Widget? getSuffixIcon() {
      if (isPassword) {
        return IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            size: 20,
          ),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        );
      }
      if (widget.suffixIcon != null) {
        return IconButton(
          icon: Icon(
            widget.suffixIcon,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            size: 20,
          ),
          onPressed: widget.onSuffixIconTap,
        );
      }
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTextStyles.labelMedium(
              isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: widget.controller,
          readOnly: widget.readOnly,
          obscureText: isPassword && _obscureText,
          onChanged: widget.onChanged,
          maxLines: widget.maxLines,
          keyboardType: widget.keyboardType,
          style: AppTextStyles.bodyMedium(
            isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: AppTextStyles.bodyMedium(
              isDark ? AppColors.textHintDark : AppColors.textHintLight,
            ),
            filled: true,
            fillColor: getFillColor(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            prefixIcon: getPrefixIcon(),
            suffixIcon: getSuffixIcon(),
            border: OutlineInputBorder(
              borderRadius: AppRadius.mdRadius,
              borderSide: BorderSide(color: getBorderColor()),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.mdRadius,
              borderSide: BorderSide(color: getBorderColor()),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.mdRadius,
              borderSide: BorderSide(
                color: isDark ? AppColors.primaryDark : AppColors.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppRadius.mdRadius,
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppRadius.mdRadius,
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.errorText!,
            style: AppTextStyles.bodySmall(AppColors.error),
          ),
        ],
        if (widget.helperText != null && widget.errorText == null) ...[
          const SizedBox(height: 4),
          Text(
            widget.helperText!,
            style: AppTextStyles.bodySmall(
              isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ],
    );
  }
}

