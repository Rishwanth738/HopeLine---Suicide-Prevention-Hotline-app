import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/therapist.dart';
import '../services/therapist_service.dart';
import '../widgets/empty_state.dart';
// import 'chat/therapist_chat_screen.dart';

class TherapistListScreen extends StatefulWidget {
  const TherapistListScreen({Key? key}) : super(key: key);

  @override
  State<TherapistListScreen> createState() => _TherapistListScreenState();
}

class _TherapistListScreenState extends State<TherapistListScreen> {
  final TherapistService _therapistService = TherapistService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String? _searchQuery;
  String _selectedSpecialty = 'All';
  final List<String> _specialties = ['All', 'Depression', 'Anxiety', 'Trauma', 'Addiction', 'General'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Therapist'),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterBar(),
          Expanded(
            child: _buildTherapistList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search by name',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.isNotEmpty ? value : null;
          });
        },
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _specialties.length,
        itemBuilder: (context, index) {
          final specialty = _specialties[index];
          final isSelected = specialty == _selectedSpecialty;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(specialty),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedSpecialty = specialty;
                });
              },
              backgroundColor: Colors.grey[200],
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected 
                    ? Theme.of(context).primaryColor
                    : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTherapistList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getTherapistsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return EmptyState(
            title: 'Error',
            message: 'Failed to load therapists. Please try again.',
            icon: Icons.error_outline,
          );
        }

        final therapists = snapshot.data?.docs ?? [];
        
        if (therapists.isEmpty) {
          return EmptyState(
            title: 'No Therapists Available',
            message: 'There are no therapists available at the moment. Please check back later.',
            icon: Icons.person_off,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: therapists.length,
          itemBuilder: (context, index) {
            final therapistData = therapists[index].data() as Map<String, dynamic>;
            final therapist = Therapist.fromMap(therapistData, therapists[index].id);
            
            return _buildTherapistCard(therapist);
          },
        );
      },
    );
  }

  Widget _buildTherapistCard(Therapist therapist) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: therapist.photoUrl != null
                      ? NetworkImage(therapist.photoUrl!)
                      : null,
                  child: therapist.photoUrl == null
                      ? Text(
                          therapist.fullName.isNotEmpty
                              ? therapist.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontSize: 24),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        therapist.fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        therapist.specialty,
                        style: TextStyle(
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            therapist.rating != null
                                ? '${therapist.rating} (${therapist.reviewCount} reviews)'
                                : 'New',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: therapist.isAvailable
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              therapist.isAvailable ? 'Available' : 'Not Available',
                              style: TextStyle(
                                color: therapist.isAvailable ? Colors.green : Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Experience: ${therapist.yearsExperience} years',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bio: ${therapist.bio}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (therapist.isAvailable)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.message),
                    label: const Text('Start Chat'),
                    onPressed: () => _startChatWithTherapist(therapist),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    icon: const Icon(Icons.notifications),
                    label: const Text('Request Session'),
                    onPressed: () => _requestSession(therapist),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _getTherapistsStream() {
    Query query = _firestore.collection('therapists');

    // Apply specialty filter
    if (_selectedSpecialty != 'All') {
      query = query.where('specialty', isEqualTo: _selectedSpecialty);
    }

    return query.snapshots();
  }

  Future<void> _startChatWithTherapist(Therapist therapist) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user
      final user = _auth.currentUser;
      if (user == null) {
        _showErrorDialog('You must be logged in to chat with a therapist');
        return;
      }

      // Check for existing conversation or create new one
      final QuerySnapshot existingConversations = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: user.uid)
          .where('therapistId', isEqualTo: therapist.id)
          .limit(1)
          .get();

      String conversationId;
      if (existingConversations.docs.isNotEmpty) {
        conversationId = existingConversations.docs.first.id;
      } else {
        // Create new conversation
        final DocumentReference newConversation = await _firestore
            .collection('conversations')
            .add({
              'participantIds': [user.uid, therapist.id],
              'therapistId': therapist.id,
              'clientId': user.uid,
              'therapistName': therapist.fullName,
              'clientName': user.displayName ?? 'Client',
              'lastMessage': 'Conversation started',
              'lastMessageTime': FieldValue.serverTimestamp(),
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
              'therapistUnreadCount': 1,
              'clientUnreadCount': 0,
              'status': 'active',
            });
        
        conversationId = newConversation.id;
        
        // Add system message
        await _firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .add({
              'text': 'Conversation started. How can I help you today?',
              'senderId': therapist.id,
              'senderType': 'system',
              'timestamp': FieldValue.serverTimestamp(),
              'isRead': false,
            });
      }

      // Navigate to chat screen
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/therapist_profile',
          arguments: {'therapistId': therapist.id},
        );
      }
    } catch (e) {
      print('Error starting chat: $e');
      _showErrorDialog('Failed to start chat. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _requestSession(Therapist therapist) async {
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Request Session with ${therapist.fullName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please describe briefly why you would like to talk to this therapist:',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Ex: I have been feeling anxious lately and would like some guidance...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final message = messageController.text.trim();
              if (message.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a message')),
                );
                return;
              }

              Navigator.pop(context);

              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Sending request...'),
                    ],
                  ),
                ),
              );

              final success = await _therapistService.requestTherapistSession(
                therapist.id, 
                message
              );
              
              if (mounted) {
                Navigator.pop(context);
                
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(success ? 'Request Sent' : 'Error'),
                    content: Text(
                      success
                          ? 'Your request has been sent to ${therapist.fullName}. You will be notified when they accept your request.'
                          : 'Failed to send request. Please try again.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
} 