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
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;

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
      style: AppTextStyles.bodyLarge(
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
      decoration: InputDecoration(
        labelText: 'Phone Number',
        hintText: '72 499 9660',
        counterText: '',
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '+94',
                  style: AppTextStyles.labelMedium(AppColors.primary)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 1,
                height: 20,
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ],
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: Icon(Icons.phone_rounded, size: 18, color: secondaryColor),
      ),
    );
  }
}
