import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_state_widgets.dart';
import '../../models/shopping_request.dart';
import '../../../proposals/providers/proposal_provider.dart';
import '../../../proposals/models/proposal.dart';

class RequestDetailsScreen extends ConsumerStatefulWidget {
  final ShoppingRequest request;

  const RequestDetailsScreen({super.key, required this.request});

  @override
  ConsumerState<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends ConsumerState<RequestDetailsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(proposalProvider.notifier).loadProposalsForRequest(widget.request.id);
    });
  }

  Color _getStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.draft:
        return Colors.grey;
      case RequestStatus.submitted:
      case RequestStatus.waitingForVendor:
        return AppColors.warning;
      case RequestStatus.vendorAccepted:
      case RequestStatus.proposalSubmitted:
        return AppColors.customerColor;
      case RequestStatus.customerAccepted:
      case RequestStatus.paid:
      case RequestStatus.cashOnDeliveryConfirmed:
      case RequestStatus.delivered:
        return AppColors.success;
      case RequestStatus.customerRejected:
      case RequestStatus.cancelled:
      case RequestStatus.expired:
        return AppColors.error;
      default:
        return AppColors.customerColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final statusColor = _getStatusColor(widget.request.status);
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final proposalState = ref.watch(proposalProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(widget.request.id),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Request Status Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.receipt_long_outlined,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Request Status',
                          style: AppTextStyles.bodySmall(secondaryText),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.request.status.displayName,
                          style: AppTextStyles.h3(statusColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Items Section Header
            Text(
              'Requested Items (${widget.request.items.length})',
              style: AppTextStyles.h2(primaryText),
            ),
            const SizedBox(height: 12),

            // Items List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.request.items.length,
              itemBuilder: (context, index) {
                final item = widget.request.items[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.customerColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          color: AppColors.customerColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: AppTextStyles.bodyLarge(primaryText),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Category: ${item.category ?? "General"}',
                              style: AppTextStyles.bodySmall(secondaryText),
                            ),
                            if (item.preferredBrand != null && item.preferredBrand!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Brand: ${item.preferredBrand}',
                                style: AppTextStyles.bodySmall(secondaryText),
                              ),
                            ],
                            if (item.description != null && item.description!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                item.description!,
                                style: AppTextStyles.bodyMedium(secondaryText),
                              ),
                            ],
                            if (item.imageUrls.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 48,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  shrinkWrap: true,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: item.imageUrls.length,
                                  itemBuilder: (context, idx) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: borderColor),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(7),
                                          child: Image.network(
                                            item.imageUrls[idx],
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 20),
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
                      Text(
                        'x${item.quantity}${item.unit != null && item.unit!.isNotEmpty ? " ${item.unit}" : ""}',
                        style: AppTextStyles.subtitle(primaryText).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Vendor Proposals Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Merchant Bids (${proposalState.proposals.length})',
                  style: AppTextStyles.h2(primaryText),
                ),
                if (proposalState.isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.customerColor),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (proposalState.proposals.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      size: 48,
                      color: AppColors.customerColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No Active Proposals Yet',
                      style: AppTextStyles.h3(primaryText),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Once nearby vendors respond to your request within 20km, their proposals will appear here.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium(secondaryText),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: proposalState.proposals.length,
                itemBuilder: (context, index) {
                  final proposal = proposalState.proposals[index];
                  
                  // Mask Vendor Name for Privacy Barrier Rule
                  final maskedVendorName = 'Partner Merchant #${proposal.vendorId.hashCode.toString().substring(0, 4)}';

                  final availableCount = proposal.items.where((i) => i.status == ProposalItemStatus.available).length;
                  final altCount = proposal.items.where((i) => i.status == ProposalItemStatus.alternative).length;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: InkWell(
                      onTap: () {
                        context.push('/customer/proposals/detail', extra: {
                          'proposal': proposal,
                          'requestId': widget.request.id,
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  maskedVendorName,
                                  style: AppTextStyles.subtitle(primaryText),
                                ),
                                StatusBadge(
                                  label: proposal.status.displayName,
                                  color: proposal.status == ProposalStatus.accepted
                                      ? AppColors.success
                                      : (proposal.status == ProposalStatus.rejected ? AppColors.error : AppColors.customerColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Delivery: ${proposal.estimatedDeliveryTime} | Delivery Fee: Rs. ${proposal.deliveryCharge.toStringAsFixed(0)}',
                              style: AppTextStyles.bodySmall(secondaryText),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Items: $availableCount available, $altCount alternatives.',
                              style: AppTextStyles.caption(secondaryText),
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Bid Price:',
                                  style: AppTextStyles.caption(secondaryText),
                                ),
                                Text(
                                  'Rs. ${proposal.totalPrice.toStringAsFixed(2)}',
                                  style: AppTextStyles.subtitle(AppColors.customerColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Tap to Review & Respond →',
                                style: AppTextStyles.caption(AppColors.customerColor).copyWith(fontWeight: FontWeight.bold),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
