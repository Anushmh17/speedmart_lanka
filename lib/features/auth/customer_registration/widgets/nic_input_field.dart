import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Sri Lanka NIC input field.
///
/// Supports both NIC formats:
/// - Old format: 9 digits followed by V or X  (e.g. 123456789V)
/// - New format: 12 digits                    (e.g. 200012345678)
///
/// Auto-detects format as the user types and shows a format hint.
class NicInputField extends StatefulWidget {
  const NicInputField({
    super.key,
    required this.controller,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
    this.focusNode,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;
  final FocusNode? focusNode;

  @override
  State<NicInputField> createState() => _NicInputFieldState();
}

class _NicInputFieldState extends State<NicInputField> {
  _NicFormat _detectedFormat = _NicFormat.unknown;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    final newFormat = _detectFormat(widget.controller.text);
    if (newFormat != _detectedFormat) {
      setState(() => _detectedFormat = newFormat);
    }
  }

  _NicFormat _detectFormat(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return _NicFormat.unknown;
    if (RegExp(r'^\d{1,9}[VvXx]?$').hasMatch(clean)) return _NicFormat.old;
    if (RegExp(r'^\d{10,12}$').hasMatch(clean)) return _NicFormat.newFormat;
    return _NicFormat.unknown;
  }

  String? _validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'NIC number is required';
    }
    final clean = value.trim().toUpperCase();
    // Old NIC: exactly 9 digits + V or X
    if (RegExp(r'^\d{9}[VX]$').hasMatch(clean)) return null;
    // New NIC: exactly 12 digits
    if (RegExp(r'^\d{12}$').hasMatch(clean)) return null;
    return 'Enter a valid NIC (e.g. 123456789V or 200012345678)';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          textInputAction: widget.textInputAction,
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.characters,
          maxLength: 12,
          validator: _validate,
          onChanged: widget.onChanged,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\dVvXx]')),
            _NicInputFormatter(),
          ],
          style: AppTextStyles.bodyLarge(
            isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
          decoration: InputDecoration(
            labelText: 'NIC Number',
            hintText: '123456789V  or  200012345678',
            counterText: '',
            prefixIcon: Icon(
              Icons.credit_card_rounded,
              size: 20,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            suffixIcon: _detectedFormat != _NicFormat.unknown
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Chip(
                      label: Text(
                        _detectedFormat == _NicFormat.old ? 'Old' : 'New',
                        style: AppTextStyles.caption(AppColors.primary)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: AppColors.primaryContainer,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      side: BorderSide.none,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              key: ValueKey(_detectedFormat),
              _formatHint(_detectedFormat),
              style: AppTextStyles.caption(
                isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatHint(_NicFormat fmt) {
    switch (fmt) {
      case _NicFormat.old:
        return 'Old NIC — 9 digits + V or X (e.g. 123456789V)';
      case _NicFormat.newFormat:
        return 'New NIC — 12 digits (e.g. 200012345678)';
      case _NicFormat.unknown:
        return 'Old: 123456789V  ·  New: 200012345678';
    }
  }
}

enum _NicFormat { unknown, old, newFormat }

/// Formatter: auto-uppercases V/X suffix for old NIC format.
class _NicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.toUpperCase();
    return newValue.copyWith(
      text: text,
      selection: newValue.selection,
    );
  }
}

