import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/utils/category_constants.dart';
import '../../../customer/delivery_address/utils/vendor_delivery_privacy.dart';
import '../../../proposals/models/proposal.dart';
import '../../../proposals/providers/proposal_provider.dart';
import '../../../requests/models/shopping_request.dart';
import '../../request_feed/models/vendor_feed_enums.dart';
import '../widgets/image_gallery_viewer.dart';

/// Vendor opens a customer request before submitting or editing a proposal.
class VendorRequestDetailScreen extends ConsumerStatefulWidget {
  const VendorRequestDetailScreen({super.key, required this.request});

  final ShoppingRequest request;

  @override
  ConsumerState<VendorRequestDetailScreen> createState() =>
      _VendorRequestDetailScreenState();
}

class _VendorRequestDetailScreenState
    extends ConsumerState<VendorRequestDetailScreen> {
  Proposal? _existingProposal;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String? get _requestCategory {
    final cats = widget.request.items
        .map((i) => i.category)
        .whereType<String>()
        .where((c) => c.isNotEmpty)
        .map(VendorCategories.normalize)
        .toSet();
    // Return null for multi-category requests so proposal lookup uses all categories.
    return cats.length == 1 ? cats.first : null;
  }

  Future<void> _load() async {
    final p = await ref
        .read(proposalProvider.notifier)
        .loadVendorProposalForRequest(
          widget.request.id,
          categoryNormalized: _requestCategory,
        );
    if (mounted) {
      setState(() {
        _existingProposal = p;
        _loading = false;
      });
    }
  }

  RequestUrgency _urgency() {
    final hours =
        DateTime.now().difference(widget.request.createdAt).inHours;
    if (hours < 2) return RequestUrgency.high;
    if (hours < 6) return RequestUrgency.medium;
    return RequestUrgency.normal;
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
    final request = widget.request;
    final urgency = _urgency();

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Request details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.vendorColor),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                120,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.vendorColor,
                          AppColors.vendorColorDark,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.vendorVisibleAreaLabel,
                          style: AppTextStyles.h2(Colors.white),
                        ),
                        if (request.deliveryLocation?.district.isNotEmpty ==
                            true)
                          Text(
                            request.deliveryLocation!.district,
                            style: AppTextStyles.bodyMedium(Colors.white70),
                          ),
                        SizedBox(height: AppSpacing.sm),
                        Text(
                          'Exact address and phone unlock after customer accepts your bid.',
                          style: AppTextStyles.caption(Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _StatusChip(
                        label: request.status.displayName,
                        color: AppColors.vendorColor,
                      ),
                      _StatusChip(
                        label: urgency.label,
                        color: urgency == RequestUrgency.high
                            ? AppColors.error
                            : AppColors.vendorColor,
                      ),
                      _StatusChip(
                        label: '${request.items.length} items',
                        color: AppColors.vendorColor,
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.lg),
                  Text('Requested items', style: AppTextStyles.h2(primaryText)),
                  SizedBox(height: AppSpacing.md),
                  // Group items by category with a header chip per group and detailed cards
                  ..._buildGroupedItems(context, request.items, primaryText, secondaryText, cardColor, borderColor),
                  if (_existingProposal != null) ...[
                    SizedBox(height: AppSpacing.lg),
                    Text('Your proposal', style: AppTextStyles.h2(primaryText)),
                    SizedBox(height: AppSpacing.sm),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _existingProposal!.id,
                                style: AppTextStyles.subtitle(primaryText),
                              ),
                              const Spacer(),
                              _StatusChip(
                                label: _existingProposal!.status.toString().split('.').last,
                                color: AppColors.vendorColor,
                              ),
                            ],
                          ),
                          SizedBox(height: AppSpacing.sm),
                          Text(
                            'Total Rs. ${_existingProposal!.totalPrice.toStringAsFixed(2)}',
                            style: AppTextStyles.bodyMedium(AppColors.vendorColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_existingProposal != null &&
                        _existingProposal!.canEdit)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.vendorColor,
                            side: const BorderSide(color: AppColors.vendorColor),
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                          onPressed: () {
                            context.push(
                              '/vendor/proposals/edit',
                              extra: {
                                'request': request,
                                'proposal': _existingProposal,
                              },
                            );
                          },
                          child: const Text('Edit proposal'),
                        ),
                      ),
                    if (_existingProposal != null) ...[
                      SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () {
                            context.push(
                              '/vendor/proposals/detail',
                              extra: _existingProposal,
                            );
                          },
                          child: const Text('View proposal & messages'),
                        ),
                      ),
                    ],
                    SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.vendorColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        onPressed: () {
                          if (_existingProposal != null &&
                              _existingProposal!.canEdit) {
                            context.push(
                              '/vendor/proposals/edit',
                              extra: {
                                'request': request,
                                'proposal': _existingProposal,
                              },
                            );
                          } else if (_existingProposal == null) {
                            context.push(
                              '/vendor/proposals/create',
                              extra: request,
                            );
                          } else {
                            context.push(
                              '/vendor/proposals/detail',
                              extra: _existingProposal,
                            );
                          }
                        },
                        child: Text(
                          _existingProposal == null
                              ? 'Create proposal'
                              : (_existingProposal!.canEdit
                                  ? 'Continue proposal'
                                  : 'View proposal'),
                          style: AppTextStyles.button(Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// Groups request items by category and returns a flat list of widgets
  /// with a category chip header before each group, followed by the item cards.
  List<Widget> _buildGroupedItems(
    BuildContext context,
    List<dynamic> items,
    Color primaryText,
    Color secondaryText,
    Color cardColor,
    Color borderColor,
  ) {
    final grouped = <String, List<dynamic>>{};
    for (final item in items) {
      final cat = (item.category as String?) ?? 'General';
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
                      style: TextStyle(
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

      // Detailed item cards in this category
      for (final item in catItems) {
        widgets.add(
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: AppSpacing.md),
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: AppTextStyles.subtitle(primaryText)),
                SizedBox(height: AppSpacing.xs),
                Text(
                  'Qty ${item.quantity}${item.unit != null ? ' ${item.unit}' : ''}'
                  '${item.category != null ? ' · ${item.category}' : ''}',
                  style: AppTextStyles.bodySmall(secondaryText),
                ),
                if (item.preferredBrand != null &&
                    item.preferredBrand!.isNotEmpty)
                  Text(
                    'Preferred: ${item.preferredBrand}',
                    style: AppTextStyles.caption(secondaryText),
                  ),
                if (item.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Customer photos (${item.imageUrls.length})',
                    style: AppTextStyles.caption(secondaryText),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: item.imageUrls.length,
                      itemBuilder: (context, index) {
                        final url = item.imageUrls[index];
                        final isNetwork = url.startsWith('http://') || url.startsWith('https://');
                        
                        return Padding(
                          padding: EdgeInsets.only(right: index < item.imageUrls.length - 1 ? AppSpacing.sm : 0),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ImageGalleryViewer(
                                    imagePaths: item.imageUrls,
                                    initialIndex: index,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: borderColor,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                border: Border.all(color: borderColor.withValues(alpha: 0.5)),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                child: isNetwork
                                    ? Image.network(
                                        url,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return const Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.vendorColor,
                                            ),
                                          );
                                        },
                                        errorBuilder: (_, __, ___) {
                                          return const Center(
                                            child: Icon(Icons.broken_image_outlined, color: Colors.white54),
                                          );
                                        },
                                      )
                                    : Image.file(
                                        File(url),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, error, ___) {
                                          return const Center(
                                            child: Icon(Icons.broken_image_outlined, color: Colors.white54),
                                          );
                                        },
                                      ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }
    });
    return widgets;
  }
}


class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption(color),
      ),
    );
  }
}

