import 'package:flutter_test/flutter_test.dart';
import 'package:speedmart_lanka/features/customer/proposals/models/customer_proposal_view.dart';
import 'package:speedmart_lanka/features/payments/presentation/screens/payment_screen.dart';
import 'package:speedmart_lanka/features/proposals/models/proposal.dart';
import 'package:speedmart_lanka/features/requests/models/request_item.dart';
import 'package:speedmart_lanka/features/requests/models/shopping_request.dart';
import 'package:speedmart_lanka/features/vendor/request_feed/services/vendor_request_filter_service.dart';
import 'package:speedmart_lanka/shared/models/vendor_status.dart';
import 'package:speedmart_lanka/shared/utils/category_constants.dart';

void main() {
  group('VendorCategories normalization', () {
    test('normalizes underscore category keys to the canonical display form', () {
      expect(VendorCategories.normalize('vehicle_parts'), 'vehicle parts');
      expect(VendorCategories.normalize('home_appliances'), 'home appliances');
    });

    test('renders normalized categories with title case display names', () {
      expect(VendorCategories.display(VendorCategories.normalize('vehicle_parts')), 'Vehicle Parts');
      expect(VendorCategories.display(VendorCategories.normalize('home_appliances')), 'Home Appliances');
    });

    test('does not expose the Other category in the shared vendor category registry', () {
      expect(VendorCategories.displayNames.contains('Other'), isFalse);
      expect(VendorCategories.normalizedList.contains('other'), isFalse);
      expect(VendorCategories.isValid('other'), isFalse);
    });
  });

  group('Proposal pricing behavior', () {
    test('keeps the customer-facing total on the inclusive quoted amount', () {
      final proposal = Proposal(
        id: 'proposal-1',
        requestId: 'request-1',
        vendorId: 'vendor-1',
        vendorBusinessName: 'Test Shop',
        items: [
          ProposalItem(
            requestItemId: 'item-1',
            itemName: 'Milk Powder',
            quantity: 2,
            status: ProposalItemStatus.available,
            price: 400,
          ),
        ],
        deliveryCharge: 100,
        estimatedDeliveryTime: 'Within 2 hours',
        totalPrice: 1008,
        createdAt: DateTime.now(),
      );

      final view = CustomerProposalView(
        proposal: proposal,
        maskedVendorName: 'Test Shop',
        distanceKm: 2.4,
        ratingPlaceholder: 4.5,
        deliverySortHours: 2,
        isBestForMode: true,
      );

      final group = AcceptedVendorGroup(
        proposal: proposal,
        acceptedItems: proposal.items,
        commissionRate: 0.12,
      );

      expect(view.totalPrice, 1008);
      expect(group.customerAmount, proposal.totalPrice);
      expect(group.platformCommission, 108);
    });

    test('rejected proposals stay out of the vendor request feed', () {
      final service = VendorRequestFilterService();
      final request = ShoppingRequest(
        id: 'request-1',
        customerId: 'customer-1',
        status: RequestStatus.waitingForVendor,
        createdAt: DateTime.now(),
        customerArea: 'Colombo',
        deliveryAddress: '123 Main Street',
        customerPhone: '0770000000',
        customerName: 'Jane Doe',
        latitude: 0,
        longitude: 0,
        items: [
          RequestItem(
            id: 'item-1',
            itemName: 'Milk Powder',
            quantity: 1,
            category: 'Groceries',
          ),
        ],
      );

      final rejectedProposal = Proposal(
        id: 'proposal-rejected',
        requestId: request.id,
        vendorId: 'vendor-1',
        vendorBusinessName: 'Test Shop',
        items: const [],
        deliveryCharge: 100,
        estimatedDeliveryTime: 'Within 2 hours',
        totalPrice: 100,
        status: ProposalStatus.rejected,
        createdAt: DateTime.now(),
      );

      final feed = service.buildFeed(
        allRequests: [request],
        allProposals: [rejectedProposal],
        vendorCategories: const ['groceries'],
        vendorLatitude: 0,
        vendorLongitude: 0,
        vendorStatus: VendorStatus.approved,
        vendorId: 'vendor-1',
      );

      expect(feed, isEmpty);
    });
  });
}
