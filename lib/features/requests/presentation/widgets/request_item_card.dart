import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../models/request_item.dart';
import 'quantity_unit_selector.dart';
import 'image_upload_grid.dart';
import '../../../admin/providers/category_provider.dart';

class RequestItemCard extends ConsumerStatefulWidget {
  final RequestItem item;
  final int itemNumber;
  final bool isMixedCategory; // Mode B
  final ValueChanged<RequestItem> onChanged;
  final VoidCallback onRemove;
  final VoidCallback onDuplicate;

  const RequestItemCard({
    super.key,
    required this.item,
    required this.itemNumber,
    required this.isMixedCategory,
    required this.onChanged,
    required this.onRemove,
    required this.onDuplicate,
  });

  @override
  ConsumerState<RequestItemCard> createState() => _RequestItemCardState();
}

class _RequestItemCardState extends ConsumerState<RequestItemCard> {
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _descController;
  final _categoryLayerLink = LayerLink();
  OverlayEntry? _categoryOverlay;
  final _overlayScrollController = ScrollController();

  void _openCategoryOverlay(BuildContext context, List<String> categories,
      Color cardColor, Color primaryText, Color secondaryText, Color borderColor, bool isDark) {
    _closeCategoryOverlay();
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _categoryOverlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeCategoryOverlay,
            ),
          ),
          CompositedTransformFollower(
            link: _categoryLayerLink,
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
                      itemCount: categories.length,
                      itemBuilder: (_, i) {
                        final cat = categories[i];
                        final isSelected = widget.item.category == cat;
                        return InkWell(
                          onTap: () {
                            _updateItem(widget.item.copyWith(category: cat));
                            _closeCategoryOverlay();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                            child: Row(
                              children: [
                                Expanded(child: Text(cat,
                                  style: TextStyle(
                                    color: isSelected ? (isDark ? AppColors.primaryDark : AppColors.primary) : primaryText,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    fontSize: 14,
                                  ))),
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
    Overlay.of(context).insert(_categoryOverlay!);
  }

  void _closeCategoryOverlay() {
    _categoryOverlay?.remove();
    _categoryOverlay = null;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.itemName);
    _brandController = TextEditingController(text: widget.item.preferredBrand);
    _descController = TextEditingController(text: widget.item.description);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Close overlay whenever the nearest scroll view scrolls
    final scrollable = Scrollable.maybeOf(context);
    scrollable?.position.isScrollingNotifier.addListener(_closeCategoryOverlay);
  }

  @override
  void didUpdateWidget(RequestItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.itemName != widget.item.itemName && _nameController.text != widget.item.itemName) {
      _nameController.text = widget.item.itemName;
    }
    if (oldWidget.item.preferredBrand != widget.item.preferredBrand && _brandController.text != widget.item.preferredBrand) {
      _brandController.text = widget.item.preferredBrand ?? '';
    }
    if (oldWidget.item.description != widget.item.description && _descController.text != widget.item.description) {
      _descController.text = widget.item.description ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _descController.dispose();
    _overlayScrollController.dispose();
    _closeCategoryOverlay();
    super.dispose();
  }

  void _updateItem(RequestItem newItem) {
    widget.onChanged(newItem);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    // Resolve active unit safely
    String? currentUnit = widget.item.unit;
    String baseUnit = currentUnit ?? 'pieces';
    String? unitNote;
    if (baseUnit.startsWith('size-based note:') || baseUnit.startsWith('custom unit:')) {
      final parts = baseUnit.split(': ');
      baseUnit = parts[0];
      if (parts.length > 1) unitNote = parts[1];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.05 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Item Number Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.customerColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Item ${widget.itemNumber}',
                        style: AppTextStyles.labelMedium(AppColors.customerColor).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Non-editable Category Chip for Same Category list mode
                    if (!widget.isMixedCategory)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.item.category ?? 'Groceries',
                          style: AppTextStyles.labelSmall(primaryText),
                        ),
                      ),
                  ],
                ),
                // Header Actions
                Row(
                  children: [
                    // Duplicate Button
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.customerColor),
                      tooltip: 'Duplicate Item',
                      onPressed: widget.onDuplicate,
                    ),
                    // Remove Button
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                      tooltip: 'Remove Item',
                      onPressed: widget.onRemove,
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Selector if Mixed Category Mode is enabled
                if (widget.isMixedCategory) ...[
                  Text('Category', style: AppTextStyles.labelMedium(secondaryText)),
                  const SizedBox(height: 8),
                  CompositedTransformTarget(
                    link: _categoryLayerLink,
                    child: Builder(
                      builder: (fieldCtx) => GestureDetector(
                        onTap: () {
                          final categories = ref.read(activeCategoriesProvider)
                              .where((c) => c.isActive)
                              .map((c) => c.displayName)
                              .toList();
                          _openCategoryOverlay(fieldCtx, categories, cardColor,
                              primaryText, secondaryText, borderColor, isDark);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black12 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.item.category ?? 'Select category',
                                  style: AppTextStyles.bodyMedium(
                                    widget.item.category != null ? primaryText : secondaryText,
                                  ),
                                ),
                              ),
                              Icon(Icons.keyboard_arrow_down_rounded, color: secondaryText, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Item Name Input
                AppTextField(
                  controller: _nameController,
                  label: 'Item Name',
                  hint: 'e.g. Onion, Red Pumpkins...',
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (val) {
                    _updateItem(widget.item.copyWith(itemName: val));
                  },
                ),
                const SizedBox(height: 16),

                // Quantity & Unit controls
                QuantityUnitSelector(
                  category: widget.item.category ?? 'Groceries',
                  quantity: widget.item.quantity,
                  unit: baseUnit,
                  customUnitNote: unitNote,
                  onQuantityChanged: (qty) {
                    _updateItem(widget.item.copyWith(quantity: qty));
                  },
                  onUnitChanged: (unit) {
                    _updateItem(widget.item.copyWith(unit: unit));
                  },
                  onCustomUnitNoteChanged: (note) {
                    String finalUnit = baseUnit;
                    if (baseUnit == 'custom unit' || baseUnit == 'size-based note') {
                      finalUnit = '$baseUnit: $note';
                    }
                    _updateItem(widget.item.copyWith(unit: finalUnit));
                  },
                ),
                const SizedBox(height: 16),

                // Preferred Brand (Optional)
                AppTextField(
                  controller: _brandController,
                  label: 'Preferred Brand / Model (Optional)',
                  hint: 'e.g. Prima, Anchor, Toyota Genuine',
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (val) {
                    _updateItem(widget.item.copyWith(preferredBrand: val));
                  },
                ),
                const SizedBox(height: 16),

                // Description/Remarks (Optional)
                AppTextField(
                  controller: _descController,
                  label: 'Description / Remarks (Optional)',
                  hint: 'e.g. Fresh medium size, organic...',
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (val) {
                    _updateItem(widget.item.copyWith(description: val));
                  },
                ),
                const SizedBox(height: 16),

                // Item-Specific Image Upload grid
                ImageUploadGrid(
                  category: widget.item.category ?? 'Groceries',
                  imageUrls: widget.item.imageUrls,
                  onImagesChanged: (list) {
                    _updateItem(widget.item.copyWith(imageUrls: list));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
