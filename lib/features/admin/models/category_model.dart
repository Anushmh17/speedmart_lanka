class CategoryModel {
  final String id;
  final String normalizedKey;
  final String displayName;
  final bool isActive;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const CategoryModel({
    required this.id,
    required this.normalizedKey,
    required this.displayName,
    required this.isActive,
    required this.isDefault,
    required this.createdAt,
    this.updatedAt,
  });

  CategoryModel copyWith({
    String? id,
    String? normalizedKey,
    String? displayName,
    bool? isActive,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      normalizedKey: normalizedKey ?? this.normalizedKey,
      displayName: displayName ?? this.displayName,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'normalized_key': normalizedKey,
      'display_name': displayName,
      'is_active': isActive,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      normalizedKey: json['normalized_key'] as String,
      displayName: json['display_name'] as String,
      isActive: json['is_active'] as bool? ?? true,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}
