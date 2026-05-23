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
    Future.microtask(() {
      if (!mounted) return;
      ref.read(proposalProvider.notifier).loadProposalsForRequest(_request.id);
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
    final requestLoading = ref.watch(requestProvider).isLoading;
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
                  else
                    ...proposalState.proposals.map(
                      (proposal) => _ProposalCard(
                        proposal: proposal,
                        requestId: _request.id,
                        enabled: proposalsEnabled,
                        cardColor: cardColor,
                        borderColor: borderColor,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                      ),
                    ),
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

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.requestId,
    required this.enabled,
    required this.cardColor,
    required this.borderColor,
    required this.primaryText,
    required this.secondaryText,
  });

  final Proposal proposal;
  final String requestId;
  final bool enabled;
  final Color cardColor;
  final Color borderColor;
  final Color primaryText;
  final Color secondaryText;

  @override
  Widget build(BuildContext context) {
    final maskedVendorName =
        'Partner Merchant #${proposal.vendorId.hashCode.toString().substring(0, 4)}';
    final availableCount = proposal.items
        .where((i) => i.status == ProposalItemStatus.available)
        .length;
    final altCount = proposal.items
        .where((i) => i.status == ProposalItemStatus.alternative)
        .length;

    final isProposalCancelled = proposal.status == ProposalStatus.cancelled;

    return Opacity(
      opacity: enabled && !isProposalCancelled ? 1 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: InkWell(
          onTap: enabled && !isProposalCancelled
              ? () {
                  context.push('/customer/proposals/detail', extra: {
                    'proposal': proposal,
                    'requestId': requestId,
                  });
                }
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      maskedVendorName,
                      style: AppTextStyles.subtitle(primaryText),
                    ),
                    StatusBadge(
                      label: proposal.status.displayName,
                      color: proposal.status == ProposalStatus.accepted
                          ? AppColors.success
                          : (proposal.status == ProposalStatus.rejected ||
                                  proposal.status == ProposalStatus.cancelled
                              ? AppColors.error
                              : AppColors.customerColor),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Delivery: ${proposal.estimatedDeliveryTime} · Fee: Rs. ${proposal.deliveryCharge.toStringAsFixed(0)}',
                  style: AppTextStyles.bodySmall(secondaryText),
                ),
                const SizedBox(height: 4),
                Text(
                  '$availableCount available · $altCount alternatives',
                  style: AppTextStyles.caption(secondaryText),
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total bid',
                      style: AppTextStyles.caption(secondaryText),
                    ),
                    Text(
                      'Rs. ${proposal.totalPrice.toStringAsFixed(2)}',
                      style: AppTextStyles.subtitle(AppColors.customerColor),
                    ),
                  ],
                ),
                if (enabled && !isProposalCancelled) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Tap to review →',
                      style: AppTextStyles.caption(AppColors.customerColor)
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
