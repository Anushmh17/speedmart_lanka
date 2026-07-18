/// Normalizes category lists: trim, lowercase, remove duplicates, remove empty strings
List<String> normalizeCategories(List<dynamic>? input) {
  if (input == null || input.isEmpty) return [];
  return input
      .cast<dynamic>()
      .map<String>((e) => e.toString().trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();
}

