import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/firestore_service.dart';
import '../../../core/storage/storage_service.dart';
import '../../auth/data/auth_repository.dart';
import '../models/proposal.dart';

/// Proposal repository — Firestore-backed.
class ProposalRepository {
  ProposalRepository._() {
    _initFuture = _initialize();
  }

  static final ProposalRepository instance = ProposalRepository._();

  static const String _proposalsCollectionPath = 'proposals';
  static const String _customerProposalsCollectionPath = 'customer_proposals';
  static const String _bankTransferInstructionsCollectionPath =
      'bank_transfer_instructions';

  late final Future<void> _initFuture;
  bool _isInitialized = false;

  final List<Proposal> _proposals = [];
  final List<String> _savedProposalIds = [];

  Future<void> ensureInitialized() => _initFuture;

  CollectionReference<Map<String, dynamic>> get _proposalsCollection =>
      FirestoreService.collection(_proposalsCollectionPath);

  CollectionReference<Map<String, dynamic>> get _customerProposalsCollection =>
      FirestoreService.collection(_customerProposalsCollectionPath);

  CollectionReference<Map<String, dynamic>> get _bankTransferInstructionsCollection =>
      FirestoreService.collection(_bankTransferInstructionsCollectionPath);

  Future<bool> _isCustomerSession() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      final profile = await FirestoreService.collection('users/customers/profiles')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      return profile.exists;
    } catch (_) {
      // Vendor/admin users cannot read customer profiles under the rules.
      return false;
    }
  }

  Future<CollectionReference<Map<String, dynamic>>> _readCollection() async =>
      (await _isCustomerSession())
          ? _customerProposalsCollection
          : _proposalsCollection;

  /// Customer list reads must be constrained by ownership. Firestore Rules
  /// cannot approve an unfiltered collection query, even if each individual
  /// returned document would be owned by the current customer.
  Future<Query<Map<String, dynamic>>> _readProposalQuery() async {
    final customerSession = await _isCustomerSession();
    if (customerSession) {
      final customerId = FirebaseAuth.instance.currentUser?.uid;
      if (customerId == null) throw StateError('Sign in before loading proposals.');
      return _customerProposalsCollection
          .where('customerId', isEqualTo: customerId)
          .limit(500);
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in before loading proposals.');
    return _proposalsCollection
        .where('vendorId', isEqualTo: uid)
        .limit(500);
  }

  Map<String, dynamic> _customerVisibleJson(Proposal proposal) => {
        'id': proposal.id,
        'requestId': proposal.requestId,
        'customerId': proposal.customerId,
        // Opaque internal identifier required for choosing and fulfilling an
        // offer; no business name, phone, location, or private note is copied.
        'vendorId': proposal.vendorId,
        // Product information is needed to choose an offer. Vendor-uploaded
        // image lists and the mutable customerDecision field are deliberately
        // excluded; decisions are stored separately below.
        'items': proposal.items.map((item) {
          final itemJson = item.toJson()
            ..remove('vendorImageUrls')
            ..remove('customerDecision');
          return itemJson;
        }).toList(),
        'missingItemIds': proposal.missingItemIds,
        'deliveryCharge': proposal.deliveryCharge,
        'estimatedDeliveryTime': proposal.estimatedDeliveryTime,
        'totalPrice': proposal.totalPrice,
        'status': proposal.status.name,
        'createdAt': proposal.createdAt.toIso8601String(),
        'updatedAt': proposal.updatedAt?.toIso8601String(),
        'rejectedAt': proposal.rejectedAt?.toIso8601String(),
        'rejectionReason': proposal.rejectionReason,
        'categoriesNormalized': proposal.categoriesNormalized,
        'customerItemDecisions': proposal.customerItemDecisions.map(
          (id, decision) => MapEntry(id, decision.name),
        ),
        'commissionRate': proposal.commissionRate,
      };

  Future<Map<String, dynamic>> _bankTransferInstructionJson(
    Proposal proposal,
  ) async {
    final profile = await FirestoreService.collection('users/vendors/profiles')
        .doc(proposal.vendorId)
        .get(const GetOptions(source: Source.server));
    final data = profile.data() ?? const <String, dynamic>{};
    final accountName = data['bank_account_name'] as String?;
    final accountNumber = data['bank_account_number'] as String?;
    final enabled = data['accepts_bank_transfer'] as bool? ?? true;

    return {
      'proposalId': proposal.id,
      'customerId': proposal.customerId,
      'vendorId': proposal.vendorId,
      'isAvailable': enabled &&
          (accountName?.trim().isNotEmpty ?? false) &&
          (accountNumber?.trim().isNotEmpty ?? false),
      'bankName': data['bank_name'] as String?,
      'bankBranch': data['bank_branch'] as String?,
      'accountName': accountName,
      'accountNumber': accountNumber,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<List<Map<String, dynamic>>> _fetchProposalsFromFirestore() async {
    if (FirebaseAuth.instance.currentUser == null) return [];
    try {
      final query = await _readProposalQuery();
      final snapshot =
          await query.get(const GetOptions(source: Source.server));
      return snapshot.docs.map((doc) => {
            ...doc.data(),
            'id': doc.id,
          }).toList();
    } catch (e) {
      debugPrint('[Proposal] Failed to load proposals from Firestore: $e');
      return [];
    }
  }

  Future<void> _syncProposalToFirestore(Proposal proposal) async {
    await FirestoreService.runAuthenticated(() async {
      if (await _isCustomerSession()) {
        await _customerProposalsCollection
            .doc(proposal.id)
            .set(_customerVisibleJson(proposal));
        return;
      }
      final batch = FirebaseFirestore.instance.batch();
      batch.set(_proposalsCollection.doc(proposal.id), proposal.toJson());

      // Fix 5: Only project customer-visible and bank-transfer docs when the
      // proposal has been submitted. Drafts must not be visible to customers.
      final shouldProject = proposal.status != ProposalStatus.draft;
      if (shouldProject) {
        batch.set(
          _customerProposalsCollection.doc(proposal.id),
          _customerVisibleJson(proposal),
        );
        batch.set(
          _bankTransferInstructionsCollection.doc(proposal.id),
          await _bankTransferInstructionJson(proposal),
        );
      }
      await batch.commit();
    });
  }

  Future<void> _syncProposalsToFirestore(Iterable<Proposal> proposals) async {
    for (final proposal in proposals) {
      await _syncProposalToFirestore(proposal);
    }
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;

    final firestoreProposals = await _fetchProposalsFromFirestore();
    if (firestoreProposals.isNotEmpty) {
      final proposals = firestoreProposals.map(Proposal.fromJson).toList();
      _proposals
        ..clear()
        ..addAll(await _patchVendorCoords(proposals));
    } else {
      // Firestore unavailable — fall back to local storage once
      final saved = await StorageService.getVendorProposals();
      if (saved.isNotEmpty) {
        _proposals.addAll(await _patchVendorCoords(saved.map(Proposal.fromJson).toList()));
      }
    }

    final savedIds = await StorageService.getSavedProposals();
    if (savedIds != null) {
      _savedProposalIds
        ..clear()
        ..addAll(savedIds);
    }

    _isInitialized = true;
  }

  /// Refreshes proposals created or updated by another signed-in user.
  Future<void> refreshFromFirestore() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      final query = await _readProposalQuery();
      final snapshot =
          await query.get(const GetOptions(source: Source.server));
      final refreshed = snapshot.docs
          .map((doc) => Proposal.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
      _proposals
        ..clear()
        ..addAll(await _patchVendorCoords(refreshed));
    } catch (e) {
      debugPrint('[Proposal] Failed to refresh proposals from Firestore: $e');
    }
  }

  /// Patches vendorLatitude/vendorLongitude on loaded proposals using the
  /// vendor's current shopLatitude/shopLongitude from the auth repository.
  Future<List<Proposal>> _patchVendorCoords(List<Proposal> proposals) async {
    if (await _isCustomerSession()) return proposals;
    final vendorIds = proposals.map((p) => p.vendorId).toSet();
    final coordMap = <String, ({double lat, double lon})>{};
    for (final id in vendorIds) {
      final user = await AuthRepository.instance.getUserById(id);
      if (user != null &&
          user.shopLatitude != null &&
          user.shopLongitude != null &&
          user.shopLatitude != 0 &&
          user.shopLongitude != 0) {
        coordMap[id] = (lat: user.shopLatitude!, lon: user.shopLongitude!);
      }
    }
    return proposals.map((p) {
      final coords = coordMap[p.vendorId];
      if (coords == null) return p;
      return p.copyWith(vendorLatitude: coords.lat, vendorLongitude: coords.lon);
    }).toList();
  }

  Future<void> _persistProposals([Iterable<Proposal>? proposals]) async {
    // Avoid replaying the whole in-memory cache, which may contain a proposal
    // the customer accepted after the vendor last refreshed.
    await _syncProposalsToFirestore(proposals ?? _proposals);
  }

  Future<Proposal?> _getProposalFromServer(String proposalId) async {
    if (FirebaseAuth.instance.currentUser == null) return null;

    final collection = await _readCollection();
    final doc = await collection.doc(proposalId).get(
          const GetOptions(source: Source.server),
        );
    if (!doc.exists || doc.data() == null) return null;
    return Proposal.fromJson({...doc.data()!, 'id': doc.id});
  }

  Future<List<Proposal>> getProposalsForRequest(String requestId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 300));
    return _proposals
        .where((p) =>
            p.requestId == requestId && p.status.isVisibleToCustomer)
        .toList();
  }

  Future<List<Proposal>> getAllProposalsForRequest(String requestId) async {
    await ensureInitialized();
    return _proposals.where((p) => p.requestId == requestId).toList();
  }

  Future<List<Proposal>> getProposalsForVendor(String vendorId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 300));
    return _proposals.where((p) => p.vendorId == vendorId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<Proposal>> getAllProposals() async {
    await ensureInitialized();
    return List<Proposal>.unmodifiable(_proposals);
  }

  Future<Proposal?> getProposalById(String id) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      return _proposals.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Proposal?> getVendorProposalForRequest({
    required String vendorId,
    required String requestId,
    String? categoryNormalized,
  }) async {
    await ensureInitialized();
    try {
      if (categoryNormalized != null) {
        return _proposals.firstWhere(
          (p) =>
              p.vendorId == vendorId &&
              p.requestId == requestId &&
              p.categoriesNormalized.contains(categoryNormalized),
        );
      }
      return _proposals.firstWhere(
        (p) => p.vendorId == vendorId && p.requestId == requestId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<Proposal>> getVendorProposalsForRequest({
    required String vendorId,
    required String requestId,
  }) async {
    await ensureInitialized();
    return _proposals
        .where((p) => p.vendorId == vendorId && p.requestId == requestId)
        .toList();
  }

  Future<Proposal> createProposal(Proposal proposal) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 400));
    final newProposal = proposal.copyWith(
      id: proposal.id.isEmpty
          ? 'PROP-${Random().nextInt(90000) + 10000}'
          : proposal.id,
      createdAt: DateTime.now(),
    );
    _proposals.insert(0, newProposal);
    await _persistProposals([newProposal]);
    return newProposal;
  }

  Future<Proposal> saveProposal(Proposal proposal) async {
    await ensureInitialized();
    final index = _proposals.indexWhere((p) => p.id == proposal.id);
    if (index >= 0) {
      _proposals[index] = proposal.copyWith(updatedAt: DateTime.now());
      await _persistProposals([_proposals[index]]);
      return _proposals[index];
    }
    return createProposal(proposal);
  }

  Future<Proposal> updateProposal(Proposal proposal) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _proposals.indexWhere((p) => p.id == proposal.id);
    if (index == -1) {
      throw Exception('Proposal not found');
    }
    final existing =
        await _getProposalFromServer(proposal.id) ?? _proposals[index];
    if (!existing.canEdit) {
      throw Exception(
        'Proposal cannot be edited in status ${existing.status.name}',
      );
    }

    final nextStatus = proposal.status == ProposalStatus.submitted &&
            existing.status != ProposalStatus.draft
        ? ProposalStatus.updated
        : proposal.status;

    _proposals[index] = proposal.copyWith(
      status: nextStatus,
      updatedAt: DateTime.now(),
    );
    await _persistProposals([_proposals[index]]);
    return _proposals[index];
  }

  Future<void> withdrawProposal(String proposalId) async {
    await ensureInitialized();
    final index = _proposals.indexWhere((p) => p.id == proposalId);
    if (index == -1) return;
    final existing =
        await _getProposalFromServer(proposalId) ?? _proposals[index];
    if (!existing.canWithdraw) {
      throw Exception('Proposal cannot be withdrawn');
    }
    _proposals[index] = existing.copyWith(
      status: ProposalStatus.withdrawn,
      updatedAt: DateTime.now(),
    );
    await _persistProposals([_proposals[index]]);
  }

  Future<void> cancelProposalsForRequest(String requestId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 150));
    var changed = false;
    for (var i = 0; i < _proposals.length; i++) {
      if (_proposals[i].requestId == requestId &&
          _proposals[i].status != ProposalStatus.accepted) {
        _proposals[i] = _proposals[i].copyWith(
          status: ProposalStatus.withdrawn,
          rejectionReason: 'Request cancelled by customer',
          updatedAt: DateTime.now(),
        );
        changed = true;
      }
    }
    if (changed) {
      await _persistProposals(
        _proposals.where((proposal) =>
            proposal.requestId == requestId &&
            proposal.status == ProposalStatus.withdrawn),
      );
    }
  }

  Future<void> updateProposalStatus(
    String proposalId,
    ProposalStatus status, {
    String? rejectionReason,
  }) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _proposals.indexWhere((p) => p.id == proposalId);
    if (index != -1) {
      _proposals[index] = _proposals[index].copyWith(
        status: status,
        rejectionReason: rejectionReason,
        rejectedAt: status == ProposalStatus.rejected ? DateTime.now() : null,
        updatedAt: DateTime.now(),
      );
      await _persistProposals([_proposals[index]]);
    }
  }

  Future<void> sendControlledMessage(
    String proposalId, {
    String? customerMsg,
    String? vendorMsg,
  }) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 150));
    final index = _proposals.indexWhere((p) => p.id == proposalId);
    if (index != -1) {
      _proposals[index] = _proposals[index].copyWith(
        customerResponse: customerMsg ?? _proposals[index].customerResponse,
        vendorResponse: vendorMsg ?? _proposals[index].vendorResponse,
        updatedAt: DateTime.now(),
      );
      await _persistProposals([_proposals[index]]);
    }
  }

  Future<void> saveProposalToWishlist(String proposalId) async {
    await ensureInitialized();
    if (!_savedProposalIds.contains(proposalId)) {
      _savedProposalIds.add(proposalId);
      await StorageService.saveSavedProposals(_savedProposalIds);
    }
  }

  Future<void> removeSavedProposal(String proposalId) async {
    await ensureInitialized();
    if (_savedProposalIds.contains(proposalId)) {
      _savedProposalIds.remove(proposalId);
      await StorageService.saveSavedProposals(_savedProposalIds);
    }
  }

  Future<List<String>> getSavedProposalIds() async {
    await ensureInitialized();
    return List<String>.unmodifiable(_savedProposalIds);
  }

  bool isSavedProposal(String proposalId) {
    return _savedProposalIds.contains(proposalId);
  }

  /// Updates the [ProposalItemDecision] for a specific item within a proposal.
  /// Used by item-level accept/reject flow.
  Future<void> updateProposalItemDecision({
    required String proposalId,
    required String requestItemId,
    required ProposalItemDecision decision,
  }) async {
    await ensureInitialized();
    final proposalIndex = _proposals.indexWhere((p) => p.id == proposalId);
    if (proposalIndex == -1) return;

    final proposal = _proposals[proposalIndex];
    final updatedItems = proposal.items.map((item) {
      if (item.requestItemId == requestItemId) {
        return item.copyWith(customerDecision: decision);
      }
      return item;
    }).toList();
    final updatedDecisions = {
      ...proposal.customerItemDecisions,
      requestItemId: decision,
    };

    _proposals[proposalIndex] = proposal.copyWith(
      items: updatedItems,
      customerItemDecisions: updatedDecisions,
      updatedAt: DateTime.now(),
    );
    await _persistProposals([_proposals[proposalIndex]]);
  }
}
