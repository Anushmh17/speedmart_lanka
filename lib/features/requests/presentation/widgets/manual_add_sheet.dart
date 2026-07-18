import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import 'package:speedmart_lanka/shared/providers/category_provider.dart';
import '../../models/request_item.dart';
import 'quantity_unit_selector.dart';
import 'image_upload_grid.dart';

class ManualAddSheet extends ConsumerStatefulWidget {
  final Function(RequestItem) onAdd;

  const ManualAddSheet({super.key, required this.onAdd});

  @override
  ConsumerState<ManualAddSheet> createState() => _ManualAddSheetState();
}

class _ManualAddSheetState extends ConsumerState<ManualAddSheet> {
  final _formKey = GlobalKey<FormState>();
  
  // Strict Field Variables in order
  String? _selectedCategory;
  final _nameController = TextEditingController();
  int _quantity = 1;
  String? _selectedUnit = 'kg';
  String? _customUnitNote;
  final _brandController = TextEditingController();
  final _descController = TextEditingController();
  List<String> _imageUrls = [];

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (_selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a category')),
        );
        return;
      }
      // Append size-based note or custom unit details directly into unit/remarks if selected
      String finalUnit = _selectedUnit ?? 'pieces';
      if (_selectedUnit == 'size-based note' || _selectedUnit == 'custom unit') {
        if (_customUnitNote != null && _customUnitNote!.trim().isNotEmpty) {
          finalUnit = '$_selectedUnit: ${_customUnitNote!.trim()}';
        }
      }

      final item = RequestItem(
        id: const Uuid().v4(),
        itemName: _nameController.text.trim(),
        quantity: _quantity,
        unit: finalUnit,
        category: _selectedCategory!,
        preferredBrand: _brandController.text.trim(),
        description: _descController.text.trim(),
        imageUrls: _imageUrls,
      );
      widget.onAdd(item);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : Colors.black;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Drag Handle & Title
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Add Item Manually', style: AppTextStyles.h2(primaryColor)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),

              // FIELD 1: Category Selector First
              Text('1. Select Category', style: AppTextStyles.labelMedium(secondaryText)),
              const SizedBox(height: 8),
              Consumer(
                builder: (context, ref, _) {
                  final activeCategories = ref.watch(activeCategoriesProvider);
                  if (_selectedCategory == null && activeCategories.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() => _selectedCategory = activeCategories.first.name);
                    });
                  }
                  return DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    dropdownColor: cardColor,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      filled: true,
                      fillColor: isDark ? Colors.black12 : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.customerColor, width: 1.5),
                      ),
                    ),
                    style: AppTextStyles.bodyMedium(primaryColor),
                    items: activeCategories.map((cat) => DropdownMenuItem(
                      value: cat.name,
                      child: Text(cat.name),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedCategory = val;
                          // Set sensible default units per category
                          final normalized = val.toLowerCase().replaceAll(' ', '_');
                          if (normalized == 'groceries') {
                            _selectedUnit = 'kg';
                          } else {
                            _selectedUnit = 'pieces';
                          }
                          _customUnitNote = null;
                        });
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // FIELD 2: Item Name
              Text('2. Item Name', style: AppTextStyles.labelMedium(secondaryText)),
              const SizedBox(height: 8),
              AppTextField(
                controller: _nameController,
                label: 'What product do you need?',
                hint: 'e.g. Anchor Milk Powder 400g, Keeri Samba...',
                textCapitalization: TextCapitalization.sentences,
                validator: (val) => val == null || val.isEmpty ? 'Please enter the item name' : null,
              ),
              const SizedBox(height: 16),

              // FIELDS 3 & 4: Quantity & Unit Selector Widget
              QuantityUnitSelector(
                category: _selectedCategory ?? 'Other',
                quantity: _quantity,
                unit: _selectedUnit,
                customUnitNote: _customUnitNote,
                onQuantityChanged: (val) => setState(() => _quantity = val),
                onUnitChanged: (val) => setState(() => _selectedUnit = val),
                onCustomUnitNoteChanged: (val) => setState(() => _customUnitNote = val),
              ),
              const SizedBox(height: 16),

              // FIELD 5: Preferred Brand / Model
              Text('5. Preferred Brand/Model (Optional)', style: AppTextStyles.labelMedium(secondaryText)),
              const SizedBox(height: 8),
              AppTextField(
                controller: _brandController,
                label: 'Prefer a specific brand?',
                hint: 'e.g. Prima, Singer, Toyota OEM',
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),

              // FIELD 6: Description/Remarks
              Text('6. Description / Remarks (Optional)', style: AppTextStyles.labelMedium(secondaryText)),
              const SizedBox(height: 8),
              AppTextField(
                controller: _descController,
                label: 'Additional specifications...',
                hint: 'e.g. Need fresh items, check expiry, specific color...',
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),

              // FIELD 7: Image Upload Section
              ImageUploadGrid(
                category: _selectedCategory ?? 'Other',
                imageUrls: _imageUrls,
                onImagesChanged: (list) => setState(() => _imageUrls = list),
              ),
              const SizedBox(height: 24),

              // FIELD 8: Add to List Submission Bar
              AppButton(
                label: 'Add to Shopping List',
                onPressed: _submit,
                color: AppColors.customerColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


