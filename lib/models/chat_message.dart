import 'package:flutter/material.dart';

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isFromUser;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isFromUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isFromUser) 
            CircleAvatar(
              backgroundColor: Colors.indigo.shade700,
              child: const Icon(Icons.support_agent, color: Colors.white),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isFromUser ? Colors.indigo.shade100 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isFromUser ? Colors.indigo.shade800 : Colors.black87,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isFromUser)
            CircleAvatar(
              backgroundColor: Colors.indigo.shade400,
              child: const Icon(Icons.person, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

class ChatMessageModel {
  final String id;
  final String text;
  final int timestamp;
  final String senderType; // 'client' or 'therapist'
  final bool isRead;
  final Map<String, dynamic>? metadata;

  ChatMessageModel({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.senderType,
    this.isRead = false,
    this.metadata,
  });

  factory ChatMessageModel.fromMap(Map<String, dynamic> map, String docId) {
    return ChatMessageModel(
      id: docId,
      text: map['text'] ?? '',
      timestamp: map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      senderType: map['senderType'] ?? 'client',
      isRead: map['isRead'] ?? false,
      metadata: map['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'timestamp': timestamp,
      'senderType': senderType,
      'isRead': isRead,
      'metadata': metadata,
    };
  }

  ChatMessageModel copyWith({
    String? id,
    String? text,
    int? timestamp,
    String? senderType,
    bool? isRead,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      senderType: senderType ?? this.senderType,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
    );
  }
} 