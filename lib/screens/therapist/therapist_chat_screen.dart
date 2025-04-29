import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/therapist_service.dart';

class TherapistChatScreen extends StatefulWidget {
  final String conversationId;
  final String clientId;
  final String clientName;
  final bool isTherapistMode;

  const TherapistChatScreen({
    Key? key,
    required this.conversationId,
    required this.clientId,
    required this.clientName,
    this.isTherapistMode = false,
  }) : super(key: key);

  @override
  State<TherapistChatScreen> createState() => _TherapistChatScreenState();
}

class _TherapistChatScreenState extends State<TherapistChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TherapistService _therapistService = TherapistService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String _userId = '';
  bool _isOnline = false;
  Timestamp? _lastSeen;
  bool _isSending = false;
  List<String> _quickResponses = [
    'How are you feeling today?',
    'Can you tell me more about that?',
    'That sounds challenging.',
    'I understand how you feel.',
    'What would help you right now?',
  ];
  
  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid ?? '';
    _markMessagesAsRead();
    _loadClientStatus();
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
  
  Future<void> _loadClientStatus() async {
    try {
      // Get client's online status
      final userDoc = await _firestore.collection('users').doc(widget.clientId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _isOnline = userData['isOnline'] ?? false;
          _lastSeen = userData['lastActive'] as Timestamp?;
        });
      }
    } catch (e) {
      print('Error loading client status: $e');
    }
  }
  
  Future<void> _markMessagesAsRead() async {
    try {
      // Update conversation unread count
      await _firestore.collection('chats').doc(widget.conversationId).update({
        'therapistUnreadCount': 0,
      });
      
      // Mark all messages as read
      final messagesRef = _firestore
          .collection('chats')
          .doc(widget.conversationId)
          .collection('messages')
          .where('senderRole', isEqualTo: 'client')
          .where('isRead', isEqualTo: false);
      
      final unreadMessages = await messagesRef.get();
      
      for (var doc in unreadMessages.docs) {
        await _firestore
            .collection('chats')
            .doc(widget.conversationId)
            .collection('messages')
            .doc(doc.id)
            .update({
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }
  
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    setState(() {
      _isSending = true;
    });
    
    _messageController.clear();
    
    try {
      // Determine sender role based on the current mode
      final String senderRole = widget.isTherapistMode ? 'therapist' : 'client';
      
      // Get current user or use anonymous ID
      final user = _auth.currentUser;
      final String senderName = user?.displayName ?? 
                               (widget.isTherapistMode ? 'Therapist' : 'Anonymous User');
      final String senderId = user?.uid ?? 'anonymous-${DateTime.now().millisecondsSinceEpoch}';
      
      // Create a document with the current timestamp for sorting
      final timestamp = Timestamp.now();
      
      // Add message to Firestore with consistent structure
      await _firestore.collection('chats')
          .doc(widget.conversationId)
          .collection('messages')
          .add({
        'text': text,
        'senderRole': senderRole, // Use a consistent role field
        'senderName': senderName, // Add sender name for display
        'senderId': senderId, // Add sender ID for reference
        'timestamp': timestamp,
        'isRead': false,
      });
      
      // Update conversation last message
      await _firestore.collection('chats').doc(widget.conversationId).set({
        'lastMessage': text,
        'lastMessageTime': timestamp,
        'lastSenderRole': senderRole,
        'lastSenderName': senderName,
        'updatedAt': timestamp,
      }, SetOptions(merge: true));
      
      // Scroll to bottom
      _scrollToBottom();
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }
  
  void _sendQuickResponse(String text) {
    _messageController.text = text;
    _sendMessage();
  }
  
  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime messageDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDay == today) {
      return 'Today at ${_formatTimeOnly(dateTime)}';
    } else if (messageDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday at ${_formatTimeOnly(dateTime)}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${_formatTimeOnly(dateTime)}';
    }
  }

  String _formatTimeOnly(DateTime dateTime) {
    final String hour = dateTime.hour.toString().padLeft(2, '0');
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  
  String _formatLastSeen() {
    if (_isOnline) return 'Online';
    if (_lastSeen == null) return 'Last seen: Unknown';
    
    final now = DateTime.now();
    final lastSeen = _lastSeen!.toDate();
    final diff = now.difference(lastSeen);
    
    if (diff.inMinutes < 1) {
      return 'Last seen just now';
    } else if (diff.inHours < 1) {
      return 'Last seen ${diff.inMinutes} min ago';
    } else if (diff.inDays < 1) {
      return 'Last seen ${diff.inHours} hours ago';
    } else if (diff.inDays < 7) {
      return 'Last seen ${diff.inDays} days ago';
    } else {
      return 'Last seen on ${DateFormat('MMM d').format(lastSeen)}';
    }
  }
  
  Future<void> _showChatOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.note_alt),
              title: const Text('Session Notes'),
              onTap: () {
                Navigator.pop(context);
                // Add session notes feature in future versions
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Session Notes feature coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.psychology),
              title: const Text('Mental Health Assessment'),
              onTap: () {
                Navigator.pop(context);
                // Add assessment feature in future versions
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Assessment feature coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Client Information'),
              onTap: () {
                Navigator.pop(context);
                // Show client information in future versions
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Client Information feature coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.isTherapistMode ? 'Therapist Mode' : widget.clientName),
            if (!widget.isTherapistMode) 
              Text(
                'Licensed Counselor',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.8),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Video call feature coming soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showChatOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.conversationId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send a message to start the conversation',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!.docs;
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData = messages[index].data() as Map<String, dynamic>;
                    final message = messageData['text'] as String? ?? 'No message content';
                    
                    return _buildMessageBubble(message, messageData);
                  },
                );
              },
            ),
          ),
          // Message input field
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, Map<String, dynamic> messageData) {
    // Determine if message is from current user based on role and mode
    final String currentUserRole = widget.isTherapistMode ? 'therapist' : 'client';
    final bool isFromCurrentUser = messageData['senderRole'] == currentUserRole && 
                                  messageData['senderId'] == _userId;
    
    // Determine colors based on sender role
    final Color bubbleColor = isFromCurrentUser
        ? Theme.of(context).colorScheme.primary.withOpacity(0.8)
        : messageData['senderRole'] == 'therapist' 
            ? Colors.green[300]! 
            : Colors.grey[300]!;
    
    final Color textColor = isFromCurrentUser || messageData['senderRole'] == 'therapist'
        ? Colors.white
        : Colors.black87;
        
    // Get sender name for display
    final String senderName = messageData['senderName'] ?? 
                             (isFromCurrentUser ? 'You' : 
                              messageData['senderRole'] == 'therapist' ? 'Therapist' : 'Client');
    
    return Column(
      crossAxisAlignment: isFromCurrentUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, right: 8, bottom: 2),
          child: Text(
            senderName,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: isFromCurrentUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isFromCurrentUser)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: isFromCurrentUser
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[400],
                  child: Icon(
                    isFromCurrentUser ? Icons.person : Icons.face,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: TextStyle(color: textColor),
                    ),
                  ],
                ),
              ),
            ),
            if (isFromCurrentUser)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: isFromCurrentUser
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[400],
                  child: Icon(
                    isFromCurrentUser ? Icons.person : Icons.face,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(
            left: isFromCurrentUser ? 0 : 28,
            right: isFromCurrentUser ? 28 : 0,
            bottom: 8,
          ),
          child: Text(
            _formatTimestamp(messageData['timestamp'] as Timestamp? ?? Timestamp.now()),
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
        ),
      ],
    );
  }
}