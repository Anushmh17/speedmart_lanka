import 'package:cloud_firestore/cloud_firestore.dart';
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

  factory ChatMessage.fromJson(Map<String, dynamic> json, String documentId) {
    return ChatMessage(
      id: documentId,
      proposalId: json['proposalId'] as String? ?? '',
      senderRole: json['senderRole'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      text: json['text'] as String? ?? '',
      maskedText: json['maskedText'] as String? ?? '',
      timestamp: json['timestamp'] != null 
          ? (json['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
      isSystemMessage: json['isSystemMessage'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'proposalId': proposalId,
      'senderRole': senderRole,
      'senderName': senderName,
      'text': text,
      'maskedText': maskedText,
      'timestamp': Timestamp.fromDate(timestamp),
      'isSystemMessage': isSystemMessage,
    };
  }
}

