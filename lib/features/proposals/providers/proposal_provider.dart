import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../requests/data/mock_request_repository.dart';
import '../../requests/models/shopping_request.dart';
import '../data/mock_proposal_repository.dart';
import '../models/proposal.dart';

class ProposalState {
  final bool isLoading;
  final String? error;
  final List<Proposal> proposals;

  const ProposalState({
    this.isLoading = false,
    this.error,
    this.proposals = const [],
  });

  ProposalState copyWith({
    bool? isLoading,
    String? error,
    List<Proposal>? proposals,
    bool clearError = false,
  }) {
    return ProposalState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      proposals: proposals ?? this.proposals,
    );
  }
}

class ProposalNotifier extends StateNotifier<ProposalState> {
  ProposalNotifier(this.ref) : super(const ProposalState()) {
    _repo = MockProposalRepository.instance;
    _requestRepo = MockRequestRepository.instance;
  }

  final Ref ref;
  late final MockProposalRepository _repo;
  late final MockRequestRepository _requestRepo;

  Future<List<Proposal>> loadProposalsForRequest(String requestId) async {
    await _repo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final proposals = await _repo.getProposalsForRequest(requestId);
      state = state.copyWith(isLoading: false, proposals: proposals);
      return proposals;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return [];
    }
  }

  Future<void> loadVendorProposals() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final proposals = await _repo.getProposalsForVendor(user.id);
      state = state.copyWith(isLoading: false, proposals: proposals);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> submitProposal(Proposal proposal) async {
    await _repo.ensureInitialized();
    await _requestRepo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final newProposal = await _repo.createProposal(proposal);
      state = state.copyWith(
        isLoading: false,
        proposals: [newProposal, ...state.proposals],
      );
      // Also update request status to 'proposalSubmitted'
      await _requestRepo.updateRequestStatus(proposal.requestId, RequestStatus.proposalSubmitted);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> acceptProposal(String proposalId, String requestId) async {
    await _repo.ensureInitialized();
    await _requestRepo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // Accept this proposal
      await _repo.updateProposalStatus(proposalId, ProposalStatus.accepted);
      
      // Reject all other proposals for this request
      final allProps = await _repo.getProposalsForRequest(requestId);
      for (final p in allProps) {
        if (p.id != proposalId) {
          await _repo.updateProposalStatus(p.id, ProposalStatus.rejected, rejectionReason: 'Other proposal accepted');
        }
      }

      // Update request status to 'customerAccepted'
      await _requestRepo.updateRequestStatus(requestId, RequestStatus.customerAccepted);
      
      // Reload proposals
      await loadProposalsForRequest(requestId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> rejectProposal(String proposalId, String requestId, String reason) async {
    await _repo.ensureInitialized();
    await _requestRepo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.updateProposalStatus(proposalId, ProposalStatus.rejected, rejectionReason: reason);
      
      // Update request status to 'customerRejected' if this was the last active proposal or just general status update
      await _requestRepo.updateRequestStatus(requestId, RequestStatus.customerRejected);
      
      // Reload proposals
      await loadProposalsForRequest(requestId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> sendControlledMessage(String proposalId, {String? customerMsg, String? vendorMsg}) async {
    await _repo.ensureInitialized();
    try {
      await _repo.sendControlledMessage(proposalId, customerMsg: customerMsg, vendorMsg: vendorMsg);
      // Reload matching proposals
      final index = state.proposals.indexWhere((p) => p.id == proposalId);
      if (index != -1) {
        final updated = state.proposals[index].copyWith(
          customerResponse: customerMsg,
          vendorResponse: vendorMsg,
        );
        final newList = List<Proposal>.from(state.proposals);
        newList[index] = updated;
        state = state.copyWith(proposals: newList);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final proposalProvider = StateNotifierProvider<ProposalNotifier, ProposalState>((ref) {
  return ProposalNotifier(ref);
});
