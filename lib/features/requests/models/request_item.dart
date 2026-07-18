class RequestItem {
  final String id;
  final String itemName;
  final String? requestId;
  final int quantity;
  final String? unit;
  final String? description;
  final String? category;
  final List<String> imageUrls;
  final String? preferredBrand;

  // Compatibility getter to prevent breaking changes in other screens
  String get name => itemName;

  RequestItem({
    required this.id,
    String? itemName,
    this.requestId,
    required this.quantity,
    this.unit,
    this.description,
    this.category,
    this.imageUrls = const [],
    this.preferredBrand,
    @Deprecated('Use itemName instead') String? name,
  }) : itemName = (itemName != null && itemName.isNotEmpty) ? itemName : (name ?? '');

  RequestItem copyWith({
    String? id,
    String? itemName,
    String? name,
    String? requestId,
    int? quantity,
    String? unit,
    String? description,
    String? category,
    List<String>? imageUrls,
    String? preferredBrand,
  }) {
    return RequestItem(
      id: id ?? this.id,
      itemName: itemName ?? name ?? this.itemName,
      requestId: requestId ?? this.requestId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      description: description ?? this.description,
      category: category ?? this.category,
      imageUrls: imageUrls ?? this.imageUrls,
      preferredBrand: preferredBrand ?? this.preferredBrand,
    );
  }

  // Helper mappings for local storage saving/retrieval
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'itemName': itemName,
      'requestId': requestId,
      'quantity': quantity,
      'unit': unit,
      'description': description,
      'category': category,
      'imageUrls': imageUrls,
      'preferredBrand': preferredBrand,
    };
  }

  factory RequestItem.fromJson(Map<String, dynamic> json) {
    return RequestItem(
      id: json['id'] as String? ?? '',
      itemName: json['itemName'] as String? ?? json['name'] as String? ?? '',
      requestId: json['requestId'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      unit: json['unit'] as String?,
      description: json['description'] as String?,
      category: json['category'] as String?,
      imageUrls: List<String>.from(json['imageUrls'] as List? ?? []),
      preferredBrand: json['preferredBrand'] as String?,
    );
  }
}

