import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speedmart_lanka/features/auth/providers/auth_provider.dart';
import 'package:speedmart_lanka/features/requests/data/mock_request_repository.dart';
import 'package:speedmart_lanka/features/requests/models/shopping_request.dart';
import 'package:speedmart_lanka/features/orders/data/mock_order_repository.dart';
import 'package:speedmart_lanka/features/orders/models/order_model.dart';
import 'package:speedmart_lanka/features/payments/models/payment.dart';

class OrderState {
  final bool isLoading;
  final String? error;
  final List<OrderModel> orders;

  const OrderState({
    this.isLoading = false,
    this.error,
    this.orders = const [],
  });

  OrderState copyWith({
    bool? isLoading,
    String? error,
    List<OrderModel>? orders,
    bool clearError = false,
  }) {
    return OrderState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      orders: orders ?? this.orders,
    );
  }
}

class OrderNotifier extends StateNotifier<OrderState> {
  OrderNotifier(this.ref) : super(const OrderState()) {
    _repo = MockOrderRepository.instance;
    _requestRepo = MockRequestRepository.instance;
  }

  final Ref ref;
  late final MockOrderRepository _repo;
  late final MockRequestRepository _requestRepo;

  Future<void> loadAllOrders() async {
    await _repo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final orders = await _repo.getAllOrders();
      state = state.copyWith(isLoading: false, orders: orders);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadCustomerOrders() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    await _repo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final orders = await _repo.getOrdersForCustomer(user.id);
      state = state.copyWith(isLoading: false, orders: orders);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadVendorOrders() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    await _repo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final orders = await _repo.getOrdersForVendor(user.id);
      state = state.copyWith(isLoading: false, orders: orders);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<OrderModel> placeOrder(OrderModel order, {bool updateRequestStatus = true}) async {
    await _repo.ensureInitialized();
    await _requestRepo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final newOrder = await _repo.createOrder(order);
      state = state.copyWith(
        isLoading: false,
        orders: [newOrder, ...state.orders],
      );

      // Only update request status once (first order in a multi-vendor placement)
      if (updateRequestStatus) {
        final nextStatus = order.paymentMethod == PaymentMethod.mockOnline
            ? RequestStatus.paid
            : RequestStatus.cashOnDeliveryConfirmed;
        await _requestRepo.updateRequestStatus(order.requestId, nextStatus);
      }

      return newOrder;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    await _repo.ensureInitialized();
    await _requestRepo.ensureInitialized();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.updateOrderStatus(orderId, status);

      // Also sync request status if order completes
      final OrderModel? order = await _repo.getOrderById(orderId);
      if (order != null) {
        RequestStatus? reqStatus;
        if (status == OrderStatus.accepted) {
          reqStatus = RequestStatus.accepted;
        } else if (status == OrderStatus.preparing) {
          reqStatus = RequestStatus.preparingOrder;
        } else if (status == OrderStatus.readyForDelivery) {
          reqStatus = RequestStatus.readyForDelivery;
        } else if (status == OrderStatus.outForDelivery) {
          reqStatus = RequestStatus.outForDelivery;
        } else if (status == OrderStatus.delivered) {
          reqStatus = RequestStatus.delivered;
        } else if (status == OrderStatus.completed) {
          reqStatus = RequestStatus.delivered;
        } else if (status == OrderStatus.cancelled) {
          reqStatus = RequestStatus.cancelled;
        }
        if (reqStatus != null) {
          await _requestRepo.updateRequestStatus(order.requestId, reqStatus);
        }
      }

      // Reload appropriate orders list
      final user = ref.read(currentUserProvider);
      if (user != null) {
        if (user.role.name == 'customer') {
          await loadCustomerOrders();
        } else {
          await loadVendorOrders();
        }
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final orderProvider = StateNotifierProvider<OrderNotifier, OrderState>((ref) {
  return OrderNotifier(ref);
});
