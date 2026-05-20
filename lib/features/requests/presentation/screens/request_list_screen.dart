import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_state_widgets.dart';
import '../../models/shopping_request.dart';
import '../../providers/request_provider.dart';
import 'request_details_screen.dart';

class RequestListScreen extends ConsumerWidget {
  const RequestListScreen({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final requestState = ref.watch(requestProvider);

    if (requestState.isLoading && requestState.requests.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (requestState.requests.isEmpty) {
      return Scaffold(
        body: AppEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No Requests Yet',
          subtitle: 'Create a request to see your shopping lists here.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: RefreshIndicator(
        onRefresh: () => ref.read(requestProvider.notifier).loadMyRequests(),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requestState.requests.length,
          itemBuilder: (context, index) {
            final request = requestState.requests[index];
            final statusColor = _getStatusColor(request.status);
            
            return Card(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (context) => RequestDetailsScreen(request: request),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            request.id,
                            style: AppTextStyles.h3(primaryText),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: statusColor.withOpacity(0.5)),
                            ),
                            child: Text(
                              request.status.displayName,
                              style: AppTextStyles.labelMedium(statusColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Items: ${request.items.map((i) => i.name).join(", ")}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium(primaryText),
                      ),
                      const SizedBox(height: 16),
                      Divider(color: isDark ? AppColors.borderDark : AppColors.borderLight, height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Created: ${_formatDate(request.createdAt)}',
                            style: AppTextStyles.bodySmall(secondaryText),
                          ),
                          Row(
                            children: [
                              Text(
                                'View Details',
                                style: AppTextStyles.button(AppColors.customerColor),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.customerColor,
                                size: 16,
                              )
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
