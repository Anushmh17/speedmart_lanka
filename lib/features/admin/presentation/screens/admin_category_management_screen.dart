import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../providers/category_provider.dart';
import '../widgets/admin_screen_header.dart';

class AdminCategoryManagementScreen extends ConsumerStatefulWidget {
  const AdminCategoryManagementScreen({super.key});

  @override
  ConsumerState<AdminCategoryManagementScreen> createState() =>
      _AdminCategoryManagementScreenState();
}

class _AdminCategoryManagementScreenState
    extends ConsumerState<AdminCategoryManagementScreen> {
  final _addCategoryCtrl = TextEditingController();

  @override
  void dispose() {
    _addCategoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _showAddCategoryDialog() async {
    _addCategoryCtrl.clear();
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(
          controller: _addCategoryCtrl,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g., Books',
          ),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = _addCategoryCtrl.text.trim();
              if (name.isEmpty) return;
              try {
                await ref.read(categoryProvider.notifier).createCategory(name);
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Category "$name" added'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(e.toString().replaceAll('Exception: ', '')),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.adminColor),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditCategoryDialog(String id, String currentName) async {
    final controller = TextEditingController(text: currentName);
    bool isSaving = false;
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Category'),
          content: TextField(
            controller: controller,
            enabled: !isSaving,
            decoration: const InputDecoration(labelText: 'Category Name'),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = controller.text.trim();
                      if (name.isEmpty || name == currentName) {
                        Navigator.of(ctx).pop();
                        return;
                      }
                      setDialogState(() => isSaving = true);
                      try {
                        await ref
                            .read(categoryProvider.notifier)
                            .updateCategory(id, displayName: name);
                        if (!mounted) return;
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Category updated to "$name"'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ));
                      } catch (e) {
                        if (!mounted) return;
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(e.toString().replaceAll('Exception: ', '')),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.adminColor),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDisable(String id, String name, bool currentState) async {
    if (!currentState) {
      try {
        await ref.read(categoryProvider.notifier).updateCategory(id, isActive: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Category "$name" enabled'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ));
        }
      }
      return;
    }
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Disable Category?'),
        content: const Text(
          'This category may already be used by existing requests, vendors, proposals, or orders.\n\n'
          'Disabling it will:\n'
          '• Hide it from new customer requests\n'
          '• Hide it from new vendor registrations\n'
          '• Keep existing requests, proposals, orders, and vendor matches working\n\n'
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref
                    .read(categoryProvider.notifier)
                    .updateCategory(id, isActive: false);
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Category "$name" disabled'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ));
              } catch (e) {
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(e.toString().replaceAll('Exception: ', '')),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Disable Category'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(String id, String name, bool isDefault) async {
    if (isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cannot delete default category'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: const Text(
          'This category is currently used. Disable it instead to preserve history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final categoryState = ref.watch(categoryProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Column(
        children: [
          AdminScreenHeader(
            title: 'Category Management',
            subtitle: 'Add, edit & toggle product categories',
            icon: Icons.category_rounded,
            isDark: isDark,
          ),
          Expanded(
            child: categoryState.isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.adminColor),
                  )
                : categoryState.categories.isEmpty
                    ? Center(
                        child: Text(
                          'No categories found',
                          style: AppTextStyles.bodyMedium(secondaryText),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: categoryState.categories.length,
                        itemBuilder: (context, index) {
                          final category = categoryState.categories[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      category.displayName,
                                      style: AppTextStyles.bodyMedium(primaryText)
                                          .copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (category.isDefault)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.info
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Default',
                                        style: AppTextStyles.caption(AppColors.info)
                                            .copyWith(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  if (!category.isActive)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Archived',
                                        style: AppTextStyles.caption(
                                                AppColors.warning)
                                            .copyWith(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Key: ${category.normalizedKey}',
                                  style: AppTextStyles.caption(secondaryText),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: category.isActive,
                                    onChanged: (val) => _confirmDisable(
                                        category.id,
                                        category.displayName,
                                        category.isActive),
                                    activeColor: AppColors.success,
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _showEditCategoryDialog(
                                            category.id, category.displayName);
                                      } else if (value == 'delete') {
                                        _confirmDelete(category.id,
                                            category.displayName, category.isDefault);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(children: [
                                          Icon(Icons.edit, size: 18),
                                          SizedBox(width: 8),
                                          Text('Edit'),
                                        ]),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        enabled: !category.isDefault,
                                        child: Row(children: [
                                          Icon(Icons.delete,
                                              size: 18,
                                              color: category.isDefault
                                                  ? Colors.grey
                                                  : AppColors.error),
                                          const SizedBox(width: 8),
                                          Text('Delete',
                                              style: TextStyle(
                                                  color: category.isDefault
                                                      ? Colors.grey
                                                      : AppColors.error)),
                                        ]),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCategoryDialog,
        backgroundColor: AppColors.adminColor,
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
    );
  }
}
