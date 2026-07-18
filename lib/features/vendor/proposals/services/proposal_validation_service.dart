import '../../../proposals/models/proposal.dart';

class ProposalValidationResult {
  const ProposalValidationResult({
    required this.isValid,
    this.errors = const [],
  });

  final bool isValid;
  final List<String> errors;

  String? get firstError => errors.isEmpty ? null : errors.first;
}

/// Validates vendor proposal forms before draft/submit/update.
/// TODO: Mirror rules on backend when API is integrated.
class ProposalValidationService {
  const ProposalValidationService();

  ProposalValidationResult validate({
    required List<ProposalItem> items,
    required String estimatedDeliveryTime,
    required double deliveryCharge,
  }) {
    final errors = <String>[];

    if (estimatedDeliveryTime.trim().isEmpty) {
      errors.add('Estimated delivery time is required');
    }

    if (items.isEmpty) {
      errors.add('Add at least one line item');
    }

    final pricedItems = items
        .where((i) => i.status != ProposalItemStatus.unavailable)
        .toList();

    if (pricedItems.isEmpty) {
      errors.add('At least one available or alternative item is required');
    } else {
      for (final item in pricedItems) {
        if (item.unitPrice <= 0) {
          errors.add('Unit price required for "${item.itemName}"');
        }
        if (item.status == ProposalItemStatus.alternative &&
            (item.alternativeName == null ||
                item.alternativeName!.trim().isEmpty)) {
          errors.add('Alternative product name required for "${item.itemName}"');
        }
      }
    }

    if (deliveryCharge < 0) {
      errors.add('Delivery fee cannot be negative');
    }

    return ProposalValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}

