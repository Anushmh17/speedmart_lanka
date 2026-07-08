import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/theme3/theme3_app_card.dart';
import '../../../../../core/widgets/theme3/theme3_empty_state.dart';
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
      final proposals = await ref
          .read(proposalProvider.notifier)
          .loadProposalsForRequest(widget.requestId);
      if (!mounted) return;
      ref
          .read(customerProposalComparisonProvider(widget.requestId).notifier)
          .updateFrom(proposals: proposals, request: widget.request);
    });
  }

  void _acceptProposal(Proposal proposal) {
    showDialog<bool>(
      context: context,
      builder: (ctx) {
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

    // Keep comparison views in sync whenever proposals change
    ref.listen(proposalProvider, (prev, next) {
      if (prev?.proposals != next.proposals) {
        ref
            .read(customerProposalComparisonProvider(widget.requestId).notifier)
            .updateFrom(
              proposals: next.proposals,
              request: widget.request,
            );
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    final hasAcceptedProposal = proposalState.proposals
        .any((p) => p.status == ProposalStatus.accepted);

    if (proposalState.isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        body: Column(
          children: [
            _buildHeader(context, isDark, primaryText, secondaryText),
            Expanded(
              child: Center(
                child: Theme3EmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Loading Proposals',
                  subtitle: 'Please wait while we fetch vendor responses',
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (proposalState.proposals.isEmpty) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        body: Column(
          children: [
            _buildHeader(context, isDark, primaryText, secondaryText),
            Expanded(
              child: Theme3EmptyState(
                icon: Icons.shopping_bag_outlined,
                title: 'No Proposals Yet',
                subtitle: 'Vendors will respond to your request shortly',
              ),
            ),
          ],
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
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        body: Column(
          children: [
            _buildHeader(context, isDark, primaryText, secondaryText),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.local_offer_outlined,
                              iconColor: AppColors.success,
                              label: 'Lowest Price',
                              value: 'Rs. ${minPrice?.toStringAsFixed(0) ?? '—'}',
                              isDark: isDark,
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.flash_on_outlined,
                              iconColor: AppColors.warning,
                              label: 'Fastest',
                              value: minDeliveryTime != null
                                  ? '${minDeliveryTime.toStringAsFixed(0)}h'
                                  : '—',
                              isDark: isDark,
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.star_rounded,
                              iconColor: Colors.amber.shade700,
                              label: 'Top Rated',
                              value: maxRating?.toStringAsFixed(1) ?? '—',
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.lg),

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
                      SizedBox(height: AppSpacing.md),

                      if (hasAcceptedProposal)
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: AppSpacing.md),
                          padding: EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                color: AppColors.success,
                                size: 20,
                              ),
                              SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'A vendor bid has been accepted. Complete payment to confirm your order.',
                                  style: AppTextStyles.bodySmall(AppColors.success),
                                ),
                              ),
                            ],
                          ),
                        ),

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
                      SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Column(
        children: [
          _buildHeader(context, isDark, primaryText, secondaryText),
          Expanded(
            child: Theme3EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Unable to Load Proposals',
              subtitle: 'Please try again later',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, Color primaryText, Color secondaryText) {
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
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: primaryText,
            ),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? AppColors.surfaceElevatedDark : AppColors.borderLight,
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compare Proposals',
                  style: AppTextStyles.h2(primaryText),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  'Choose the best offer for your request',
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.isDark,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Theme3AppCard(
      padding: EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor),
          SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.caption(secondaryText),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.xs),
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
