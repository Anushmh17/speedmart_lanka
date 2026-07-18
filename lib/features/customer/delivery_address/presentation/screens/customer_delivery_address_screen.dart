import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/widgets/theme3/theme3_widgets.dart';
import '../../../../location/providers/location_provider.dart';
import '../../models/customer_delivery_address.dart';
import '../../providers/customer_delivery_address_provider.dart';
import '../widgets/delivery_address_form.dart';
import '../widgets/delivery_location_map_picker.dart';
import '../widgets/save_default_address_dialog.dart';

class CustomerDeliveryAddressScreen extends ConsumerStatefulWidget {
  const CustomerDeliveryAddressScreen({
    super.key,
    this.fromCreateRequest = false,
    this.startWithGpsDetection = false,
  });

  final bool fromCreateRequest;
  final bool startWithGpsDetection;

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
    if (widget.startWithGpsDetection) {
      await _formWidgetKey.currentState?.detectGps();
      if (mounted) _formWidgetKey.currentState?.syncFromProvider();
    }
  }

  Future<void> _save() async {
    final formState = _formWidgetKey.currentState;
    if (formState == null || !formState.validateAndSync()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final loc = ref.read(deliveryLocationProvider).currentLocation;
    if (loc == null) return;
    
    debugPrint('[ApproxAreaAudit] ===== SAVE BUTTON CLICKED =====');
    debugPrint('[ApproxAreaAudit] deliveryLocationProvider.currentLocation.approximateAreaText: "${loc.approximateAreaText}"');
    debugPrint('[ApproxAreaAudit] deliveryLocationProvider.approximateAreaText: "${ref.read(deliveryLocationProvider).approximateAreaText}"');
    
    if (loc.latitude == null ||
        loc.longitude == null ||
        loc.latitude == 0.0 ||
        loc.longitude == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a valid delivery location.'),
        ),
      );
      return;
    }

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
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final addrState = ref.watch(customerDeliveryAddressProvider);
    final loc = ref.watch(deliveryLocationProvider).currentLocation;

    return Scaffold(
      appBar: Theme3AppBar(
        title: 'Delivery Address',
      ),
      body: addrState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text('Manage Delivery Address', style: AppTextStyles.h2(primaryText)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Shop owners see only your approximate area until order confirmation',
                    style: AppTextStyles.bodySmall(secondaryText),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Current Address Card
                  Theme3AppCard(
                    type: Theme3CardType.elevated,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              color: isDark ? AppColors.primaryDark : AppColors.primary,
                              size: 24,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Current Address',
                              style: AppTextStyles.h3(primaryText),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        DeliveryAddressForm(
                          key: _formWidgetKey,
                          formKey: _formKey,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Location Status Card
                  if (loc != null && loc.latitude != null && loc.longitude != null) ...[
                    Theme3AppCard(
                      type: Theme3CardType.standard,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Icon(
                                  Icons.gps_fixed_rounded,
                                  color: AppColors.success,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'GPS Detected',
                                      style: AppTextStyles.labelLarge(primaryText),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Location verified successfully',
                                      style: AppTextStyles.caption(secondaryText),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Map Picker
                  Theme3AppCard(
                    type: Theme3CardType.standard,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pin Location on Map',
                          style: AppTextStyles.labelLarge(primaryText),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const DeliveryLocationMapPicker(),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Save Button
                  Theme3AppButton(
                    label: 'Save Changes',
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _save,
                    icon: Icons.check_rounded,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
    );
  }
}

