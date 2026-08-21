import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/providers/notification_provider.dart';
import 'package:speedmart_lanka/features/notifications/providers/notification_provider.dart' as notification_feature;
import 'package:speedmart_lanka/features/notifications/models/notification_type.dart';
import 'package:speedmart_lanka/shared/utils/category_constants.dart';
import '../../vendor/proposals/services/proposal_validation_service.dart';
import '../../requests/data/request_repository.dart';
import '../../requests/models/shopping_request.dart';
import '../../requests/models/request_category_fulfillment.dart';
import '../../requests/providers/request_provider.dart';
import '../data/proposal_repository.dart';
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
    _repo = ProposalRepository.instance;
    _requestRepo = RequestRepository.instance;
  }

  final Ref ref;
  late final ProposalRepository _repo;
  late final RequestRepository _requestRepo;

  Future<List<Proposal>> loadProposalsForRequest(String requestId) async {
    await _repo.ensureInitialized();
    await _repo.refreshFromFirestore();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final proposals = await _repo.getProposalsForRequest(requestId);
      print('[ProposalDebug] loadProposalsForRequest($requestId): found ${proposals.length} proposals');
      for (final p in proposals) {
        print('[ProposalDebug]   id=${p.id} status=${p.status.name} categories=${p.categoriesNormalized.join(', ')} items=${p.items.length}');
        for (final item in p.items) {
          print('[ProposalDebug]     item=${item.itemName} status=${item.status.name}');
        }
      }
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

  Future<Proposal?> loadVendorProposalForRequest(
    String requestId, {
    String? categoryNormalized,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return null;
    await _repo.ensureInitialized();
    final proposal = await _repo.getVendorProposalForRequest(
      vendorId: user.id,
      requestId: requestId,
      categoryNormalized: categoryNormalized,
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
      totalPrice: proposal.totalPrice,
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

  Future<Proposal> submitProposal(Proposal proposal) async {
    await _repo.ensureInitialized();
    await _requestRepo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final toSubmit = proposal.copyWith(
        status: ProposalStatus.submitted,
        totalPrice: proposal.totalPrice,
      );

      final Proposal saved;
      if (toSubmit.id.isEmpty) {
        saved = await _repo.createProposal(toSubmit);
      } else {
        saved = await _repo.updateProposal(toSubmit);
      }

      _upsertInList(saved);

      // Increment proposalCount on the request and sync to state
      final request = await _requestRepo.getRequestById(proposal.requestId);
      if (request != null) {
        final updatedRequest = request.copyWith(
          status: RequestStatus.proposalSubmitted,
          proposalCount: request.proposalCount + 1,
          updatedAt: DateTime.now(),
        );
        try {
          await _requestRepo.updateRequest(updatedRequest);
        } catch (e) {
          debugPrint('[ProposalProvider] Ignoring updateRequest error (expected if vendor): $e');
        }
        ref.read(requestProvider.notifier).syncRequest(updatedRequest);
        
        // The server-side onNewProposal function creates the customer
        // notification. Client-side notification creates are denied by rules.
      } else {
        try {
          await _requestRepo.updateRequestStatus(
            proposal.requestId,
            RequestStatus.proposalSubmitted,
          );
        } catch (e) {
          debugPrint('[ProposalProvider] Ignoring updateRequestStatus error: ');
        }
      }

      state = state.copyWith(isLoading: false, selectedProposal: saved);
      return saved;
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
          totalPrice: proposal.totalPrice,
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

  Future<void> acceptProposal(
    String proposalId,
    String requestId, {
    List<String>? categoryScope,
  }) async {
    await _repo.ensureInitialized();
    await _requestRepo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // Get accepted proposal and its category
      final acceptedProposal = await _repo.getProposalById(proposalId);
      if (acceptedProposal == null) throw Exception('Proposal not found');
      
      final acceptedCategories = (categoryScope != null && categoryScope.isNotEmpty
              ? categoryScope
              : acceptedProposal.categoriesNormalized)
          .map(VendorCategories.normalize)
          .where((category) => category.isNotEmpty)
          .toSet()
          .toList();
      print('[MultiCategoryFlow] Accept proposal: ${acceptedProposal.id}');
      print('[MultiCategoryFlow] Accepted categories: $acceptedCategories');

      // Persist notification to vendor that their proposal was accepted
      try {
        await ref.read(notification_feature.notificationProvider.notifier).createNotification(
          type: NotificationType.proposalAccepted,
          title: 'Proposal Accepted',
          body: 'Your proposal has been accepted by the customer.',
          userId: acceptedProposal.vendorId,
          relatedId: acceptedProposal.id,
          data: {'requestId': requestId},
        );
      } catch (_) {}

      // Reject only competing proposals from SAME category
      final allProps = await _repo.getAllProposalsForRequest(requestId);
      for (final p in allProps) {
        if (p.id != proposalId && p.status.isEditableByVendor) {
          // Check if competing proposal overlaps with any accepted categories
          final overlaps = p.categoriesNormalized.any(
            (category) =>
                acceptedCategories.contains(VendorCategories.normalize(category)),
          );
          final proposalCategories = p.categoriesNormalized
              .map(VendorCategories.normalize)
              .where((category) => category.isNotEmpty)
              .toSet();
          final hasOtherOpenCategories = proposalCategories.any(
            (category) => !acceptedCategories.contains(category),
          );
          if (overlaps && !hasOtherOpenCategories) {
            final overlappingCats = proposalCategories
                .where(acceptedCategories.contains)
                .join(', ');
            final rejectionReason = 'Customer selected another vendor for $overlappingCats category';
            
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
            // Persist rejection notification for vendor
            try {
              await ref.read(notification_feature.notificationProvider.notifier).createNotification(
                type: NotificationType.proposalRejected,
                title: 'Proposal Rejected',
                body: rejectionReason,
                userId: p.vendorId,
                relatedId: p.id,
              );
            } catch (_) {}
          } else {
            print('[MultiCategoryFlow] Preserved other-category proposal: ${p.id} (${p.categoriesNormalized})');
          }
        }
      }

      // Update category fulfillment
      final request = await _requestRepo.getRequestById(requestId);
      if (request != null) {
        // Find which categories are actually fulfilled by this proposal 
        // (i.e. items that are NOT unavailable)
        final fulfilledItemIds = acceptedProposal.items
            .where((i) => i.status != ProposalItemStatus.unavailable)
            .map((i) => i.requestItemId)
            .toSet();

        final fulfilledCategories = request.items
            .where((i) => fulfilledItemIds.contains(i.id) && i.category != null && i.category!.isNotEmpty)
            .map((i) => VendorCategories.normalize(i.category!))
            .toSet()
            .toList();

        // Resolve categories: use the actual fulfilled categories, or fall back to
        // all categories if the request has only one or mapping fails.
        final resolvedCategories = acceptedCategories.isNotEmpty
            ? acceptedCategories
            : fulfilledCategories.isNotEmpty
                ? fulfilledCategories
                : request.categoryFulfillments.keys.toList();

        if (resolvedCategories.isNotEmpty) {
          final updatedFulfillments = Map<String, RequestCategoryFulfillment>.from(
            request.categoryFulfillments,
          );
          
          for (final category in resolvedCategories) {
            final current = updatedFulfillments[category];
            if (current != null) {
              updatedFulfillments[category] = current.copyWith(
                status: RequestCategoryStatus.accepted,
                acceptedProposalId: proposalId,
                acceptedVendorId: acceptedProposal.vendorId,
                acceptedAt: DateTime.now(),
              );
              print('[MultiCategoryFlow] Updated category fulfillment: $category');
            }
          }

          final tentativeRequest = request.copyWith(
            categoryFulfillments: updatedFulfillments,
            updatedAt: DateTime.now(),
          );
          final allCategoriesResolved =
              tentativeRequest.categoryFulfillments.isNotEmpty &&
                  tentativeRequest.categoryFulfillments.values
                      .every((fulfillment) =>
                          !fulfillment.status.canReceiveProposals);
          final updatedRequest = tentativeRequest.copyWith(
            status: allCategoriesResolved || !request.isMultiCategory
                ? RequestStatus.customerAccepted
                : request.status,
          );
          await _requestRepo.updateRequest(updatedRequest);

          final proposalFullyAccepted = !request.isMultiCategory ||
              acceptedProposal.categoriesNormalized.every((category) {
                final fulfillment =
                    updatedRequest.getFulfillment(VendorCategories.normalize(category));
                return fulfillment?.acceptedProposalId == proposalId &&
                    fulfillment?.status.canReceiveProposals == false;
              });
          if (proposalFullyAccepted &&
              acceptedProposal.status != ProposalStatus.accepted) {
            await _repo.updateProposalStatus(proposalId, ProposalStatus.accepted);
          }

          // Log summary
          final accepted = updatedRequest.acceptedCategoriesCount;
          final pending = updatedRequest.pendingCategoriesCount;
          final completed = updatedRequest.completedCategoriesCount;
          print('[MultiCategoryFlow] Request summary: $accepted accepted, $pending pending, $completed completed');
        }

        // Sync updated request into requestProvider state
        final refreshed = await _requestRepo.getRequestById(requestId);
        if (refreshed != null) {
          ref.read(requestProvider.notifier).syncRequest(refreshed);
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
      // Persist notification to vendor about rejection
      try {
        final updatedProp = await _repo.getProposalById(proposalId);
        if (updatedProp != null) {
          await ref.read(notification_feature.notificationProvider.notifier).createNotification(
            type: NotificationType.proposalRejected,
            title: 'Proposal Rejected',
            body: reason,
            userId: updatedProp.vendorId,
            relatedId: updatedProp.id,
          );
        }
      } catch (_) {}
      
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

      // Decrement proposalCount and sync
      final request = await _requestRepo.getRequestById(requestId);
      if (request != null) {
        final newCount = (request.proposalCount - 1).clamp(0, 9999);
        final newStatus = hasAccepted
            ? request.status
            : hasOpenBids
                ? RequestStatus.proposalSubmitted
                : RequestStatus.waitingForVendor;
        final updatedRequest = request.copyWith(
          status: newStatus,
          proposalCount: newCount,
          updatedAt: DateTime.now(),
        );
        try {
          await _requestRepo.updateRequest(updatedRequest);
        } catch (e) {
          debugPrint('[ProposalProvider] Ignoring updateRequest error: ');
        }
        ref.read(requestProvider.notifier).syncRequest(updatedRequest);
      } else if (!hasAccepted && !hasOpenBids) {
        try {
          await _requestRepo.updateRequestStatus(
            requestId,
            RequestStatus.waitingForVendor,
          );
        } catch (e) {
          debugPrint('[ProposalProvider] Ignoring updateRequestStatus error: ');
        }
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

  // ── Item-level accept/reject ──────────────────────────────────────────────

  /// Accepts one vendor's offer for a specific requested item.
  /// - Sets that ProposalItem's customerDecision = accepted.
  /// - Rejects the same requestItemId from ALL OTHER proposals.
  /// - If all items in the winning proposal are resolved → marks proposal accepted.
  /// - Competing proposals from other categories remain untouched.
  Future<void> acceptProposalItem({
    required String proposalId,
    required String requestItemId,
    required String requestId,
  }) async {
    await _repo.ensureInitialized();
    await _requestRepo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // 1. Mark the specific item as accepted in the winning proposal
      await _repo.updateProposalItemDecision(
        proposalId: proposalId,
        requestItemId: requestItemId,
        decision: ProposalItemDecision.accepted,
      );
      print('[ItemAccept] Accepted item $requestItemId in proposal $proposalId');

      // 2. Reject the same requestItemId in ALL OTHER proposals for this request
      final allProps = await _repo.getAllProposalsForRequest(requestId);
      for (final p in allProps) {
        if (p.id == proposalId || !p.status.isEditableByVendor) continue;
        final hasMatchingItem = p.items.any((i) => i.requestItemId == requestItemId);
        if (hasMatchingItem) {
          await _repo.updateProposalItemDecision(
            proposalId: p.id,
            requestItemId: requestItemId,
            decision: ProposalItemDecision.rejected,
          );
          print('[ItemAccept] Rejected item $requestItemId in competing proposal ${p.id}');
        }
      }

      // 3. Check if the winning proposal's items are all resolved → mark whole proposal accepted
      /*
      final updatedWinner = await _repo.getProposalById(proposalId);
      if (updatedWinner != null) {
        // Item choices remain provisional until the checkout transaction writes
        // matching orders, payments, and item fulfillments.
        final checkoutTransactionIsRequired = true;
        final allResolved = updatedWinner.items.every(
          (i) => i.customerDecision != ProposalItemDecision.pending ||
              i.status == ProposalItemStatus.unavailable,
        );
        final anyAccepted = updatedWinner.items
            .any((i) => i.customerDecision == ProposalItemDecision.accepted);
        if (allResolved && anyAccepted && !checkoutTransactionIsRequired) {
          await _repo.updateProposalStatus(proposalId, ProposalStatus.accepted);
          print('[ItemAccept] All items resolved — proposal $proposalId → accepted');
          // Update request category fulfillment
          final request = await _requestRepo.getRequestById(requestId);
          if (request != null) {
            // Find which categories were actually accepted by looking at the accepted items
            final acceptedItemIds = updatedWinner.items
                .where((i) => i.customerDecision == ProposalItemDecision.accepted)
                .map((i) => i.requestItemId)
                .toSet();

            final fulfilledCategories = request.items
                .where((i) => acceptedItemIds.contains(i.id) && i.category != null && i.category!.isNotEmpty)
                .map((i) => VendorCategories.normalize(i.category!))
                .toSet()
                .toList();

            // Fallback for single category requests or if category mapping fails
            final resolvedCategories = fulfilledCategories.isNotEmpty
                ? fulfilledCategories
                : request.categoryFulfillments.keys.toList();

            if (resolvedCategories.isNotEmpty) {
              final updatedFulfillments = Map<String, RequestCategoryFulfillment>.from(
                request.categoryFulfillments,
              );
              for (final category in resolvedCategories) {
                final current = updatedFulfillments[category];
                if (current != null) {
                  updatedFulfillments[category] = current.copyWith(
                    status: RequestCategoryStatus.accepted,
                    acceptedProposalId: proposalId,
                    acceptedVendorId: updatedWinner.vendorId,
                    acceptedAt: DateTime.now(),
                  );
                }
              }
              // Only set request to customerAccepted once ALL categories are resolved
              final tentativeRequest = request.copyWith(
                categoryFulfillments: updatedFulfillments,
                updatedAt: DateTime.now(),
              );
              final allCategoriesAccepted = tentativeRequest.categoryFulfillments.values
                  .every((f) => !f.status.canReceiveProposals);
              final updatedRequest = tentativeRequest.copyWith(
                status: allCategoriesAccepted
                    ? RequestStatus.customerAccepted
                    : request.status,
              );
              await _requestRepo.updateRequest(updatedRequest);
              ref.read(requestProvider.notifier).syncRequest(updatedRequest);
            }
          }
        }
      }
      */

      await loadProposalsForRequest(requestId);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Rejects one vendor's offer for a specific requested item.
  Future<void> rejectProposalItem({
    required String proposalId,
    required String requestItemId,
    required String requestId,
  }) async {
    await _repo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.updateProposalItemDecision(
        proposalId: proposalId,
        requestItemId: requestItemId,
        decision: ProposalItemDecision.rejected,
      );
      print('[ItemReject] Rejected item $requestItemId in proposal $proposalId');
      await loadProposalsForRequest(requestId);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}


final proposalProvider =
    StateNotifierProvider<ProposalNotifier, ProposalState>((ref) {
  return ProposalNotifier(ref);
});

final proposalValidationServiceProvider =
    Provider((ref) => const ProposalValidationService());

