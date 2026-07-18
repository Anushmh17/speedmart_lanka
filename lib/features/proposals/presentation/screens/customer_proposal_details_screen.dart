import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/proposal.dart';
import '../../providers/proposal_provider.dart';
import '../../../customer/proposals/services/proposal_comparison_service.dart';
import '../../../vendor/proposals/widgets/image_gallery_viewer.dart';
import 'customer_proposal_details_screen_header.dart';

class CustomerProposalDetailsScreen extends ConsumerStatefulWidget {
  const CustomerProposalDetailsScreen({
    super.key,
    required this.proposal,
    required this.requestId,
  });

  final Proposal proposal;
  final String requestId;

  @override
  ConsumerState<CustomerProposalDetailsScreen> createState() => _CustomerProposalDetailsScreenState();
}

class _CustomerProposalDetailsScreenState extends ConsumerState<CustomerProposalDetailsScreen> {
  String? _selectedControlledMsg;

  final List<String> _suggestedMessages = [
    'I agree with alternative product',
    'I do not agree with alternative product',
    'Price is reasonable, please prepare',
    'Price too high',
    'Product is different than expected',
    'Need exact product only',
  ];

  bool _isProcessingAccept = false;

  Future<void> _handleAccept() async {
    if (_isProcessingAccept) return;
    setState(() {
      _isProcessingAccept = true;
    });
    try {
      if (widget.proposal.status != ProposalStatus.accepted) {
        await ref.read(proposalProvider.notifier).acceptProposal(
              widget.proposal.id,
              widget.requestId,
            );
      }
      if (!mounted) return;
      context.push('/customer/payment', extra: {
        'proposal': widget.proposal,
        'requestId': widget.requestId,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAccept = false;
        });
      }
    }
  }

  Future<void> _handleReject(String reason) async {
    await ref.read(proposalProvider.notifier).rejectProposal(widget.proposal.id, widget.requestId, reason);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Proposal rejected: "$reason"'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    }
  }

  Future<void> _sendSuggestedMessage() async {
    if (_selectedControlledMsg == null) return;
    await ref.read(proposalProvider.notifier).sendControlledMessage(
          widget.proposal.id,
          customerMsg: _selectedControlledMsg,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sent: "$_selectedControlledMsg"'),
          backgroundColor: AppColors.customerColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _selectedControlledMsg = null;
      });
    }
  }

  void _showRejectDialog() {
    final reasons = ['Price too high', 'Product is different', 'Need exact product only', 'Search again'];
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Reject Proposal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons.map((reason) {
              return ListTile(
                title: Text(reason),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleReject(reason);
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    const comparisonService = ProposalComparisonService();
    final maskedVendorName =
        comparisonService.maskedVendorName(widget.proposal.vendorId);
    final rating =
        comparisonService.ratingPlaceholderFor(widget.proposal.vendorId);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Column(
        children: [
          buildProposalDetailsHeader(context, isDark, primaryText, secondaryText, maskedVendorName),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shop Owner Privacy Banner
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.customerColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.customerColor.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined, color: AppColors.customerColor, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Full shop profile and contact details are shielded until order confirmation.',
                                style: AppTextStyles.caption(AppColors.customerColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.customerColor,
                            side: const BorderSide(color: AppColors.customerColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                          label: const Text('Chat with Shop Owner (Secure Link)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            final item = widget.proposal.items.isNotEmpty
                                ? widget.proposal.items.first
                                : null;
                            final autoMsg = item != null
                                ? _buildItemChatMessage(item)
                                : null;
                            context.push(
                              '/chat',
                              extra: {
                                'proposalId': widget.proposal.id,
                                'vendorName': maskedVendorName,
                                'isUnlocked': false,
                                'autoMessage': autoMsg,
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '$rating shop rating (preview)',
                        style: AppTextStyles.bodySmall(secondaryText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Item Availability Summary
                  _buildItemAvailabilitySummary(widget.proposal, cardColor, borderColor, primaryText, secondaryText),
                  const SizedBox(height: 24),

                  Text('Proposal Items Detail', style: AppTextStyles.h2(primaryText)),
                  const SizedBox(height: 10),

                  // Items List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: widget.proposal.items.length,
                    itemBuilder: (context, index) {
                      final sortedItems = [...widget.proposal.items]
                        ..sort((a, b) {
                          int rank(ProposalItemStatus s) {
                            if (s == ProposalItemStatus.available) return 0;
                            if (s == ProposalItemStatus.alternative) return 1;
                            return 2;
                          }
                          return rank(a.status).compareTo(rank(b.status));
                        });
                      final item = sortedItems[index];
                      Color badgeColor = Colors.grey;
                      IconData badgeIcon = Icons.help_outline;
                      String statusText = 'Unknown';

                      if (item.status == ProposalItemStatus.available) {
                        badgeColor = AppColors.success;
                        badgeIcon = Icons.check_circle_outline_rounded;
                        statusText = 'Available';
                      } else if (item.status == ProposalItemStatus.alternative) {
                        badgeColor = AppColors.warning;
                        badgeIcon = Icons.swap_horiz_rounded;
                        statusText = 'Alternative Offered';
                      } else if (item.status == ProposalItemStatus.unavailable) {
                        badgeColor = AppColors.error;
                        badgeIcon = Icons.cancel_outlined;
                        statusText = 'Not Available';
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Item name + status badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.requestItemName,
                                    style: AppTextStyles.subtitle(primaryText),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(badgeIcon, color: badgeColor, size: 14),
                                      const SizedBox(width: 4),
                                      Text(statusText, style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Qty: ${item.quantity}', style: AppTextStyles.caption(secondaryText)),

                            if (item.status == ProposalItemStatus.available) ...[
                              // Vendor photos first
                              _buildVendorImages(item, borderColor, secondaryText, context),
                              const SizedBox(height: 10),
                              // Pricing summary below images
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.success.withValues(alpha: 0.18)),
                                ),
                                child: Column(
                                  children: [
                                    _priceRow('Unit Price', 'Rs. ${item.price.toStringAsFixed(2)}', secondaryText, primaryText),
                                    const SizedBox(height: 4),
                                    _priceRow('Qty × Unit', '${item.quantity} × Rs. ${item.price.toStringAsFixed(2)}', secondaryText, secondaryText),
                                    const Divider(height: 14),
                                    _priceRow('Item Total', 'Rs. ${item.totalPrice.toStringAsFixed(2)}', primaryText, AppColors.success, bold: true),
                                  ],
                                ),
                              ),
                              if (item.description != null && item.description!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('Shop Owner Note: "${item.description}"', style: AppTextStyles.caption(AppColors.customerColor)),
                              ],
                            ] else if (item.status == ProposalItemStatus.alternative) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Offered Alternative:', style: AppTextStyles.bodySmall(AppColors.warning).copyWith(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(item.alternativeName ?? 'Replacement Product', style: AppTextStyles.bodyMedium(primaryText)),
                                    if (item.alternativeBrand != null && item.alternativeBrand!.isNotEmpty)
                                      Text('Brand: ${item.alternativeBrand}', style: AppTextStyles.caption(secondaryText)),
                                    if (item.alternativeReason != null && item.alternativeReason!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text('Reason: "${item.alternativeReason}"', style: AppTextStyles.caption(secondaryText)),
                                    ],
                                  ],
                                ),
                              ),
                              // Vendor photos
                              _buildVendorImages(item, borderColor, secondaryText, context),
                              const SizedBox(height: 10),
                              // Pricing summary below images
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.18)),
                                ),
                                child: Column(
                                  children: [
                                    _priceRow('Unit Price', 'Rs. ${item.price.toStringAsFixed(2)}', secondaryText, primaryText),
                                    const SizedBox(height: 4),
                                    _priceRow('Qty × Unit', '${item.quantity} × Rs. ${item.price.toStringAsFixed(2)}', secondaryText, secondaryText),
                                    const Divider(height: 14),
                                    _priceRow('Item Total', 'Rs. ${item.totalPrice.toStringAsFixed(2)}', primaryText, AppColors.warning, bold: true),
                                  ],
                                ),
                              ),
                            ] else if (item.status == ProposalItemStatus.unavailable) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, size: 14, color: AppColors.error),
                                  const SizedBox(width: 6),
                                  Text('Out of stock — not included in bid total.', style: AppTextStyles.caption(AppColors.error)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),

                  // Total Proposal Bid — below all item cards
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        _priceRow('Estimated Delivery', widget.proposal.estimatedDeliveryTime, secondaryText, primaryText),
                        const SizedBox(height: 10),
                        _priceRow('Delivery Charge', 'Rs. ${widget.proposal.deliveryCharge.toStringAsFixed(2)}', secondaryText, primaryText),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Proposal Bid', style: AppTextStyles.subtitle(primaryText)),
                            Text(
                              'Rs. ${widget.proposal.totalPrice.toStringAsFixed(2)}',
                              style: AppTextStyles.h1(AppColors.customerColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Controlled Communication Log
                  if (widget.proposal.customerResponse != null || widget.proposal.vendorResponse != null) ...[
                    Text('Predefined Response Log', style: AppTextStyles.h2(primaryText)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.proposal.customerResponse != null) ...[
                            Text('You: "${widget.proposal.customerResponse}"', style: AppTextStyles.bodyMedium(AppColors.customerColor)),
                            const SizedBox(height: 8),
                          ],
                          if (widget.proposal.vendorResponse != null)
                            Text('Shop Owner: "${widget.proposal.vendorResponse}"', style: AppTextStyles.bodyMedium(AppColors.vendorColor)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Suggested Predefined Responses (Controlled Communication)
                  if (widget.proposal.status == ProposalStatus.submitted ||
                      widget.proposal.status == ProposalStatus.updated) ...[
                    Text('Send Predefined Response', style: AppTextStyles.h2(primaryText)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _selectedControlledMsg,
                            hint: const Text('Select suggested response'),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: _suggestedMessages.map((msg) {
                              return DropdownMenuItem(
                                value: msg,
                                child: Text(msg, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedControlledMsg = val;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.customerColor),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: _selectedControlledMsg == null ? null : _sendSuggestedMessage,
                              icon: const Icon(Icons.send_rounded, size: 18),
                              label: const Text('Send Response Option'),
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ],
              ),
            ),
          ),

          // Accept / Reject Buttons
          if (widget.proposal.status == ProposalStatus.submitted ||
              widget.proposal.status == ProposalStatus.updated)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.error),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _showRejectDialog,
                          child: Text('Reject Bid', style: AppTextStyles.button(AppColors.error)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.customerColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: _handleAccept,
                          child: Text('Accept & Pay', style: AppTextStyles.button(Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildVendorImages(ProposalItem item, Color borderColor, Color secondaryText, BuildContext context) {
    final allUrls = [
      if (item.imageUrl != null && item.imageUrl!.trim().isNotEmpty) item.imageUrl!.trim(),
      ...item.vendorImageUrls.where((u) => u.trim().isNotEmpty),
    ];
    if (allUrls.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text('Shop Owner photos (${allUrls.length})', style: AppTextStyles.caption(secondaryText)),
        const SizedBox(height: 6),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: allUrls.length,
            itemBuilder: (context, index) {
              final url = allUrls[index];
              final isNetwork = url.startsWith('http://') || url.startsWith('https://');
              return Padding(
                padding: EdgeInsets.only(right: index < allUrls.length - 1 ? 8 : 0),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ImageGalleryViewer(imagePaths: allUrls, initialIndex: index),
                  )),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: isNetwork
                        ? Image.network(url, width: 80, height: 80, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imageFallback(borderColor))
                        : Image.file(File(url), width: 80, height: 80, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imageFallback(borderColor)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _buildItemChatMessage(ProposalItem item) {
    final statusLabel = item.status == ProposalItemStatus.available
        ? 'available'
        : item.status == ProposalItemStatus.alternative
            ? 'offered as an alternative'
            : 'marked unavailable';
    final buffer = StringBuffer();
    buffer.write('Hi, I wanted to discuss the item "${item.requestItemName}" (Qty: ${item.quantity}) which you have $statusLabel');
    if (item.status == ProposalItemStatus.alternative) {
      if (item.alternativeName != null && item.alternativeName!.isNotEmpty) {
        buffer.write('. The alternative offered is "${item.alternativeName}"');
        if (item.alternativeBrand != null && item.alternativeBrand!.isNotEmpty) {
          buffer.write(' (${item.alternativeBrand})');
        }
      }
    } else if (item.status == ProposalItemStatus.available) {
      buffer.write(' at Rs. ${item.price.toStringAsFixed(2)} per unit (Total: Rs. ${item.totalPrice.toStringAsFixed(2)})');
    }
    buffer.write('. Could you please provide more details?');
    return buffer.toString();
  }

  Widget _priceRow(String label, String value, Color labelColor, Color valueColor, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodySmall(labelColor)),
        Text(
          value,
          style: bold
              ? AppTextStyles.subtitle(valueColor)
              : AppTextStyles.bodyMedium(valueColor),
        ),
      ],
    );
  }

  Widget _imageFallback(Color borderColor) => Container(
        width: 80, height: 80,
        decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: const Icon(Icons.broken_image_outlined, color: Colors.white54),
      );

  Widget _buildItemAvailabilitySummary(
    Proposal proposal,
    Color cardColor,
    Color borderColor,
    Color primaryText,
    Color secondaryText,
  ) {
    int available = 0;
    int alternative = 0;
    int unavailable = 0;

    for (final item in proposal.items) {
      if (item.status == ProposalItemStatus.available) {
        available++;
      } else if (item.status == ProposalItemStatus.alternative) {
        alternative++;
      } else if (item.status == ProposalItemStatus.unavailable) {
        unavailable++;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.success,
            count: available,
            label: 'Available',
          ),
          _buildSummaryItem(
            icon: Icons.swap_horiz_rounded,
            color: AppColors.warning,
            count: alternative,
            label: 'Alternatives',
          ),
          _buildSummaryItem(
            icon: Icons.cancel_outlined,
            color: AppColors.error,
            count: unavailable,
            label: 'Unavailable',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required Color color,
    required int count,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: AppTextStyles.subtitle(color),
        ),
        Text(
          label,
          style: AppTextStyles.caption(color),
        ),
      ],
    );
  }
}

