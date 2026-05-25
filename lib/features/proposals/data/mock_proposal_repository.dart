import 'dart:math';

import '../../../core/storage/storage_service.dart';
import '../models/proposal.dart';

/// Mock vendor proposal repository with local persistence.
/// TODO: Replace local mock proposal persistence with backend API.
class MockProposalRepository {
  MockProposalRepository._() {
    _initFuture = _initialize();
  }

  static final MockProposalRepository instance = MockProposalRepository._();

  late final Future<void> _initFuture;
  bool _isInitialized = false;

  final List<Proposal> _proposals = [];

  Future<void> ensureInitialized() => _initFuture;

  Future<void> _initialize() async {
    if (_isInitialized) return;

    final saved = await StorageService.getVendorProposals();
    if (saved.isNotEmpty) {
      _proposals
        ..clear()
        ..addAll(saved.map(Proposal.fromJson));
    }

    _isInitialized = true;
  }

  Future<void> _persistProposals() async {
    await StorageService.saveVendorProposals(
      _proposals.map((p) => p.toJson()).toList(),
    );
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
  }) async {
    await ensureInitialized();
    try {
      return _proposals.firstWhere(
        (p) => p.vendorId == vendorId && p.requestId == requestId,
      );
    } catch (_) {
      return null;
    }
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
    await _persistProposals();
    return newProposal;
  }

  Future<Proposal> saveProposal(Proposal proposal) async {
    await ensureInitialized();
    final index = _proposals.indexWhere((p) => p.id == proposal.id);
    if (index >= 0) {
      _proposals[index] = proposal.copyWith(updatedAt: DateTime.now());
      await _persistProposals();
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
    final existing = _proposals[index];
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
    await _persistProposals();
    return _proposals[index];
  }

  Future<void> withdrawProposal(String proposalId) async {
    await ensureInitialized();
    final index = _proposals.indexWhere((p) => p.id == proposalId);
    if (index == -1) return;
    if (!_proposals[index].canWithdraw) {
      throw Exception('Proposal cannot be withdrawn');
    }
    _proposals[index] = _proposals[index].copyWith(
      status: ProposalStatus.withdrawn,
      updatedAt: DateTime.now(),
    );
    await _persistProposals();
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
    if (changed) await _persistProposals();
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
        updatedAt: DateTime.now(),
      );
      await _persistProposals();
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
      await _persistProposals();
    }
  }
}
