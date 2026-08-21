import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../providers/chat_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../shared/models/user_role.dart';
import 'package:speedmart_lanka/core/utils/error_translator.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.proposalId,
    required this.vendorName,
    required this.isUnlocked,
    this.autoMessage,
  });

  final String proposalId;
  final String vendorName;
  final bool isUnlocked;
  final String? autoMessage;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();


  @override
  void initState() {
    super.initState();
    if (widget.autoMessage != null) {
      _controller.text = widget.autoMessage!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? customText]) async {
    final text = customText ?? _controller.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider);
    final senderRole = user?.role == UserRole.vendor ? 'vendor' : 'customer';
    final senderName = user?.fullName ?? (senderRole == 'vendor' ? 'Vendor' : 'Customer');

    try {
      await ref.read(chatProvider.notifier).sendMessage(
            proposalId: widget.proposalId,
            senderRole: senderRole,
            senderName: senderName,
            text: text,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorTranslator.friendly(e)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (customText == null) {
      _controller.clear();
    }

    // Scroll to end
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : Colors.black;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    // Use ref.watch so the list rebuilds whenever new messages arrive
    final messages = ref.watch(chatProvider).messages
        .where((m) => m.proposalId == widget.proposalId)
        .toList();
        
    // Mark messages as read automatically when viewing them
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(chatProvider.notifier).markMessagesAsRead(widget.proposalId);
      }
    });

    // The caller is expected to pass the correctly masked name (e.g. Verified Partner #ID) when locked
    final displayName = widget.vendorName;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _buildHeader(context, isDark, primaryText, secondaryText, displayName),
          _buildSecurityBanner(isDark, primaryText),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(AppSpacing.md),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isMe = message.senderRole == 'customer';
                final bubbleColor = isMe
                    ? AppColors.customerColor
                    : (isDark ? Colors.grey[850] : Colors.grey[200]);
                final textColor = isMe ? Colors.white : primaryText;

                // Choose between original and masked text based on checkout status
                final displayMessageText = widget.isUnlocked ? message.text : message.maskedText;

                // Detect if the message was redacted/masked to show visual helper
                final wasRedacted = !widget.isUnlocked && message.maskedText != message.text;

                return Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: bubbleColor,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(AppRadius.lg),
                              topRight: Radius.circular(AppRadius.lg),
                              bottomLeft: Radius.circular(isMe ? AppRadius.lg : AppRadius.xs),
                              bottomRight: Radius.circular(isMe ? AppRadius.xs : AppRadius.lg),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayMessageText,
                                style: AppTextStyles.bodyMedium(textColor),
                              ),
                              if (wasRedacted) ...[
                                SizedBox(height: AppSpacing.xs),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(AppRadius.xs),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 10),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Sensitive contact details redacted',
                                        style: AppTextStyles.caption(Colors.red).copyWith(fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                              style: AppTextStyles.caption(secondaryText),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                message.isPending
                                    ? Icons.schedule_rounded
                                    : (message.isRead ? Icons.done_all_rounded : Icons.check_rounded),
                                size: 14,
                                color: (message.isRead && !message.isPending) 
                                    ? (isDark ? AppColors.primary : AppColors.customerColor) 
                                    : secondaryText,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),



          // Input bar
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 10,
              bottom: 12,
            ),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: isDark ? Colors.grey[900] : Colors.grey[100],
                      elevation: isDark ? 0 : 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                maxLines: null,
                                style: AppTextStyles.bodyMedium(primaryText),
                                decoration: InputDecoration(
                                  hintText: 'Discuss availability, prices...',
                                  hintStyle: TextStyle(color: secondaryText, fontSize: 14),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                  // Prevent global InputDecorationTheme from painting a filled white box
                                  filled: false,
                                  fillColor: Colors.transparent,
                                ),
                                cursorColor: AppColors.customerColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Material(
                    color: AppColors.customerColor,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: IconButton(
                      onPressed: () => _sendMessage(),
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, Color primaryText, Color secondaryText, String displayName) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        MediaQuery.of(context).padding.top + AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.borderLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.15) : AppColors.borderLight,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.pop(),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: primaryText,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.customerColor.withValues(alpha: 0.12),
            child: Icon(Icons.storefront_rounded, color: AppColors.customerColor, size: 20),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: AppTextStyles.h3(primaryText),
                ),
                SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: widget.isUnlocked ? AppColors.success : AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: AppSpacing.xs),
                    Text(
                      widget.isUnlocked ? 'Open Channel' : 'Secure Shield',
                      style: AppTextStyles.bodySmall(
                        widget.isUnlocked ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // View proposal/order shortcut
          GestureDetector(
            onTap: () => context.push('/customer/proposals/${widget.proposalId}'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.customerColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.customerColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isUnlocked
                        ? Icons.local_shipping_rounded
                        : Icons.receipt_long_rounded,
                    color: AppColors.customerColor,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.isUnlocked ? 'Order' : 'Proposal',
                    style: AppTextStyles.caption(AppColors.customerColor)
                        .copyWith(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityBanner(bool isDark, Color primaryText) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: widget.isUnlocked
            ? AppColors.success.withValues(alpha: 0.08)
            : AppColors.warning.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(
            color: widget.isUnlocked
                ? AppColors.success.withValues(alpha: 0.2)
                : AppColors.warning.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            widget.isUnlocked ? Icons.shield_rounded : Icons.shield_outlined,
            color: widget.isUnlocked ? AppColors.success : AppColors.warning,
            size: 18,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              widget.isUnlocked
                  ? 'Order Confirmed! Platform safety filters have been lifted. You can communicate openly.'
                  : 'Security Shield Active: Phone numbers and private links are automatically masked to prevent platform bypass and protect your billing dispute rights.',
              style: AppTextStyles.bodySmall(primaryText).copyWith(height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

