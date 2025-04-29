import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:suicide_hotline_app/services/therapist_service.dart';

class TalkToTherapistScreen extends StatefulWidget {
  const TalkToTherapistScreen({Key? key}) : super(key: key);

  @override
  State<TalkToTherapistScreen> createState() => _TalkToTherapistScreenState();
}

class _TalkToTherapistScreenState extends State<TalkToTherapistScreen> {
  final TherapistService _therapistService = TherapistService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _conversations = [];
  Map<String, dynamic>? _pendingRequest;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load conversations
      final conversations = await _therapistService.getUserConversations();
      
      // Check pending request
      final pendingRequest = await _getPendingRequest();

      if (mounted) {
        setState(() {
          _conversations = conversations;
          _pendingRequest = pendingRequest;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading therapist data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _getPendingRequest() async {
    try {
      final user = FirebaseFirestore.instance.collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid);
          
      final requestSnapshot = await FirebaseFirestore.instance
          .collection('therapist_requests')
          .where('clientId', isEqualTo: user.id)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (requestSnapshot.docs.isEmpty) {
        return null;
      }

      final request = requestSnapshot.docs.first;
      final therapistDoc = await FirebaseFirestore.instance
          .collection('therapists')
          .doc(request.get('therapistId'))
          .get();

      return {
        'id': request.id,
        'therapistId': request.get('therapistId'),
        'therapistName': therapistDoc.get('name') ?? 'Unknown',
        'therapistPhoto': therapistDoc.get('photoUrl'),
        'message': request.get('message') ?? '',
        'createdAt': request.get('createdAt') ?? Timestamp.now(),
      };
    } catch (e) {
      print('Error getting pending request: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Talk to Therapist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _therapistService.showTherapistSelectionDialog(context);
        },
        child: const Icon(Icons.add),
        tooltip: 'Connect with a new therapist',
      ),
    );
  }

  Widget _buildBody() {
    if (_conversations.isEmpty && _pendingRequest == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No therapist conversations yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Connect with a therapist to start a conversation',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _therapistService.showTherapistSelectionDialog(context);
              },
              icon: const Icon(Icons.add),
              label: const Text('Connect with a Therapist'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_pendingRequest != null) _buildPendingRequestCard(),
        if (_pendingRequest != null && _conversations.isNotEmpty) 
          const SizedBox(height: 20),
        if (_conversations.isNotEmpty) 
          const Text(
            'Your Conversations',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        if (_conversations.isNotEmpty) 
          const SizedBox(height: 12),
        ..._conversations.map((conversation) => _buildConversationCard(conversation)),
      ],
    );
  }

  Widget _buildPendingRequestCard() {
    final request = _pendingRequest!;
    final createdAt = request['createdAt'] as Timestamp;
    final formattedDate = DateFormat.yMMMd().add_jm().format(createdAt.toDate());

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: request['therapistPhoto'] != null
                      ? NetworkImage(request['therapistPhoto'])
                      : null,
                  child: request['therapistPhoto'] == null
                      ? Text(request['therapistName'].substring(0, 1))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['therapistName'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Request sent on $formattedDate',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pending, size: 14, color: Colors.amber[800]),
                      const SizedBox(width: 4),
                      Text(
                        'Pending',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Your message:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              request['message'],
              style: const TextStyle(fontSize: 14),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Waiting for therapist response...',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    // Show confirmation dialog
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Cancel Request?'),
                        content: const Text(
                            'Are you sure you want to cancel this request?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('No'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Yes'),
                          ),
                        ],
                      ),
                    );

                    if (result == true) {
                      try {
                        await FirebaseFirestore.instance
                            .collection('therapist_requests')
                            .doc(request['id'])
                            .update({'status': 'cancelled'});
                        
                        // Refresh data
                        if (mounted) {
                          _loadData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Request cancelled successfully'),
                            ),
                          );
                        }
                      } catch (e) {
                        print('Error cancelling request: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to cancel request'),
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Cancel Request'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationCard(Map<String, dynamic> conversation) {
    final updatedAt = conversation['updatedAt'] as Timestamp;
    final formattedDate = DateFormat.MMMd().add_jm().format(updatedAt.toDate());
    final hasUnread = (conversation['unreadCount'] as int) > 0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/client_chat',
            arguments: {
              'conversationId': conversation['id'],
              'therapistId': conversation['therapistId'],
              'therapistName': conversation['therapistName'],
            },
          ).then((_) => _loadData());
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundImage: conversation['therapistPhoto'] != null
                    ? NetworkImage(conversation['therapistPhoto'])
                    : null,
                child: conversation['therapistPhoto'] == null
                    ? Text(conversation['therapistName'].substring(0, 1))
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          conversation['therapistName'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      conversation['lastMessage'],
                      style: TextStyle(
                        fontSize: 14,
                        color: hasUnread ? Colors.black : Colors.grey[600],
                        fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (hasUnread)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue,
                  ),
                  child: Text(
                    conversation['unreadCount'].toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart'; 