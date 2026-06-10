import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/mock_category_repository.dart';
import '../models/category_model.dart';
import '../../auth/data/mock_auth_repository.dart';

class CategoryState {
  final List<CategoryModel> categories;
  final bool isLoading;
  final String? error;

  const CategoryState({
    this.categories = const [],
    this.isLoading = false,
    this.error,
  });

  CategoryState copyWith({
    List<CategoryModel>? categories,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return CategoryState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  List<CategoryModel> get activeCategories =>
      categories.where((c) => c.isActive).toList();
}

class CategoryNotifier extends StateNotifier<CategoryState> {
  final MockCategoryRepository _repository;
  final MockAuthRepository _authRepository;

  CategoryNotifier(this._repository, this._authRepository)
      : super(const CategoryState()) {
    loadCategories();
  }

  Future<void> loadCategories() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final categories = await _repository.getAllCategories();
      debugPrint('[CategorySync] Loaded ${categories.length} categories');
      state = state.copyWith(categories: categories, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> createCategory(String displayName) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.createCategory(displayName);
      debugPrint('[CategorySync] Created category: $displayName');
      await loadCategories();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      rethrow;
    }
  }

  Future<void> updateCategory(
    String id, {
    String? displayName,
    bool? isActive,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final oldCategory = state.categories.firstWhere((c) => c.id == id);
      final oldNormalizedKey = oldCategory.normalizedKey;

      await _repository.updateCategory(
        id,
        displayName: displayName,
        isActive: isActive,
      );

      await loadCategories();
      final newCategory = state.categories.firstWhere((c) => c.id == id);
      final newNormalizedKey = newCategory.normalizedKey;

      if (displayName != null && oldNormalizedKey != newNormalizedKey) {
        debugPrint(
            '[CategorySync] Category name changed: $oldNormalizedKey → $newNormalizedKey');
        await _syncVendorCategoriesAfterEdit(
          oldNormalizedKey,
          newNormalizedKey,
        );
      }

      if (isActive == false) {
        debugPrint('[CategorySync] Category disabled: $oldNormalizedKey');
        await _syncVendorCategoriesAfterDisable(oldNormalizedKey);
      }

      // Master sync after any category update - runs only once after successful save
      await syncAllUsersCategoryKeysWithRepository();
      
      // Clear loading state only after complete sync
      state = state.copyWith(isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      rethrow;
    }
  }

  Future<void> deleteCategory(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final categoryToDelete =
          state.categories.firstWhere((c) => c.id == id);
      final normalizedKeyToDelete = categoryToDelete.normalizedKey;

      await _repository.deleteCategory(id);

      debugPrint('[CategorySync] Category deleted: $normalizedKeyToDelete');
      await _syncVendorCategoriesAfterDelete(normalizedKeyToDelete);

      // Master sync after delete - runs only once after successful deletion
      await syncAllUsersCategoryKeysWithRepository();

      await loadCategories();
      
      // Clear loading state only after complete sync
      state = state.copyWith(isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      rethrow;
    }
  }

  Future<void> _syncVendorCategoriesAfterEdit(
    String oldKey,
    String newKey,
  ) async {
    try {
      await _authRepository.ensureInitialized();
      final allUsers = await _authRepository.getAllUsers();

      for (final user in allUsers) {
        bool needsUpdate = false;

        List<String>? updatedAllowed = user.allowedCategories?.map((key) {
          if (key == oldKey) {
            debugPrint(
                '[CategorySync] Updated allowedCategories: $oldKey → $newKey for user ${user.id}');
            needsUpdate = true;
            return newKey;
          }
          return key;
        }).toList();

        List<String>? updatedVendor = user.vendorCategories?.map((key) {
          if (key == oldKey) {
            debugPrint(
                '[CategorySync] Updated vendorCategories: $oldKey → $newKey for user ${user.id}');
            needsUpdate = true;
            return newKey;
          }
          return key;
        }).toList();

        List<String>? updatedRequested = user.requestedCategories?.map((key) {
          if (key == oldKey) {
            debugPrint(
                '[CategorySync] Updated requestedCategories: $oldKey → $newKey for user ${user.id}');
            needsUpdate = true;
            return newKey;
          }
          return key;
        }).toList();

        if (needsUpdate) {
          final syncedUser = user.copyWith(
            allowedCategories: updatedAllowed,
            vendorCategories: updatedVendor,
            requestedCategories: updatedRequested,
          );
          await _authRepository.updateUser(syncedUser);
          debugPrint(
              '[CategorySync] Synced user ${user.id} after category edit');
        }
      }
    } catch (e) {
      debugPrint('[CategorySync] ERROR syncing after edit: $e');
    }
  }

  Future<void> _syncVendorCategoriesAfterDisable(String disabledKey) async {
    try {
      debugPrint(
          '[CategorySync] Disabled category $disabledKey - cleaning up from vendor displays');
      // Disabled categories should not be removed from DB, just filtered on display/selector
    } catch (e) {
      debugPrint('[CategorySync] ERROR processing disable: $e');
    }
  }

  /// Targeted sync: Clean single user's category keys against current repository
  /// Removes deleted/unknown keys, deduplicates
  /// Used when opening Assign Store or similar single-vendor screens
  Future<void> cleanSingleUserCategoryKeysWithRepository(String userId) async {
    debugPrint('[CategorySync] Cleaning categories for user: $userId');
    try {
      await _authRepository.ensureInitialized();
      final user = await _authRepository.getUserById(userId);
      if (user == null) {
        debugPrint('[CategorySync] User not found: $userId');
        return;
      }

      final validKeys = state.categories.map((c) => c.normalizedKey).toSet();
      bool needsUpdate = false;

      // Clean allowedCategories
      final cleanedAllowed = _cleanCategoryList(
        user.allowedCategories,
        validKeys,
        'allowedCategories',
        userId,
      );
      if (cleanedAllowed != user.allowedCategories) {
        needsUpdate = true;
      }

      // Clean vendorCategories
      final cleanedVendor = _cleanCategoryList(
        user.vendorCategories,
        validKeys,
        'vendorCategories',
        userId,
      );
      if (cleanedVendor != user.vendorCategories) {
        needsUpdate = true;
      }

      // Clean requestedCategories
      final cleanedRequested = _cleanCategoryList(
        user.requestedCategories,
        validKeys,
        'requestedCategories',
        userId,
      );
      if (cleanedRequested != user.requestedCategories) {
        needsUpdate = true;
      }

      // Update hasPendingCategoryRequest flag
      final newHasPending = (cleanedRequested?.isNotEmpty ?? false);
      if (newHasPending != (user.hasPendingCategoryRequest ?? false)) {
        needsUpdate = true;
      }

      if (needsUpdate) {
        final syncedUser = user.copyWith(
          allowedCategories: cleanedAllowed,
          vendorCategories: cleanedVendor,
          requestedCategories: cleanedRequested,
          hasPendingCategoryRequest: newHasPending,
        );
        await _authRepository.updateUser(syncedUser);
        debugPrint('[CategorySync] Cleaned user $userId');
      }
    } catch (e) {
      debugPrint('[CategorySync] ERROR cleaning user $userId: $e');
    }
  }

  /// Master sync: Clean all user category keys against current repository
  /// Removes deleted/unknown keys, migrates edited keys, deduplicates
  /// Called after any category edit/delete/disable ONLY
  Future<void> syncAllUsersCategoryKeysWithRepository() async {
    debugPrint('[CategorySync] ===== MASTER SYNC START =====');
    try {
      await _authRepository.ensureInitialized();
      final allCategories = state.categories;
      final validKeys = allCategories.map((c) => c.normalizedKey).toSet();
      final activeKeys = allCategories
          .where((c) => c.isActive)
          .map((c) => c.normalizedKey)
          .toSet();

      debugPrint('[CategorySync] Valid keys in repo: ${validKeys.length}');
      debugPrint('[CategorySync] Active keys in repo: ${activeKeys.length}');

      final allUsers = await _authRepository.getAllUsers();
      int usersSynced = 0;

      for (final user in allUsers) {
        bool needsUpdate = false;

        // Clean allowedCategories
        final cleanedAllowed = _cleanCategoryList(
          user.allowedCategories,
          validKeys,
          'allowedCategories',
          user.id,
        );
        if (cleanedAllowed != user.allowedCategories) {
          needsUpdate = true;
        }

        // Clean vendorCategories
        final cleanedVendor = _cleanCategoryList(
          user.vendorCategories,
          validKeys,
          'vendorCategories',
          user.id,
        );
        if (cleanedVendor != user.vendorCategories) {
          needsUpdate = true;
        }

        // Clean requestedCategories
        final cleanedRequested = _cleanCategoryList(
          user.requestedCategories,
          validKeys,
          'requestedCategories',
          user.id,
        );
        if (cleanedRequested != user.requestedCategories) {
          needsUpdate = true;
        }

        // Update hasPendingCategoryRequest flag
        final newHasPending = (cleanedRequested?.isNotEmpty ?? false);
        if (newHasPending != (user.hasPendingCategoryRequest ?? false)) {
          debugPrint(
              '[CategorySync] Updated hasPendingCategoryRequest for ${user.id}: ${user.hasPendingCategoryRequest} → $newHasPending');
          needsUpdate = true;
        }

        if (needsUpdate) {
          final syncedUser = user.copyWith(
            allowedCategories: cleanedAllowed,
            vendorCategories: cleanedVendor,
            requestedCategories: cleanedRequested,
            hasPendingCategoryRequest: newHasPending,
          );
          await _authRepository.updateUser(syncedUser);
          usersSynced++;
          debugPrint('[CategorySync] Synced user ${user.id}');
        }
      }

      debugPrint('[CategorySync] ===== MASTER SYNC COMPLETE: $usersSynced users updated =====');
    } catch (e) {
      debugPrint('[CategorySync] ERROR in master sync: $e');
      rethrow;
    }
  }

  /// Helper: Clean a category list by removing deleted/unknown keys and deduplicating
  /// Normalizes keys, removes invalid keys, removes duplicates, returns null if empty
  List<String>? _cleanCategoryList(
    List<String>? original,
    Set<String> validKeys,
    String fieldName,
    String userId,
  ) {
    if (original == null || original.isEmpty) return null;

    // Normalize all keys
    final normalized = original.map((k) => k.toLowerCase().trim()).toList();
    
    // Filter to only valid keys and deduplicate
    final cleaned = <String>{};
    int removedCount = 0;
    
    for (final key in normalized) {
      if (validKeys.contains(key)) {
        cleaned.add(key);
      } else {
        removedCount++;
        debugPrint(
            '[CategorySync] Removed invalid key "$key" from $fieldName for user $userId');
      }
    }

    if (cleaned.isEmpty) {
      if (removedCount > 0) {
        debugPrint(
            '[CategorySync] Field $fieldName is now empty for user $userId (removed $removedCount invalid keys)');
      }
      return null;
    }

    return cleaned.toList();
  }

  Future<void> _syncVendorCategoriesAfterDelete(String deletedKey) async {
    try {
      await _authRepository.ensureInitialized();
      final allUsers = await _authRepository.getAllUsers();

      for (final user in allUsers) {
        bool needsUpdate = false;

        final updatedAllowed = user.allowedCategories
            ?.where((key) {
              if (key == deletedKey) {
                debugPrint(
                    '[CategorySync] Removed from allowedCategories: $deletedKey for user ${user.id}');
                needsUpdate = true;
                return false;
              }
              return true;
            })
            .toList()
            .cast<String>();

        final updatedVendor = user.vendorCategories
            ?.where((key) {
              if (key == deletedKey) {
                debugPrint(
                    '[CategorySync] Removed from vendorCategories: $deletedKey for user ${user.id}');
                needsUpdate = true;
                return false;
              }
              return true;
            })
            .toList()
            .cast<String>();

        final updatedRequested = user.requestedCategories
            ?.where((key) {
              if (key == deletedKey) {
                debugPrint(
                    '[CategorySync] Removed from requestedCategories: $deletedKey for user ${user.id}');
                needsUpdate = true;
                return false;
              }
              return true;
            })
            .toList()
            .cast<String>();

        if (needsUpdate) {
          final syncedUser = user.copyWith(
            allowedCategories: updatedAllowed,
            vendorCategories: updatedVendor,
            requestedCategories: updatedRequested,
            hasPendingCategoryRequest:
                (updatedRequested?.isNotEmpty ?? false) ? true : false,
          );
          await _authRepository.updateUser(syncedUser);
          debugPrint(
              '[CategorySync] Synced user ${user.id} after category deletion');
        }
      }
    } catch (e) {
      debugPrint('[CategorySync] ERROR syncing after delete: $e');
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  List<CategoryModel> getAllCategories() {
    return state.categories;
  }

  CategoryModel? getCategoryByKey(String normalizedKey) {
    try {
      return state.categories.firstWhere(
        (c) => c.normalizedKey == normalizedKey,
      );
    } catch (_) {
      return null;
    }
  }
}

final categoryRepositoryProvider = Provider<MockCategoryRepository>((ref) {
  return MockCategoryRepository.instance;
});

final authRepositoryProvider = Provider<MockAuthRepository>((ref) {
  return MockAuthRepository.instance;
});

final categoryProvider =
    StateNotifierProvider<CategoryNotifier, CategoryState>((ref) {
  return CategoryNotifier(
    ref.watch(categoryRepositoryProvider),
    ref.watch(authRepositoryProvider),
  );
});

final activeCategoriesProvider = Provider<List<CategoryModel>>((ref) {
  return ref.watch(categoryProvider).activeCategories;
});

final allCategoriesProvider = Provider<List<CategoryModel>>((ref) {
  return ref.watch(categoryProvider).categories;
});
