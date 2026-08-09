import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../providers/chat_provider.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatProvider);
    final messages = state.messages;

    // Group by proposalId to create conversation entries
    final Map<String, List> grouped = {};
    for (final m in messages) {
      grouped.putIfAbsent(m.proposalId, () => []).add(m);
    }

    final convoEntries = grouped.entries.toList()
      ..sort((a, b) {
        final aTs = (a.value.last as dynamic).timestamp as DateTime;
        final bTs = (b.value.last as dynamic).timestamp as DateTime;
        return bTs.compareTo(aTs);
      });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : Colors.black;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: surfaceColor,
        foregroundColor: primaryText,
        elevation: 1,
      ),
      body: convoEntries.isEmpty
          ? SafeArea(
              child: Align(
                alignment: const Alignment(0, -0.2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  Icon(Icons.chat_bubble_outline, size: 72, color: AppColors.primary.withOpacity(0.9)),
                  SizedBox(height: AppSpacing.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      "Once you start a new conversation with a seller about a product, you'll see it listed here.",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium(secondaryText),
                    ),
                  ),
                  SizedBox(height: AppSpacing.xl * 2),
                  ElevatedButton(
                    onPressed: () => context.go(RouteNames.customerHome),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      backgroundColor: AppColors.primary,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('Start Shopping', style: AppTextStyles.bodyMedium(Colors.white)),
                  ),
                ],
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.all(AppSpacing.md),
              itemCount: convoEntries.length,
              separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final entry = convoEntries[index];
                final proposalId = entry.key;
                final lastMsg = entry.value.last as dynamic;
                final vendorName = (entry.value.first as dynamic).senderRole == 'vendor'
                    ? (entry.value.first as dynamic).senderName
                    : lastMsg.senderName;

                return ListTile(
                  onTap: () {
                    context.push('/chat', extra: {
                      'proposalId': proposalId,
                      'vendorName': vendorName ?? 'Partner Shop Owner',
                      'isUnlocked': false,
                    });
                  },
                  leading: CircleAvatar(child: Icon(Icons.storefront_rounded, color: AppColors.customerColor)),
                  title: Text(vendorName ?? 'Shop', style: AppTextStyles.bodyMedium(primaryText)),
                  subtitle: Text((lastMsg.text ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text(
                    '${(lastMsg.timestamp as DateTime).hour.toString().padLeft(2, '0')}:${(lastMsg.timestamp as DateTime).minute.toString().padLeft(2, '0')}',
                    style: AppTextStyles.caption(secondaryText),
                  ),
                );
              },
            ),
    );
  }
}
