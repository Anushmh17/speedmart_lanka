enum VendorStatus {
  pendingApproval,
  approved,
  rejected,
  suspended,
}

extension VendorStatusExtension on VendorStatus {
  String get displayName {
    switch (this) {
      case VendorStatus.pendingApproval:
        return 'Pending Approval';
      case VendorStatus.approved:
        return 'Approved';
      case VendorStatus.rejected:
        return 'Rejected';
      case VendorStatus.suspended:
        return 'Suspended';
    }
  }

  bool get isPending => this == VendorStatus.pendingApproval;
  bool get isApproved => this == VendorStatus.approved;
  bool get isRejected => this == VendorStatus.rejected;
  bool get isSuspended => this == VendorStatus.suspended;
  bool get isActive => this == VendorStatus.approved;
  bool get isInactive => this != VendorStatus.approved;
}

