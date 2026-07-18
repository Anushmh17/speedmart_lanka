import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class QuantityUnitSelector extends StatefulWidget {
  final String? category;
  final int quantity;
  final String? unit;
  final String? customUnitNote; // for custom unit or size note
  final ValueChanged<int> onQuantityChanged;
  final ValueChanged<String?> onUnitChanged;
  final ValueChanged<String?> onCustomUnitNoteChanged;

  const QuantityUnitSelector({
    super.key,
    required this.category,
    required this.quantity,
    required this.unit,
    this.customUnitNote,
    required this.onQuantityChanged,
    required this.onUnitChanged,
    required this.onCustomUnitNoteChanged,
  });

  @override
  State<QuantityUnitSelector> createState() => _QuantityUnitSelectorState();
}

class _QuantityUnitSelectorState extends State<QuantityUnitSelector> {
  late TextEditingController _noteController;
  final _unitLayerLink = LayerLink();
  OverlayEntry? _unitOverlay;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.customUnitNote);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Scrollable.maybeOf(context)?.position.isScrollingNotifier.addListener(_closeUnitOverlay);
  }

  @override
  void didUpdateWidget(QuantityUnitSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customUnitNote != widget.customUnitNote) {
      _noteController.text = widget.customUnitNote ?? '';
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _closeUnitOverlay();
    super.dispose();
  }

  void _openUnitOverlay(BuildContext context, List<String> units, String currentUnit,
      Color cardColor, Color primaryText, Color secondaryText, bool isDark) {
    _closeUnitOverlay();
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _unitOverlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeUnitOverlay,
            ),
          ),
          CompositedTransformFollower(
            link: _unitLayerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 4),
            child: SizedBox(
              width: size.width,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                color: cardColor,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      shrinkWrap: true,
                      itemCount: units.length,
                      itemBuilder: (_, i) {
                        final u = units[i];
                        final isSelected = currentUnit == u;
                        return InkWell(
                          onTap: () {
                            widget.onUnitChanged(u);
                            _closeUnitOverlay();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    u,
                                    style: TextStyle(
                                      color: isSelected
                                          ? (isDark ? AppColors.primaryDark : AppColors.primary)
                                          : primaryText,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_rounded, size: 16,
                                      color: isDark ? AppColors.primaryDark : AppColors.primary),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_unitOverlay!);
  }

  void _closeUnitOverlay() {
    _unitOverlay?.remove();
    _unitOverlay = null;
  }

  List<String> _getUnits() {
    final cat = widget.category;
    switch (cat) {
      case 'Groceries':
        return ['kg', 'g', 'packets', 'bottles', 'pieces', 'liters', 'ml'];
      case 'Electronics':
        return ['pieces', 'units'];
      case 'Furniture':
        return ['pieces', 'sets'];
      case 'Vehicle parts':
        return ['pieces', 'sets', 'pairs'];
      case 'Clothing':
        return ['pieces', 'sets', 'size-based note'];
      default:
        return ['pieces', 'units', 'custom unit'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final units = _getUnits();
    // Safely assign active unit
    String? currentUnit = widget.unit;
    if (currentUnit == null || !units.contains(currentUnit)) {
      currentUnit = units.first;
      // Trigger callback on next frame to keep state synced
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onUnitChanged(currentUnit);
      });
    }

    final isCustomUnit = currentUnit == 'custom unit';
    final isSizeNote = currentUnit == 'size-based note';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Quantity Button Control Block
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quantity',
                    style: AppTextStyles.labelMedium(secondaryText),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_rounded, size: 20, color: AppColors.customerColor),
                          onPressed: widget.quantity > 1
                              ? () => widget.onQuantityChanged(widget.quantity - 1)
                              : null,
                        ),
                        Text(
                          '${widget.quantity}',
                          style: AppTextStyles.bodyLarge(primaryText).copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_rounded, size: 20, color: AppColors.customerColor),
                          onPressed: () => widget.onQuantityChanged(widget.quantity + 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Unit Dropdown Control Block
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unit',
                    style: AppTextStyles.labelMedium(secondaryText),
                  ),
                  const SizedBox(height: 8),
                  CompositedTransformTarget(
                    link: _unitLayerLink,
                    child: Builder(
                      builder: (fieldCtx) => GestureDetector(
                        onTap: () => _openUnitOverlay(
                          fieldCtx, units, currentUnit!,
                          cardColor, primaryText, secondaryText, isDark,
                        ),
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black26 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  currentUnit!,
                                  style: AppTextStyles.bodyMedium(primaryText),
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.customerColor),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (isCustomUnit || isSizeNote) ...[
          const SizedBox(height: 12),
          Text(
            isSizeNote ? 'Size details (e.g. Size M, chest 40, shoes UK 9)' : 'Enter custom unit description',
            style: AppTextStyles.labelSmall(secondaryText),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _noteController,
            style: AppTextStyles.bodyMedium(primaryText),
            decoration: InputDecoration(
              hintText: isSizeNote ? 'e.g. Size L / EU 42' : 'e.g. bundle, box, crate',
              hintStyle: TextStyle(color: secondaryText.withOpacity(0.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.customerColor, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
            ),
            onChanged: widget.onCustomUnitNoteChanged,
          ),
        ],
      ],
    );
  }
}

