import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../orders/models/order_model.dart';
import '../../proposals/models/proposal.dart';
import '../../requests/models/request_item_fulfillment.dart';
import '../../requests/models/shopping_request.dart';
import '../../../shared/utils/category_constants.dart';
import '../models/payment.dart';

class CheckoutSelection {
  const CheckoutSelection({
    required this.proposalId,
    required this.requestItemIds,
  });

  final String proposalId;
  final List<String> requestItemIds;

  Map<String, dynamic> toJson() => {
        'proposalId': proposalId,
        'requestItemIds': requestItemIds,
      };
}

class CheckoutResult {
  const CheckoutResult({required this.orders, required this.payments});

  final List<OrderModel> orders;
  final List<PaymentModel> payments;
}

/// Client-side Firestore transaction for checkout. Rules validate document
/// ownership and immutable links while the transaction prevents partial writes.
class CheckoutService {
  CheckoutService._();

  static final CheckoutService instance = CheckoutService._();

  Future<CheckoutResult> checkout({
    required String requestId,
    required PaymentMethod paymentMethod,
    required String customerPhone,
    required List<CheckoutSelection> selections,
  }) async {
    final customerId = FirebaseAuth.instance.currentUser?.uid;
    if (customerId == null) throw StateError('Sign in before checking out.');

    final firestore = FirebaseFirestore.instance;

    final result = await firestore.runTransaction<CheckoutResult>((transaction) async {
      final requestRef = firestore.collection('requests').doc(requestId);
      final checkoutRef = firestore.collection('request_checkouts').doc(requestId);
      final requestSnapshot = await transaction.get(requestRef);
      final checkoutSnapshot = await transaction.get(checkoutRef);
      if (!requestSnapshot.exists || requestSnapshot.data() == null) {
        throw StateError('Shopping request not found.');
      }
      if (checkoutSnapshot.exists) {
        throw StateError('This shopping request has already been checked out.');
      }
      final request = ShoppingRequest.fromJson({
        ...requestSnapshot.data()!,
        'id': requestSnapshot.id,
      });
      if (request.customerId != customerId) {
        throw StateError('This shopping request belongs to another customer.');
      }
      if (request.status == RequestStatus.cancelled ||
          request.status == RequestStatus.completed) {
        throw StateError('This shopping request can no longer be checked out.');
      }
      if (request.itemFulfillments.values
          .any((fulfillment) => fulfillment.orderId?.isNotEmpty == true)) {
        throw StateError('An order has already been created for this request.');
      }

      final requestedItemIds = request.items.map((item) => item.id).toSet();
      final selectedItemIds = <String>{};
      final proposalSnapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final selection in selections) {
        if (proposalSnapshots.containsKey(selection.proposalId)) {
          throw StateError('Each vendor proposal can be selected only once.');
        }
        proposalSnapshots[selection.proposalId] = await transaction.get(
          firestore.collection('customer_proposals').doc(selection.proposalId),
        );
        for (final itemId in selection.requestItemIds) {
          if (!requestedItemIds.contains(itemId) || !selectedItemIds.add(itemId)) {
            throw StateError('Each requested item must have one selected offer.');
          }
        }
      }
      if (selectedItemIds.length != requestedItemIds.length) {
        throw StateError('Select an offer for every requested item.');
      }

      final itemFulfillments =
          Map<String, RequestItemFulfillment>.from(request.itemFulfillments);
      final categoryFulfillments =
          Map<String, dynamic>.from(request.categoryFulfillments.map(
        (key, value) => MapEntry(key, value.toJson()),
      ));
      final now = DateTime.now();
      final orders = <OrderModel>[];
      final payments = <PaymentModel>[];

      for (final selection in selections) {
        final proposalSnapshot = proposalSnapshots[selection.proposalId]!;
        if (!proposalSnapshot.exists || proposalSnapshot.data() == null) {
          throw StateError('A selected proposal no longer exists.');
        }
        final proposal = Proposal.fromJson({
          ...proposalSnapshot.data()!,
          'id': proposalSnapshot.id,
        });
        final proposalIsAvailable = proposal.status.isEditableByVendor ||
            proposal.status == ProposalStatus.accepted;
        if (proposal.requestId != requestId ||
            proposal.customerId != customerId ||
            !proposalIsAvailable) {
          throw StateError('A selected proposal is no longer available.');
        }
        final selectedItems = selection.requestItemIds.map((itemId) {
          return proposal.items.firstWhere(
            (item) => item.requestItemId == itemId &&
                item.status != ProposalItemStatus.unavailable &&
                item.price > 0,
            orElse: () => throw StateError('A selected item is unavailable.'),
          );
        }).toList();
        final subtotal = selectedItems.fold<double>(
          0,
          (total, item) => total + item.subtotal,
        );
        final commission = proposal.subtotal > 0
            ? proposal.platformCommission * subtotal / proposal.subtotal
            : 0.0;
        final orderRef = firestore.collection('orders').doc();
        final paymentRef = firestore.collection('payments').doc();
        final paymentStatus = paymentMethod == PaymentMethod.cashOnDelivery
            ? PaymentStatus.pendingOnDelivery
            : PaymentStatus.pendingBankTransfer;
        final order = OrderModel(
          id: orderRef.id,
          proposalId: proposal.id,
          requestId: request.id,
          customerId: customerId,
          vendorId: proposal.vendorId,
          vendorBusinessName: proposal.vendorBusinessName,
          vendorPhone: '',
          customerName: request.customerName,
          customerPhone: customerPhone.isEmpty ? request.customerPhone : customerPhone,
          deliveryAddress: request.deliveryAddress,
          customerProvince: request.deliveryLocation?.province ?? '',
          customerDistrict: request.deliveryLocation?.district ?? '',
          customerCity: request.deliveryLocation?.city ?? '',
          customerSuburb: request.deliveryLocation?.suburb ?? request.customerArea,
          customerFormattedAddress:
              request.deliveryLocation?.formattedAddress ?? request.customerArea,
          items: selectedItems,
          deliveryCharge: proposal.deliveryCharge,
          totalPrice: subtotal + proposal.deliveryCharge + commission,
          paymentId: paymentRef.id,
          paymentMethod: paymentMethod,
          paymentStatus: paymentStatus,
          isAddressReleased: true,
          addressReleasedAt: now,
          status: OrderStatus.submitted,
          createdAt: now,
          // Vendor pickup location is private and is never stored in a
          // customer-readable order document.
          vendorLatitude: 0,
          vendorLongitude: 0,
          customerLatitude: request.latitude,
          customerLongitude: request.longitude,
          accuracy: request.deliveryLocation?.accuracy,
          detectedAt: request.deliveryLocation?.detectedAt,
          commissionRate: proposal.commissionRate ?? 0,
        );
        final payment = PaymentModel(
          id: paymentRef.id,
          orderId: order.id,
          customerId: customerId,
          vendorId: proposal.vendorId,
          vendorBusinessName: proposal.vendorBusinessName,
          proposalId: proposal.id,
          amount: order.totalPrice,
          subtotal: subtotal,
          deliveryFee: order.deliveryCharge,
          serviceFee: commission,
          platformCommission: commission,
          vendorNetAmount: order.totalPrice - commission,
          paymentMethod: paymentMethod,
          paymentStatus: paymentStatus,
          createdAt: now,
          transactionReference: '${paymentMethod.name}-${order.id}',
          receiptNumber: 'RCPT-${order.id.substring(order.id.length - 8)}',
        );
        transaction.set(orderRef, order.toJson());
        transaction.set(paymentRef, payment.toJson());
        if (proposal.status != ProposalStatus.accepted) {
          transaction.update(proposalSnapshot.reference, {
            'status': ProposalStatus.accepted.name,
            'updatedAt': now.toIso8601String(),
          });
          // The private proposal is updated without being read by the
          // customer. Rules require this matching safe projection update.
          transaction.update(firestore.collection('proposals').doc(proposal.id), {
            'status': ProposalStatus.accepted.name,
            'updatedAt': now.toIso8601String(),
          });
        }
        orders.add(order);
        payments.add(payment);

        for (final item in selectedItems) {
          itemFulfillments[item.requestItemId] = RequestItemFulfillment(
            requestItemId: item.requestItemId,
            status: RequestItemFulfillmentStatus.accepted,
            proposalId: proposal.id,
            vendorId: proposal.vendorId,
            orderId: order.id,
            paymentId: payment.id,
            acceptedAt: now,
            updatedAt: now,
          );
          final requestItem = request.items.firstWhere(
            (candidate) => candidate.id == item.requestItemId,
          );
          final category = VendorCategories.normalize(requestItem.category ?? '');
          if (category.isNotEmpty && categoryFulfillments.containsKey(category)) {
            categoryFulfillments[category] = {
              ...Map<String, dynamic>.from(categoryFulfillments[category] as Map),
              'status': paymentMethod == PaymentMethod.cashOnDelivery
                  ? 'codConfirmed'
                  : 'accepted',
              'acceptedAt': now.toIso8601String(),
            };
          }
        }
      }

      transaction.update(requestRef, {
        'itemFulfillments': itemFulfillments.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'categoryFulfillments': categoryFulfillments,
        'status': paymentMethod == PaymentMethod.cashOnDelivery
            ? RequestStatus.cashOnDeliveryConfirmed.name
            : RequestStatus.customerAccepted.name,
        'updatedAt': now.toIso8601String(),
      });
      transaction.set(checkoutRef, {
        'id': requestId,
        'requestId': requestId,
        'customerId': customerId,
        'createdAt': now.toIso8601String(),
      });
      return CheckoutResult(orders: orders, payments: payments);
    });
    if (result.orders.isEmpty || result.payments.isEmpty) {
      throw StateError('Checkout did not create an order and payment.');
    }
    return result;
  }

  Future<void> submitBankTransferReceipt({
    required String paymentId,
    String? receiptImageUrl,
  }) async {
    await FirebaseFirestore.instance.collection('payments').doc(paymentId).update({
      'receiptImageUrl': receiptImageUrl,
      'receiptSubmittedAt': DateTime.now().toIso8601String(),
    });
  }
}
