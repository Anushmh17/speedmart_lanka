import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../models/proposal_badge.dart';

class ProposalBadgeDisplay extends StatelessWidget {
  const ProposalBadgeDisplay({
    super.key,
    required this.badges,
  });

  final List<ProposalBadge> badges;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: badges.map((badge) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badge.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: badge.color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(badge.icon, size: 12, color: badge.color),
              const SizedBox(width: 4),
              Text(
                badge.label,
                style: AppTextStyles.caption(badge.color)
                    .copyWith(fontWeight: FontWeight.w600, fontSize: 11),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

