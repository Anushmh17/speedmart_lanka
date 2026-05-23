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
    return _proposals.where((p) => p.requestId == requestId).toList();
  }

  Future<List<Proposal>> getProposalsForVendor(String vendorId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 300));
    return _proposals.where((p) => p.vendorId == vendorId).toList();
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

  Future<void> cancelProposalsForRequest(String requestId) async {
    await ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 150));
    var changed = false;
    for (var i = 0; i < _proposals.length; i++) {
      if (_proposals[i].requestId == requestId &&
          _proposals[i].status != ProposalStatus.accepted) {
        _proposals[i] = _proposals[i].copyWith(
          status: ProposalStatus.cancelled,
          rejectionReason: 'Request cancelled by customer',
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
      );
      await _persistProposals();
    }
  }
}
