/// Admin-managed category model for marketplace categories.
/// Foundation for future admin category management.
class CategoryModel {
  final String id;
  final String name; // Display name (e.g., "Home Appliances")
  final String normalizedKey; // Lowercase key (e.g., "home appliances")
  final bool isActive;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CategoryModel({
    required this.id,
    required this.name,
    required this.normalizedKey,
    this.isActive = true,
    required this.displayOrder,
    required this.createdAt,
    this.updatedAt,
  });

  CategoryModel copyWith({
    String? id,
    String? name,
    String? normalizedKey,
    bool? isActive,
    int? displayOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedKey: normalizedKey ?? this.normalizedKey,
      isActive: isActive ?? this.isActive,
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
      'displayOrder': displayOrder,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      normalizedKey: json['normalizedKey'] as String,
      isActive: json['isActive'] as bool? ?? true,
      displayOrder: json['displayOrder'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Validates that normalized key is unique (case-insensitive)
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

  /// Generates normalized key from display name
  static String generateNormalizedKey(String displayName) {
    return displayName.trim().toLowerCase();
  }
}

