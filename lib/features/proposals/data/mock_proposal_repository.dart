import 'dart:math';
import '../models/proposal.dart';

class MockProposalRepository {
  static final MockProposalRepository instance = MockProposalRepository._();
  MockProposalRepository._() {
    // Pre-populate a mock proposal for request REQ-87421 (milk request) so customers see it immediately
    _proposals.add(
      Proposal(
        id: 'PROP-12093',
        requestId: 'REQ-87421',
        vendorId: 'vendor-123',
        vendorBusinessName: 'Super Liyana Grocery', // This will be masked on the UI
        deliveryCharge: 250.0,
        estimatedDeliveryTime: 'Within 2 hours',
        totalPrice: 1650.0, // (400 * 2) + 600 + 250
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        status: ProposalStatus.submitted,
        vendorLatitude: 6.9145,
        vendorLongitude: 79.8510,
        items: [
          ProposalItem(
            requestItemId: 'item-101',
            requestItemName: 'Keells Fresh Milk 1L',
            quantity: 2,
            status: ProposalItemStatus.available,
            price: 400.0,
            description: 'Anchor Fresh Milk available (same brand category). Expiry date: 28/05/2026',
          ),
          ProposalItem(
            requestItemId: 'item-102',
            requestItemName: 'Fortune Coconut Oil 1L',
            quantity: 1,
            status: ProposalItemStatus.available,
            price: 600.0,
          ),
          ProposalItem(
            requestItemId: 'item-103',
            requestItemName: 'Harischandra Coffee 200g',
            quantity: 1,
            status: ProposalItemStatus.unavailable,
            description: 'Currently out of stock.',
          ),
        ],
        missingItemIds: ['item-103'],
      ),
    );
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
