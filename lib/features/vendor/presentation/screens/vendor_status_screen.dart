import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/models/vendor_status.dart';
import '../../../../core/guards/vendor_status_guard.dart';
import '../../../../features/auth/providers/auth_provider.dart';

/// Streams the vendor's Firestore doc so status changes are reflected in real-time.
final _vendorStatusStreamProvider = StreamProvider.family<DocumentSnapshot<Map<String, dynamic>>, String>(
  (ref, vendorId) => FirebaseFirestore.instance
      .collection('users/vendors/profiles')
      .doc(vendorId)
      .snapshots(),
);

class VendorStatusScreen extends ConsumerWidget {
  const VendorStatusScreen({
    super.key,
    required this.user,
  });

  final UserModel user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    // When blocked (pending, approved-but-unassigned), listen to Firestore in real-time
    // and refresh auth state on any change.
    if (VendorStatusGuard.shouldShowStatusScreen(user)) {
      ref.listen(_vendorStatusStreamProvider(user.id), (_, next) {
        next.whenData((snapshot) {
          if (!snapshot.exists) return;
          ref.read(authProvider.notifier).refreshVendorStatus();
        });
      });
    }

    final statusTitle = VendorStatusGuard.getStatusScreenTitle(user);
    final statusMessage = VendorStatusGuard.getBlockedReason(user);

    IconData statusIcon = Icons.pending_actions_outlined;
    Color statusColor = AppColors.warning;

    if (user.vendorStatus?.isRejected ?? false) {
      statusIcon = Icons.block_outlined;
      statusColor = AppColors.error;
    } else if (user.vendorStatus?.isSuspended ?? false) {
      statusIcon = Icons.warning_outlined;
      statusColor = AppColors.error;
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Section header
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Shop Owner Account',
                style: AppTextStyles.h2(primaryText),
              ),
            ),
            const SizedBox(height: 120),

            // Status Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                statusIcon,
                size: 64,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 24),

            // Status Title
            Text(
              statusTitle,
              style: AppTextStyles.h1(primaryText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Status Message
            Text(
              statusMessage,
              style: AppTextStyles.bodyMedium(secondaryText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Helper Text
            if (user.vendorStatus?.isPending ?? false) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.customerColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.customerColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What happens next?',
                      style: AppTextStyles.subtitle(primaryText),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Our admin team will review your shop details\n'
                      '• You\'ll be notified once your account is approved\n'
                      '• After approval, we\'ll assign your shop location\n'
                      '• Then you can start accepting customer requests',
                      style: AppTextStyles.bodySmall(secondaryText),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ] else if (user.vendorStatus?.isRejected ?? false) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  'If you believe this is an error, please contact our support team at support@speedmart.lk',
                  style: AppTextStyles.bodySmall(secondaryText),
                ),
              ),
              const SizedBox(height: 24),
            ] else if (user.vendorStatus?.isSuspended ?? false) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  'Please contact support@speedmart.lk for more information about your account status.',
                  style: AppTextStyles.bodySmall(secondaryText),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _launchSupport(context),
                icon: const Icon(Icons.mail_outline_rounded),
                label: const Text('Contact Support'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.customerColor,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _backToLogin(context, ref),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Back to Login'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchSupport(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Contact Support'),
        content: const Text(
          'This will open your mail app to send an email to support@speedmart.lk.\n\nDo you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.customerColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open Mail', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;
      final uri = Uri(
        scheme: 'mailto',
        path: 'support@speedmart.lk',
        queryParameters: {'subject': 'Shop Account Support'},
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No mail app found. Please email support@speedmart.lk directly.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _backToLogin(BuildContext context, WidgetRef ref) async {
    debugPrint('[VendorStatus] Back to login tapped');

    // Capture notifier before any await to avoid ref-after-dispose
    final authNotifier = ref.read(authProvider.notifier);

    // Call logout
    await authNotifier.logout();
    debugPrint('[VendorStatus] Session cleared');

    // Check if still mounted before navigation
    if (!context.mounted) {
      debugPrint('[VendorStatus] Context not mounted, skipping navigation');
      return;
    }

    debugPrint('[VendorStatus] Navigating to vendor login');
    context.go(RouteNames.vendorLogin);
  }
}

