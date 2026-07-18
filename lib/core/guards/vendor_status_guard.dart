import '../../shared/models/user_model.dart';
import '../../shared/models/user_role.dart';
import '../../shared/models/vendor_status.dart';

/// Guards vendor marketplace access based on approval and shop assignment status.
class VendorStatusGuard {
  /// Check if vendor can access marketplace features.
  static bool canAccessMarketplace(UserModel? user) {
    if (user == null) return false;
    if (user.role != UserRole.vendor) return true; // Allow non-vendors

    return user.isVendorActive;
  }

  /// Check if vendor can view requests.
  static bool canViewRequests(UserModel? user) => canAccessMarketplace(user);

  /// Check if vendor can submit proposals.
  static bool canSubmitProposal(UserModel? user) => canAccessMarketplace(user);

  /// Check if vendor can edit proposals.
  static bool canEditProposal(UserModel? user) => canAccessMarketplace(user);

  /// Check if vendor can access vendor orders.
  static bool canAccessOrders(UserModel? user) => canAccessMarketplace(user);

  /// Get detailed reason why marketplace is blocked.
  static String getBlockedReason(UserModel? user) {
    if (user == null) return 'User not authenticated.';
    if (user.role != UserRole.vendor) return ''; // Not a vendor

    final status = user.vendorStatus ?? VendorStatus.pendingApproval;

    if (status == VendorStatus.pendingApproval) {
      return 'Your vendor account is pending admin approval. Please check back later.';
    }

    if (status == VendorStatus.rejected) {
      return 'Your vendor registration was rejected and cannot access the marketplace.';
    }

    if (status == VendorStatus.suspended) {
      return 'Your vendor account has been suspended. Please contact support for assistance.';
    }

    if (status == VendorStatus.approved) {
      if (user.isShopLocationAssigned != true) {
        return 'Your shop location has not been assigned by the administrator yet.';
      }
      if (user.shopLatitude == null || user.shopLongitude == null) {
        return 'Your shop coordinates are not properly configured.';
      }
      if (user.vendorCategories?.isEmpty ?? true) {
        return 'You have not been assigned any product categories.';
      }
    }

    return '';
  }

  /// Check if vendor is blocked and get status screen title.
  static String getStatusScreenTitle(UserModel? user) {
    if (user == null || user.role != UserRole.vendor) return '';

    final status = user.vendorStatus ?? VendorStatus.pendingApproval;

    if (status == VendorStatus.pendingApproval) {
      return 'Pending Approval';
    }
    if (status == VendorStatus.rejected) {
      return 'Registration Rejected';
    }
    if (status == VendorStatus.suspended) {
      return 'Account Suspended';
    }
    if (status == VendorStatus.approved &&
        user.isShopLocationAssigned != true) {
      return 'Shop Not Assigned';
    }

    return '';
  }

  /// Check if vendor needs to see a status screen instead of dashboard.
  static bool shouldShowStatusScreen(UserModel? user) {
    return !canAccessMarketplace(user) && user?.role == UserRole.vendor;
  }
}

