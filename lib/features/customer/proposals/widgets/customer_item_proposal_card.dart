import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../proposals/models/proposal.dart';
import '../models/customer_item_proposal_view.dart';

/// A card that shows all vendor offers for ONE requested item.
/// Unavailable items are never passed to this widget — they are filtered
/// upstream in [ProposalComparisonService.buildItemViews].
class CustomerItemProposalCard extends StatefulWidget {
  const CustomerItemProposalCard({
    super.key,
    required this.itemView,
    required this.onAcceptOffer,
    required this.onRejectOffer,
    this.enabled = true,
  });

  final CustomerItemProposalView itemView;
  final void Function(ItemVendorOffer offer) onAcceptOffer;
  final void Function(ItemVendorOffer offer) onRejectOffer;
  final bool enabled;

  @override
  State<CustomerItemProposalCard> createState() =>
      _CustomerItemProposalCardState();
}

class _CustomerItemProposalCardState extends State<CustomerItemProposalCard> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final iv = widget.itemView;

    final hasAccepted = iv.isAccepted;
    final headerColor =
        hasAccepted ? AppColors.success : AppColors.customerColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasAccepted ? AppColors.success : borderColor,
          width: hasAccepted ? 2 : 1,
        ),
        boxShadow: hasAccepted
            ? [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Item header ─────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Icon(Icons.shopping_basket_outlined,
                    size: 18, color: headerColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        iv.requestItemName,
                        style: AppTextStyles.subtitle(primaryText)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${iv.requestedQuantity}${iv.requestedUnit != null ? ' ${iv.requestedUnit}' : ''}'
                        '${iv.requestItemCategory.isNotEmpty ? ' · ${iv.requestItemCategory}' : ''}',
                        style: AppTextStyles.caption(secondaryText),
                      ),
                    ],
                  ),
                ),
                if (hasAccepted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '✓ Accepted',
                      style: AppTextStyles.caption(AppColors.success)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),

          // ── Vendor offers ────────────────────────────────────────────────
          ...iv.vendorOffers.asMap().entries.map((entry) {
            final idx = entry.key;
            final offer = entry.value;
            return _VendorOfferTile(
              offer: offer,
              isFirst: idx == 0,
              isLast: idx == iv.vendorOffers.length - 1,
              isDark: isDark,
              primaryText: primaryText,
              secondaryText: secondaryText,
              borderColor: borderColor,
              enabled: widget.enabled,
              onAccept: () => widget.onAcceptOffer(offer),
              onReject: () => widget.onRejectOffer(offer),
            );
          }),
        ],
      ),
    );
  }
}

class _VendorOfferTile extends StatelessWidget {
  const _VendorOfferTile({
    required this.offer,
    required this.isFirst,
    required this.isLast,
    required this.isDark,
    required this.primaryText,
    required this.secondaryText,
    required this.borderColor,
    required this.enabled,
    required this.onAccept,
    required this.onReject,
  });

  final ItemVendorOffer offer;
  final bool isFirst;
  final bool isLast;
  final bool isDark;
  final Color primaryText;
  final Color secondaryText;
  final Color borderColor;
  final bool enabled;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  Color get _accentColor {
    if (offer.isAccepted) return AppColors.success;
    if (offer.isRejected) return AppColors.error;
    if (offer.proposalItem.status == ProposalItemStatus.alternative) {
      return AppColors.warning;
    }
    return AppColors.customerColor;
  }

  @override
  Widget build(BuildContext context) {
    final isAccepted = offer.isAccepted;
    final isRejected = offer.isRejected;
    final isPending = offer.canAccept;
    final isAlt = offer.proposalItem.status == ProposalItemStatus.alternative;

    return Column(
      children: [
        if (!isFirst)
          Divider(height: 1, color: borderColor.withValues(alpha: 0.5)),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, isLast ? 16 : 12),
          child: Opacity(
            opacity: isRejected ? 0.45 : 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vendor name row + price
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: _accentColor.withValues(alpha: 0.12),
                      child: Icon(Icons.storefront_rounded,
                          size: 16, color: _accentColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  offer.maskedVendorName,
                                  style:
                                      AppTextStyles.bodyMedium(primaryText)
                                          .copyWith(
                                              fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (offer.isSameVendorAsAnother) ...[
                                const SizedBox(width: 6),
                                _SmallBadge(
                                    label: '🏪 Same Vendor',
                                    color: AppColors.customerColor),
                              ],
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.star_rounded,
                                  size: 12,
                                  color: Colors.amber.shade700),
                              const SizedBox(width: 2),
                              Text(
                                offer.ratingPlaceholder.toStringAsFixed(1),
                                style: AppTextStyles.caption(secondaryText),
                              ),
                              if (offer.distanceKm > 0) ...[
                                Text(' · ', style: AppTextStyles.caption(secondaryText)),
                                Text(
                                  '${offer.distanceKm.toStringAsFixed(1)} km',
                                  style: AppTextStyles.caption(secondaryText),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Price
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Rs. ${offer.itemSubtotal.toStringAsFixed(0)}',
                          style: AppTextStyles.subtitle(_accentColor),
                        ),
                        if (isAlt)
                          _SmallBadge(
                              label: 'Alternative', color: AppColors.warning),
                        if (isAccepted)
                          _SmallBadge(
                              label: '✓ Accepted', color: AppColors.success),
                        if (isRejected)
                          _SmallBadge(label: 'Rejected', color: AppColors.error),
                      ],
                    ),
                  ],
                ),

                // Item details
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (offer.displayItemName != offer.proposalItem.itemName ||
                        isAlt)
                      _DetailChip(
                        icon: Icons.label_outline_rounded,
                        label: offer.displayItemName,
                        color: secondaryText,
                      ),
                    if (offer.proposalItem.offeredBrandModel != null &&
                        offer.proposalItem.offeredBrandModel!.isNotEmpty)
                      _DetailChip(
                        icon: Icons.business_center_outlined,
                        label: offer.proposalItem.offeredBrandModel!,
                        color: secondaryText,
                      ),
                    if (offer.proposalItem.availableStock != null)
                      _DetailChip(
                        icon: Icons.inventory_2_outlined,
                        label: 'Stock: ${offer.proposalItem.availableStock}',
                        color: secondaryText,
                      ),
                    if (isAlt &&
                        offer.proposalItem.alternativeReason != null &&
                        offer.proposalItem.alternativeReason!.isNotEmpty)
                      _DetailChip(
                        icon: Icons.info_outline_rounded,
                        label: offer.proposalItem.alternativeReason!,
                        color: AppColors.warning,
                      ),
                  ],
                ),

                // Accept / Reject buttons (only for pending offers)
                if (isPending && enabled && !isRejected) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onReject,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            minimumSize: const Size(0, 38),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: onAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.customerColor,
                            minimumSize: const Size(0, 38),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Accept',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label,
            style:
                TextStyle(color: color, fontSize: 11)),
      ],
    );
  }
}

