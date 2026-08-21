import 'package:cloud_firestore/cloud_firestore.dart';

/// Transactional client-side order and payment transitions. Firestore rules
/// enforce ownership and the allowed field/status changes.
class OrderWorkflowService {
  OrderWorkflowService._();

  static final OrderWorkflowService instance = OrderWorkflowService._();

  Future<String> advanceOrder(String orderId) async {
    const transitions = {
      'submitted': 'accepted',
      'accepted': 'preparing',
      'preparing': 'readyForDelivery',
      'readyForDelivery': 'outForDelivery',
      'outForDelivery': 'delivered',
      'delivered': 'completed',
    };
    final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderRef);
      if (!snapshot.exists || snapshot.data() == null) {
        throw StateError('Order not found.');
      }
      final order = snapshot.data()!;
      final nextStatus = transitions[order['status'] as String? ?? ''];
      if (nextStatus == null) throw StateError('This order cannot advance further.');
      if (order['status'] == 'submitted' &&
          order['paymentMethod'] == 'bankTransfer' &&
          order['paymentStatus'] != 'paid') {
        throw StateError('Verify the bank transfer before accepting this order.');
      }
      if (order['status'] == 'outForDelivery' &&
          order['paymentMethod'] == 'cashOnDelivery' &&
          order['paymentStatus'] != 'paid') {
        throw StateError('Collect COD payment before completing delivery.');
      }
      transaction.update(orderRef, {
        'status': nextStatus,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return nextStatus;
    });
  }

  Future<void> completeCodDelivery(String orderId) async {
    final firestore = FirebaseFirestore.instance;
    final orderRef = firestore.collection('orders').doc(orderId);
    await firestore.runTransaction((transaction) async {
      final orderSnapshot = await transaction.get(orderRef);
      if (!orderSnapshot.exists || orderSnapshot.data() == null) {
        throw StateError('Order not found.');
      }
      final order = orderSnapshot.data()!;
      if (order['status'] != 'outForDelivery' ||
          order['paymentMethod'] != 'cashOnDelivery') {
        throw StateError('This COD order is not ready for cash collection.');
      }
      final paymentId = order['paymentId'] as String?;
      if (paymentId == null || paymentId.isEmpty) {
        throw StateError('This order has no linked payment.');
      }
      final paymentRef = firestore.collection('payments').doc(paymentId);
      final paymentSnapshot = await transaction.get(paymentRef);
      if (!paymentSnapshot.exists) throw StateError('Payment record not found.');
      final now = DateTime.now().toIso8601String();
      transaction.update(paymentRef, {'paymentStatus': 'paid', 'paidAt': now});
      transaction.update(orderRef, {
        'paymentStatus': 'paid',
        'status': 'delivered',
        'updatedAt': now,
      });
    });
  }

  Future<void> confirmBankTransferPayment(String paymentId) async {
    final firestore = FirebaseFirestore.instance;
    final paymentRef = firestore.collection('payments').doc(paymentId);
    await firestore.runTransaction((transaction) async {
      final paymentSnapshot = await transaction.get(paymentRef);
      if (!paymentSnapshot.exists || paymentSnapshot.data() == null) {
        throw StateError('Payment record not found.');
      }
      final payment = paymentSnapshot.data()!;
      if (payment['paymentMethod'] != 'bankTransfer' ||
          payment['paymentStatus'] != 'pendingBankTransfer') {
        throw StateError('This payment cannot be confirmed.');
      }
      final orderId = payment['orderId'] as String?;
      if (orderId == null || orderId.isEmpty) throw StateError('Payment has no linked order.');
      final now = DateTime.now().toIso8601String();
      transaction.update(paymentRef, {'paymentStatus': 'paid', 'paidAt': now});
      transaction.update(firestore.collection('orders').doc(orderId), {
        'paymentStatus': 'paid',
        'updatedAt': now,
      });
    });
  }
}
