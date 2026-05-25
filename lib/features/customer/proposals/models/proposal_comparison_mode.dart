/// How the customer sorts vendor proposals on the request detail screen.
enum ProposalComparisonMode {
  lowestPrice,
  fastestDelivery,
  nearestVendor,
}

extension ProposalComparisonModeExtension on ProposalComparisonMode {
  String get label {
    switch (this) {
      case ProposalComparisonMode.lowestPrice:
        return 'Lowest price';
      case ProposalComparisonMode.fastestDelivery:
        return 'Fastest delivery';
      case ProposalComparisonMode.nearestVendor:
        return 'Nearest vendor';
    }
  }

  String get shortLabel {
    switch (this) {
      case ProposalComparisonMode.lowestPrice:
        return 'Price';
      case ProposalComparisonMode.fastestDelivery:
        return 'Delivery';
      case ProposalComparisonMode.nearestVendor:
        return 'Nearest';
    }
  }
}
