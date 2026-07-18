import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/sri_lanka_phone_formatter.dart';
import '../../../../core/utils/sri_lanka_phone_helper.dart';

/// Sri Lanka phone number input with a fixed +94 prefix chip.
///
/// Accepts input in either format:
/// - `07XXXXXXXX`  (10 digits with leading 0, auto-removed)
/// - `7XXXXXXXXX`  (9 digits, preferred)
///
/// The raw value is normalised to `+94XXXXXXXXX` via [normalise].
class PhoneFieldLk extends StatefulWidget {
  const PhoneFieldLk({
    super.key,
    required this.controller,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
    this.focusNode,
    this.onFieldSubmitted,
    this.labelText = 'Phone Number',
    this.hintText = '72 499 9660',
    this.floatingLabelBehavior = FloatingLabelBehavior.auto,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;
  final String? labelText;
  final String? hintText;
  final FloatingLabelBehavior floatingLabelBehavior;

  /// Normalises the raw input to international format `+94XXXXXXXXX`.
  /// Returns null if the value is empty or already normalised.
  static String? normalise(String raw) {
    if (raw.isEmpty) return null;
    return SriLankaPhoneHelper.normalizeSriLankaPhoneForStorage(raw);
  }

  @override
  State<PhoneFieldLk> createState() => _PhoneFieldLkState();
}

class _PhoneFieldLkState extends State<PhoneFieldLk> {
  String? _validate(String? value) {
    return SriLankaPhoneHelper.validateSriLankaMobile(value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final cardBg = isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight;

    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      textInputAction: widget.textInputAction,
      keyboardType: TextInputType.phone,
      validator: _validate,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        SriLankaPhoneInputFormatter(),
      ],
      style: AppTextStyles.bodyLarge(primaryText).copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
      ),
      decoration: InputDecoration(
        labelText: widget.labelText,
        floatingLabelBehavior: widget.floatingLabelBehavior,
        labelStyle: AppTextStyles.bodyMedium(secondaryColor).copyWith(
          fontWeight: FontWeight.w500,
        ),
        hintText: widget.hintText,
        hintStyle: AppTextStyles.bodyLarge(secondaryColor.withOpacity(0.5)).copyWith(
          fontWeight: FontWeight.w400,
          letterSpacing: 1.0,
        ),
        counterText: '',
        fillColor: cardBg,
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 12, right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x15FFB84D) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0x30FFB84D) : const Color(0xFFFDBA74),
                    width: 1,
                  ),
                ),
                child: Text(
                  '+94',
                  style: AppTextStyles.labelMedium(
                    isDark ? AppColors.customerColorDark : AppColors.customerColor,
                  ).copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 22,
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ],
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: Icon(
          Icons.phone_outlined,
          size: 20,
          color: isDark ? AppColors.customerColorDark : AppColors.customerColor,
        ),
      ),
    );
  }
}

