import 'sri_lanka_district.dart';

/// Represents one of Sri Lanka's 9 administrative provinces.
class SriLankaProvince {
  final int id;
  final String name;
  final List<SriLankaDistrict> districts;

  const SriLankaProvince({
    required this.id,
    required this.name,
    required this.districts,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SriLankaProvince && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}

