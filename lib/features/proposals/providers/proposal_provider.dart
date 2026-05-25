import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../vendor/proposals/services/proposal_validation_service.dart';
import '../../requests/data/mock_request_repository.dart';
import '../../requests/models/shopping_request.dart';
import '../data/mock_proposal_repository.dart';
import '../models/proposal.dart';

class ProposalState {
  const ProposalState({
    this.isLoading = false,
    this.error,
    this.proposals = const [],
    this.selectedProposal,
  });

  final bool isLoading;
  final String? error;
  final List<Proposal> proposals;
  final Proposal? selectedProposal;

  ProposalState copyWith({
    bool? isLoading,
    String? error,
    List<Proposal>? proposals,
    Proposal? selectedProposal,
    bool clearError = false,
    bool clearSelected = false,
  }) {
    return ProposalState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      proposals: proposals ?? this.proposals,
      selectedProposal:
          clearSelected ? null : (selectedProposal ?? this.selectedProposal),
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

  Future<Proposal?> loadVendorProposalForRequest(String requestId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return null;
    await _repo.ensureInitialized();
    final proposal = await _repo.getVendorProposalForRequest(
      vendorId: user.id,
      requestId: requestId,
    );
    state = state.copyWith(selectedProposal: proposal);
    return proposal;
  }

  Future<Proposal?> loadProposalById(String id) async {
    await _repo.ensureInitialized();
    final proposal = await _repo.getProposalById(id);
    state = state.copyWith(selectedProposal: proposal);
    return proposal;
  }

  Future<Proposal> saveDraft(Proposal proposal) async {
    await _repo.ensureInitialized();
    final draft = proposal.copyWith(
      status: ProposalStatus.draft,
      totalPrice: proposal.subtotal + proposal.deliveryCharge,
    );
    final Proposal saved;
    if (draft.id.isEmpty) {
      saved = await _repo.createProposal(draft);
    } else {
      saved = await _repo.updateProposal(draft);
    }
    _upsertInList(saved);
    return saved;
  }

  Future<void> submitProposal(Proposal proposal) async {
    await _repo.ensureInitialized();
    await _requestRepo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final toSubmit = proposal.copyWith(
        status: ProposalStatus.submitted,
        totalPrice: proposal.subtotal + proposal.deliveryCharge,
      );

      final Proposal saved;
      if (toSubmit.id.isEmpty) {
        saved = await _repo.createProposal(toSubmit);
      } else {
        saved = await _repo.updateProposal(toSubmit);
      }

      _upsertInList(saved);

      await _requestRepo.updateRequestStatus(
        proposal.requestId,
        RequestStatus.proposalSubmitted,
      );
      state = state.copyWith(isLoading: false, selectedProposal: saved);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<Proposal> updateVendorProposal(Proposal proposal) async {
    await _repo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _repo.updateProposal(
        proposal.copyWith(
          totalPrice: proposal.subtotal + proposal.deliveryCharge,
        ),
      );
      _upsertInList(updated);
      state = state.copyWith(isLoading: false, selectedProposal: updated);
      return updated;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> withdrawProposal(String proposalId) async {
    await _repo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.withdrawProposal(proposalId);
      final updated = await _repo.getProposalById(proposalId);
      if (updated != null) _upsertInList(updated);
      state = state.copyWith(isLoading: false, selectedProposal: updated);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  void _upsertInList(Proposal proposal) {
    final list = List<Proposal>.from(state.proposals);
    final idx = list.indexWhere((p) => p.id == proposal.id);
    if (idx >= 0) {
      list[idx] = proposal;
    } else {
      list.insert(0, proposal);
    }
    state = state.copyWith(proposals: list, selectedProposal: proposal);
  }

  Future<void> acceptProposal(String proposalId, String requestId) async {
    await _repo.ensureInitialized();
    await _requestRepo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.updateProposalStatus(proposalId, ProposalStatus.accepted);

      final allProps = await _repo.getAllProposalsForRequest(requestId);
      for (final p in allProps) {
        if (p.id != proposalId && p.status.isEditableByVendor) {
          await _repo.updateProposalStatus(
            p.id,
            ProposalStatus.rejected,
            rejectionReason: 'Other proposal accepted',
          );
        }
      }

      await _requestRepo.updateRequestStatus(
        requestId,
        RequestStatus.customerAccepted,
      );

      await loadProposalsForRequest(requestId);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> rejectProposal(
    String proposalId,
    String requestId,
    String reason,
  ) async {
    await _repo.ensureInitialized();
    await _requestRepo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.updateProposalStatus(
        proposalId,
        ProposalStatus.rejected,
        rejectionReason: reason,
      );

      // Keep request open while other vendor bids may still be active.
      final all = await _repo.getAllProposalsForRequest(requestId);
      final hasAccepted =
          all.any((p) => p.status == ProposalStatus.accepted);
      final hasOpenBids = all.any(
        (p) =>
            p.status == ProposalStatus.submitted ||
            p.status == ProposalStatus.updated,
      );
      if (!hasAccepted && !hasOpenBids) {
        await _requestRepo.updateRequestStatus(
          requestId,
          RequestStatus.waitingForVendor,
        );
      }

      await loadProposalsForRequest(requestId);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> sendControlledMessage(
    String proposalId, {
    String? customerMsg,
    String? vendorMsg,
  }) async {
    await _repo.ensureInitialized();
    try {
      await _repo.sendControlledMessage(
        proposalId,
        customerMsg: customerMsg,
        vendorMsg: vendorMsg,
      );
      final updated = await _repo.getProposalById(proposalId);
      if (updated != null) _upsertInList(updated);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final proposalProvider =
    StateNotifierProvider<ProposalNotifier, ProposalState>((ref) {
  return ProposalNotifier(ref);
});

final proposalValidationServiceProvider =
    Provider((ref) => const ProposalValidationService());
