import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/providers/notification_provider.dart';
import '../../vendor/proposals/services/proposal_validation_service.dart';
import '../../requests/data/mock_request_repository.dart';
import '../../requests/models/shopping_request.dart';
import '../../requests/models/request_category_fulfillment.dart';
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
      // Get accepted proposal and its category
      final acceptedProposal = await _repo.getProposalById(proposalId);
      if (acceptedProposal == null) throw Exception('Proposal not found');
      
      final acceptedCategory = acceptedProposal.categoryNormalized;
      print('[MultiCategoryFlow] Accept proposal: ${acceptedProposal.id}');
      print('[MultiCategoryFlow] Accepted category: $acceptedCategory');

      // Accept selected proposal
      await _repo.updateProposalStatus(proposalId, ProposalStatus.accepted);

      // Reject only competing proposals from SAME category
      final allProps = await _repo.getAllProposalsForRequest(requestId);
      for (final p in allProps) {
        if (p.id != proposalId && p.status.isEditableByVendor) {
          // Only reject if same category
          if (p.categoryNormalized == acceptedCategory) {
            final rejectionReason = acceptedCategory != null
                ? 'Customer selected another vendor for $acceptedCategory category'
                : 'Customer selected another vendor for this category';
            
            await _repo.updateProposalStatus(
              p.id,
              ProposalStatus.rejected,
              rejectionReason: rejectionReason,
            );
            print('[MultiCategoryFlow] Rejected same-category competitor: ${p.id}');
            
            // Notify vendor about rejection
            ref.read(notificationProvider.notifier).triggerNotification(
              title: 'Proposal not selected',
              body: rejectionReason,
              icon: Icons.cancel_outlined,
              color: const Color(0xFFEF5350),
            );
          } else {
            print('[MultiCategoryFlow] Preserved other-category proposal: ${p.id} (${p.categoryNormalized})');
          }
        }
      }

      // Update category fulfillment
      final request = await _requestRepo.getRequestById(requestId);
      if (request != null && acceptedCategory != null) {
        final updatedFulfillments = Map<String, RequestCategoryFulfillment>.from(
          request.categoryFulfillments,
        );
        final current = updatedFulfillments[acceptedCategory];
        if (current != null) {
          updatedFulfillments[acceptedCategory] = current.copyWith(
            status: RequestCategoryStatus.accepted,
            acceptedProposalId: proposalId,
            acceptedVendorId: acceptedProposal.vendorId,
            acceptedAt: DateTime.now(),
          );
          print('[MultiCategoryFlow] Updated category fulfillment: $acceptedCategory');
        }

        // Update request with new fulfillments
        final updatedRequest = request.copyWith(
          categoryFulfillments: updatedFulfillments,
          updatedAt: DateTime.now(),
        );
        await _requestRepo.updateRequest(updatedRequest);

        // Log summary
        final accepted = updatedRequest.acceptedCategoriesCount;
        final pending = updatedRequest.pendingCategoriesCount;
        final completed = updatedRequest.completedCategoriesCount;
        print('[MultiCategoryFlow] Request summary: $accepted accepted, $pending pending, $completed completed');

        // Only mark entire request as accepted if all categories are accepted/completed
        // For now, keep as customerAccepted when first category accepted
        if (request.status != RequestStatus.customerAccepted) {
          await _requestRepo.updateRequestStatus(
            requestId,
            RequestStatus.customerAccepted,
          );
        }
      }

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
      
      // Notify vendor about rejection
      ref.read(notificationProvider.notifier).triggerNotification(
        title: 'Proposal rejected',
        body: reason,
        icon: Icons.cancel_outlined,
        color: const Color(0xFFEF5350),
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

  Future<void> saveProposalToWishlist(String proposalId) async {
    await _repo.ensureInitialized();
    try {
      await _repo.saveProposalToWishlist(proposalId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> removeSavedProposal(String proposalId) async {
    await _repo.ensureInitialized();
    try {
      await _repo.removeSavedProposal(proposalId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<List<String>> getSavedProposalIds() async {
    await _repo.ensureInitialized();
    return _repo.getSavedProposalIds();
  }

  bool isSavedProposal(String proposalId) {
    return _repo.isSavedProposal(proposalId);
  }
}

final proposalProvider =
    StateNotifierProvider<ProposalNotifier, ProposalState>((ref) {
  return ProposalNotifier(ref);
});

final proposalValidationServiceProvider =
    Provider((ref) => const ProposalValidationService());
