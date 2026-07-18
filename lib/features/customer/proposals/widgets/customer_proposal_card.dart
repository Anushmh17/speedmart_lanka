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
    this.overrideBorderColor,
  });

  final CustomerProposalView view;
  final String requestId;
  final bool enabled;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onSave;
  final bool isSaved;
  final Color? overrideBorderColor;

  @override
  State<CustomerProposalCard> createState() => _CustomerProposalCardState();
}

class _CustomerProposalCardState extends State<CustomerProposalCard> {
  bool _expanded = false;

  /// Blue for pending/submitted proposals, orange only after acceptance.
  Color get _accentColor {
    final status = widget.view.proposal.status;
    if (status == ProposalStatus.accepted) return AppColors.customerColor;
    return AppColors.vendorColor;
  }

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
            color: widget.overrideBorderColor ?? (v.isBestForMode ? _accentColor : borderColor),
            width: widget.overrideBorderColor != null ? 1.5 : (v.isBestForMode ? 2 : 1),
          ),
          boxShadow: [
            if (v.isBestForMode)
              BoxShadow(
                color: _accentColor.withValues(alpha: 0.12),
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
                                color: _accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Best match',
                                style: AppTextStyles.caption(_accentColor)
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
                          backgroundColor: _accentColor.withValues(alpha: 0.12),
                          child: Icon(
                            Icons.storefront_rounded,
                            color: _accentColor,
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
                                      ' · Shop rating',
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
                              style: AppTextStyles.subtitle(_accentColor),
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
                          accentColor: _accentColor,
                        ),
                        if (v.distanceKm > 0)
                          _MetaChip(
                            icon: Icons.near_me_outlined,
                            label: '${v.distanceKm.toStringAsFixed(1)} km',
                            isDark: isDark,
                            accentColor: _accentColor,
                          ),
                        _MetaChip(
                          icon: Icons.receipt_long_outlined,
                          label:
                              'Delivery Rs. ${v.deliveryFee.toStringAsFixed(0)}',
                          isDark: isDark,
                          accentColor: _accentColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Builder(builder: (context) {
                      final altCount = p.items
                          .where((i) => i.status == ProposalItemStatus.alternative)
                          .length;
                      final naCount = p.items
                          .where((i) => i.status == ProposalItemStatus.unavailable)
                          .length;
                      if (altCount == 0 && naCount == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (altCount > 0)
                              _StatusWarningChip(
                                icon: Icons.swap_horiz_rounded,
                                label: '$altCount alternative${altCount > 1 ? 's' : ''} offered',
                                color: AppColors.warning,
                              ),
                            if (naCount > 0)
                              _StatusWarningChip(
                                icon: Icons.cancel_outlined,
                                label: '$naCount item${naCount > 1 ? 's' : ''} unavailable',
                                color: AppColors.error,
                              ),
                          ],
                        ),
                      );
                    }),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _expanded ? 'Hide details' : 'View details',
                            style: AppTextStyles.caption(_accentColor)
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
                                  : _accentColor,
                              size: 20,
                            ),
                            tooltip:
                                widget.isSaved ? 'Remove from saved' : 'Save for later',
                          ),
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: _accentColor,
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
                      accentColor: _accentColor,
                    ),
                    if (p.notes != null && p.notes!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Shop Owner note',
                        style: AppTextStyles.caption(secondaryText),
                      ),
                      Text(
                        p.notes!,
                        style: AppTextStyles.bodySmall(primaryText),
                      ),
                    ],
                    const SizedBox(height: 8),
                    ...([...p.items]
                      ..sort((a, b) {
                        int rank(ProposalItemStatus s) {
                          if (s == ProposalItemStatus.available) return 0;
                          if (s == ProposalItemStatus.alternative) return 1;
                          return 2;
                        }
                        return rank(a.status).compareTo(rank(b.status));
                      })).take(4).map((item) {
                      if (item.status == ProposalItemStatus.unavailable) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            children: [
                              Icon(Icons.cancel_outlined, size: 13, color: AppColors.error),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  '${item.itemName} — unavailable',
                                  style: AppTextStyles.caption(AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      if (item.status == ProposalItemStatus.alternative) {
                        final altName = (item.alternativeName != null && item.alternativeName!.isNotEmpty)
                            ? item.alternativeName!
                            : 'Alternative product';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.swap_horiz_rounded, size: 13, color: AppColors.warning),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      '${item.itemName} — alternative offered',
                                      style: AppTextStyles.caption(AppColors.warning)
                                          .copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 18, top: 1),
                                child: Text(
                                  '↳ $altName × ${item.quantity} @ Rs. ${item.unitPrice.toStringAsFixed(0)}',
                                  style: AppTextStyles.caption(secondaryText),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      // available
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 13, color: AppColors.success),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                '${item.itemName} × ${item.quantity} @ Rs. ${item.unitPrice.toStringAsFixed(0)}',
                                style: AppTextStyles.caption(secondaryText),
                              ),
                            ),
                          ],
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
                                backgroundColor: _accentColor,
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
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final bool isDark;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accentColor),
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
    this.accentColor = AppColors.customerColor,
  });

  final String label;
  final String value;
  final bool isDark;
  final bool bold;
  final Color accentColor;

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
                ? AppTextStyles.subtitle(accentColor)
                : AppTextStyles.bodyMedium(primary),
          ),
        ],
      ),
    );
  }
}

/// Small coloured chip shown in the proposal card header to warn the customer
/// that some items have alternatives or are unavailable.
class _StatusWarningChip extends StatelessWidget {
  const _StatusWarningChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

