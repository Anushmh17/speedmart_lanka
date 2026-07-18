import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../proposals/models/proposal.dart';

class VendorProposalStatusChip extends StatelessWidget {
  const VendorProposalStatusChip({super.key, required this.status});

  final ProposalStatus status;

  Color get _color {
    switch (status) {
      case ProposalStatus.draft:
        return AppColors.warning;
      case ProposalStatus.submitted:
      case ProposalStatus.updated:
        return AppColors.vendorColor;
      case ProposalStatus.accepted:
        return AppColors.success;
      case ProposalStatus.rejected:
      case ProposalStatus.withdrawn:
      case ProposalStatus.expired:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withOpacity(0.35)),
      ),
      child: Text(
        status.displayName,
        style: AppTextStyles.caption(_color).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

