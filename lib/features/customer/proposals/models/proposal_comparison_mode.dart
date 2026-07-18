/// How the customer sorts vendor proposals on the request detail screen.
enum ProposalComparisonMode {
  lowestPrice,
  fastestDelivery,
  nearestVendor,
  lowestDeliveryFee,
  mostComplete,
  recommended,
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
      case ProposalComparisonMode.lowestDeliveryFee:
        return 'Lowest delivery fee';
      case ProposalComparisonMode.mostComplete:
        return 'Most complete';
      case ProposalComparisonMode.recommended:
        return 'Recommended';
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
      case ProposalComparisonMode.lowestDeliveryFee:
        return 'Delivery Fee';
      case ProposalComparisonMode.mostComplete:
        return 'Complete';
      case ProposalComparisonMode.recommended:
        return 'Recommended';
    }
  }
}

