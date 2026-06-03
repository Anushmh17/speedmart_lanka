import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../proposals/providers/proposal_provider.dart';
import '../../providers/customer_proposal_comparison_provider.dart';
import '../../widgets/customer_proposal_card.dart';
import '../../widgets/proposal_comparison_bar.dart';
import '../../../../requests/models/shopping_request.dart';
import '../../../../proposals/models/proposal.dart';

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
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      await ref
          .read(proposalProvider.notifier)
          .loadProposalsForRequest(widget.requestId);
    });
  }

  void _acceptProposal(Proposal proposal) {
    showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final primaryText =
            isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Accept Proposal?'),
          content: const Text(
              'Pending proposals from other vendors will be automatically rejected.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.customerColor,
              ),
              child: const Text('Accept'),
            ),
          ],
        );
      },
    ).then((confirmed) async {
      if (confirmed == true && mounted) {
        await ref
            .read(proposalProvider.notifier)
            .acceptProposal(proposal.id, widget.requestId);
        if (mounted) {
          context.push(
            '/customer/payment',
            extra: {
              'proposal': proposal,
              'requestId': widget.requestId,
            },
          );
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
              const Text('This doesn\'t reject the request. Other vendors can still bid.'),
              const SizedBox(height: 12),
              ...reasons.map((reason) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(reason),
                  onTap: () => Navigator.pop(ctx, reason),
                );
              }),
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

  @override
  Widget build(BuildContext context) {
    final proposalState = ref.watch(proposalProvider);
    final comparisonState =
        ref.watch(customerProposalComparisonProvider(widget.requestId));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final hasAcceptedProposal = proposalState.proposals
        .any((p) => p.status == ProposalStatus.accepted);

    if (proposalState.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Compare Proposals'),
          centerTitle: false,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: AppColors.customerColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading proposals...',
                style: AppTextStyles.bodyMedium(secondaryText),
              ),
            ],
          ),
        ),
      );
    }

    if (proposalState.proposals.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Compare Proposals'),
          centerTitle: false,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 64,
                  color: secondaryText,
                ),
                const SizedBox(height: 16),
                Text(
                  'No proposals yet',
                  style: AppTextStyles.h2(primaryText),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Vendors will respond to your request shortly.',
                  style: AppTextStyles.bodyMedium(secondaryText),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final views = comparisonState.views;
    final hasProposals = views.isNotEmpty;

    if (hasProposals) {
      // Calculate stats
      double? minPrice;
      int? minDeliveryTime;
      double? maxRating;

      for (final view in views) {
        if (minPrice == null || view.totalPrice < minPrice) {
          minPrice = view.totalPrice;
        }
        if (minDeliveryTime == null ||
            view.deliverySortHours < minDeliveryTime) {
          minDeliveryTime = view.deliverySortHours;
        }
        if (maxRating == null || view.ratingPlaceholder > maxRating) {
          maxRating = view.ratingPlaceholder;
        }
      }

      return Scaffold(
        appBar: AppBar(
          title: const Text('Compare Proposals'),
          centerTitle: false,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats row
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.local_offer_outlined,
                        iconColor: AppColors.success,
                        label: 'Lowest Price',
                        value: 'Rs. ${minPrice?.toStringAsFixed(0) ?? '—'}',
                        cardColor: cardColor,
                        borderColor: borderColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.flash_on_outlined,
                        iconColor: AppColors.warning,
                        label: 'Fastest',
                        value: minDeliveryTime != null
                            ? '${minDeliveryTime.toStringAsFixed(0)}h'
                            : '—',
                        cardColor: cardColor,
                        borderColor: borderColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.star_rounded,
                        iconColor: Colors.amber.shade700,
                        label: 'Top Rated',
                        value: maxRating?.toStringAsFixed(1) ?? '—',
                        cardColor: cardColor,
                        borderColor: borderColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Comparison bar
                ProposalComparisonBar(
                  selectedMode: comparisonState.mode,
                  proposalCount: views.length,
                  onModeChanged: (mode) {
                    ref
                        .read(
                          customerProposalComparisonProvider(widget.requestId)
                              .notifier,
                        )
                        .setMode(
                          mode,
                          proposals: proposalState.proposals,
                          request: widget.request,
                        );
                  },
                ),
                const SizedBox(height: 16),

                // Accepted notice
                if (hasAcceptedProposal)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Text(
                      'A vendor bid has been accepted. Complete payment to confirm your order.',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                // Proposals list
                ...views.map((view) {
                  final canAct = view.canAcceptOrReject && !hasAcceptedProposal;
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
                    onReject:
                        canAct ? () => _rejectProposal(view.proposal) : null,
                  );
                }),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare Proposals'),
        centerTitle: false,
      ),
      body: Center(
        child: Text(
          'Unable to load proposals',
          style: AppTextStyles.bodyMedium(secondaryText),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.cardColor,
    required this.borderColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color cardColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.caption(secondaryText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.subtitle(primaryText),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
