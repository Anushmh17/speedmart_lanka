import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../../auth/providers/auth_provider.dart';

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
  final Ref ref;
  StreamSubscription? _sub;

  ChatNotifier(this.ref) : super(ChatState(messages: [])) {
    _init();
  }

  void _init() {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    _sub = FirebaseFirestore.instance
        .collection('chat_messages')
        .where('participants', arrayContains: user.id)
        .orderBy('timestamp')
        .snapshots()
        .listen((snap) {
      final msgs = snap.docs.map((d) => ChatMessage.fromJson(d.data(), d.id)).toList();
      state = state.copyWith(messages: msgs);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
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

    final proposalDoc = await FirebaseFirestore.instance.collection('proposals').doc(proposalId).get();
    final proposalData = proposalDoc.data();
    if (proposalData == null) return;

    final customerId = proposalData['customerId'] as String;
    final vendorId = proposalData['vendorId'] as String;

    final messageData = {
      'proposalId': proposalId,
      'senderRole': senderRole,
      'senderName': senderName,
      'text': text,
      'maskedText': masked,
      'timestamp': FieldValue.serverTimestamp(),
      'isSystemMessage': false,
      'participants': [customerId, vendorId],
    };

    await FirebaseFirestore.instance.collection('chat_messages').add(messageData);
  }

  List<ChatMessage> getMessagesForProposal(String proposalId) {
    return state.messages.where((m) => m.proposalId == proposalId).toList();
  }

  /// Returns number of conversations where the last message is from the vendor,
  /// which we treat as an unread conversation for the customer.
  int unreadConversationsCount() {
    final Map<String, List<ChatMessage>> grouped = {};
    for (final m in state.messages) {
      grouped.putIfAbsent(m.proposalId, () => []).add(m);
    }

    int count = 0;
    for (final entry in grouped.entries) {
      final last = entry.value.isNotEmpty ? entry.value.last : null;
      if (last != null && last.senderRole == 'vendor') {
        count++;
      }
    }
    return count;
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});

