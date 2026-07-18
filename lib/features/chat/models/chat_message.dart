import 'package:uuid/uuid.dart';

class ChatMessage {
  final String id;
  final String proposalId;
  final String senderRole; // 'customer' or 'vendor' or 'system'
  final String senderName;
  final String text;
  final String maskedText;
  final DateTime timestamp;
  final bool isSystemMessage;

  ChatMessage({
    required this.id,
    required this.proposalId,
    required this.senderRole,
    required this.senderName,
    required this.text,
    required this.maskedText,
    required this.timestamp,
    this.isSystemMessage = false,
  });

  factory ChatMessage.system({
    required String proposalId,
    required String text,
  }) {
    return ChatMessage(
      id: const Uuid().v4(),
      proposalId: proposalId,
      senderRole: 'system',
      senderName: 'Speedmart System',
      text: text,
      maskedText: text,
      timestamp: DateTime.now(),
      isSystemMessage: true,
    );
  }
}

