import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/theme3/theme3_app_bar.dart';
import '../../../../core/widgets/theme3/theme3_app_button.dart';
import '../../../../core/widgets/theme3/theme3_app_card.dart';
import '../../../../core/widgets/theme3/theme3_status_chip.dart';
import '../../../../core/widgets/safe_request_image.dart';
import '../../../../shared/utils/category_constants.dart';
import '../../models/request_item.dart';
import '../../models/shopping_request.dart';
import '../../models/request_category_fulfillment.dart';
import '../../providers/request_provider.dart';
import '../../../proposals/providers/proposal_provider.dart';
import '../../../proposals/models/proposal.dart';
import '../../../customer/proposals/models/customer_proposal_view.dart';
import '../../../customer/proposals/providers/customer_proposal_comparison_provider.dart';
import '../../../customer/proposals/services/proposal_comparison_service.dart';
import '../../../customer/proposals/widgets/customer_proposal_card.dart';
import '../../../requests/data/mock_request_repository.dart';
import 'request_item_details_screen.dart';
import '../widgets/category_selector.dart';

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
  bool _isAcceptingProposal = false;

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

  Future<void> _acceptProposal(
    Proposal proposal, {
    String? categoryNormalized,
    Proposal? paymentProposal,
  }) async {
    if (_isAcceptingProposal) return;
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

    setState(() {
      _isAcceptingProposal = true;
    });

    try {
      await ref
          .read(proposalProvider.notifier)
          .acceptProposal(
            proposal.id,
            _request.id,
            categoryNormalized: categoryNormalized,
          );
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
    } finally {
      if (mounted) {
        setState(() {
          _isAcceptingProposal = false;
        });
      }
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

  Widget _buildProposalsSectionHeader({
    required String title,
    required String subtitle,
    required int count,
    required Color primaryText,
    required Color secondaryText,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.customerColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.h2(primaryText)),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTextStyles.caption(secondaryText)),
            ],
          ),
        ),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.customerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              count.toString(),
              style: AppTextStyles.caption(AppColors.customerColor)
                  .copyWith(fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  Widget _buildProposalInfoTile({
    required IconData icon,
    required Color color,
    required String message,
    required bool isDark,
    required Color borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: color.withValues(alpha: 0.7)),
          const SizedBox(height: 10),
          Text(
            message,
            style: AppTextStyles.bodyMedium(
              isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<CustomerProposalView> _buildViewsFromProposals(List<Proposal> proposals) {
    const service = ProposalComparisonService();
    return proposals.map((p) => CustomerProposalView(
      proposal: p,
      maskedVendorName: service.maskedVendorName(p.vendorId),
      distanceKm: service.distanceKmFor(proposal: p, request: _request),
      ratingPlaceholder: service.ratingPlaceholderFor(p.vendorId),
      deliverySortHours: service.deliverySortHours(p.estimatedDeliveryTime),
      isBestForMode: false,
      badges: [],
    )).toList();
  }

  List<Widget> _buildSplitProposalSections({
    required List<CustomerProposalView> views,
    required bool hasAcceptedProposal,
    required bool proposalsEnabled,
    required Color primaryText,
    required Color secondaryText,
    required Color borderColor,
    required bool isDark,
  }) {
    final confirmed = views.where((v) => v.isAccepted).toList();
    final pending = views.where((v) => !v.isAccepted && !v.isInactive).toList();
    final inactive = views.where((v) => v.isInactive).toList();
    final widgets = <Widget>[];

    // ── Confirmed Order ──────────────────────────────────────────────────
    if (confirmed.isNotEmpty) {
      widgets.add(_buildGroupContainer(
        color: AppColors.success,
        icon: Icons.check_circle_rounded,
        label: 'Confirmed Order',
        sublabel: 'You accepted this offer',
        count: confirmed.length,
        isDark: isDark,
        children: confirmed.map((view) => CustomerProposalCard(
          key: ValueKey(view.proposalId),
          view: view,
          requestId: _request.id,
          enabled: proposalsEnabled,
          onAccept: () => context.push('/customer/payment', extra: {
            'proposal': view.proposal,
            'requestId': _request.id,
          }),
          onReject: null,
        )).toList(),
      ));
    }

    // ── Pending Offers ───────────────────────────────────────────────────
    if (pending.isNotEmpty) {
      final pendingChildren = <Widget>[];
      for (int i = 0; i < pending.length; i++) {
        final view = pending[i];
        final canAct = proposalsEnabled && view.canAcceptOrReject && !hasAcceptedProposal;
        if (i > 0) {
          pendingChildren.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Divider(color: borderColor)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or', style: TextStyle(fontSize: 12, color: secondaryText)),
                  ),
                  Expanded(child: Divider(color: borderColor)),
                ],
              ),
            ),
          );
        }
        pendingChildren.add(CustomerProposalCard(
          key: ValueKey(view.proposalId),
          view: view,
          requestId: _request.id,
          enabled: proposalsEnabled,
          onAccept: canAct ? () => _acceptProposal(view.proposal) : null,
          onReject: canAct ? () => _rejectProposal(view.proposal) : null,
        ));
      }
      widgets.add(_buildGroupContainer(
        color: AppColors.vendorColor,
        icon: Icons.pending_actions_rounded,
        label: 'Pending Offers',
        sublabel: hasAcceptedProposal
            ? 'Other offers — already accepted one'
            : 'Compare and accept the best offer',
        count: pending.length,
        isDark: isDark,
        children: pendingChildren,
      ));
    }

    // ── Closed Offers ────────────────────────────────────────────────────
    if (inactive.isNotEmpty) {
      widgets.add(_buildGroupContainer(
        color: AppColors.textSecondaryLight,
        icon: Icons.do_not_disturb_rounded,
        label: 'Closed Offers',
        sublabel: 'Rejected or expired',
        count: inactive.length,
        isDark: isDark,
        children: inactive.map((view) => Opacity(
          opacity: 0.5,
          child: CustomerProposalCard(
            key: ValueKey(view.proposalId),
            view: view,
            requestId: _request.id,
            enabled: false,
            onAccept: null,
            onReject: null,
          ),
        )).toList(),
      ));
    }

    return widgets;
  }

  Widget _buildGroupContainer({
    required Color color,
    required IconData icon,
    required String label,
    required String sublabel,
    required int count,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.06) : color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                      Text(sublabel, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
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

    // Build a map of requestItemId -> normalized category from the request items
    final itemCategoryMap = <String, String>{};
    for (final item in _request.items) {
      final cat = VendorCategories.normalize(item.category?.trim() ?? '');
      if (cat.isNotEmpty) itemCategoryMap[item.id] = cat;
    }

    // Group proposals per category — a single proposal covering multiple
    // categories appears in EACH category it has items for.
    final groupedProposals = <String, List<Proposal>>{};
    for (final proposal in proposals) {
      // Collect every category this proposal actually covers via its items
      final coveredCategories = <String>{};
      for (final pi in proposal.items) {
        final cat = itemCategoryMap[pi.requestItemId];
        if (cat != null && cat.isNotEmpty) coveredCategories.add(cat);
      }
      // Fall back to categoryNormalized field if items gave nothing
      if (coveredCategories.isEmpty && proposal.categoryNormalized != null &&
          proposal.categoryNormalized!.isNotEmpty) {
        coveredCategories.add(proposal.categoryNormalized!);
      }
      // Last resort: first request category
      if (coveredCategories.isEmpty && requestCategories.isNotEmpty) {
        coveredCategories.add(requestCategories.first);
      }
      for (final cat in coveredCategories) {
        groupedProposals.putIfAbsent(cat, () => []).add(proposal);
      }
    }

    // Sort: categories with active offers (accepted/pending) first, no-offer categories last
    bool hasActiveOffers(String cat) {
      final catProposals = groupedProposals[cat] ?? [];
      return catProposals.any((p) =>
          p.status != ProposalStatus.withdrawn &&
          p.status != ProposalStatus.rejected &&
          p.status != ProposalStatus.expired);
    }
    requestCategories.sort((a, b) {
      final aRank = hasActiveOffers(a) ? 0 : 1;
      final bRank = hasActiveOffers(b) ? 0 : 1;
      return aRank.compareTo(bRank);
    });

    const service = ProposalComparisonService();

    // Detect which proposals span more than one category (multi-category proposals)
    final proposalCategoryCount = <String, int>{};
    for (final catProposals in groupedProposals.values) {
      for (final p in catProposals) {
        proposalCategoryCount[p.id] = (proposalCategoryCount[p.id] ?? 0) + 1;
      }
    }
    bool isMultiCategoryProposal(String proposalId) =>
        (proposalCategoryCount[proposalId] ?? 1) > 1;

    final widgets = <Widget>[];

    for (final category in requestCategories) {
      final categoryProposals = groupedProposals[category] ?? [];
      final categoryStatus = _request.getCategoryStatus(category);
      final categoryAccepted =
          categoryStatus == RequestCategoryStatus.accepted ||
          categoryStatus == RequestCategoryStatus.codConfirmed ||
          categoryStatus == RequestCategoryStatus.outForDelivery ||
          categoryStatus == RequestCategoryStatus.paid;
      final catMeta = CategoryMeta.of(category);
      final categoryColor = catMeta.color;

      final categoryItems = _request.items
          .where((item) => VendorCategories.normalize(item.category?.trim() ?? '') == category)
          .toList();

      // Map each request item to the proposals that cover it
      final itemProposalsMap = <String, List<Proposal>>{};
      for (final item in categoryItems) {
        itemProposalsMap[item.id] = [];
      }
      for (final p in categoryProposals) {
        for (final pi in p.items) {
          if (itemProposalsMap.containsKey(pi.requestItemId) &&
              pi.status != ProposalItemStatus.unavailable) {
            if (!itemProposalsMap[pi.requestItemId]!.contains(p)) {
              itemProposalsMap[pi.requestItemId]!.add(p);
            }
          }
        }
      }

      // Items with any active offer sort to top
      bool itemHasOffer(RequestItem item) {
        final ps = itemProposalsMap[item.id] ?? [];
        return ps.any((p) =>
            p.status == ProposalStatus.submitted ||
            p.status == ProposalStatus.updated ||
            p.status == ProposalStatus.accepted);
      }
      categoryItems.sort((a, b) {
        final aRank = itemHasOffer(a) ? 0 : 1;
        final bRank = itemHasOffer(b) ? 0 : 1;
        return aRank.compareTo(bRank);
      });

      // Global item number within the category (1-based, stable original order)
      final originalOrder = _request.items
          .where((item) => VendorCategories.normalize(item.category?.trim() ?? '') == category)
          .toList();
      int itemNumber(RequestItem item) => originalOrder.indexOf(item) + 1;

      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: categoryColor.withValues(alpha: 0.35)),
            color: isDark ? categoryColor.withValues(alpha: 0.05) : categoryColor.withValues(alpha: 0.03),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Category header ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.10),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(catMeta.icon, size: 18, color: categoryColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(VendorCategories.display(category),
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)),
                          Text('${categoryItems.length} item${categoryItems.length == 1 ? '' : 's'} · ${categoryProposals.length} offer${categoryProposals.length == 1 ? '' : 's'}',
                              style: TextStyle(fontSize: 11, color: categoryColor.withValues(alpha: 0.85))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: categoryColor, borderRadius: BorderRadius.circular(20)),
                      child: Text(categoryStatus.displayName,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...() {
                      final itemWidgets = <Widget>[];
                      for (int ei = 0; ei < categoryItems.length; ei++) {
                        final item = categoryItems[ei];
                        final num = itemNumber(item);
                        final itemProposals = itemProposalsMap[item.id] ?? [];
                        final hasOffer = itemHasOffer(item);

                        bool isAcceptedForCategory(Proposal p) {
                          final fulfillment = _request.getFulfillment(category);
                          return fulfillment?.acceptedProposalId == p.id &&
                              (fulfillment?.status == RequestCategoryStatus.accepted ||
                                  fulfillment?.status == RequestCategoryStatus.codConfirmed ||
                                  fulfillment?.status == RequestCategoryStatus.outForDelivery ||
                                  fulfillment?.status == RequestCategoryStatus.paid ||
                                  fulfillment?.status == RequestCategoryStatus.completed);
                        }

                        final acceptedForItem = itemProposals
                            .where(isAcceptedForCategory)
                            .toList();
                        final pendingForItem = itemProposals.where((p) {
                          final openStatus = p.status == ProposalStatus.submitted ||
                              p.status == ProposalStatus.updated ||
                              p.status == ProposalStatus.accepted;
                          return openStatus && !isAcceptedForCategory(p);
                        }).toList();
                        final closedForItem = itemProposals.where((p) =>
                            p.status == ProposalStatus.withdrawn ||
                            p.status == ProposalStatus.rejected ||
                            p.status == ProposalStatus.expired).toList();

                        if (ei > 0) {
                          itemWidgets.add(Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Divider(color: AppColors.error.withValues(alpha: 1), thickness: 1),
                          ));
                        }

                        itemWidgets.add(Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Item heading ──
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22, height: 22,
                                    decoration: BoxDecoration(
                                      color: categoryColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$num',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Item $num',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: categoryColor),
                                  ),
                                ],
                              ),
                            ),
                            // ── Item row ──
                            _Theme3RequestItemCard(
                              itemNumber: num,
                              item: item,
                              categoryStatus: categoryStatus,
                              hasOffer: hasOffer,
                              onTap: () => _openItemDetails(item),
                              isDark: isDark,
                            ),
                            const SizedBox(height: 8),
                            // ── Offers for this item ──
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Row(
                                children: [
                                  Expanded(child: Divider(color: secondaryText.withValues(alpha: 0.3))),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.local_offer_rounded, size: 13, color: secondaryText),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Shop Owner Offers',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: secondaryText),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(child: Divider(color: secondaryText.withValues(alpha: 0.3))),
                                ],
                              ),
                            ),
                            if (acceptedForItem.isNotEmpty)
                              ...acceptedForItem.map((p) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: _ProposalCardWithBadge(
                                  key: ValueKey('${p.id}_${item.id}_accepted'),
                                  view: _toItemFilteredView(p, item, service),
                                  originalProposalId: p.id,
                                  requestId: _request.id,
                                  enabled: proposalsEnabled,
                                  isMultiCategoryProposal: isMultiCategoryProposal(p.id),
                                  cardBorderColor: AppColors.error,
                                  onAccept: () => _handleAcceptedProposalAction(
                                    _toItemFilteredView(p, item, service).proposal,
                                    categoryStatus,
                                  ),
                                  onReject: null,
                                ),
                              ))
                            else if (pendingForItem.isNotEmpty)
                              ...pendingForItem.map((p) {
                                final canAct = proposalsEnabled && !categoryAccepted;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: _ProposalCardWithBadge(
                                    key: ValueKey('${p.id}_${item.id}_pending'),
                                    view: _toItemFilteredView(p, item, service),
                                    originalProposalId: p.id,
                                    requestId: _request.id,
                                    enabled: proposalsEnabled,
                                    isMultiCategoryProposal: isMultiCategoryProposal(p.id),
                                    cardBorderColor: AppColors.error,
                                    onAccept: canAct
                                        ? () {
                                            final itemView = _toItemFilteredView(
                                              p,
                                              item,
                                              service,
                                            );
                                            _acceptProposal(
                                              p,
                                              categoryNormalized: category,
                                              paymentProposal: itemView.proposal,
                                            );
                                          }
                                        : null,
                                    onReject: canAct ? () => _rejectProposal(p) : null,
                                  ),
                                );
                              })
                            else
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.customerColor.withValues(alpha: 0.05)
                                      : AppColors.customerColor.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.customerColor.withValues(alpha: 0.12)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.hourglass_empty_rounded, size: 15, color: secondaryText),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Waiting for shop owner offer',
                                      style: TextStyle(fontSize: 12, color: secondaryText),
                                    ),
                                  ],
                                ),
                              ),
                            // ── Closed offers for this item ──
                            if (closedForItem.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: _buildGroupContainer(
                                  color: AppColors.textSecondaryLight,
                                  icon: Icons.do_not_disturb_rounded,
                                  label: 'Closed Offers',
                                  sublabel: 'Rejected or expired',
                                  count: closedForItem.length,
                                  isDark: isDark,
                                  children: closedForItem.map((p) => Opacity(
                                    opacity: 0.5,
                                    child: _ProposalCardWithBadge(
                                      key: ValueKey('${p.id}_${item.id}_closed'),
                                      view: _toItemFilteredView(p, item, service),
                                      originalProposalId: p.id,
                                      requestId: _request.id,
                                      enabled: false,
                                      isMultiCategoryProposal: isMultiCategoryProposal(p.id),
                                      onAccept: null,
                                      onReject: null,
                                    ),
                                  )).toList(),
                                ),
                              ),
                          ],
                        ));
                      }
                      return itemWidgets;
                    }(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  CustomerProposalView _toItemFilteredView(
    Proposal p,
    RequestItem requestItem,
    ProposalComparisonService service,
  ) {
    final singleItem = p.items
        .where((pi) => pi.requestItemId == requestItem.id)
        .toList();
    final subtotal = singleItem.fold<double>(0, (s, i) => s + i.subtotal);
    final category = VendorCategories.normalize(requestItem.category?.trim() ?? '');
    final fulfillment = _request.getFulfillment(category);
    final acceptedForCategory = fulfillment?.acceptedProposalId == p.id &&
        (fulfillment?.status == RequestCategoryStatus.accepted ||
            fulfillment?.status == RequestCategoryStatus.codConfirmed ||
            fulfillment?.status == RequestCategoryStatus.outForDelivery ||
            fulfillment?.status == RequestCategoryStatus.paid ||
            fulfillment?.status == RequestCategoryStatus.completed);
    final displayStatus = acceptedForCategory
        ? ProposalStatus.accepted
        : p.status == ProposalStatus.accepted
            ? ProposalStatus.submitted
            : p.status;
    final proposalItemId = singleItem.isNotEmpty ? singleItem.first.id : requestItem.id;

    return CustomerProposalView(
      proposal: p.copyWith(
        items: singleItem,
        totalPrice: subtotal + p.deliveryCharge,
        status: displayStatus,
        categoryNormalized: category.isEmpty ? p.categoryNormalized : category,
      ),
      proposalItemId: proposalItemId,
      maskedVendorName: service.maskedVendorName(p.vendorId),
      distanceKm: service.distanceKmFor(proposal: p, request: _request),
      ratingPlaceholder: service.ratingPlaceholderFor(p.vendorId),
      deliverySortHours: service.deliverySortHours(p.estimatedDeliveryTime),
      isBestForMode: false,
      badges: [],
    );
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

  Widget _buildDeliveryContactSummary({
    required Color primaryText,
    required Color secondaryText,
    required Color borderColor,
    required bool isDark,
  }) {
    final loc = _request.deliveryLocation;

    final area = loc != null
        ? (loc.approximateAreaText.isNotEmpty ? loc.approximateAreaText : loc.displayArea)
        : _request.customerArea;

    final districtProvince = loc != null && loc.district.isNotEmpty
        ? '${loc.district}, ${loc.province}'
        : null;

    final street = loc != null && loc.streetAddress.isNotEmpty
        ? loc.streetAddress
        : null;

    final note = loc != null && loc.deliveryNote.isNotEmpty
        ? loc.deliveryNote
        : null;

    final name = _request.customerName.isNotEmpty ? _request.customerName : null;
    final phone = _request.customerPhone.isNotEmpty ? _request.customerPhone : null;

    return Theme3AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 18, color: AppColors.customerColor),
              const SizedBox(width: 8),
              Text('Delivery Details', style: AppTextStyles.subtitle(primaryText)),
            ],
          ),
          const SizedBox(height: 12),
          _summaryRow(Icons.place_outlined, area, primaryText, bold: true),
          if (districtProvince != null) ...[
            const SizedBox(height: 4),
            _summaryRow(Icons.map_outlined, districtProvince, secondaryText),
          ],
          if (street != null) ...[
            const SizedBox(height: 4),
            _summaryRow(Icons.home_outlined, street, secondaryText),
          ],
          if (note != null) ...[
            const SizedBox(height: 4),
            _summaryRow(Icons.sticky_note_2_outlined, 'Note: $note', secondaryText),
          ],
          if (name != null || phone != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: borderColor, height: 1),
            ),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.customerColor),
                const SizedBox(width: 8),
                Text('Contact', style: AppTextStyles.subtitle(primaryText)),
              ],
            ),
            const SizedBox(height: 8),
            if (name != null) ...[
              _summaryRow(Icons.badge_outlined, name, primaryText),
              const SizedBox(height: 4),
            ],
            if (phone != null)
              _summaryRow(Icons.phone_outlined, phone, secondaryText),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String text, Color color, {bool bold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall(color).copyWith(
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
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
    ref.listen<ProposalState>(proposalProvider, (previous, next) {
      if (previous?.proposals != next.proposals) {
        _syncComparison(next.proposals);
      }
    });
    final requestState = ref.watch(requestProvider);
    final requestLoading = requestState.isLoading;

    // Reactively sync _request from provider state so that category
    // fulfillment changes (e.g. COD Confirmed after payment) are shown
    // immediately when the customer navigates back from the payment screen.
    final freshRequest = requestState.requests
        .where((r) => r.id == _request.id)
        .firstOrNull;
    if (freshRequest != null &&
        freshRequest.updatedAt != _request.updatedAt) {
      // Schedule the setState outside of build to avoid calling it during build.
      Future.microtask(() {
        if (mounted) setState(() => _request = freshRequest);
      });
    }

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
                              value: proposalState.proposals
                                  .where((p) =>
                                      p.status != ProposalStatus.withdrawn &&
                                      p.status != ProposalStatus.rejected &&
                                      p.status != ProposalStatus.expired)
                                  .length
                                  .toString(),
                              icon: Icons.local_offer_outlined,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDeliveryContactSummary(
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    borderColor: borderColor,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 24),
                  if (_request.isMultiCategory && !_isCancelled) ...[
                    // ── Multi-category: items + offers unified per category ──
                    Row(
                      children: [
                        Container(
                          width: 4, height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.customerColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Items & Offers by Category', style: AppTextStyles.h2(primaryText)),
                              const SizedBox(height: 2),
                              Text(
                                _isCancelled
                                    ? 'This request was cancelled'
                                    : hasAcceptedProposal
                                        ? 'You have confirmed an order'
                                        : '${_request.totalCategories} categories · ${proposalState.proposals.length} offer${proposalState.proposals.length == 1 ? '' : 's'} received',
                                style: AppTextStyles.caption(secondaryText),
                              ),
                            ],
                          ),
                        ),
                        // Progress pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${_request.acceptedCategoriesCount}/${_request.totalCategories} done',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _request.totalCategories > 0
                            ? _request.acceptedCategoriesCount / _request.totalCategories
                            : 0,
                        minHeight: 6,
                        backgroundColor: borderColor,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isCancelled)
                      _buildProposalInfoTile(
                        icon: Icons.block_rounded,
                        color: AppColors.error,
                        message: 'Proposals are closed for cancelled requests.',
                        isDark: isDark,
                        borderColor: borderColor,
                      )
                    else
                      ..._buildCategoryGroupedProposals(
                        proposalState.proposals,
                        hasAcceptedProposal,
                        proposalsEnabled,
                        primaryText,
                        secondaryText,
                        borderColor,
                      ),
                  ] else ...[
                    // ── Single-category: items list then offers ──
                    Row(
                      children: [
                        Container(
                          width: 4, height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.customerColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Requested Items (${_request.items.length})',
                          style: AppTextStyles.h2(primaryText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._request.items.asMap().entries.map((entry) {
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
                    }),
                    const SizedBox(height: 32),
                    Container(width: double.infinity, height: 1, color: borderColor),
                    const SizedBox(height: 28),
                    if (_isCancelled)
                      _buildProposalsSectionHeader(
                        title: 'Proposals',
                        subtitle: 'This request was cancelled',
                        count: 0,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                      )
                    else
                      _buildProposalsSectionHeader(
                        title: 'Shop Owner Offers',
                        subtitle: proposalState.proposals.isEmpty
                            ? 'Waiting for shop owners to respond'
                            : hasAcceptedProposal
                                ? 'You have confirmed an order'
                                : '${proposalState.proposals.length} offer${proposalState.proposals.length == 1 ? '' : 's'} received — pick the best one',
                        count: proposalState.proposals.length,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                      ),
                    const SizedBox(height: 16),
                    if (_isCancelled)
                      _buildProposalInfoTile(
                        icon: Icons.block_rounded,
                        color: AppColors.error,
                        message: 'Proposals are closed for cancelled requests.',
                        isDark: isDark,
                        borderColor: borderColor,
                      )
                    else if (proposalState.proposals.isEmpty)
                      _buildProposalInfoTile(
                        icon: Icons.storefront_outlined,
                        color: AppColors.customerColor,
                        message: 'Your request is live. Vendors nearby will send offers shortly.',
                        isDark: isDark,
                        borderColor: borderColor,
                      )
                    else
                      ..._buildSplitProposalSections(
                        views: _buildViewsFromProposals(proposalState.proposals),
                        hasAcceptedProposal: hasAcceptedProposal,
                        proposalsEnabled: proposalsEnabled,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                        borderColor: borderColor,
                        isDark: isDark,
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

class _Theme3RequestItemCard extends StatelessWidget {
  const _Theme3RequestItemCard({
    required this.itemNumber,
    required this.item,
    required this.categoryStatus,
    required this.onTap,
    required this.isDark,
    this.hasOffer = false,
  });

  final int itemNumber;
  final RequestItem item;
  final RequestCategoryStatus categoryStatus;
  final VoidCallback onTap;
  final bool isDark;
  final bool hasOffer;

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
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: item.imageUrls.isNotEmpty
                  ? SafeRequestImage(
                      path: item.imageUrls.first,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 64,
                      height: 64,
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
                      if (item.preferredBrand != null && item.preferredBrand!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: secondaryText.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: secondaryText.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.label_outline_rounded, size: 11, color: secondaryText),
                              const SizedBox(width: 4),
                              Text(
                                item.preferredBrand!,
                                style: TextStyle(fontSize: 11, color: secondaryText, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (hasOffer ? AppColors.success : statusColor).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          hasOffer ? 'Offer received' : 'No offer yet',
                          style: TextStyle(
                            fontSize: 10,
                            color: hasOffer ? AppColors.success : statusColor,
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

class _SectionBanner extends StatelessWidget {
  const _SectionBanner({
    required this.label,
    required this.sublabel,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String label;
  final String sublabel;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                ),
                Text(
                  sublabel,
                  style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProposalSectionHeader extends StatelessWidget {
  const _ProposalSectionHeader({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String label;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps [CustomerProposalCard] and prepends a "same vendor" banner when the
/// proposal covers items from multiple categories.
class _ProposalCardWithBadge extends StatelessWidget {
  const _ProposalCardWithBadge({
    super.key,
    required this.view,
    required this.originalProposalId,
    required this.requestId,
    required this.enabled,
    required this.isMultiCategoryProposal,
    this.cardBorderColor,
    this.onAccept,
    this.onReject,
  });

  final CustomerProposalView view;
  final String originalProposalId;
  final String requestId;
  final bool enabled;
  final bool isMultiCategoryProposal;
  final Color? cardBorderColor;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final card = CustomerProposalCard(
      view: view,
      requestId: requestId,
      enabled: enabled,
      overrideBorderColor: cardBorderColor,
      onAccept: onAccept,
      onReject: onReject,
    );
    if (!isMultiCategoryProposal) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.vendorColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.vendorColor.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_rounded, size: 13, color: AppColors.vendorColor),
              const SizedBox(width: 6),
              Text(
                'Same vendor · Ref: $originalProposalId',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.vendorColor,
                ),
              ),
            ],
          ),
        ),
        card,
      ],
    );
  }
}



