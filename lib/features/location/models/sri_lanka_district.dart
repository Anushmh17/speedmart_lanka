/// Represents one of Sri Lanka's 25 administrative districts.
class SriLankaDistrict {
  final int id;
  final int provinceId;
  final String name;

  const SriLankaDistrict({
    required this.id,
    required this.provinceId,
    required this.name,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SriLankaDistrict && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}

