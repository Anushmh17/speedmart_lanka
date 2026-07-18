import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/theme3/theme3_empty_state.dart';
import '../../../../proposals/providers/proposal_provider.dart';
import '../../../../proposals/models/proposal.dart';
import '../../providers/customer_proposal_comparison_provider.dart';
import '../../models/customer_item_proposal_view.dart';
import '../../widgets/customer_item_proposal_card.dart';
import '../../widgets/customer_proposal_card.dart';
import '../../widgets/proposal_comparison_bar.dart';
import '../../../../requests/models/shopping_request.dart';
import '../../../../requests/models/request_category_fulfillment.dart';

/// Customer-facing proposal comparison screen.
///
/// Default mode: **"By Item"** — one card per requested item, showing all
/// vendor offers for that item. Unavailable items are never shown.
/// Toggle to **"By Vendor"** for the legacy whole-proposal view.
class CustomerProposalComparisonScreen extends ConsumerStatefulWidget {
  final String requestId;
  final ShoppingRequest request;

  const CustomerProposalComparisonScreen({
    super.key,
    required this.requestId,
    required this.request,
  });

  @override
  ConsumerState<CustomerProposalComparisonScreen> createState() =>
      _CustomerProposalComparisonScreenState();
}

class _CustomerProposalComparisonScreenState
    extends ConsumerState<CustomerProposalComparisonScreen> {
  /// false = "By Item" (default), true = "By Vendor"
  bool _byVendorMode = false;
  bool _isAcceptingProposal = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      final proposals = await ref
          .read(proposalProvider.notifier)
          .loadProposalsForRequest(widget.requestId);
      if (!mounted) return;
      ref
          .read(customerProposalComparisonProvider(widget.requestId).notifier)
          .updateFrom(proposals: proposals, request: widget.request);
    });
  }

  // ── Item-level accept ───────────────────────────────────────────────────

  void _onAcceptOffer(ItemVendorOffer offer) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Accept this offer?'),
        content: Text(
          'Accept ${offer.displayItemName} from ${offer.maskedVendorName}?\n\n'
          'Other vendors\'s offers for this item will be automatically declined.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.customerColor),
            child: const Text('Accept', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true && mounted) {
        await ref.read(proposalProvider.notifier).acceptProposalItem(
              proposalId: offer.vendorProposal.id,
              requestItemId: offer.proposalItem.requestItemId,
              requestId: widget.requestId,
            );
      }
    });
  }

  void _onRejectOffer(ItemVendorOffer offer) {
    showDialog<String>(
      context: context,
      builder: (ctx) {
        final reasons = [
          'Price too high',
          'Wrong product',
          'Need exact brand only',
          'Prefer another shop',
        ];
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Reject this offer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Other vendors can still offer this item.'),
              const SizedBox(height: 12),
              ...reasons.map((r) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(r),
                    onTap: () => Navigator.pop(ctx, r),
                  )),
            ],
          ),
        );
      },
    ).then((reason) async {
      if (reason != null && mounted) {
        await ref.read(proposalProvider.notifier).rejectProposalItem(
              proposalId: offer.vendorProposal.id,
              requestItemId: offer.proposalItem.requestItemId,
              requestId: widget.requestId,
            );
      }
    });
  }

  // ── Whole-proposal (by-vendor) actions ──────────────────────────────────

  void _acceptProposal(Proposal proposal) {
    if (_isAcceptingProposal) return;
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Accept Proposal?'),
        content: const Text(
            'Pending proposals from other shops will be automatically rejected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.customerColor),
            child: const Text('Accept'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true && mounted) {
        setState(() {
          _isAcceptingProposal = true;
        });
        try {
          await ref.read(proposalProvider.notifier).acceptProposal(
                proposal.id,
                widget.requestId,
                categoryNormalized: proposal.categoryNormalized,
              );
          if (mounted) {
            context.push('/customer/payment', extra: {
              'proposal': proposal,
              'requestId': widget.requestId,
            });
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
            );
          }
        } finally {
          if (mounted) {
            setState(() {
              _isAcceptingProposal = false;
            });
          }
        }
      }
    });
  }

  void _rejectProposal(Proposal proposal) {
    showDialog<String>(
      context: context,
      builder: (ctx) {
        final reasons = [
          'Price too high',
          'Product is different',
          'Need exact product only',
          'Search again',
        ];
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Reject Proposal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'This doesn\'t reject the request. Other shops can still bid.'),
              const SizedBox(height: 12),
              ...reasons.map((reason) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(reason),
                    onTap: () => Navigator.pop(ctx, reason),
                  )),
            ],
          ),
        );
      },
    ).then((reason) async {
      if (reason != null && mounted) {
        await ref.read(proposalProvider.notifier).rejectProposal(
              proposal.id,
              widget.requestId,
              reason,
            );
      }
    });
  }

  bool _categoryHasAccepted(Proposal proposal, List<Proposal> proposals) {
    final category = proposal.categoryNormalized;
    if (category == null || category.isEmpty) {
      return proposals.any((p) => p.status == ProposalStatus.accepted);
    }
    final status = widget.request.getCategoryStatus(category);
    if (status == RequestCategoryStatus.accepted ||
        status == RequestCategoryStatus.codConfirmed ||
        status == RequestCategoryStatus.outForDelivery ||
        status == RequestCategoryStatus.paid ||
        status == RequestCategoryStatus.completed) {
      return true;
    }
    return proposals.any(
      (p) =>
          p.status == ProposalStatus.accepted &&
          p.categoryNormalized == category,
    );
  }

  // ── Pay for accepted items ───────────────────────────────────────────────

  void _payForAcceptedItems(List<Proposal> proposals) {
    // Find a proposal that was accepted — use it for the payment screen.
    final accepted =
        proposals.where((p) => p.status == ProposalStatus.accepted).toList();
    if (accepted.isEmpty) return;
    // Use the first accepted proposal as the primary one.
    context.push('/customer/payment', extra: {
      'proposal': accepted.first,
      'requestId': widget.requestId,
    });
  }

  @override
  Widget build(BuildContext context) {
    final proposalState = ref.watch(proposalProvider);
    final comparisonState =
        ref.watch(customerProposalComparisonProvider(widget.requestId));

    // Keep comparison views in sync whenever proposals change.
    ref.listen(proposalProvider, (prev, next) {
      if (prev?.proposals != next.proposals) {
        ref
            .read(
                customerProposalComparisonProvider(widget.requestId).notifier)
            .updateFrom(
              proposals: next.proposals,
              request: widget.request,
            );
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final hasAcceptedProposal =
        proposalState.proposals.any((p) => p.status == ProposalStatus.accepted);
    final hasAnyAcceptedItem = comparisonState.itemViews
        .any((iv) => iv.isAccepted);

    if (proposalState.isLoading) {
      return Scaffold(
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        body: Column(
          children: [
            _buildHeader(context, isDark, primaryText, secondaryText),
            const Expanded(
              child: Center(child: CircularProgressIndicator(color: AppColors.customerColor)),
            ),
          ],
        ),
      );
    }

    if (proposalState.proposals.isEmpty) {
      return Scaffold(
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        body: Column(
          children: [
            _buildHeader(context, isDark, primaryText, secondaryText),
            Expanded(
              child: Theme3EmptyState(
                icon: Icons.shopping_bag_outlined,
                title: 'No Proposals Yet',
                subtitle: 'Shops will respond to your request shortly',
              ),
            ),
          ],
        ),
      );
    }

    final itemViews = comparisonState.itemViews;
    final proposalViews = comparisonState.views;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Column(
        children: [
          _buildHeader(context, isDark, primaryText, secondaryText),

          // ── Mode toggle ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            child: Row(
              children: [
                Expanded(
                  child: _ModeToggle(
                    label: '🛒 By Item',
                    selected: !_byVendorMode,
                    onTap: () => setState(() => _byVendorMode = false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeToggle(
                    label: '🏪 By Shop',
                    selected: _byVendorMode,
                    onTap: () => setState(() => _byVendorMode = true),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Accepted banner ──────────────────────────────────
                  if (hasAcceptedProposal || hasAnyAcceptedItem)
                    _AcceptedBanner(
                      onPay: () => _payForAcceptedItems(proposalState.proposals),
                    ),

                  // ── BY ITEM mode ─────────────────────────────────────
                  if (!_byVendorMode) ...[
                    if (itemViews.isEmpty)
                      Theme3EmptyState(
                        icon: Icons.shopping_bag_outlined,
                        title: 'No Offers Available',
                        subtitle:
                            'All items are marked unavailable by vendors.',
                      )
                    else ...[
                      Text(
                        '${itemViews.length} items with offers',
                        style: AppTextStyles.caption(secondaryText),
                      ),
                      const SizedBox(height: 12),
                      ...itemViews.map((iv) => CustomerItemProposalCard(
                            itemView: iv,
                            onAcceptOffer: _onAcceptOffer,
                            onRejectOffer: _onRejectOffer,
                          )),
                    ],
                  ],

                  // ── BY VENDOR mode ───────────────────────────────────
                  if (_byVendorMode) ...[
                    ProposalComparisonBar(
                      selectedMode: comparisonState.mode,
                      proposalCount: proposalViews.length,
                      onModeChanged: (mode) {
                        ref
                            .read(customerProposalComparisonProvider(
                                    widget.requestId)
                                .notifier)
                            .setMode(
                              mode,
                              proposals: proposalState.proposals,
                              request: widget.request,
                            );
                      },
                    ),
                    const SizedBox(height: 12),
                    ...proposalViews.map((view) {
                      final categoryAccepted = _categoryHasAccepted(
                          view.proposal, proposalState.proposals);
                      final canAct =
                          view.canAcceptOrReject && !categoryAccepted;
                      return CustomerProposalCard(
                        view: view,
                        requestId: widget.requestId,
                        enabled: true,
                        onAccept: view.isAccepted
                            ? () {
                                context.push('/customer/payment', extra: {
                                  'proposal': view.proposal,
                                  'requestId': widget.requestId,
                                });
                              }
                            : canAct
                                ? () => _acceptProposal(view.proposal)
                                : null,
                        onReject: canAct
                            ? () => _rejectProposal(view.proposal)
                            : null,
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Floating Pay button (shown when items accepted) ──────────────
      floatingActionButton: (hasAnyAcceptedItem || hasAcceptedProposal)
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.customerColor,
              onPressed: () =>
                  _payForAcceptedItems(proposalState.proposals),
              icon: const Icon(Icons.payment_rounded, color: Colors.white),
              label: const Text('Pay Now',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, Color primaryText,
      Color secondaryText) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        MediaQuery.of(context).padding.top + AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryText),
            style: IconButton.styleFrom(
              backgroundColor:
                  isDark ? AppColors.surfaceElevatedDark : AppColors.borderLight,
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Shop Owner Proposals', style: AppTextStyles.h2(primaryText)),
                SizedBox(height: AppSpacing.xs),
                Text(
                  'Choose the best offer for each item',
                  style: AppTextStyles.bodySmall(secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.customerColor
              : (isDark
                  ? AppColors.surfaceElevatedDark
                  : AppColors.borderLight),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.customerColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _AcceptedBanner extends StatelessWidget {
  const _AcceptedBanner({required this.onPay});
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border:
            Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: AppColors.success, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You\'ve accepted some offers! Tap Pay Now to complete your order.',
              style: AppTextStyles.bodySmall(AppColors.success),
            ),
          ),
          TextButton(
            onPressed: onPay,
            style: TextButton.styleFrom(foregroundColor: AppColors.success),
            child: const Text('Pay Now',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

