import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;

  ChatState({
    required this.messages,
    this.isLoading = false,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier() : super(ChatState(messages: [])) {
    _seedInitialMessages();
  }

  void _seedInitialMessages() {
    // Seed some initial friendly chat logs between customer and vendor
    state = ChatState(messages: [
      ChatMessage(
        id: 'init-msg-1',
        proposalId: 'seed-proposal-id',
        senderRole: 'vendor',
        senderName: 'Partner Merchant #A3B1',
        text: 'Hi there! I have all your grocery items in stock, except the fresh milk. I have offered Kotmale pasteurized fresh milk as a replacement. Let me know if that is okay!',
        maskedText: 'Hi there! I have all your grocery items in stock, except the fresh milk. I have offered Kotmale pasteurized fresh milk as a replacement. Let me know if that is okay!',
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
      ChatMessage(
        id: 'init-msg-2',
        proposalId: 'seed-proposal-id',
        senderRole: 'customer',
        senderName: 'Customer',
        text: 'Yes, Kotmale fresh milk works perfectly for me. Thank you.',
        maskedText: 'Yes, Kotmale fresh milk works perfectly for me. Thank you.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
      ),
    ]);
  }

  // Regex utility to dynamically mask phone numbers, emails and suburb details
  String maskSensitiveDetails(String originalText) {
    String processed = originalText;

    // 1. Regex for phone numbers (matches 07XXXXXXXX, +94XXXXXXXX, with spaces or hyphens)
    final phoneRegex = RegExp(
      r'(\+?94\s?|0)([0-9\s-]{8,11})',
      caseSensitive: false,
    );

    // 2. Regex for email addresses
    final emailRegex = RegExp(
      r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
      caseSensitive: false,
    );

    // Replace matches
    processed = processed.replaceAllMapped(phoneRegex, (match) {
      // Validate length of numbers inside to avoid masking simple numbers
      final cleanDigits = match.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.length >= 8) {
        return '[PHONE DETAILS MASKED]';
      }
      return match.group(0)!;
    });

    processed = processed.replaceAll(emailRegex, '[EMAIL ADDRESS MASKED]');

    return processed;
  }

  // Send message method with real-time regex parsing
  Future<void> sendMessage({
    required String proposalId,
    required String senderRole,
    required String senderName,
    required String text,
  }) async {
    final masked = maskSensitiveDetails(text);

    final newMessage = ChatMessage(
      id: const Uuid().v4(),
      proposalId: proposalId,
      senderRole: senderRole,
      senderName: senderName,
      text: text,
      maskedText: masked,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(messages: [...state.messages, newMessage]);

    // Simulate merchant responding to customer after 2 seconds
    if (senderRole == 'customer') {
      Future.delayed(const Duration(seconds: 2), () {
        final String vendorReply;
        if (text.toLowerCase().contains('fresh') || text.toLowerCase().contains('brand')) {
          vendorReply = 'Yes, all products are fresh from Keells store, and packed today morning.';
        } else if (text.toLowerCase().contains('deliver') || text.toLowerCase().contains('when')) {
          vendorReply = 'We can deliver within 2 hours of payment confirmation. Our rider is ready.';
        } else {
          vendorReply = 'Thank you for your response! Looking forward to serving you through Speedmart.';
        }

        final vendorMsg = ChatMessage(
          id: const Uuid().v4(),
          proposalId: proposalId,
          senderRole: 'vendor',
          senderName: 'Partner Merchant #A3B1',
          text: vendorReply,
          maskedText: maskSensitiveDetails(vendorReply),
          timestamp: DateTime.now(),
        );

        state = state.copyWith(messages: [...state.messages, vendorMsg]);
      });
    }
  }

  List<ChatMessage> getMessagesForProposal(String proposalId) {
    return state.messages.where((m) => m.proposalId == proposalId || m.proposalId == 'seed-proposal-id').toList();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});
