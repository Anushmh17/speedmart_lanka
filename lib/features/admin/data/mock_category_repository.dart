import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../shared/models/category_model.dart';
import '../../../shared/utils/category_sync_helper.dart';
import '../../auth/data/mock_auth_repository.dart';

class MockCategoryRepository {
  static const String _storageKey = 'admin_categories';
  
  static final MockCategoryRepository instance = MockCategoryRepository._();
  MockCategoryRepository._();

  List<CategoryModel> _categories = [];
  bool _isInitialized = false;

  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    
    await _loadFromStorage();
    _isInitialized = true;
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      
      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        _categories = jsonList.map((j) => CategoryModel.fromJson(j)).toList();
        debugPrint('[CategoryAdmin] loaded categories: ${_categories.length} from storage');
      } else {
        _initializeDefaultCategories();
      }
    } catch (e) {
      debugPrint('[CategoryAdmin] Error loading from storage: $e');
      _initializeDefaultCategories();
    }
  }

  void _initializeDefaultCategories() {
    final now = DateTime.now();
    _categories = [
      CategoryModel(
        id: 'cat-001',
        normalizedKey: 'groceries',
        name: 'Groceries',
        isActive: true,
        isDefault: true,
        createdAt: now,
      ),
      CategoryModel(
        id: 'cat-002',
        normalizedKey: 'electronics',
        name: 'Electronics',
        isActive: true,
        isDefault: true,
        createdAt: now,
      ),
      CategoryModel(
        id: 'cat-003',
        normalizedKey: 'hardware',
        name: 'Hardware',
        isActive: true,
        isDefault: true,
        createdAt: now,
      ),
      CategoryModel(
        id: 'cat-004',
        normalizedKey: 'furniture',
        name: 'Furniture',
        isActive: true,
        isDefault: true,
        createdAt: now,
      ),
      CategoryModel(
        id: 'cat-005',
        normalizedKey: 'pharmacy',
        name: 'Pharmacy',
        isActive: true,
        isDefault: true,
        createdAt: now,
      ),
      CategoryModel(
        id: 'cat-006',
        normalizedKey: 'clothing',
        name: 'Clothing',
        isActive: true,
        isDefault: true,
        createdAt: now,
      ),
      CategoryModel(
        id: 'cat-007',
        normalizedKey: 'vehicle parts',
        name: 'Vehicle Parts',
        isActive: true,
        isDefault: true,
        createdAt: now,
      ),
      CategoryModel(
        id: 'cat-008',
        normalizedKey: 'home appliances',
        name: 'Home Appliances',
        isActive: true,
        isDefault: true,
        createdAt: now,
      ),
      CategoryModel(
        id: 'cat-009',
        normalizedKey: 'stationery',
        name: 'Stationery',
        isActive: true,
        isDefault: true,
        createdAt: now,
      ),
      CategoryModel(
        id: 'cat-010',
        normalizedKey: 'other',
        name: 'Other',
        isActive: true,
        isDefault: true,
        createdAt: now,
      ),
    ];
    debugPrint('[CategoryAdmin] loaded categories: ${_categories.length} defaults initialized');
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(_categories.map((c) => c.toJson()).toList());
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      debugPrint('[CategoryAdmin] Error persisting: $e');
    }
  }

  Future<List<CategoryModel>> getAllCategories() async {
    await ensureInitialized();
    return List.from(_categories);
  }

  Future<List<CategoryModel>> getActiveCategories() async {
    await ensureInitialized();
    return _categories.where((c) => c.isActive).toList();
  }

  Future<CategoryModel?> createCategory(String displayName) async {
    await ensureInitialized();
    
    final normalized = CategorySyncHelper.normalizeCategoryKey(displayName);
    
    if (_categories.any((c) => c.normalizedKey == normalized)) {
      debugPrint('[CategoryAdmin] duplicate blocked: $displayName ($normalized)');
      throw Exception('Category "$displayName" already exists');
    }

    final newCategory = CategoryModel(
      id: 'cat-${DateTime.now().millisecondsSinceEpoch}',
      normalizedKey: normalized,
      name: displayName,
      isActive: true,
      isDefault: false,
      createdAt: DateTime.now(),
    );

    _categories.add(newCategory);
    await _persist();
    
    debugPrint('[CategoryAdmin] created: $displayName ($normalized)');
    return newCategory;
  }

  Future<CategoryModel> updateCategory(String id, {String? displayName, bool? isActive}) async {
    await ensureInitialized();
    
    final index = _categories.indexWhere((c) => c.id == id);
    if (index == -1) throw Exception('Category not found');

    final category = _categories[index];
    
    String? newNormalized;
    if (displayName != null && displayName != category.displayName) {
      newNormalized = CategorySyncHelper.normalizeCategoryKey(displayName);
      
      if (_categories.any((c) => c.id != id && c.normalizedKey == newNormalized)) {
        debugPrint('[CategoryAdmin] duplicate blocked: $displayName ($newNormalized)');
        throw Exception('Category "$displayName" already exists');
      }
    }

    final updated = category.copyWith(
      name: displayName,
      normalizedKey: newNormalized,
      isActive: isActive,
      updatedAt: DateTime.now(),
    );

    _categories[index] = updated;
    await _persist();
    
    if (displayName != null) {
      debugPrint('[CategoryAdmin] updated: ${category.displayName} → $displayName');
    }
    if (isActive != null) {
      debugPrint('[CategoryAdmin] ${isActive ? "enabled" : "disabled"}: ${updated.displayName}');
    }
    
    return updated;
  }

  Future<bool> isCategoryInUse(String normalizedKey) async {
    try {
      // Check in mock auth repository for vendors using this category
      final authRepo = MockAuthRepository.instance;
      await authRepo.ensureInitialized();
      final allUsers = await authRepo.getAllUsers();
      
      for (final user in allUsers) {
        if ((user.vendorCategories?.contains(normalizedKey) ?? false) ||
            (user.allowedCategories?.contains(normalizedKey) ?? false) ||
            (user.requestedCategories?.contains(normalizedKey) ?? false)) {
          debugPrint('[CategoryAdmin] Category in use by vendor: ${user.id}');
          return true;
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('[CategoryAdmin] Error checking category in use: $e');
      return false;
    }
  }

  Future<void> deleteCategory(String id) async {
    await ensureInitialized();
    
    final category = _categories.firstWhere((c) => c.id == id);
    
    if (category.isDefault) {
      throw Exception('Cannot delete default category');
    }

    // Check if category is in use before allowing hard delete
    final inUse = await isCategoryInUse(category.normalizedKey);
    if (inUse) {
      throw Exception('This category is currently used. Disable it instead to preserve history.');
    }

    _categories.removeWhere((c) => c.id == id);
    await _persist();
    
    debugPrint('[CategoryAdmin] deleted: ${category.displayName}');
  }
}
