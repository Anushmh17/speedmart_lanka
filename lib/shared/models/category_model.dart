/// Admin-managed category model for marketplace categories.
class CategoryModel {
  final String id;
  final String name;
  final String normalizedKey;
  final bool isActive;
  final bool isDefault;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CategoryModel({
    required this.id,
    required this.name,
    required this.normalizedKey,
    this.isActive = true,
    this.isDefault = false,
    this.displayOrder = 0,
    required this.createdAt,
    this.updatedAt,
  });

  /// Alias so admin screens using displayName still work
  String get displayName => name;

  CategoryModel copyWith({
    String? id,
    String? name,
    String? normalizedKey,
    bool? isActive,
    bool? isDefault,
    int? displayOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedKey: normalizedKey ?? this.normalizedKey,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'normalizedKey': normalizedKey,
      'isActive': isActive,
      'isDefault': isDefault,
      'displayOrder': displayOrder,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: (json['name'] ?? json['display_name'] ?? '') as String,
      normalizedKey: (json['normalizedKey'] ?? json['normalized_key'] ?? '') as String,
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
      isDefault: json['isDefault'] as bool? ?? json['is_default'] as bool? ?? false,
      displayOrder: json['displayOrder'] as int? ?? 0,
      createdAt: DateTime.parse((json['createdAt'] ?? json['created_at']) as String),
      updatedAt: (json['updatedAt'] ?? json['updated_at']) != null
          ? DateTime.parse((json['updatedAt'] ?? json['updated_at']) as String)
          : null,
    );
  }

  static bool isNormalizedKeyUnique(
    String normalizedKey,
    List<CategoryModel> existingCategories, {
    String? excludeId,
  }) {
    return !existingCategories.any(
      (cat) =>
          cat.normalizedKey.toLowerCase() == normalizedKey.toLowerCase() &&
          cat.id != excludeId,
    );
  }

  static String generateNormalizedKey(String displayName) {
    return displayName.trim().toLowerCase();
  }
}
