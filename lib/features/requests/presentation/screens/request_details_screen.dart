import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/theme3/theme3_app_bar.dart';
import '../../../../core/widgets/theme3/theme3_app_button.dart';
import '../../../../core/widgets/theme3/theme3_app_card.dart';
import '../../../../core/widgets/theme3/theme3_status_chip.dart';
import '../../../../core/widgets/theme3/theme3_category_chip.dart';
import '../../../../core/widgets/theme3/theme3_empty_state.dart';
import '../../../../shared/utils/category_constants.dart';
import '../../models/request_item.dart';
import '../../models/shopping_request.dart';
import '../../models/request_category_fulfillment.dart';
import '../../providers/request_provider.dart';
import '../../../proposals/providers/proposal_provider.dart';
import '../../../proposals/models/proposal.dart';
import '../../../customer/proposals/providers/customer_proposal_comparison_provider.dart';
import '../../../customer/proposals/widgets/customer_proposal_card.dart';
import '../../../requests/data/mock_request_repository.dart';
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

  Theme3StatusType _getStatusType(RequestStatus status) {
    switch (status) {
      case RequestStatus.draft:
        return Theme3StatusType.pending;
      case RequestStatus.submitted:
      case RequestStatus.waitingForVendor:
        return Theme3StatusType.pending;
      case RequestStatus.vendorAccepted:
      case RequestStatus.proposalSubmitted:
        return Theme3StatusType.inProgress;
      case RequestStatus.customerAccepted:
      case RequestStatus.paid:
      case RequestStatus.cashOnDeliveryConfirmed:
      case RequestStatus.delivered:
        return Theme3StatusType.completed;
      case RequestStatus.customerRejected:
      case RequestStatus.cancelled:
      case RequestStatus.expired:
        return Theme3StatusType.cancelled;
      default:
        return Theme3StatusType.inProgress;
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
    Color borderColor,
  ) {
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

    final groupedProposals = <String, List<Proposal>>{};
    for (final proposal in proposals) {
      final category = proposal.categoryNormalized ?? 'unknown';
      groupedProposals.putIfAbsent(category, () => []).add(proposal);
    }

    final widgets = <Widget>[];

    for (final category in requestCategories) {
      final categoryProposals = groupedProposals[category] ?? [];
      final categoryStatus = _request.getCategoryStatus(category);
      final categoryAccepted =
          categoryStatus == RequestCategoryStatus.accepted ||
              categoryStatus == RequestCategoryStatus.codConfirmed ||
              categoryStatus == RequestCategoryStatus.outForDelivery ||
              categoryStatus == RequestCategoryStatus.paid;

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

      if (categoryProposals.isEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
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
              child: _Theme3ProposalCard(
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
    final isPaid = categoryStatus == RequestCategoryStatus.paid;
    final isCodConfirmed = categoryStatus == RequestCategoryStatus.codConfirmed;

    if (isPaid || isCodConfirmed) {
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

    await context.push('/customer/payment', extra: {
      'proposal': proposal,
      'requestId': _request.id,
    });

    if (!mounted) return;
    final refreshed = await MockRequestRepository.instance.getRequestById(_request.id);
    if (refreshed != null && mounted) {
      setState(() => _request = refreshed);
    }
  }

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final bgColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

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
      backgroundColor: bgColor,
      appBar: Theme3AppBar(
        title: 'Request ${_request.id}',
        onBackPressed: () => context.pop(),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isCancelled)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Theme3AppCard(
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                color: AppColors.error, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This request has been cancelled.',
                                style: AppTextStyles.subtitle(AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Theme3AppCard(
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
                                    'Request ID',
                                    style: AppTextStyles.caption(secondaryText),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _request.id,
                                    style: AppTextStyles.h2(primaryText),
                                  ),
                                ],
                              ),
                            ),
                            Theme3StatusChip(
                              label: _request.status.displayName,
                              status: _getStatusType(_request.status),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _InfoBadge(
                              label: 'Created',
                              value: _formatDate(_request.createdAt),
                              icon: Icons.calendar_today_outlined,
                            ),
                            _InfoBadge(
                              label: 'Items',
                              value: _request.items.length.toString(),
                              icon: Icons.shopping_bag_outlined,
                            ),
                            _InfoBadge(
                              label: 'Proposals',
                              value: proposalState.proposals.length.toString(),
                              icon: Icons.local_offer_outlined,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_request.isMultiCategory && !_isCancelled) ...[
                    Theme3AppCard(
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
                            ],
                          ),
                          const SizedBox(height: 10),
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
                    const SizedBox(height: 16),
                  ],
                  Theme3AppCard(
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 18, color: AppColors.customerColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delivery Area',
                                style: AppTextStyles.caption(secondaryText),
                              ),
                              Text(
                                _request.customerArea.isNotEmpty
                                    ? _request.customerArea
                                    : 'Delivery area on file',
                                style: AppTextStyles.bodyMedium(primaryText),
                              ),
                            ],
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
                  const SizedBox(height: 12),
                  ..._request.items.asMap().entries.map(
                    (entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final itemCategory = item.category?.trim().toLowerCase() ?? '';
                      final categoryStatus = _request.getCategoryStatus(itemCategory);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _Theme3RequestItemCard(
                          itemNumber: idx + 1,
                          item: item,
                          categoryStatus: categoryStatus,
                          onTap: () => _openItemDetails(item),
                          isDark: isDark,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Proposals Received',
                        style: AppTextStyles.h2(primaryText),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.customerColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          proposalState.proposals.length.toString(),
                          style: AppTextStyles.caption(AppColors.customerColor)
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isCancelled)
                    Theme3AppCard(
                      child: Text(
                        'Proposals are closed for cancelled requests.',
                        style: AppTextStyles.bodyMedium(secondaryText),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else if (proposalState.proposals.isEmpty)
                    Theme3EmptyState(
                      icon: Icons.hourglass_top_rounded,
                      title: 'Waiting for proposals',
                      subtitle:
                          'Your request is visible to nearby vendors. Most proposals arrive within a few hours.',
                    )
                  else ...[
                    if (!_request.isMultiCategory) ...comparisonState.views.map(
                      (view) {
                        final canAct = proposalsEnabled &&
                            (view.canAcceptOrReject && !hasAcceptedProposal);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: CustomerProposalCard(
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
                          ),
                        );
                      },
                    ) else
                      ..._buildCategoryGroupedProposals(
                        proposalState.proposals,
                        hasAcceptedProposal,
                        proposalsEnabled,
                        primaryText,
                        secondaryText,
                        borderColor,
                      ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
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
                    ? Theme3AppButton(
                        label: 'Cancel Request',
                        onPressed: (_isCancelling || requestLoading)
                            ? null
                            : _confirmCancel,
                        isLoading: _isCancelling || requestLoading,
                        type: Theme3ButtonType.danger,
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    return '${date.day} ${_monthName(date.month)}';
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    return Column(
      children: [
        Icon(icon, size: 16, color: AppColors.customerColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.subtitle(AppColors.customerColor),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.caption(secondaryText),
        ),
      ],
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

class _Theme3RequestItemCard extends StatelessWidget {
  const _Theme3RequestItemCard({
    required this.itemNumber,
    required this.item,
    required this.categoryStatus,
    required this.onTap,
    required this.isDark,
  });

  final int itemNumber;
  final RequestItem item;
  final RequestCategoryStatus categoryStatus;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
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
      child: Theme3AppCard(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.customerColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  itemNumber.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.customerColor,
                  ),
                ),
              ),
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
                      Theme3CategoryChip(
                        label: item.category ?? 'General',
                        isSelected: false,
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

class _Theme3ProposalCard extends StatelessWidget {
  const _Theme3ProposalCard({
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
    final isPaid = categoryStatus == RequestCategoryStatus.paid;
    final isCodConfirmed = categoryStatus == RequestCategoryStatus.codConfirmed;
    if (isPaid) return 'Payment Complete';
    if (isCodConfirmed) return 'COD Confirmed';
    return 'Choose Payment';
  }

  bool _isButtonEnabled() {
    if (!isAccepted) return onAccept != null;
    final isPaid = categoryStatus == RequestCategoryStatus.paid;
    final isCodConfirmed = categoryStatus == RequestCategoryStatus.codConfirmed;
    return !isPaid && !isCodConfirmed && onAccept != null;
  }

  @override
  Widget build(BuildContext context) {
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final buttonLabel = _getActionButtonLabel();
    final buttonEnabled = _isButtonEnabled();

    return Theme3AppCard(
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
                    Theme3StatusChip(
                      label: 'ACCEPTED',
                      status: Theme3StatusType.approved,
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
                    child: Theme3AppButton(
                      label: 'Reject',
                      onPressed: onReject,
                      type: Theme3ButtonType.secondary,
                    ),
                  ),
                if (onReject != null && onAccept != null)
                  const SizedBox(width: 8),
                if (onAccept != null)
                  Expanded(
                    flex: onReject != null ? 1 : 2,
                    child: Theme3AppButton(
                      label: buttonLabel,
                      onPressed: buttonEnabled ? onAccept : null,
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
