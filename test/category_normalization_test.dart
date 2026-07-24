import 'package:flutter_test/flutter_test.dart';
import 'package:speedmart_lanka/shared/utils/category_constants.dart';

void main() {
  group('VendorCategories normalization', () {
    test('normalizes underscore category keys to the canonical display form', () {
      expect(VendorCategories.normalize('vehicle_parts'), 'vehicle parts');
      expect(VendorCategories.normalize('home_appliances'), 'home appliances');
    });

    test('renders normalized categories with title case display names', () {
      expect(VendorCategories.display(VendorCategories.normalize('vehicle_parts')), 'Vehicle Parts');
      expect(VendorCategories.display(VendorCategories.normalize('home_appliances')), 'Home Appliances');
    });

    test('does not expose the Other category in the shared vendor category registry', () {
      expect(VendorCategories.displayNames.contains('Other'), isFalse);
      expect(VendorCategories.normalizedList.contains('other'), isFalse);
      expect(VendorCategories.isValid('other'), isFalse);
    });
  });
}
