import 'package:flutter/material.dart';

class ChatMessageWidget extends StatelessWidget {
  final String text;
  final bool isFromUser;

  const ChatMessageWidget({
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