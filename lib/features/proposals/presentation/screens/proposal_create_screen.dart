import '../../../requests/models/shopping_request.dart';
import '../../../vendor/proposals/presentation/vendor_proposal_form_screen.dart';

/// Legacy entry point — delegates to [VendorProposalFormScreen].
@Deprecated('Use VendorProposalFormScreen from features/vendor/proposals')
class ProposalCreateScreen extends VendorProposalFormScreen {
  const ProposalCreateScreen({super.key, required ShoppingRequest request})
      : super(request: request);
}

