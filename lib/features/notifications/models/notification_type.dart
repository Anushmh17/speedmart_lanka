enum NotificationType {
  newNearbyRequest,
  newProposal,
  proposalAccepted,
  proposalRejected,
  orderStatusUpdated,
  cashOnDeliveryConfirmed,
  receiptGenerated,
  paymentFailed,
  orderReadyForPickup,
  orderOutForDelivery,
  orderDelivered,
}

extension NotificationTypeExtension on NotificationType {
  String get displayName {
    switch (this) {
      case NotificationType.newNearbyRequest:
        return 'New Request Nearby';
      case NotificationType.newProposal:
        return 'New Proposal Received';
      case NotificationType.proposalAccepted:
        return 'Proposal Accepted';
      case NotificationType.proposalRejected:
        return 'Proposal Rejected';
      case NotificationType.orderStatusUpdated:
        return 'Order Status Updated';
      case NotificationType.cashOnDeliveryConfirmed:
        return 'COD Confirmed';
      case NotificationType.receiptGenerated:
        return 'Receipt Generated';
      case NotificationType.paymentFailed:
        return 'Payment Failed';
      case NotificationType.orderReadyForPickup:
        return 'Order Ready for Pickup';
      case NotificationType.orderOutForDelivery:
        return 'Order Out for Delivery';
      case NotificationType.orderDelivered:
        return 'Order Delivered';
    }
  }

  String get icon {
    switch (this) {
      case NotificationType.newNearbyRequest:
        return '📍';
      case NotificationType.newProposal:
        return '💬';
      case NotificationType.proposalAccepted:
        return '✅';
      case NotificationType.proposalRejected:
        return '❌';
      case NotificationType.orderStatusUpdated:
        return '📦';
      case NotificationType.cashOnDeliveryConfirmed:
        return '💵';
      case NotificationType.receiptGenerated:
        return '🧾';
      case NotificationType.paymentFailed:
        return '⚠️';
      case NotificationType.orderReadyForPickup:
        return '🚀';
      case NotificationType.orderOutForDelivery:
        return '🛵';
      case NotificationType.orderDelivered:
        return '🎉';
    }
  }
}

