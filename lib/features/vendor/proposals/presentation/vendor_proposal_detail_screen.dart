import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../proposals/models/proposal.dart';
import '../../../proposals/providers/proposal_provider.dart';
import '../../../requests/data/mock_request_repository.dart';
import '../../../requests/models/shopping_request.dart';
import '../../request_feed/providers/vendor_request_feed_provider.dart';
import '../widgets/vendor_proposal_status_chip.dart';
import '../widgets/image_gallery_viewer.dart';
import 'dart:io';

/// View vendor proposal, send notes, edit, or withdraw before acceptance.
class VendorProposalDetailScreen extends ConsumerStatefulWidget {
  const VendorProposalDetailScreen({super.key, required this.proposal});

  final Proposal proposal;

  @override
  ConsumerState<VendorProposalDetailScreen> createState() =>
      _VendorProposalDetailScreenState();
}

class _VendorProposalDetailScreenState
    extends ConsumerState<VendorProposalDetailScreen> {
  late Proposal _proposal;
  ShoppingRequest? _request;
  final _messageController = TextEditingController();
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _proposal = widget.proposal;
    _messageController.text = _proposal.vendorResponse ?? '';
    _load();
  }

  Future<void> _load() async {
    final proposalNotifier = ref.read(proposalProvider.notifier);
    final req = await MockRequestRepository.instance
        .getRequestById(_proposal.requestId);
    if (!mounted) return;

    final latest = await proposalNotifier.loadProposalById(_proposal.id);
    if (!mounted) return;

    setState(() {
      _request = req;
      if (latest != null) _proposal = latest;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _saveMessage() async {
    if (_busy) return;
    final proposalNotifier = ref.read(proposalProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    try {
      await proposalNotifier.sendControlledMessage(
        _proposal.id,
        vendorMsg: _messageController.text.trim(),
      );
      if (!mounted) return;

      // Reload proposal to show updated message
      final updatedProposal = await proposalNotifier.loadProposalById(_proposal.id);
      if (!mounted) return;

      // Update local state with the fresh proposal data
      if (updatedProposal != null) {
        setState(() {
          _proposal = updatedProposal;
          _messageController.text = _proposal.vendorResponse ?? '';
        });
      }

      // Dismiss keyboard
      FocusScope.of(context).unfocus();

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Message saved to proposal'),
          duration: Duration(milliseconds: 1500),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error saving message: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw proposal?'),
        content: const Text(
          'The customer will no longer see this bid. You can submit a new proposal later.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Withdraw', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final proposalNotifier = ref.read(proposalProvider.notifier);
    final feedNotifier = ref.read(vendorRequestFeedProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    try {
      await proposalNotifier.withdrawProposal(_proposal.id);
      if (!mounted) return;

      await feedNotifier.loadFeed();
      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('Proposal withdrawn')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
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

    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.vendorColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(_proposal.id),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_proposal.canEdit && _request != null)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () {
                context.push('/vendor/proposals/edit', extra: {
                  'request': _request,
                  'proposal': _proposal,
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                VendorProposalStatusChip(status: _proposal.status),
                const Spacer(),
                Text(
                  'Rs. ${_proposal.totalPrice.toStringAsFixed(2)}',
                  style: AppTextStyles.h2(AppColors.vendorColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Request ${_proposal.requestId}',
              style: AppTextStyles.bodySmall(secondaryText),
            ),
            const SizedBox(height: 20),
            _SummaryRow(
              label: 'Subtotal',
              value: 'Rs. ${_proposal.subtotal.toStringAsFixed(2)}',
              isDark: isDark,
            ),
            _SummaryRow(
              label: 'Delivery fee',
              value: 'Rs. ${_proposal.deliveryFee.toStringAsFixed(2)}',
              isDark: isDark,
            ),
            _SummaryRow(
              label: 'Delivery time',
              value: _proposal.estimatedDeliveryTime,
              isDark: isDark,
            ),
            if (_proposal.notes != null && _proposal.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Your notes', style: AppTextStyles.subtitle(primaryText)),
              Text(_proposal.notes!, style: AppTextStyles.bodyMedium(secondaryText)),
            ],
            const SizedBox(height: 20),
            Text('Line items', style: AppTextStyles.h2(primaryText)),
            const SizedBox(height: 8),
            ..._proposal.items.map((item) {
              final requestItem = _request?.items.where((r) => r.id == item.requestItemId).firstOrNull;
              final customerImages = requestItem?.imageUrls ?? [];
              final vendorImages = item.vendorImageUrls;
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.itemName, style: AppTextStyles.bodyMedium(primaryText)),
                    Text(
                      '${item.status.name} · Qty ${item.quantity} · Rs. ${item.subtotal.toStringAsFixed(2)}',
                      style: AppTextStyles.caption(secondaryText),
                    ),
                    if (item.offeredBrandModel != null && item.offeredBrandModel!.isNotEmpty)
                      Text('Brand: ${item.offeredBrandModel}', style: AppTextStyles.caption(secondaryText)),
                    if (item.availableStock != null)
                      Text('Stock: ${item.availableStock}', style: AppTextStyles.caption(secondaryText)),
                    if (customerImages.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Customer photos:', style: AppTextStyles.caption(secondaryText)),
                      const SizedBox(height: 4),
                      _ImageRow(images: customerImages),
                    ],
                    if (vendorImages.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Your photos:', style: AppTextStyles.caption(secondaryText)),
                      const SizedBox(height: 4),
                      _ImageRow(images: vendorImages),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
            Text('Message to customer', style: AppTextStyles.h2(primaryText)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _messageController,
              maxLines: 3,
              enabled: _proposal.canEdit,
              decoration: InputDecoration(
                hintText: 'Optional follow-up note (controlled messaging)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_proposal.canEdit) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _busy ? null : _saveMessage,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.vendorColor),
                          ),
                        )
                      : const Text('Save message'),
                ),
              ),
            ],
            if (_proposal.vendorResponse != null && _proposal.vendorResponse!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.vendorColor.withValues(alpha: 0.1),
                  border: Border.all(color: AppColors.vendorColor.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: AppColors.vendorColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Saved: "${_proposal.vendorResponse}"',
                        style: AppTextStyles.bodySmall(AppColors.vendorColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_proposal.status == ProposalStatus.rejected) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Proposal Not Selected',
                          style: AppTextStyles.subtitle(AppColors.error),
                        ),
                      ],
                    ),
                    if (_proposal.rejectionReason != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _proposal.rejectionReason!,
                        style: AppTextStyles.bodyMedium(primaryText),
                      ),
                    ],
                    if (_proposal.rejectedAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Rejected on ${_proposal.rejectedAt!.day}/${_proposal.rejectedAt!.month}/${_proposal.rejectedAt!.year} at ${_proposal.rejectedAt!.hour}:${_proposal.rejectedAt!.minute.toString().padLeft(2, '0')}',
                        style: AppTextStyles.caption(secondaryText),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (_proposal.customerResponse != null) ...[
              const SizedBox(height: 16),
              Text('Customer reply', style: AppTextStyles.subtitle(primaryText)),
              Text(
                _proposal.customerResponse!,
                style: AppTextStyles.bodyMedium(secondaryText),
              ),
            ],
            if (_proposal.canWithdraw) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _busy ? null : _withdraw,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  child: const Text('Withdraw proposal'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImageRow extends StatelessWidget {
  const _ImageRow({required this.images});
  final List<String> images;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (context, index) {
          final path = images[index];
          final isNetwork = path.startsWith('http://') || path.startsWith('https://');
          return Padding(
            padding: EdgeInsets.only(right: index < images.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ImageGalleryViewer(imagePaths: images, initialIndex: index),
              )),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: isNetwork
                    ? Image.network(path, width: 72, height: 72, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined))
                    : Image.file(File(path), width: 72, height: 72, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.isDark,
  });

  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final primary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium(secondary)),
          Text(value, style: AppTextStyles.bodyMedium(primary)),
        ],
      ),
    );
  }
}

