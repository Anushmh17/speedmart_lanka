import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../proposals/models/proposal.dart';
import '../models/customer_proposal_view.dart';
import '../presentation/modals/vendor_profile_preview_modal.dart';
import 'proposal_badge_display.dart';

/// Expandable vendor proposal card with pricing summary and quick actions.
class CustomerProposalCard extends StatefulWidget {
  const CustomerProposalCard({
    super.key,
    required this.view,
    required this.requestId,
    required this.enabled,
    this.onAccept,
    this.onReject,
    this.onSave,
    this.isSaved = false,
  });

  final CustomerProposalView view;
  final String requestId;
  final bool enabled;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onSave;
  final bool isSaved;

  @override
  State<CustomerProposalCard> createState() => _CustomerProposalCardState();
}

class _CustomerProposalCardState extends State<CustomerProposalCard> {
  bool _expanded = false;

  Color _statusColor(ProposalStatus status) {
    switch (status) {
      case ProposalStatus.accepted:
        return AppColors.success;
      case ProposalStatus.rejected:
      case ProposalStatus.withdrawn:
      case ProposalStatus.expired:
        return AppColors.error;
      case ProposalStatus.draft:
        return AppColors.warning;
      default:
        return AppColors.customerColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final v = widget.view;
    final p = v.proposal;
    final inactive = v.isInactive || !widget.enabled;

    return Opacity(
      opacity: inactive ? 0.55 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: v.isBestForMode ? AppColors.customerColor : borderColor,
            width: v.isBestForMode ? 2 : 1,
          ),
          boxShadow: [
            if (v.isBestForMode)
              BoxShadow(
                color: AppColors.customerColor.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: inactive
                  ? null
                  : () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (v.isBestForMode || v.badges.isNotEmpty) ...[
                      Row(
                        children: [
                          if (v.isBestForMode)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.customerColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Best match',
                                style: AppTextStyles.caption(AppColors.customerColor)
                                    .copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                      ),
                      if (v.badges.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ProposalBadgeDisplay(badges: v.badges),
                      ],
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor:
                              AppColors.customerColor.withValues(alpha: 0.12),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: AppColors.customerColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: inactive
                                ? null
                                : () => VendorProfilePreviewModal.show(
                                      context,
                                      proposal: p,
                                      requestId: widget.requestId,
                                    ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  v.maskedVendorName,
                                  style: AppTextStyles.subtitle(primaryText),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: Colors.amber.shade700,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      v.ratingPlaceholder.toStringAsFixed(1),
                                      style: AppTextStyles.caption(secondaryText),
                                    ),
                                    Text(
                                      ' · Vendor rating',
                                      style: AppTextStyles.caption(secondaryText),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Rs. ${v.totalPrice.toStringAsFixed(0)}',
                              style:
                                  AppTextStyles.subtitle(AppColors.customerColor),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(p.status)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                p.status.displayName,
                                style: AppTextStyles.caption(
                                  _statusColor(p.status),
                                ).copyWith(fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _MetaChip(
                          icon: Icons.local_shipping_outlined,
                          label: v.estimatedDelivery,
                          isDark: isDark,
                        ),
                        if (v.distanceKm > 0)
                          _MetaChip(
                            icon: Icons.near_me_outlined,
                            label: '${v.distanceKm.toStringAsFixed(1)} km',
                            isDark: isDark,
                          ),
                        _MetaChip(
                          icon: Icons.receipt_long_outlined,
                          label:
                              'Delivery Rs. ${v.deliveryFee.toStringAsFixed(0)}',
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _expanded ? 'Hide details' : 'View details',
                            style: AppTextStyles.caption(AppColors.customerColor)
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (widget.onSave != null && !inactive)
                          IconButton(
                            onPressed: widget.onSave,
                            icon: Icon(
                              widget.isSaved
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_outline_rounded,
                              color: widget.isSaved
                                  ? AppColors.error
                                  : AppColors.customerColor,
                              size: 20,
                            ),
                            tooltip:
                                widget.isSaved ? 'Remove from saved' : 'Save for later',
                          ),
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: AppColors.customerColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    _PricingRow(
                      label: 'Items subtotal',
                      value: 'Rs. ${v.subtotal.toStringAsFixed(2)}',
                      isDark: isDark,
                    ),
                    _PricingRow(
                      label: 'Delivery fee',
                      value: 'Rs. ${v.deliveryFee.toStringAsFixed(2)}',
                      isDark: isDark,
                    ),
                    const Divider(height: 16),
                    _PricingRow(
                      label: 'Total',
                      value: 'Rs. ${v.totalPrice.toStringAsFixed(2)}',
                      isDark: isDark,
                      bold: true,
                    ),
                    if (p.notes != null && p.notes!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Vendor note',
                        style: AppTextStyles.caption(secondaryText),
                      ),
                      Text(
                        p.notes!,
                        style: AppTextStyles.bodySmall(primaryText),
                      ),
                    ],
                    const SizedBox(height: 8),
                    ...p.items.take(4).map((item) {
                      final line =
                          item.status == ProposalItemStatus.unavailable
                              ? '${item.itemName} — unavailable'
                              : '${item.itemName} × ${item.quantity} @ Rs. ${item.unitPrice.toStringAsFixed(0)}';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: AppTextStyles.caption(secondaryText),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    if (!inactive && v.canAcceptOrReject) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: widget.onReject,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                                minimumSize: const Size(0, 44),
                              ),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: widget.onAccept,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.customerColor,
                                minimumSize: const Size(0, 44),
                              ),
                              child: Text(
                                v.isAccepted ? 'Pay now' : 'Accept',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: inactive
                            ? null
                            : () {
                                context.push(
                                  '/customer/proposals/detail',
                                  extra: {
                                    'proposal': p,
                                    'requestId': widget.requestId,
                                  },
                                );
                              },
                        child: const Text('Full details & messages'),
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.customerColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.customerColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption(
              isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _PricingRow extends StatelessWidget {
  const _PricingRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool isDark;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final primary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: bold
                ? AppTextStyles.subtitle(primary)
                : AppTextStyles.bodySmall(secondary),
          ),
          Text(
            value,
            style: bold
                ? AppTextStyles.subtitle(AppColors.customerColor)
                : AppTextStyles.bodyMedium(primary),
          ),
        ],
      ),
    );
  }
}
