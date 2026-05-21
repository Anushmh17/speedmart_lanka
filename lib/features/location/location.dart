// Speedmart Lanka – Location Feature
//
// Import this barrel file to access the entire location module.
//
// ```dart
// import 'package:speedmart_lanka/features/location/location.dart';
// ```

// Models
export 'models/delivery_location.dart';
export 'models/gps_location_result.dart';
export 'models/location_suggestion.dart';
export 'models/sri_lanka_district.dart';
export 'models/sri_lanka_province.dart';

// Data
export 'data/sri_lanka_data.dart';

// Utils
export 'utils/haversine.dart';

// Services
export 'services/distance_calculation_service.dart';
export 'services/gps_location_service.dart';
export 'services/reverse_geocoding_service.dart';
export 'services/sri_lanka_location_service.dart';

// Repositories
export 'repositories/location_repository.dart';
export 'repositories/local_location_repository.dart';

// Providers
export 'providers/location_provider.dart';

// Widgets
export 'widgets/district_dropdown.dart';
export 'widgets/province_dropdown.dart';
export 'widgets/searchable_location_field.dart';
