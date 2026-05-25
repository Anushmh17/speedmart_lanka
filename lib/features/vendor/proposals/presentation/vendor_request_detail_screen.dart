import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_state_widgets.dart';
import '../../../customer/delivery_address/utils/vendor_delivery_privacy.dart';
import '../../../proposals/models/proposal.dart';
import '../../../proposals/providers/proposal_provider.dart';
import '../../../requests/models/shopping_request.dart';
import '../../request_feed/models/vendor_feed_enums.dart';
import '../widgets/vendor_proposal_status_chip.dart';

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

  Future<void> _load() async {
    final p = await ref
        .read(proposalProvider.notifier)
        .loadVendorProposalForRequest(widget.request.id);
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.vendorColor,
                          AppColors.vendorColorDark,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
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
                        const SizedBox(height: 8),
                        Text(
                          'Exact address and phone unlock after customer accepts your bid.',
                          style: AppTextStyles.caption(Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusBadge(
                        label: request.status.displayName,
                        color: AppColors.vendorColor,
                      ),
                      StatusBadge(
                        label: urgency.label,
                        color: urgency == RequestUrgency.high
                            ? AppColors.error
                            : AppColors.vendorColor,
                      ),
                      StatusBadge(
                        label: '${request.items.length} items',
                        color: AppColors.vendorColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Requested items', style: AppTextStyles.h2(primaryText)),
                  const SizedBox(height: 10),
                  ...request.items.map((item) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: AppTextStyles.subtitle(primaryText)),
                          const SizedBox(height: 4),
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
                        ],
                      ),
                    );
                  }),
                  if (_existingProposal != null) ...[
                    const SizedBox(height: 20),
                    Text('Your proposal', style: AppTextStyles.h2(primaryText)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
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
                              VendorProposalStatusChip(
                                status: _existingProposal!.status,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_existingProposal != null &&
                        _existingProposal!.canEdit)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            context.push(
                              '/vendor/proposals/edit',
                              extra: {
                                'request': request,
                                'proposal': _existingProposal,
                              },
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.vendorColor,
                            side: const BorderSide(color: AppColors.vendorColor),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Edit proposal'),
                        ),
                      ),
                    if (_existingProposal != null) ...[
                      const SizedBox(height: 8),
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
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.vendorColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
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
}
