import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../proposals/models/proposal.dart';
import '../../../requests/models/shopping_request.dart';
import '../models/customer_proposal_view.dart';
import '../models/proposal_comparison_mode.dart';
import '../services/proposal_comparison_service.dart';

class CustomerProposalComparisonState {
  const CustomerProposalComparisonState({
    this.mode = ProposalComparisonMode.lowestPrice,
    this.views = const [],
  });

  final ProposalComparisonMode mode;
  final List<CustomerProposalView> views;

  CustomerProposalComparisonState copyWith({
    ProposalComparisonMode? mode,
    List<CustomerProposalView>? views,
  }) {
    return CustomerProposalComparisonState(
      mode: mode ?? this.mode,
      views: views ?? this.views,
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
    final views = service.buildViews(
      proposals: proposals,
      request: request,
      mode: effectiveMode,
    );
    state = CustomerProposalComparisonState(
      mode: effectiveMode,
      views: views,
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
  return CustomerProposalComparisonNotifier(ref);
});
