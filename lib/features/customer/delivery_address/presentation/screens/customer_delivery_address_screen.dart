import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../location/providers/location_provider.dart';
import '../../models/customer_delivery_address.dart';
import '../../providers/customer_delivery_address_provider.dart';
import '../widgets/delivery_address_form.dart';
import '../widgets/save_default_address_dialog.dart';

class CustomerDeliveryAddressScreen extends ConsumerStatefulWidget {
  const CustomerDeliveryAddressScreen({
    super.key,
    this.fromCreateRequest = false,
  });

  final bool fromCreateRequest;

  @override
  ConsumerState<CustomerDeliveryAddressScreen> createState() =>
      _CustomerDeliveryAddressScreenState();
}

class _CustomerDeliveryAddressScreenState
    extends ConsumerState<CustomerDeliveryAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _formWidgetKey = GlobalKey<DeliveryAddressFormState>();
  bool _isSaving = false;
  bool _initialLoadDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runInitialLoad());
  }

  Future<void> _runInitialLoad() async {
    if (_initialLoadDone) return;
    _initialLoadDone = true;

    await ref
        .read(customerDeliveryAddressProvider.notifier)
        .loadForCurrentUser();
    if (!mounted) return;

    await ref
        .read(customerDeliveryAddressProvider.notifier)
        .applyActiveLocationToProvider();
    if (!mounted) return;

    _formWidgetKey.currentState?.syncFromProvider();
  }

  Future<void> _save() async {
    final formState = _formWidgetKey.currentState;
    if (formState == null || !formState.validateAndSync()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final loc = ref.read(deliveryLocationProvider).currentLocation;
    if (loc == null) return;

    SaveDefaultAddressChoice choice = SaveDefaultAddressChoice.saveAsDefault;
    if (widget.fromCreateRequest) {
      choice = await SaveDefaultAddressDialog.show(context);
      if (choice == SaveDefaultAddressChoice.cancelled) return;
    }

    setState(() => _isSaving = true);
    try {
      final address = CustomerDeliveryAddress.fromDeliveryLocation(
        customerId: user.id,
        location: loc,
        deliveryNote: loc.deliveryNote,
      );

      if (choice == SaveDefaultAddressChoice.saveAsDefault) {
        await ref
            .read(customerDeliveryAddressProvider.notifier)
            .saveDefaultAddress(address);
      } else {
        ref
            .read(customerDeliveryAddressProvider.notifier)
            .setRequestOnlyLocation(loc);
      }

      if (mounted) {
        context.pop(loc);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final addrState = ref.watch(customerDeliveryAddressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Address'),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      ),
      body: addrState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Delivery Address', style: AppTextStyles.h2(primaryText)),
                  const SizedBox(height: 8),
                  Text(
                    'This address is used for shopping requests. Vendors see only your approximate area until an order is confirmed.',
                    style: AppTextStyles.bodySmall(
                      isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 24),
                  DeliveryAddressForm(
                    key: _formWidgetKey,
                    formKey: _formKey,
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Save Address',
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _save,
                  ),
                ],
              ),
            ),
    );
  }
}