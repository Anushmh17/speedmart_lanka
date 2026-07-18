/// How the vendor request feed is sorted.
enum VendorFeedSortMode {
  nearest,
  newest,
  lowCompetition,
}

extension VendorFeedSortModeExtension on VendorFeedSortMode {
  String get label {
    switch (this) {
      case VendorFeedSortMode.nearest:
        return 'Nearest';
      case VendorFeedSortMode.newest:
        return 'Newest';
      case VendorFeedSortMode.lowCompetition:
        return 'Low competition';
    }
  }
}

/// Urgency derived from how long ago the request was posted.
enum RequestUrgency {
  normal,
  medium,
  high,
}

extension RequestUrgencyExtension on RequestUrgency {
  String get label {
    switch (this) {
      case RequestUrgency.normal:
        return 'Open';
      case RequestUrgency.medium:
        return 'Active';
      case RequestUrgency.high:
        return 'Urgent';
    }
  }
}

