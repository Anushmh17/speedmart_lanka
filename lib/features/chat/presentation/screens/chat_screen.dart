import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.proposalId,
    required this.vendorName,
    required this.isUnlocked,
  });

  final String proposalId;
  final String vendorName;
  final bool isUnlocked;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  final List<String> _quickSuggestions = [
    'Is the Keells fresh milk in stock?',
    'When will the rider deliver to Colombo 05?',
    'Is the alternative product high quality?',
    'Can we adjust the price details?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage([String? customText]) {
    final text = customText ?? _controller.text.trim();
    if (text.isEmpty) return;

    ref.read(chatProvider.notifier).sendMessage(
          proposalId: widget.proposalId,
          senderRole: 'customer',
          senderName: 'Customer',
          text: text,
        );

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

    final messages = ref.read(chatProvider.notifier).getMessagesForProposal(widget.proposalId);

    // If order is pre-payment/not unlocked, mask real name to protect merchant
    final displayName = widget.isUnlocked ? widget.vendorName : 'Partner Merchant #A3B1';

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.customerColor.withOpacity(0.12),
              child: const Icon(Icons.storefront_rounded, color: AppColors.customerColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, style: AppTextStyles.subtitle(primaryText)),
                  Text(
                    widget.isUnlocked ? '● Open Chat Channel' : '🔒 Secure Shield Active',
                    style: AppTextStyles.caption(widget.isUnlocked ? AppColors.success : AppColors.warning),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: surfaceColor,
      ),
      body: Column(
        children: [
          // Security Shield warning / unlock banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isUnlocked
                  ? AppColors.success.withOpacity(0.08)
                  : AppColors.warning.withOpacity(0.08),
              border: Border(
                bottom: BorderSide(
                  color: widget.isUnlocked
                      ? AppColors.success.withOpacity(0.2)
                      : AppColors.warning.withOpacity(0.2),
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
                const SizedBox(width: 10),
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
          ),

          // Messages bubble list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
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
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: bubbleColor,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isMe ? 16 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 16),
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
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
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
                        Text(
                          '${message.senderName} • ${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                          style: AppTextStyles.caption(secondaryText),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Pre-defined quick suggestions
          if (!widget.isUnlocked) ...[
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: surfaceColor,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _quickSuggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _quickSuggestions[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      backgroundColor: cardColor,
                      side: BorderSide(color: borderColor),
                      label: Text(suggestion, style: AppTextStyles.caption(AppColors.customerColor).copyWith(fontWeight: FontWeight.bold)),
                      onPressed: () => _sendMessage(suggestion),
                    ),
                  );
                },
              ),
            ),
          ],

          // Input bar
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      style: AppTextStyles.bodyMedium(primaryText),
                      decoration: InputDecoration(
                        hintText: 'Discuss availability, prices...',
                        hintStyle: TextStyle(color: secondaryText, fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.customerColor,
                    shape: const CircleBorder(),
                  ),
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  onPressed: () => _sendMessage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
