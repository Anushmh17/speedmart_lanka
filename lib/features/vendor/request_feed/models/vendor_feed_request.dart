import '../../../requests/models/shopping_request.dart';
import '../../../../shared/utils/category_constants.dart';
import 'vendor_feed_enums.dart';

/// Enriched marketplace view of a customer request for the vendor feed.
class VendorFeedRequest {
  const VendorFeedRequest({
    required this.request,
    required this.distanceKm,
    required this.proposalCount,
    required this.urgency,
    required this.primaryCategory,
    required this.approximateArea,
    required this.district,
    required this.maxRadiusKm,
  });

  final ShoppingRequest request;
  final double distanceKm;
  final int proposalCount;
  final RequestUrgency urgency;
  final String primaryCategory;
  final String approximateArea;
  final String district;
  final double maxRadiusKm;

  int get itemCount => request.items.length;

  String get requestId => request.id;

  String get statusLabel => request.status.displayName;

  List<String> get allCategories {
    final cats = request.items
        .map((i) => i.category?.trim() ?? '')
        .where((c) => c.isNotEmpty)
        .map((c) => VendorCategories.display(VendorCategories.normalize(c)))
        .toSet()
        .toList();
    return cats.isNotEmpty ? cats : [VendorCategories.display(VendorCategories.normalize(primaryCategory))];
  }

  Duration get age => DateTime.now().difference(request.createdAt);

  String get timePostedLabel {
    final d = age;
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

