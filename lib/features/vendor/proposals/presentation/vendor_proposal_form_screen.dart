import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/providers/notification_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../shared/models/user_model.dart';
import '../../../vendor/request_feed/providers/vendor_request_feed_provider.dart';
import '../../../proposals/models/proposal.dart';
import '../../../proposals/providers/proposal_provider.dart';
import '../../../requests/models/shopping_request.dart';
import '../../../requests/providers/request_provider.dart';
import '../../../customer/delivery_address/utils/vendor_delivery_privacy.dart';
/// Create or edit a vendor proposal (quotation) for a customer request.
class VendorProposalFormScreen extends ConsumerStatefulWidget {
  const VendorProposalFormScreen({
    super.key,
    required this.request,
    this.existingProposal,
  });

  final ShoppingRequest request;
  final Proposal? existingProposal;

  @override
  ConsumerState<VendorProposalFormScreen> createState() =>
      _VendorProposalFormScreenState();
}

class _VendorProposalFormScreenState
    extends ConsumerState<VendorProposalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _deliveryFeeController = TextEditingController(text: '200');
  final _deliveryTimeController = TextEditingController(text: 'Within 2 hours');
  final _notesController = TextEditingController();

  late Map<String, ProposalItemStatus> _itemStatuses;
  late Map<String, TextEditingController> _priceControllers;
  late Map<String, TextEditingController> _brandControllers;
  late Map<String, TextEditingController> _stockControllers;
  late Map<String, TextEditingController> _remarkControllers;
  late Map<String, TextEditingController> _altNameControllers;
  late Map<String, TextEditingController> _altBrandControllers;
  late Map<String, TextEditingController> _altReasonControllers;

  List<String> _productImages = [];
  double _itemsSubtotal = 0;
  double _deliveryFee = 200;
  bool _saving = false;

  bool get _isEditing => widget.existingProposal != null;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _deliveryFeeController.addListener(_onDeliveryFeeChanged);
  }

  void _initControllers() {
    _itemStatuses = {};
    _priceControllers = {};
    _brandControllers = {};
    _stockControllers = {};
    _remarkControllers = {};
    _altNameControllers = {};
    _altBrandControllers = {};
    _altReasonControllers = {};

    final existing = widget.existingProposal;
    if (existing != null) {
      _deliveryFeeController.text = existing.deliveryCharge.toStringAsFixed(0);
      _deliveryTimeController.text = existing.estimatedDeliveryTime;
      _notesController.text = existing.notes ?? '';
      _productImages = List<String>.from(existing.productImageUrls);
      _deliveryFee = existing.deliveryCharge;
    }

    for (final item in widget.request.items) {
      ProposalItem? match;
      if (existing != null) {
        for (final pi in existing.items) {
          if (pi.requestItemId == item.id) {
            match = pi;
            break;
          }
        }
      }

      _itemStatuses[item.id] =
          match?.status ?? ProposalItemStatus.available;
      _priceControllers[item.id] = TextEditingController(
        text: match != null && match.price > 0
            ? match.price.toStringAsFixed(0)
            : '',
      );
      _brandControllers[item.id] = TextEditingController(
        text: match?.offeredBrandModel ?? item.preferredBrand ?? '',
      );
      _stockControllers[item.id] = TextEditingController(
        text: match?.availableStock?.toString() ?? '',
      );
      _remarkControllers[item.id] =
          TextEditingController(text: match?.description ?? '');
      _altNameControllers[item.id] = TextEditingController(
        text: match?.alternativeName ?? '${item.name} alternative',
      );
      _altBrandControllers[item.id] =
          TextEditingController(text: match?.alternativeBrand ?? '');
      _altReasonControllers[item.id] = TextEditingController(
        text: match?.alternativeReason ?? 'Original out of stock.',
      );
    }
    _recalculateSubtotal();
  }

  void _onDeliveryFeeChanged() {
    setState(() {
      _deliveryFee = double.tryParse(_deliveryFeeController.text) ?? 0;
    });
  }

  @override
  void dispose() {
    _deliveryFeeController.dispose();
    _deliveryTimeController.dispose();
    _notesController.dispose();
    for (final c in [
      ..._priceControllers.values,
      ..._brandControllers.values,
      ..._stockControllers.values,
      ..._remarkControllers.values,
      ..._altNameControllers.values,
      ..._altBrandControllers.values,
      ..._altReasonControllers.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _recalculateSubtotal() {
    var total = 0.0;
    for (final item in widget.request.items) {
      final status = _itemStatuses[item.id]!;
      if (status == ProposalItemStatus.unavailable) continue;
      final price = double.tryParse(_priceControllers[item.id]?.text ?? '') ?? 0;
      total += price * item.quantity;
    }
    setState(() => _itemsSubtotal = total);
  }

  List<ProposalItem> _buildItems() {
    final items = <ProposalItem>[];
    final missing = <String>[];

    for (final item in widget.request.items) {
      final status = _itemStatuses[item.id]!;
      final price = double.tryParse(_priceControllers[item.id]?.text ?? '') ?? 0;
      final stock = int.tryParse(_stockControllers[item.id]?.text ?? '');

      if (status == ProposalItemStatus.unavailable) {
        missing.add(item.id);
        items.add(ProposalItem(
          requestItemId: item.id,
          itemName: item.name,
          quantity: item.quantity,
          status: status,
        ));
      } else if (status == ProposalItemStatus.available) {
        items.add(ProposalItem(
          requestItemId: item.id,
          itemName: item.name,
          quantity: item.quantity,
          status: status,
          price: price,
          offeredBrandModel: _brandControllers[item.id]?.text,
          availableStock: stock,
          description: _remarkControllers[item.id]?.text,
        ));
      } else {
        items.add(ProposalItem(
          requestItemId: item.id,
          itemName: item.name,
          quantity: item.quantity,
          status: status,
          price: price,
          offeredBrandModel: _altBrandControllers[item.id]?.text,
          availableStock: stock,
          alternativeName: _altNameControllers[item.id]?.text,
          alternativeBrand: _altBrandControllers[item.id]?.text,
          alternativeReason: _altReasonControllers[item.id]?.text,
        ));
      }
    }
    return items;
  }

  Proposal? _buildProposal({
    required ProposalStatus status,
    required UserModel user,
    required double vendorLatitude,
    required double vendorLongitude,
  }) {
    final items = _buildItems();
    final missing = items
        .where((i) => i.status == ProposalItemStatus.unavailable)
        .map((i) => i.requestItemId)
        .toList();
    final subtotal = items.fold<double>(0, (s, i) => s + i.subtotal);

    return Proposal(
      id: widget.existingProposal?.id ?? '',
      requestId: widget.request.id,
      vendorId: user.id,
      vendorBusinessName: user.businessName ?? 'Partner Vendor',
      items: items,
      missingItemIds: missing,
      deliveryCharge: _deliveryFee,
      estimatedDeliveryTime: _deliveryTimeController.text.trim(),
      totalPrice: subtotal + _deliveryFee,
      status: status,
      createdAt: widget.existingProposal?.createdAt ?? DateTime.now(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      productImageUrls: _productImages,
      vendorLatitude: vendorLatitude,
      vendorLongitude: vendorLongitude,
    );
  }

  Future<void> _pickProductImage() async {
    if (_productImages.length >= 4) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() => _productImages = [..._productImages, file.path]);
    }
  }

  Future<void> _saveDraft() async {
    if (_saving) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final loc = ref.read(requestProvider);
    final proposalNotifier = ref.read(proposalProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    final proposal = _buildProposal(
      status: ProposalStatus.draft,
      user: user,
      vendorLatitude: loc.vendorLatitude,
      vendorLongitude: loc.vendorLongitude,
    );
    if (proposal == null) return;

    setState(() => _saving = true);
    try {
      await proposalNotifier.saveDraft(proposal);
      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Draft saved locally'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final loc = ref.read(requestProvider);
    final validator = ref.read(proposalValidationServiceProvider);
    final proposalNotifier = ref.read(proposalProvider.notifier);
    final feedNotifier = ref.read(vendorRequestFeedProvider.notifier);
    final notificationNotifier = ref.read(notificationProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    final items = _buildItems();
    final result = validator.validate(
      items: items,
      estimatedDeliveryTime: _deliveryTimeController.text,
      deliveryCharge: _deliveryFee,
    );
    if (!result.isValid) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.firstError ?? 'Invalid proposal'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final proposal = _buildProposal(
      status: ProposalStatus.submitted,
      user: user,
      vendorLatitude: loc.vendorLatitude,
      vendorLongitude: loc.vendorLongitude,
    );
    if (proposal == null) return;

    setState(() => _saving = true);
    try {
      if (_isEditing && widget.existingProposal!.status != ProposalStatus.draft) {
        await proposalNotifier.updateVendorProposal(proposal);
      } else {
        await proposalNotifier.submitProposal(proposal);
      }
      if (!mounted) return;

      await feedNotifier.loadFeed();
      if (!mounted) return;

      notificationNotifier.triggerNotification(
        title: 'New bid received',
        body:
            'A merchant bid Rs. ${proposal.totalPrice.toStringAsFixed(0)} on ${proposal.requestId}.',
        icon: Icons.local_offer_rounded,
        color: AppColors.customerColor,
      );

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Proposal submitted'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit proposal' : 'Submit proposal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _saving ? null : () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.request.vendorVisibleAreaLabel,
                            style: AppTextStyles.subtitle(primaryText),
                          ),
                          Text(
                            '${widget.request.items.length} items · ${widget.request.status.displayName}',
                            style: AppTextStyles.caption(secondaryText),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Line items', style: AppTextStyles.h2(primaryText)),
                    const SizedBox(height: 10),
                    ...widget.request.items.map((item) {
                      final status = _itemStatuses[item.id]!;
                      return _ItemEditorCard(
                        itemName: item.name,
                        quantity: item.quantity,
                        status: status,
                        isDark: isDark,
                        onStatusChanged: (s) {
                          setState(() {
                            _itemStatuses[item.id] = s;
                            _recalculateSubtotal();
                          });
                        },
                        priceController: _priceControllers[item.id]!,
                        brandController: _brandControllers[item.id]!,
                        stockController: _stockControllers[item.id]!,
                        remarkController: _remarkControllers[item.id]!,
                        altNameController: _altNameControllers[item.id]!,
                        altBrandController: _altBrandControllers[item.id]!,
                        altReasonController: _altReasonControllers[item.id]!,
                        onPriceChanged: _recalculateSubtotal,
                      );
                    }),
                    const SizedBox(height: 20),
                    Text('Delivery & notes', style: AppTextStyles.h2(primaryText)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _deliveryFeeController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Delivery fee (LKR)',
                              prefixText: 'Rs. ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _deliveryTimeController,
                            decoration: InputDecoration(
                              labelText: 'Estimated delivery time *',
                              hintText: 'e.g. 1-2 hours',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _notesController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Message / notes to customer',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Product photos (optional)',
                        style: AppTextStyles.subtitle(primaryText)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._productImages.map(
                          (path) => Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: _productImagePreview(path, cardColor),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _productImages =
                                        _productImages.where((p) => p != path).toList();
                                  }),
                                  child: const CircleAvatar(
                                    radius: 10,
                                    backgroundColor: AppColors.error,
                                    child: Icon(Icons.close, size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_productImages.length < 4)
                          InkWell(
                            onTap: _pickProductImage,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                border: Border.all(color: borderColor),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.add_photo_alternate_outlined,
                                color: AppColors.vendorColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal', style: AppTextStyles.bodyMedium(secondaryText)),
                        Text('Rs. ${_itemsSubtotal.toStringAsFixed(2)}',
                            style: AppTextStyles.bodyMedium(primaryText)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total bid', style: AppTextStyles.subtitle(primaryText)),
                        Text(
                          'Rs. ${(_itemsSubtotal + _deliveryFee).toStringAsFixed(2)}',
                          style: AppTextStyles.h2(AppColors.vendorColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving ? null : _saveDraft,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.vendorColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Save draft'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.vendorColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _isEditing ? 'Update & submit' : 'Submit proposal',
                                    style: AppTextStyles.button(Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productImagePreview(String path, Color cardColor) {
    const size = 72.0;
    if (!kIsWeb && File(path).existsSync()) {
      return Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }
    return Container(
      width: size,
      height: size,
      color: cardColor,
      child: const Icon(Icons.image_outlined),
    );
  }
}

class _ItemEditorCard extends StatelessWidget {
  const _ItemEditorCard({
    required this.itemName,
    required this.quantity,
    required this.status,
    required this.isDark,
    required this.onStatusChanged,
    required this.priceController,
    required this.brandController,
    required this.stockController,
    required this.remarkController,
    required this.altNameController,
    required this.altBrandController,
    required this.altReasonController,
    required this.onPriceChanged,
  });

  final String itemName;
  final int quantity;
  final ProposalItemStatus status;
  final bool isDark;
  final ValueChanged<ProposalItemStatus> onStatusChanged;
  final TextEditingController priceController;
  final TextEditingController brandController;
  final TextEditingController stockController;
  final TextEditingController remarkController;
  final TextEditingController altNameController;
  final TextEditingController altBrandController;
  final TextEditingController altReasonController;
  final VoidCallback onPriceChanged;

  @override
  Widget build(BuildContext context) {
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(itemName, style: AppTextStyles.subtitle(primaryText)),
          Text('Qty $quantity', style: AppTextStyles.caption(primaryText)),
          const SizedBox(height: 10),
          Row(
            children: [
              _chip('Available', ProposalItemStatus.available),
              const SizedBox(width: 6),
              _chip('Alt', ProposalItemStatus.alternative),
              const SizedBox(width: 6),
              _chip('N/A', ProposalItemStatus.unavailable),
            ],
          ),
          if (status != ProposalItemStatus.unavailable) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: priceController,
              keyboardType: TextInputType.number,
              onChanged: (_) => onPriceChanged(),
              decoration: InputDecoration(
                labelText: 'Unit price (LKR) *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: brandController,
              decoration: InputDecoration(
                labelText: 'Brand / model offered',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: stockController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Available stock',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (status == ProposalItemStatus.alternative) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: altNameController,
                decoration: InputDecoration(
                  labelText: 'Alternative product name *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: altReasonController,
                decoration: InputDecoration(
                  labelText: 'Replacement reason',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextFormField(
              controller: remarkController,
              decoration: InputDecoration(
                labelText: 'Item note',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, ProposalItemStatus value) {
    final selected = status == value;
    return Expanded(
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: selected,
        onSelected: (_) => onStatusChanged(value),
        selectedColor: AppColors.vendorColor.withOpacity(0.2),
        checkmarkColor: AppColors.vendorColor,
      ),
    );
  }
}
