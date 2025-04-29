import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../models/chat_message_widget.dart';
import '../services/ai_service.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({Key? key}) : super(key: key);

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessageWidget> _messages = [];
  bool _isTyping = false;
  bool _isInitializing = true;
  
  @override
  void initState() {
    super.initState();
    _initializeAIService();
  }
  
  Future<void> _initializeAIService() async {
    setState(() {
      _isInitializing = true;
    });
    
    try {
      await AIService.initialize();
    } catch (e) {
      debugPrint('Error initializing AI service: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing AI model: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    AIService.dispose();
    super.dispose();
  }
  
  void _sendMessage() async {
    if (_messageController.text.trim().isNotEmpty) {
      final message = _messageController.text;
      setState(() {
        _messages.add(ChatMessageWidget(
          text: message,
          isFromUser: true,
        ));
        _isTyping = true;
      });
      
      _messageController.clear();
      
      try {
        final response = await AIService.getChatResponse(message);
        
        if (mounted) {
          setState(() {
            _messages.add(ChatMessageWidget(
              text: response.replaceAll('\n', '\n\n'),
              isFromUser: false,
            ));
            _isTyping = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _messages.add(ChatMessageWidget(
              text: "I'm sorry, I couldn't process your message right now. If you're in crisis, please call 108 for immediate help.",
              isFromUser: false,
            ));
            _isTyping = false;
          });
        }
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Therapist Chat'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isInitializing 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Initializing AI Therapist...',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Loading AI model...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Colors.indigo.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'How are you feeling today?',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Chat with our AI Therapist powered by DeepSeek. Share your feelings and get supportive responses. In a crisis, always call 108 for immediate help.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return _messages[index];
                        },
                      ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.indigo.shade700,
                    child: const Icon(Icons.support_agent, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text('AI is typing...'),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Colors.indigo,
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 