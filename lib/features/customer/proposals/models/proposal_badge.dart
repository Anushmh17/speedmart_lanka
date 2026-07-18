import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

enum ProposalBadge {
  bestPrice,
  fastestDelivery,
  highestRated,
  popularVendor,
}

extension ProposalBadgeExtension on ProposalBadge {
  String get label {
    switch (this) {
      case ProposalBadge.bestPrice:
        return 'Best Price';
      case ProposalBadge.fastestDelivery:
        return 'Fastest Delivery';
      case ProposalBadge.highestRated:
        return 'Highest Rated';
      case ProposalBadge.popularVendor:
        return 'Popular Vendor';
    }
  }

  IconData get icon {
    switch (this) {
      case ProposalBadge.bestPrice:
        return Icons.local_offer_outlined;
      case ProposalBadge.fastestDelivery:
        return Icons.flash_on_outlined;
      case ProposalBadge.highestRated:
        return Icons.star_rounded;
      case ProposalBadge.popularVendor:
        return Icons.local_fire_department_outlined;
    }
  }

  Color get color {
    switch (this) {
      case ProposalBadge.bestPrice:
        return AppColors.success;
      case ProposalBadge.fastestDelivery:
        return AppColors.warning;
      case ProposalBadge.highestRated:
        return Colors.amber;
      case ProposalBadge.popularVendor:
        return AppColors.error;
    }
  }
}

