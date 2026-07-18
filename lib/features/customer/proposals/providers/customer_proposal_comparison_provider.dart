import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../proposals/models/proposal.dart';
import '../../../requests/models/shopping_request.dart';
import '../../../orders/providers/order_provider.dart';
import '../models/customer_item_proposal_view.dart';
import '../models/customer_proposal_view.dart';
import '../models/proposal_comparison_mode.dart';
import '../services/proposal_comparison_service.dart';

class CustomerProposalComparisonState {
  const CustomerProposalComparisonState({
    this.mode = ProposalComparisonMode.lowestPrice,
    this.views = const [],
    this.itemViews = const [],
  });

  final ProposalComparisonMode mode;

  /// Legacy per-proposal views (backward compat).
  final List<CustomerProposalView> views;

  /// Item-level views: one entry per requested item, containing all vendor offers.
  final List<CustomerItemProposalView> itemViews;

  CustomerProposalComparisonState copyWith({
    ProposalComparisonMode? mode,
    List<CustomerProposalView>? views,
    List<CustomerItemProposalView>? itemViews,
  }) {
    return CustomerProposalComparisonState(
      mode: mode ?? this.mode,
      views: views ?? this.views,
      itemViews: itemViews ?? this.itemViews,
    );
  }
}

final proposalComparisonServiceProvider =
    Provider((ref) => const ProposalComparisonService());

class CustomerProposalComparisonNotifier
    extends StateNotifier<CustomerProposalComparisonState> {
  CustomerProposalComparisonNotifier(this.ref)
      : super(const CustomerProposalComparisonState());

  final Ref ref;

  void updateFrom({
    required List<Proposal> proposals,
    required ShoppingRequest request,
    ProposalComparisonMode? mode,
  }) {
    final service = ref.read(proposalComparisonServiceProvider);
    final effectiveMode = mode ?? state.mode;
    final orders = ref.read(orderProvider).orders;
    final views = service.buildViews(
      proposals: proposals,
      request: request,
      mode: effectiveMode,
      orders: orders,
    );
    final itemViews = service.buildItemViews(
      proposals: proposals,
      request: request,
    );
    state = CustomerProposalComparisonState(
      mode: effectiveMode,
      views: views,
      itemViews: itemViews,
    );
  }

  void setMode(
    ProposalComparisonMode mode, {
    required List<Proposal> proposals,
    required ShoppingRequest request,
  }) {
    updateFrom(proposals: proposals, request: request, mode: mode);
  }
}

final customerProposalComparisonProvider = StateNotifierProvider.autoDispose
    .family<CustomerProposalComparisonNotifier, CustomerProposalComparisonState,
        String>((ref, requestId) {
  // Watch orderProvider to auto-trigger update whenever order status changes
  ref.watch(orderProvider);
  return CustomerProposalComparisonNotifier(ref);
});

