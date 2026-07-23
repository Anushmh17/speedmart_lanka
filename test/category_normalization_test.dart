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
  });
}
