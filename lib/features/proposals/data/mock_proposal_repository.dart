import 'dart:math';
import '../models/proposal.dart';

class MockProposalRepository {
  static final MockProposalRepository instance = MockProposalRepository._();
  MockProposalRepository._() {
    // Start with empty list to ensure no mock locations appear in the system.
  }

  final List<Proposal> _proposals = [];

  Future<List<Proposal>> getProposalsForRequest(String requestId) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return _proposals.where((p) => p.requestId == requestId).toList();
  }

  Future<List<Proposal>> getProposalsForVendor(String vendorId) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return _proposals.where((p) => p.vendorId == vendorId).toList();
  }

  Future<Proposal?> getProposalById(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      return _proposals.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Proposal> createProposal(Proposal proposal) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final newProposal = proposal.copyWith(
      id: proposal.id.isEmpty ? 'PROP-${Random().nextInt(90000) + 10000}' : proposal.id,
      createdAt: DateTime.now(),
    );
    _proposals.insert(0, newProposal);
    return newProposal;
  }

  Future<void> updateProposalStatus(
    String proposalId,
    ProposalStatus status, {
    String? rejectionReason,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final index = _proposals.indexWhere((p) => p.id == proposalId);
    if (index != -1) {
      _proposals[index] = _proposals[index].copyWith(
        status: status,
        rejectionReason: rejectionReason,
      );
    }
  }

  Future<void> sendControlledMessage(
    String proposalId, {
    String? customerMsg,
    String? vendorMsg,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _proposals.indexWhere((p) => p.id == proposalId);
    if (index != -1) {
      _proposals[index] = _proposals[index].copyWith(
        customerResponse: customerMsg ?? _proposals[index].customerResponse,
        vendorResponse: vendorMsg ?? _proposals[index].vendorResponse,
      );
    }
  }
}
