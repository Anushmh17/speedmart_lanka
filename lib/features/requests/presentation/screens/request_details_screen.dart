import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_state_widgets.dart';
import '../../models/request_item.dart';
import '../../models/shopping_request.dart';
import '../../providers/request_provider.dart';
import '../../../proposals/providers/proposal_provider.dart';
import '../../../proposals/models/proposal.dart';
import '../../../customer/proposals/providers/customer_proposal_comparison_provider.dart';
import '../../../customer/proposals/widgets/customer_proposal_card.dart';
import '../../../customer/proposals/widgets/proposal_comparison_bar.dart';
import '../../../requests/data/mock_request_repository.dart';
import '../widgets/request_item_list_tile.dart';
import 'request_item_details_screen.dart';

class RequestDetailsScreen extends ConsumerStatefulWidget {
  final ShoppingRequest request;

  const RequestDetailsScreen({super.key, required this.request});

  @override
  ConsumerState<RequestDetailsScreen> createState() =>
      _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends ConsumerState<RequestDetailsScreen> {
  late ShoppingRequest _request;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _request = widget.request;
    Future.microtask(() async {
      if (!mounted) return;
      await ref
          .read(proposalProvider.notifier)
          .loadProposalsForRequest(_request.id);
      if (!mounted) return;
      _syncComparison(ref.read(proposalProvider).proposals);
    });
  }

  bool get _isCancelled => _request.status.isCancelled;

  bool _canCancel(List<Proposal> proposals) {
    return _request.canBeCancelledByCustomer(
      hasAcceptedProposal:
          proposals.any((p) => p.status == ProposalStatus.accepted),
    );
  }

  Color _getStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.draft:
        return Colors.grey;
      case RequestStatus.submitted:
      case RequestStatus.waitingForVendor:
        return AppColors.warning;
      case RequestStatus.vendorAccepted:
      case RequestStatus.proposalSubmitted:
        return AppColors.customerColor;
      case RequestStatus.customerAccepted:
      case RequestStatus.paid:
      case RequestStatus.cashOnDeliveryConfirmed:
      case RequestStatus.delivered:
        return AppColors.success;
      case RequestStatus.customerRejected:
      case RequestStatus.cancelled:
      case RequestStatus.expired:
        return AppColors.error;
      default:
        return AppColors.customerColor;
    }
  }

  Future<void> _confirmCancel() async {
    final proposalState = ref.read(proposalProvider);
    if (!_canCancel(proposalState.proposals)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final primaryText =
            isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
        final secondaryText = isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Cancel Request?',
            style: TextStyle(color: primaryText, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'This request will be removed from nearby vendor queues.\n'
            'You can still create a new request later.',
            style: TextStyle(color: secondaryText, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Keep Request', style: TextStyle(color: secondaryText)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Cancel Request'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);
    try {
      final cancelled = await ref
          .read(requestProvider.notifier)
          .cancelRequest(_request.id);

      if (!mounted) return;

      if (cancelled != null) {
        setState(() => _request = cancelled);
        await ref
            .read(proposalProvider.notifier)
            .loadProposalsForRequest(_request.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request cancelled successfully.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  void _syncComparison(List<Proposal> proposals) {
    ref
        .read(customerProposalComparisonProvider(_request.id).notifier)
        .updateFrom(proposals: proposals, request: _request);
  }

  Future<void> _acceptProposal(Proposal proposal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept this bid?'),
        content: Text(
          'Request ${_request.id} will be locked to this vendor. '
          'Other bids will be declined automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Accept & continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(proposalProvider.notifier)
          .acceptProposal(proposal.id, _request.id);
      final refreshed =
          await MockRequestRepository.instance.getRequestById(_request.id);
      if (refreshed != null && mounted) {
        setState(() => _request = refreshed);
      }
      if (!mounted) return;
      context.push('/customer/payment', extra: {
        'proposal': proposal,
        'requestId': _request.id,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _rejectProposal(Proposal proposal) async {
    final reasons = [
      'Price too high',
      'Delivery too slow',
      'Product mismatch',
      'Prefer another vendor',
    ];
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Reject bid'),
        children: reasons
            .map(
              (r) => SimpleDialogOption(
                child: Text(r),
                onPressed: () => Navigator.pop(ctx, r),
              ),
            )
            .toList(),
      ),
    );
    if (reason == null || !mounted) return;

    try {
      await ref.read(proposalProvider.notifier).rejectProposal(
            proposal.id,
            _request.id,
            reason,
          );
      _syncComparison(ref.read(proposalProvider).proposals);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bid rejected')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  void _openItemDetails(RequestItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RequestItemDetailsScreen(
          item: item,
          requestCreatedAt: _request.createdAt,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final statusColor = _getStatusColor(_request.status);
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final proposalState = ref.watch(proposalProvider);
    final comparisonState =
        ref.watch(customerProposalComparisonProvider(_request.id));
    ref.listen<ProposalState>(proposalProvider, (previous, next) {
      if (previous?.proposals != next.proposals) {
        _syncComparison(next.proposals);
      }
    });
    final requestLoading = ref.watch(requestProvider).isLoading;
    final hasAcceptedProposal = proposalState.proposals
        .any((p) => p.status == ProposalStatus.accepted);
    final canCancel = _canCancel(proposalState.proposals) && !_isCancelled;
    final proposalsEnabled = !_isCancelled;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Request ${_request.id}'),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: _isCancelled
                        ? _CancelledBanner(
                            key: const ValueKey('cancelled'),
                            cardColor: cardColor,
                            borderColor: borderColor,
                          )
                        : const SizedBox.shrink(key: ValueKey('active')),
                  ),
                  if (_isCancelled) const SizedBox(height: 12),

                  // Status card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          statusColor.withValues(alpha: 0.12),
                          cardColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isCancelled
                                ? Icons.cancel_outlined
                                : Icons.receipt_long_outlined,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Request Status',
                                style: AppTextStyles.caption(secondaryText),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _request.status.displayName,
                                style: AppTextStyles.h3(statusColor),
                              ),
                              if (_request.status.isAwaitingVendorResponse &&
                                  !_isCancelled) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Nearby vendors can review and send bids.',
                                  style: AppTextStyles.bodySmall(secondaryText),
                                ),
                              ],
                            ],
                          ),
                        ),
                        StatusBadge(
                          label: _request.status.displayName,
                          color: statusColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Delivery area summary
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: AppColors.customerColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _request.customerArea.isNotEmpty
                                ? _request.customerArea
                                : 'Delivery area on file',
                            style: AppTextStyles.bodyMedium(primaryText),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Requested Items (${_request.items.length})',
                    style: AppTextStyles.h2(primaryText),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap an item to view full details and images.',
                    style: AppTextStyles.caption(secondaryText),
                  ),
                  const SizedBox(height: 12),

                  ..._request.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: RequestItemListTile(
                        item: item,
                        enabled: true,
                        onTap: () => _openItemDetails(item),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Merchant bids
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Merchant Bids (${proposalState.proposals.length})',
                        style: AppTextStyles.h2(primaryText),
                      ),
                      if (proposalState.isLoading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.customerColor,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_isCancelled)
                    _DisabledBidsNotice(
                      cardColor: cardColor,
                      borderColor: borderColor,
                      primaryText: primaryText,
                      secondaryText: secondaryText,
                    )
                  else if (proposalState.proposals.isEmpty)
                    _AwaitingBidsEmptyState(
                      cardColor: cardColor,
                      borderColor: borderColor,
                      primaryText: primaryText,
                      secondaryText: secondaryText,
                    )
                  else ...[
                    ProposalComparisonBar(
                      selectedMode: comparisonState.mode,
                      proposalCount: comparisonState.views.length,
                      onModeChanged: (mode) {
                        ref
                            .read(
                              customerProposalComparisonProvider(_request.id)
                                  .notifier,
                            )
                            .setMode(
                              mode,
                              proposals: proposalState.proposals,
                              request: _request,
                            );
                      },
                    ),
                    const SizedBox(height: 12),
                    if (hasAcceptedProposal)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
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
                    ...comparisonState.views.map(
                      (view) {
                        final canAct = proposalsEnabled &&
                            (view.canAcceptOrReject && !hasAcceptedProposal);
                        return CustomerProposalCard(
                          view: view,
                          requestId: _request.id,
                          enabled: proposalsEnabled,
                          onAccept: view.isAccepted
                              ? () {
                                  context.push('/customer/payment', extra: {
                                    'proposal': view.proposal,
                                    'requestId': _request.id,
                                  });
                                }
                              : canAct
                                  ? () => _acceptProposal(view.proposal)
                                  : null,
                          onReject:
                              canAct ? () => _rejectProposal(view.proposal) : null,
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom actions
          if (canCancel || _isCancelled)
            SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: canCancel
                    ? OutlinedButton.icon(
                        onPressed: (_isCancelling || requestLoading)
                            ? null
                            : _confirmCancel,
                        icon: _isCancelling
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel Request'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      )
                    : Text(
                        'This request has been cancelled.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium(AppColors.error),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CancelledBanner extends StatelessWidget {
  const _CancelledBanner({
    super.key,
    required this.cardColor,
    required this.borderColor,
  });

  final Color cardColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.error, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'This request has been cancelled.',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AwaitingBidsEmptyState extends StatelessWidget {
  const _AwaitingBidsEmptyState({
    required this.cardColor,
    required this.borderColor,
    required this.primaryText,
    required this.secondaryText,
  });

  final Color cardColor;
  final Color borderColor;
  final Color primaryText;
  final Color secondaryText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.customerColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              size: 40,
              color: AppColors.customerColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Waiting for nearby vendors…',
            style: AppTextStyles.h3(primaryText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your request is visible to merchants within 20 km. '
            'Most bids arrive within a few hours depending on item availability.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium(secondaryText).copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _DisabledBidsNotice extends StatelessWidget {
  const _DisabledBidsNotice({
    required this.cardColor,
    required this.borderColor,
    required this.primaryText,
    required this.secondaryText,
  });

  final Color cardColor;
  final Color borderColor;
  final Color primaryText;
  final Color secondaryText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        'Merchant bids are closed for cancelled requests.',
        style: AppTextStyles.bodyMedium(secondaryText),
        textAlign: TextAlign.center,
      ),
    );
  }
}
