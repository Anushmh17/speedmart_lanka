import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sri_lanka_district.dart';
import '../models/sri_lanka_province.dart';
import '../providers/location_provider.dart';

/// Reusable district dropdown widget.
///
/// Filters districts based on the currently selected province.
/// Disabled automatically when no province is selected.
///
/// Can be used standalone by providing [selectedProvince], [value],
/// and [onChanged], or fully auto-managed via [locationProvider].
class DistrictDropdown extends ConsumerWidget {
  /// Override province (if not using locationProvider).
  final SriLankaProvince? selectedProvince;

  /// Override value (if not using locationProvider).
  final SriLankaDistrict? value;

  /// Override change handler (if not using locationProvider).
  final ValueChanged<SriLankaDistrict?>? onChanged;

  final String hint;
  final String? labelText;
  final bool showLabel;

  const DistrictDropdown({
    super.key,
    this.selectedProvince,
    this.value,
    this.onChanged,
    this.hint = 'Select district',
    this.labelText,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final locationState = ref.watch(locationProvider);
    final effectiveProvince = selectedProvince ?? locationState.selectedProvince;
    final effectiveValue = value ?? locationState.selectedDistrict;

    // Districts available for the selected province
    final availableDistricts = effectiveProvince?.districts ?? const [];

    // District is invalid if province changed and it no longer belongs
    final validValue = availableDistricts.contains(effectiveValue)
        ? effectiveValue
        : null;

    final isEnabled = effectiveProvince != null && availableDistricts.isNotEmpty;

    void handleChange(SriLankaDistrict? district) {
      if (onChanged != null) {
        onChanged!(district);
      } else {
        ref.read(locationProvider.notifier).setDistrict(district);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel) ...[
          Text(
            labelText ?? 'District',
            style: theme.textTheme.labelMedium?.copyWith(
              color: isEnabled
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSurface.withOpacity(0.38),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
        ],
        AnimatedOpacity(
          opacity: isEnabled ? 1.0 : 0.5,
          duration: const Duration(milliseconds: 200),
          child: Container(
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
              child: DropdownButton<SriLankaDistrict>(
                value: validValue,
                hint: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    isEnabled ? hint : 'Select province first',
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
                  color: isEnabled
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurface.withOpacity(0.38),
                ),
                dropdownColor: isDark
                    ? colorScheme.surfaceContainerHigh
                    : colorScheme.surface,
                onChanged: isEnabled ? handleChange : null,
                items: availableDistricts.map((district) {
                  return DropdownMenuItem<SriLankaDistrict>(
                    value: district,
                    child: Text(
                      district.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  );
                }).toList(),
                selectedItemBuilder: (context) {
                  return availableDistricts.map((district) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        district.name,
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
        ),
      ],
    );
  }
}

