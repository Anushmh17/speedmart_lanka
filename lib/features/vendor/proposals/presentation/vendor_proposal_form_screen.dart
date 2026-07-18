import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/providers/notification_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/utils/category_constants.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../shared/models/user_model.dart';
import '../../../vendor/request_feed/providers/vendor_request_feed_provider.dart';
import '../../../proposals/models/proposal.dart';
import '../../../proposals/providers/proposal_provider.dart';
import '../../../requests/models/shopping_request.dart';
import '../../../requests/providers/request_provider.dart';
import '../../../customer/delivery_address/utils/vendor_delivery_privacy.dart';
import '../widgets/image_gallery_viewer.dart';
import '../../../../core/routes/route_names.dart';
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

  late Map<String, List<String>> _vendorItemImages;
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
    _vendorItemImages = {};

    final existing = widget.existingProposal;
    if (existing != null) {
      _deliveryFeeController.text = existing.deliveryCharge.toStringAsFixed(0);
      _deliveryTimeController.text = existing.estimatedDeliveryTime;
      _notesController.text = existing.notes ?? '';
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
      _vendorItemImages[item.id] = List<String>.from(match?.vendorImageUrls ?? []);
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

  /// Generates a globally unique product item ID.
  /// Format: ITEM-<13-digit timestamp ms>-<6-digit random>
  String _generateUniqueItemId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(900000) + 100000;
    return 'ITEM-$ts-$rand';
  }

  List<ProposalItem> _buildItems() {
    final items = <ProposalItem>[];
    final missing = <String>[];

    for (final item in widget.request.items) {
      final status = _itemStatuses[item.id]!;
      final price = double.tryParse(_priceControllers[item.id]?.text ?? '') ?? 0;
      final stock = int.tryParse(_stockControllers[item.id]?.text ?? '');
      final vendorImgs = _vendorItemImages[item.id] ?? [];

      // Preserve existing ID when editing; generate a new unique one for new items.
      ProposalItem? existing;
      if (widget.existingProposal != null) {
        for (final pi in widget.existingProposal!.items) {
          if (pi.requestItemId == item.id) { existing = pi; break; }
        }
      }
      final itemId = (existing != null && existing.id.isNotEmpty)
          ? existing.id
          : _generateUniqueItemId();

      if (status == ProposalItemStatus.unavailable) {
        missing.add(item.id);
        items.add(ProposalItem(
          id: itemId,
          requestItemId: item.id,
          itemName: item.name,
          quantity: item.quantity,
          status: status,
          vendorImageUrls: const [],
        ));
      } else if (status == ProposalItemStatus.available) {
        items.add(ProposalItem(
          id: itemId,
          requestItemId: item.id,
          itemName: item.name,
          quantity: item.quantity,
          status: status,
          price: price,
          offeredBrandModel: _brandControllers[item.id]?.text,
          availableStock: stock,
          description: _remarkControllers[item.id]?.text,
          vendorImageUrls: vendorImgs,
        ));
      } else {
        items.add(ProposalItem(
          id: itemId,
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
          vendorImageUrls: vendorImgs,
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

    // Determine category for this proposal from the (already-filtered) request items
    String? proposalCategory;
    final categoriesInProposal = widget.request.items
        .map((i) => i.category)
        .whereType<String>()
        .where((c) => c.isNotEmpty)
        .map(VendorCategories.normalize)
        .toSet();

    if (categoriesInProposal.isNotEmpty) {
      proposalCategory = categoriesInProposal.first;
      if (categoriesInProposal.length > 1) {
        debugPrint('[MultiCategoryFlow] Warning: filtered request still has multiple categories: $categoriesInProposal');
      }
      debugPrint('[MultiCategoryFlow] Created proposal category: $proposalCategory');
    }

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
      productImageUrls: const [],
      vendorLatitude: vendorLatitude,
      vendorLongitude: vendorLongitude,
      categoryNormalized: proposalCategory,
    );
  }

  List<Widget> _buildGroupedItemEditors({
    required bool isDark,
  }) {
    final grouped = <String, List<dynamic>>{};
    for (final item in widget.request.items) {
      final cat = item.category ?? 'General';
      grouped.putIfAbsent(cat, () => []).add(item);
    }

    final widgets = <Widget>[];
    grouped.forEach((category, catItems) {
      // Category header chip
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.vendorColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.vendorColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.category_outlined,
                        size: 14, color: AppColors.vendorColor),
                    const SizedBox(width: 5),
                    Text(
                      category,
                      style: const TextStyle(
                        color: AppColors.vendorColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      for (final item in catItems) {
        final status = _itemStatuses[item.id]!;
        widgets.add(
          _ItemEditorCard(
            key: ValueKey(item.id),
            itemName: item.name,
            quantity: item.quantity,
            status: status,
            isDark: isDark,
            customerImageUrls: item.imageUrls,
            vendorImageUrls: _vendorItemImages[item.id] ?? [],
            onVendorImagesChanged: (imgs) {
              setState(() => _vendorItemImages[item.id] = imgs);
            },
            onStatusChanged: (s) {
              setState(() {
                _itemStatuses[item.id] = s;
                if (s == ProposalItemStatus.unavailable) {
                  _vendorItemImages[item.id] = [];
                }
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
          ),
        );
      }
    });

    return widgets;
  }

  Future<void> _saveDraft() async {
    if (_saving) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final loc = ref.read(requestProvider);
    final proposalNotifier = ref.read(proposalProvider.notifier);

    final proposal = _buildProposal(
      status: ProposalStatus.draft,
      user: user,
      vendorLatitude: user.shopLatitude ?? loc.vendorLatitude,
      vendorLongitude: user.shopLongitude ?? loc.vendorLongitude,
    );
    if (proposal == null) return;

    setState(() => _saving = true);
    try {
      await proposalNotifier.saveDraft(proposal);
      if (!mounted) return;

      ref.read(notificationProvider.notifier).triggerNotification(
        title: 'Draft saved',
        body: 'Your proposal draft has been saved locally.',
        icon: Icons.save_outlined,
        color: AppColors.vendorColor,
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
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
      vendorLatitude: user.shopLatitude ?? loc.vendorLatitude,
      vendorLongitude: user.shopLongitude ?? loc.vendorLongitude,
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
        title: _isEditing ? 'Proposal updated' : 'Proposal submitted',
        body: 'Rs. ${proposal.totalPrice.toStringAsFixed(0)} bid sent for ${widget.request.items.length} item(s).',
        icon: Icons.local_offer_rounded,
        color: AppColors.vendorColor,
      );
      context.pushReplacement(
        RouteNames.vendorProposalDetail,
        extra: proposal,
      );
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
                    ..._buildGroupedItemEditors(isDark: isDark),
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
                            textCapitalization: TextCapitalization.sentences,
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
                            textCapitalization: TextCapitalization.sentences,
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

}

class _ItemEditorCard extends StatefulWidget {
  const _ItemEditorCard({
    super.key,
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
    this.customerImageUrls = const [],
    this.vendorImageUrls = const [],
    required this.onVendorImagesChanged,
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
  final List<String> customerImageUrls;
  final List<String> vendorImageUrls;
  final ValueChanged<List<String>> onVendorImagesChanged;

  @override
  State<_ItemEditorCard> createState() => _ItemEditorCardState();
}

class _ItemEditorCardState extends State<_ItemEditorCard> {
  Future<void> _pickVendorImage() async {
    if (widget.vendorImageUrls.length >= 4) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      widget.onVendorImagesChanged([...widget.vendorImageUrls, file.path]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryText = widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final cardColor = widget.isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = widget.isDark ? AppColors.borderDark : AppColors.borderLight;

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
          Text(widget.itemName, style: AppTextStyles.subtitle(primaryText)),
          Text('Qty ${widget.quantity}', style: AppTextStyles.caption(primaryText)),
          if (widget.customerImageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Customer photos (${widget.customerImageUrls.length}):', style: AppTextStyles.caption(primaryText)),
            const SizedBox(height: 6),
            SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.customerImageUrls.length,
                itemBuilder: (context, index) {
                  final url = widget.customerImageUrls[index];
                  final isNetwork = url.startsWith('http://') || url.startsWith('https://');
                  return Padding(
                    padding: EdgeInsets.only(right: index < widget.customerImageUrls.length - 1 ? 8 : 0),
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ImageGalleryViewer(imagePaths: widget.customerImageUrls, initialIndex: index),
                      )),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: isNetwork
                            ? Image.network(url, width: 72, height: 72, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined))
                            : Image.file(File(url), width: 72, height: 72, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
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
          if (widget.status != ProposalItemStatus.unavailable) ...[
            const SizedBox(height: 10),
            Text('Your photos (optional):', style: AppTextStyles.caption(primaryText)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...widget.vendorImageUrls.map((path) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _imagePreview(path, cardColor),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () => widget.onVendorImagesChanged(
                          widget.vendorImageUrls.where((p) => p != path).toList(),
                        ),
                        child: const CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.error,
                          child: Icon(Icons.close, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                )),
                if (widget.vendorImageUrls.length < 4)
                  InkWell(
                    onTap: _pickVendorImage,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add_photo_alternate_outlined,
                          color: AppColors.vendorColor, size: 22),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: widget.priceController,
              keyboardType: TextInputType.number,
              onChanged: (_) => widget.onPriceChanged(),
              decoration: InputDecoration(
                labelText: 'Unit price (LKR) *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: widget.brandController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Brand / model offered',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: widget.stockController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Available stock',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (widget.status == ProposalItemStatus.alternative) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: widget.altNameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Alternative product name *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: widget.altReasonController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Replacement reason',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextFormField(
              controller: widget.remarkController,
              textCapitalization: TextCapitalization.sentences,
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

  Widget _imagePreview(String path, Color cardColor) {
    const size = 56.0;
    if (!kIsWeb && File(path).existsSync()) {
      return Image.file(File(path), width: size, height: size, fit: BoxFit.cover);
    }
    return Container(width: size, height: size, color: cardColor,
        child: const Icon(Icons.image_outlined));
  }

  Widget _chip(String label, ProposalItemStatus value) {
    final selected = widget.status == value;
    return Expanded(
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: selected,
        onSelected: (_) => widget.onStatusChanged(value),
        selectedColor: AppColors.vendorColor.withValues(alpha: 0.2),
        checkmarkColor: AppColors.vendorColor,
      ),
    );
  }
}

