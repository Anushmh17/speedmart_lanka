import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/location_suggestion.dart';
import '../providers/location_provider.dart';

/// Reusable searchable location field with autocomplete, recent searches,
/// and optional GPS detection button.
///
/// Reads and writes [locationProvider] automatically.
/// Can also be used standalone via callbacks.
class SearchableLocationField extends ConsumerStatefulWidget {
  /// Initial text value override.
  final String? initialValue;

  /// Called when a suggestion is selected.
  final ValueChanged<LocationSuggestion>? onSuggestionSelected;

  /// Called when the user types and submits free text (no suggestion picked).
  final ValueChanged<String>? onManualTextSubmitted;

  /// Whether to show the GPS detect button.
  final bool showGpsButton;

  /// Called when the text changes.
  final ValueChanged<String>? onChanged;

  /// Field hint text.
  final String hintText;

  /// Label shown above the field.
  final String? labelText;
  final bool showLabel;

  /// Max suggestions shown in overlay.
  final int maxSuggestions;

  const SearchableLocationField({
    super.key,
    this.initialValue,
    this.onSuggestionSelected,
    this.onManualTextSubmitted,
    this.onChanged,
    this.showGpsButton = true,
    this.hintText = 'Search area, district or province...',
    this.labelText,
    this.showLabel = true,
    this.maxSuggestions = 6,
  });

  @override
  ConsumerState<SearchableLocationField> createState() =>
      _SearchableLocationFieldState();
}

class _SearchableLocationFieldState
    extends ConsumerState<SearchableLocationField> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _showOverlay = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue ??
          ref.read(locationProvider).approximateAreaText,
    );
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant SearchableLocationField oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    debugPrint('[ApproxAreaUI] Searchable didUpdateWidget oldInitial: "${oldWidget.initialValue}"');
    debugPrint('[ApproxAreaUI] Searchable didUpdateWidget newInitial: "${widget.initialValue}"');
    debugPrint('[ApproxAreaUI] Searchable focused: ${_focusNode.hasFocus}');
    debugPrint('[ApproxAreaUI] Searchable controller.text before: "${_controller.text}"');

    // Only sync external initialValue when field is not focused (user not typing)
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text &&
        !_focusNode.hasFocus) {
      _controller.text = widget.initialValue ?? '';
      debugPrint('[ApproxAreaUI] Searchable controller synced to: "${_controller.text}"');
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _openOverlay();
    } else {
      // Small delay so tapping a suggestion registers before overlay closes
      Future.delayed(const Duration(milliseconds: 200), _closeOverlay);
    }
  }

  void _openOverlay() {
    if (!mounted) return;
    setState(() => _showOverlay = true);
    _buildOverlay();
  }

  void _closeOverlay() {
    if (!mounted) return;
    setState(() => _showOverlay = false);
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _buildOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(builder: (_) => _OverlayContent(
      layerLink: _layerLink,
      fieldContext: context,
      onSelect: _selectSuggestion,
      onClearRecents: () {
        ref.read(locationProvider.notifier).clearRecentSearches();
        _overlayEntry?.markNeedsBuild();
      },
      maxSuggestions: widget.maxSuggestions,
    ));
    overlay.insert(_overlayEntry!);
  }

  void _onTextChanged(String query) {
    if (widget.onChanged != null) {
      widget.onChanged!(query);
    }
    ref.read(locationProvider.notifier).search(query);
    _overlayEntry?.markNeedsBuild();
  }

  void _selectSuggestion(LocationSuggestion suggestion) {
    _controller.text = suggestion.display;
    _focusNode.unfocus();
    _closeOverlay();

    if (widget.onSuggestionSelected != null) {
      widget.onSuggestionSelected!(suggestion);
    } else {
      ref.read(locationProvider.notifier).applySuggestion(suggestion);
    }
  }

  void _onSubmitted(String value) {
    _focusNode.unfocus();
    _closeOverlay();

    if (value.trim().isEmpty) return;

    if (widget.onManualTextSubmitted != null) {
      widget.onManualTextSubmitted!(value.trim());
    } else {
      ref.read(locationProvider.notifier).setApproximateAreaText(value.trim());
    }
  }

  Future<void> _onGpsTapped() async {
    _focusNode.unfocus();
    _closeOverlay();
    await ref.read(locationProvider.notifier).fetchCurrentLocation();

    // Sync text field after GPS
    if (mounted) {
      final area = ref.read(locationProvider).approximateAreaText;
      if (area.isNotEmpty) {
        _controller.text = area;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Watch GPS loading for button state
    final isGpsLoading = ref.watch(isGpsLoadingProvider);
    final geocodingFailed = ref.watch(geocodingFailedProvider);
    final errorMsg = ref.watch(locationErrorProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showLabel) ...[
          Text(
            widget.labelText ?? 'Approximate Area',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
        ],

        CompositedTransformTarget(
          link: _layerLink,
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerHighest
                  : colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showOverlay
                    ? colorScheme.primary
                    : (isDark
                        ? colorScheme.outlineVariant
                        : colorScheme.outline.withOpacity(0.4)),
                width: _showOverlay ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.15 : 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _onTextChanged,
                    onSubmitted: _onSubmitted,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      isDense: true,
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),

                // Clear button
                if (_controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    color: colorScheme.onSurfaceVariant,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    onPressed: () {
                      _controller.clear();
                      ref.read(locationProvider.notifier).setApproximateAreaText('');
                      ref.read(locationProvider.notifier).search('');
                      _overlayEntry?.markNeedsBuild();
                    },
                  ),

                // GPS button
                if (widget.showGpsButton) ...[
                  const SizedBox(width: 4),
                  _GpsButton(
                    isLoading: isGpsLoading,
                    onTap: _onGpsTapped,
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),

        // Geocoding failed notice
        if (geocodingFailed) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: colorScheme.tertiary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Could not detect your area automatically. '
                  'Please type your area above.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.tertiary,
                  ),
                ),
              ),
            ],
          ),
        ],

        // GPS error notice
        if (errorMsg != null && !isGpsLoading) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_outlined,
                size: 14,
                color: colorScheme.error,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  errorMsg,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── GPS Button ─────────────────────────────────────────────────────────────

class _GpsButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _GpsButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: 'Detect my location',
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withOpacity(0.6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                )
              : Icon(
                  Icons.my_location_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
        ),
      ),
    );
  }
}

// ── Overlay Content ────────────────────────────────────────────────────────

class _OverlayContent extends ConsumerWidget {
  final LayerLink layerLink;
  final BuildContext fieldContext;
  final ValueChanged<LocationSuggestion> onSelect;
  final VoidCallback onClearRecents;
  final int maxSuggestions;

  const _OverlayContent({
    required this.layerLink,
    required this.fieldContext,
    required this.onSelect,
    required this.onClearRecents,
    required this.maxSuggestions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final locationState = ref.watch(locationProvider);
    final suggestions = locationState.suggestions;
    final recents = locationState.recentSearches;

    final showSuggestions = suggestions.isNotEmpty;
    final showRecents = !showSuggestions && recents.isNotEmpty;

    if (!showSuggestions && !showRecents) {
      return const SizedBox.shrink();
    }

    // Get the render box of the field to size the overlay
    final renderBox = fieldContext.findRenderObject() as RenderBox?;
    final width = renderBox?.size.width ?? 300;

    final items = showSuggestions
        ? suggestions.take(maxSuggestions).toList()
        : recents.take(maxSuggestions).toList();

    return Positioned(
      width: width,
      child: CompositedTransformFollower(
        link: layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 56),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? colorScheme.outlineVariant
                    : colorScheme.outline.withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section header
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        showRecents ? 'Recent Searches' : 'Suggestions',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (showRecents)
                        GestureDetector(
                          onTap: onClearRecents,
                          child: Text(
                            'Clear',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const Divider(height: 1, thickness: 0.5),

                // List of items
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (ctx, i) {
                      final item = items[i];
                      return _SuggestionTile(
                        suggestion: item,
                        isRecent: showRecents,
                        onTap: () => onSelect(item),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Suggestion Tile ────────────────────────────────────────────────────────

class _SuggestionTile extends StatelessWidget {
  final LocationSuggestion suggestion;
  final bool isRecent;
  final VoidCallback onTap;

  const _SuggestionTile({
    required this.suggestion,
    required this.isRecent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              isRecent ? Icons.history_rounded : Icons.place_outlined,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                suggestion.display,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (suggestion.hasCoordinates)
              Icon(
                Icons.gps_fixed,
                size: 14,
                color: colorScheme.primary.withOpacity(0.6),
              ),
          ],
        ),
      ),
    );
  }
}

