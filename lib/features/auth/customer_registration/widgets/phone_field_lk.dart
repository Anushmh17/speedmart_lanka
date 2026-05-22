import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Sri Lanka phone number input with a fixed +94 prefix chip.
///
/// Accepts input in either format:
/// - `07XXXXXXXX`  (10 digits, user types with leading 0)
/// - `7XXXXXXXXX`  (9 digits, user omits leading 0)
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
    final clean = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (clean.isEmpty) return null;
    // Strip leading 0 or +94 or 94 to get the 9-digit local number
    String local = clean;
    if (local.startsWith('+94')) {
      local = local.substring(3);
    } else if (local.startsWith('94') && local.length == 11) {
      local = local.substring(2);
    } else if (local.startsWith('0')) {
      local = local.substring(1);
    }
    if (local.length != 9) return null;
    return '+94$local';
  }

  @override
  State<PhoneFieldLk> createState() => _PhoneFieldLkState();
}

class _PhoneFieldLkState extends State<PhoneFieldLk> {
  String? _validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final clean = value.replaceAll(RegExp(r'[\s\-()]'), '');
    // Accept: 07XXXXXXXX (10) or 7XXXXXXXXX (9)
    if (!RegExp(r'^0?[1-9]\d{8}$').hasMatch(clean)) {
      return 'Enter a valid Sri Lanka number (e.g. 0771234567)';
    }
    return null;
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
      maxLength: 10,
      validator: _validate,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      style: AppTextStyles.bodyLarge(
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
      decoration: InputDecoration(
        labelText: 'Phone Number',
        hintText: '077 123 4567',
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
