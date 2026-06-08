import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_state_widgets.dart';
import '../../../../shared/utils/category_constants.dart';
import '../../models/request_item.dart';
import '../../models/shopping_request.dart';
import '../../models/request_category_fulfillment.dart';
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

  @override
  void didUpdateWidget(covariant RequestDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id) {
      _request = widget.request;
    }
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

  List<Widget> _buildCategoryGroupedProposals(
    List<Proposal> proposals,
    bool hasAcceptedProposal,
    bool proposalsEnabled,
    Color primaryText,
    Color secondaryText,
    Color cardColor,
    Color borderColor,
  ) {
    // Get all categories from request items (source of truth)
    final requestCategories = _request.items
        .map((item) {
          final cat = item.category?.trim();
          if (cat == null || cat.isEmpty) return null;
          return VendorCategories.normalize(cat);
        })
        .where((cat) => cat != null && cat.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    print('[MultiCategoryUI] Request item categories: $requestCategories');

    // Group proposals by category
    final groupedProposals = <String, List<Proposal>>{};
    for (final proposal in proposals) {
      final category = proposal.categoryNormalized ?? 'unknown';
      groupedProposals.putIfAbsent(category, () => []).add(proposal);
      print('[MultiCategoryFlow] Loaded proposal category: $category (${proposal.id})');
    }

    print('[MultiCategoryUI] Proposal grouped categories: ${groupedProposals.keys.toList()}');

    final widgets = <Widget>[];
    
    // Iterate through ALL request categories (not just those with proposals)
    for (final category in requestCategories) {
      print('[MultiCategoryUI] Rendering category: $category');
      
      final categoryProposals = groupedProposals[category] ?? [];
      final categoryStatus = _request.getCategoryStatus(category);
      final categoryAccepted =
          categoryStatus == RequestCategoryStatus.accepted ||
              categoryStatus == RequestCategoryStatus.codConfirmed ||
              categoryStatus == RequestCategoryStatus.outForDelivery ||
              categoryStatus == RequestCategoryStatus.paid;

      // Category header
      widgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 8, top: 16),
          decoration: BoxDecoration(
            color: categoryAccepted
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.customerColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: categoryAccepted
                  ? AppColors.success.withValues(alpha: 0.3)
                  : borderColor,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${VendorCategories.display(category)} Offers',
                  style: AppTextStyles.subtitle(primaryText),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: categoryAccepted
                      ? AppColors.success
                      : AppColors.customerColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  categoryStatus.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      // Category proposals or empty state
      if (categoryProposals.isEmpty) {
        print('[MultiCategoryUI] Empty category section: $category');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.hourglass_empty_rounded,
                    color: secondaryText,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      categoryAccepted
                          ? 'Vendor assigned for this category'
                          : 'No offers yet — Waiting for ${VendorCategories.display(category).toLowerCase()} vendors',
                      style: AppTextStyles.bodyMedium(secondaryText),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        // Show proposals
        for (final proposal in categoryProposals) {
          final isAccepted = proposal.status == ProposalStatus.accepted;
          final canAct = proposalsEnabled &&
              !categoryAccepted &&
              proposal.status.isVisibleToCustomer &&
              (proposal.status == ProposalStatus.submitted ||
                  proposal.status == ProposalStatus.updated);

          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SimplifiedProposalCard(
                proposal: proposal,
                isAccepted: isAccepted,
                categoryStatus: categoryStatus,
                onAccept: isAccepted
                    ? () => _handleAcceptedProposalAction(proposal, categoryStatus)
                    : canAct
                        ? () => _acceptProposal(proposal)
                        : null,
                onReject: canAct ? () => _rejectProposal(proposal) : null,
                isDark: Theme.of(context).brightness == Brightness.dark,
              ),
            ),
          );
        }
      }
    }

    return widgets;
  }

  void _handleAcceptedProposalAction(
    Proposal proposal,
    RequestCategoryStatus categoryStatus,
  ) async {
    final category = proposal.categoryNormalized ?? '';
    final isPaid = categoryStatus == RequestCategoryStatus.paid;
    final isCodConfirmed = categoryStatus == RequestCategoryStatus.codConfirmed;
    
    debugPrint('[CODFlow] Accepted category: $category');
    debugPrint('[CODFlow] categoryStatus: ${categoryStatus.name}');
    debugPrint('[CODFlow] isPaid: $isPaid');
    debugPrint('[CODFlow] isCodConfirmed: $isCodConfirmed');
    
    if (isPaid || isCodConfirmed) {
      // Already paid or COD confirmed, do nothing
      final message = isCodConfirmed 
          ? 'COD order confirmed — Waiting for delivery and cash collection'
          : 'Payment already confirmed for this category';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    // Navigate to payment
    await context.push('/customer/payment', extra: {
      'proposal': proposal,
      'requestId': _request.id,
    });
    
    // Reload request after payment
    if (!mounted) return;
    final refreshed = await MockRequestRepository.instance.getRequestById(_request.id);
    if (refreshed != null && mounted) {
      setState(() => _request = refreshed);
      debugPrint('[CODFlow] request reloaded after payment');
      debugPrint('[CODFlow] customer UI status after confirmation: ${refreshed.getCategoryStatus(category).name}');
    }
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

                  // Multi-category progress summary
                  if (_request.isMultiCategory && !_isCancelled) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.customerColor.withValues(alpha: 0.1),
                            cardColor,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.customerColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Category Progress',
                            style: AppTextStyles.h3(primaryText),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _CategoryStatCard(
                                  label: 'Requested',
                                  count: _request.totalCategories,
                                  color: AppColors.customerColor,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _CategoryStatCard(
                                  label: 'Accepted',
                                  count: _request.acceptedCategoriesCount,
                                  color: AppColors.success,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _CategoryStatCard(
                                  label: 'Pending',
                                  count: _request.pendingCategoriesCount,
                                  color: AppColors.warning,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _CategoryStatCard(
                                  label: 'Completed',
                                  count: _request.completedCategoriesCount,
                                  color: AppColors.success,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _request.totalCategories > 0
                                  ? _request.acceptedCategoriesCount /
                                      _request.totalCategories
                                  : 0,
                              minHeight: 8,
                              backgroundColor: borderColor,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

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
                    (item) {
                      final itemCategory = item.category?.trim().toLowerCase() ?? '';
                      final categoryStatus = _request.getCategoryStatus(itemCategory);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RequestItemWithCategory(
                          item: item,
                          categoryStatus: categoryStatus,
                          onTap: () => _openItemDetails(item),
                          isDark: isDark,
                        ),
                      );
                    },
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
                    if (!_request.isMultiCategory) ...[
                      // Single category: Show standard view
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
                    ] else ...[
                      // Multi-category: Group by category
                      ..._buildCategoryGroupedProposals(
                        proposalState.proposals,
                        hasAcceptedProposal,
                        proposalsEnabled,
                        primaryText,
                        secondaryText,
                        cardColor,
                        borderColor,
                      ),
                    ],
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

class _CategoryStatCard extends StatelessWidget {
  const _CategoryStatCard({
    required this.label,
    required this.count,
    required this.color,
    required this.isDark,
  });

  final String label;
  final int count;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RequestItemWithCategory extends StatelessWidget {
  const _RequestItemWithCategory({
    required this.item,
    required this.categoryStatus,
    required this.onTap,
    required this.isDark,
  });

  final RequestItem item;
  final RequestCategoryStatus categoryStatus;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    Color statusColor;
    switch (categoryStatus) {
      case RequestCategoryStatus.pending:
      case RequestCategoryStatus.proposalReceived:
        statusColor = AppColors.warning;
        break;
      case RequestCategoryStatus.accepted:
        statusColor = AppColors.customerColor;
        break;
      case RequestCategoryStatus.codConfirmed:
      case RequestCategoryStatus.outForDelivery:
        statusColor = AppColors.warning;
        break;
      case RequestCategoryStatus.paid:
      case RequestCategoryStatus.completed:
        statusColor = AppColors.success;
        break;
      case RequestCategoryStatus.cancelled:
        statusColor = AppColors.error;
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            if (item.imageUrls.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(item.imageUrls.first),
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 50,
                    height: 50,
                    color: borderColor,
                    child: Icon(Icons.image_outlined, color: secondaryText),
                  ),
                ),
              )
            else
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.shopping_bag_outlined, color: secondaryText),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: AppTextStyles.subtitle(primaryText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        item.category ?? 'General',
                        style: AppTextStyles.caption(secondaryText),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          categoryStatus.displayName,
                          style: TextStyle(
                            fontSize: 10,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Qty ${item.quantity}',
              style: AppTextStyles.caption(secondaryText),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: secondaryText, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SimplifiedProposalCard extends StatelessWidget {
  const _SimplifiedProposalCard({
    required this.proposal,
    required this.isAccepted,
    required this.categoryStatus,
    required this.onAccept,
    required this.onReject,
    required this.isDark,
  });

  final Proposal proposal;
  final bool isAccepted;
  final RequestCategoryStatus categoryStatus;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final bool isDark;

  String _getActionButtonLabel() {
    if (!isAccepted) return 'Accept';
    
    // Check payment and COD status for accepted proposals
    final isPaid = categoryStatus == RequestCategoryStatus.paid;
    final isCodConfirmed = categoryStatus == RequestCategoryStatus.codConfirmed;
    
    print('[CODFlow] Button label check:');
    print('[CODFlow] - isAccepted: $isAccepted');
    print('[CODFlow] - categoryStatus: ${categoryStatus.name}');
    print('[CODFlow] - isPaid: $isPaid');
    print('[CODFlow] - isCodConfirmed: $isCodConfirmed');
    
    if (isPaid) {
      return 'Payment Complete';
    }
    
    if (isCodConfirmed) {
      return 'COD Confirmed';
    }
    
    return 'Choose Payment';
  }

  bool _isButtonEnabled() {
    if (!isAccepted) return onAccept != null;
    
    // Disable if already paid or COD confirmed
    final isPaid = categoryStatus == RequestCategoryStatus.paid;
    final isCodConfirmed = categoryStatus == RequestCategoryStatus.codConfirmed;
    return !isPaid && !isCodConfirmed && onAccept != null;
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final buttonLabel = _getActionButtonLabel();
    final buttonEnabled = _isButtonEnabled();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAccepted
            ? AppColors.success.withValues(alpha: 0.08)
            : cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAccepted
              ? AppColors.success.withValues(alpha: 0.3)
              : borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proposal.vendorBusinessName,
                      style: AppTextStyles.subtitle(primaryText),
                    ),
                    Text(
                      proposal.estimatedDeliveryTime,
                      style: AppTextStyles.caption(secondaryText),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rs. ${proposal.totalPrice.toStringAsFixed(0)}',
                    style: AppTextStyles.h3(AppColors.customerColor),
                  ),
                  if (isAccepted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'ACCEPTED',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (onAccept != null || onReject != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onReject != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                if (onReject != null && onAccept != null)
                  const SizedBox(width: 8),
                if (onAccept != null)
                  Expanded(
                    flex: onReject != null ? 1 : 2,
                    child: ElevatedButton(
                      onPressed: buttonEnabled ? onAccept : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAccepted
                            ? (categoryStatus == RequestCategoryStatus.paid
                                ? AppColors.success
                                : categoryStatus == RequestCategoryStatus.codConfirmed
                                    ? AppColors.warning
                                    : AppColors.success)
                            : AppColors.customerColor,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        disabledBackgroundColor: categoryStatus == RequestCategoryStatus.codConfirmed
                            ? AppColors.warning.withValues(alpha: 0.5)
                            : Colors.grey.withValues(alpha: 0.5),
                      ),
                      child: Text(
                        buttonLabel,
                        style: TextStyle(
                          color: buttonEnabled ? Colors.white : Colors.white70,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
