import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/sri_lanka_data.dart';
import '../models/sri_lanka_province.dart';
import '../providers/location_provider.dart';

/// Reusable province dropdown widget.
///
/// Reads + writes [locationProvider] automatically.
/// Can also be used standalone by providing [value] and [onChanged].
class ProvinceDropdown extends ConsumerWidget {
  /// If null, the widget reads from [locationProvider].
  final SriLankaProvince? value;

  /// If null, changes are written to [locationProvider] automatically.
  final ValueChanged<SriLankaProvince?>? onChanged;

  final String hint;
  final bool enabled;
  final String? labelText;
  final bool showLabel;

  const ProvinceDropdown({
    super.key,
    this.value,
    this.onChanged,
    this.hint = 'Select province',
    this.enabled = true,
    this.labelText,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final effectiveValue =
        value ?? ref.watch(locationProvider).selectedProvince;

    void handleChange(SriLankaProvince? province) {
      if (onChanged != null) {
        onChanged!(province);
      } else {
        ref.read(locationProvider.notifier).setProvince(province);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel) ...[
          Text(
            labelText ?? 'Province',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surfaceContainerHighest
                : colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? colorScheme.outlineVariant
                  : colorScheme.outline.withOpacity(0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.15 : 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<SriLankaProvince>(
              value: effectiveValue,
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  hint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: enabled
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurface.withOpacity(0.38),
              ),
              dropdownColor: isDark
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.surface,
              onChanged: enabled ? handleChange : null,
              items: SriLankaData.provinces.map((province) {
                return DropdownMenuItem<SriLankaProvince>(
                  value: province,
                  child: Text(
                    province.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                );
              }).toList(),
              selectedItemBuilder: (context) {
                return SriLankaData.provinces.map((province) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      province.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ],
    );
  }
}

