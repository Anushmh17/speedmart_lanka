import 'package:cloud_firestore/cloud_firestore.dart';

/// The only customer-readable representation of a vendor's bank account.
/// It is scoped to one proposal and is used exclusively by the bank-transfer
/// payment flow; customers never read the vendor profile for these details.
class BankTransferInstruction {
  const BankTransferInstruction({
    required this.proposalId,
    required this.customerId,
    required this.vendorId,
    required this.isAvailable,
    this.bankName,
    this.bankBranch,
    this.accountName,
    this.accountNumber,
  });

  final String proposalId;
  final String customerId;
  final String vendorId;
  final bool isAvailable;
  final String? bankName;
  final String? bankBranch;
  final String? accountName;
  final String? accountNumber;

  bool get hasRequiredDetails =>
      isAvailable &&
      (accountName?.trim().isNotEmpty ?? false) &&
      (accountNumber?.trim().isNotEmpty ?? false);

  factory BankTransferInstruction.fromJson(Map<String, dynamic> json) {
    return BankTransferInstruction(
      proposalId: json['proposalId'] as String? ?? '',
      customerId: json['customerId'] as String? ?? '',
      vendorId: json['vendorId'] as String? ?? '',
      isAvailable: json['isAvailable'] as bool? ?? false,
      bankName: json['bankName'] as String?,
      bankBranch: json['bankBranch'] as String?,
      accountName: json['accountName'] as String?,
      accountNumber: json['accountNumber'] as String?,
    );
  }
}

class BankTransferInstructionService {
  BankTransferInstructionService._();

  static final instance = BankTransferInstructionService._();

  Future<BankTransferInstruction?> getForProposal(String proposalId) async {
    final document = await FirebaseFirestore.instance
        .collection('bank_transfer_instructions')
        .doc(proposalId)
        .get(const GetOptions(source: Source.server));
    final data = document.data();
    if (!document.exists || data == null) return null;
    return BankTransferInstruction.fromJson({...data, 'proposalId': document.id});
  }
}
