import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'therapist_chat_screen.dart';
import '../../services/therapist_service.dart';

class TherapistClientsScreen extends StatefulWidget {
  final String therapistId;
  
  const TherapistClientsScreen({
    Key? key,
    required this.therapistId,
  }) : super(key: key);

  @override
  _TherapistClientsScreenState createState() => _TherapistClientsScreenState();
}

class _TherapistClientsScreenState extends State<TherapistClientsScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;
  final therapistService = TherapistService();
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: 'Active Clients'),
            Tab(text: 'Pending Requests'),
            Tab(text: 'Past Clients'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildActiveClientsTab(),
              _buildPendingRequestsTab(),
              _buildPastClientsTab(),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildActiveClientsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('therapistId', isEqualTo: widget.therapistId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No active clients'),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final conversation = snapshot.data!.docs[index];
            final data = conversation.data() as Map<String, dynamic>;
            
            final clientName = data['clientName'] ?? 'Unknown Client';
            final clientId = data['clientId'] as String;
            final lastMessageTime = data['lastMessageTime'] != null
                ? (data['lastMessageTime'] as Timestamp).toDate()
                : null;
            final unreadCount = data['therapistUnreadCount'] ?? 0;
            
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    clientName.isNotEmpty ? clientName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  clientName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      lastMessageTime != null
                          ? 'Last message: ${_formatTimestamp(lastMessageTime)}'
                          : 'No messages yet',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    _buildClientStatus(data['clientStatus'] ?? 'unknown'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.message, color: Colors.blue),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TherapistChatScreen(
                              conversationId: conversation.id,
                              clientId: clientId,
                              clientName: clientName,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                onTap: () {
                  _showClientDetailsDialog(clientId, clientName);
                },
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildPendingRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('therapistRequests')
          .where('therapistId', isEqualTo: widget.therapistId)
          .where('status', isEqualTo: 'pending')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No pending requests'),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final request = snapshot.data!.docs[index];
            final data = request.data() as Map<String, dynamic>;
            
            final clientName = data['clientName'] ?? 'Unknown Client';
            final clientId = data['clientId'] as String;
            final requestTime = data['timestamp'] as Timestamp;
            final message = data['message'] ?? 'No message provided';
            
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.orange,
                          child: Text(
                            clientName.isNotEmpty ? clientName[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                clientName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Requested on ${_formatTimestamp(requestTime.toDate())}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Message:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => _handleRequestResponse(request.id, 'rejected', clientId, clientName),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: const Text(
                            'Decline',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () => _handleRequestResponse(request.id, 'accepted', clientId, clientName),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('Accept'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildPastClientsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('therapistId', isEqualTo: widget.therapistId)
          .where('status', isEqualTo: 'inactive')
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No past clients'),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final conversation = snapshot.data!.docs[index];
            final data = conversation.data() as Map<String, dynamic>;
            
            final clientName = data['clientName'] ?? 'Unknown Client';
            final clientId = data['clientId'] as String;
            final lastMessageTime = data['lastMessageTime'] != null
                ? (data['lastMessageTime'] as Timestamp).toDate()
                : null;
            final sessionCount = data['sessionCount'] ?? 0;
            
            return Card(
              elevation: 1,
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey,
                  child: Text(
                    clientName.isNotEmpty ? clientName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(clientName),
                subtitle: Text(
                  lastMessageTime != null
                      ? 'Last session: ${_formatTimestamp(lastMessageTime)}'
                      : 'No session data',
                ),
                trailing: Text(
                  '$sessionCount sessions',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  _showClientDetailsDialog(clientId, clientName);
                },
              ),
            );
          },
        );
      },
    );
  }
  
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 7) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }
  
  Widget _buildClientStatus(String status) {
    Color color;
    String text;
    
    switch (status.toLowerCase()) {
      case 'active':
        color = Colors.green;
        text = 'Active';
        break;
      case 'at_risk':
        color = Colors.red;
        text = 'At Risk';
        break;
      case 'improving':
        color = Colors.blue;
        text = 'Improving';
        break;
      case 'stable':
        color = Colors.teal;
        text = 'Stable';
        break;
      default:
        color = Colors.grey;
        text = 'Unknown';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  Future<void> _handleRequestResponse(String requestId, String response, String clientId, String clientName) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      if (response == 'accepted') {
        // Create a new conversation
        final conversationRef = FirebaseFirestore.instance.collection('conversations').doc();
        await conversationRef.set({
          'therapistId': widget.therapistId,
          'clientId': clientId,
          'clientName': clientName,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessageTime': FieldValue.serverTimestamp(),
          'therapistUnreadCount': 0,
          'clientUnreadCount': 0,
          'clientStatus': 'active',
        });
        
        // Create welcome message
        await FirebaseFirestore.instance.collection('messages').add({
          'conversationId': conversationRef.id,
          'senderId': widget.therapistId,
          'senderRole': 'therapist',
          'text': 'Thank you for connecting with me. I look forward to working with you. How are you feeling today?',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
        
        // Add record to therapist activity
        await FirebaseFirestore.instance.collection('therapistActivity').add({
          'therapistId': widget.therapistId,
          'clientId': clientId,
          'clientName': clientName,
          'conversationId': conversationRef.id,
          'description': 'Started working with $clientName',
          'type': 'client_accepted',
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        // Send notification to client
        // Implement notification logic here
      }
      
      // Update request status
      await FirebaseFirestore.instance
          .collection('therapistRequests')
          .doc(requestId)
          .update({
            'status': response,
            'responseTimestamp': FieldValue.serverTimestamp(),
          });
      
      // Show confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response == 'accepted'
                  ? 'You have accepted $clientName as a client'
                  : 'You have declined the request from $clientName',
            ),
            backgroundColor: response == 'accepted' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error handling request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to process request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _showClientDetailsDialog(String clientId, String clientName) async {
    try {
      // Get client details
      final clientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(clientId)
          .get();
      
      if (!clientDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Client details not found')),
          );
        }
        return;
      }
      
      final clientData = clientDoc.data() as Map<String, dynamic>;
      
      // Get assessment data if any
      final assessmentQuery = await FirebaseFirestore.instance
          .collection('assessments')
          .where('clientId', isEqualTo: clientId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      Map<String, dynamic>? assessmentData;
      if (assessmentQuery.docs.isNotEmpty) {
        assessmentData = assessmentQuery.docs.first.data();
      }
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(clientName),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailItem('Email', clientData['email'] ?? 'Not provided'),
                  _buildDetailItem('Phone', clientData['phone'] ?? 'Not provided'),
                  _buildDetailItem('Age', clientData['age']?.toString() ?? 'Not provided'),
                  _buildDetailItem('Gender', clientData['gender'] ?? 'Not provided'),
                  
                  const SizedBox(height: 16),
                  const Text(
                    'Assessment Data',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  if (assessmentData != null) ...[
                    _buildDetailItem('Risk Level', assessmentData['riskLevel'] ?? 'Unknown'),
                    _buildDetailItem('Mood Score', assessmentData['moodScore']?.toString() ?? 'Not recorded'),
                    _buildDetailItem('Anxiety Score', assessmentData['anxietyScore']?.toString() ?? 'Not recorded'),
                    _buildDetailItem('Date', assessmentData['timestamp'] != null
                        ? _formatTimestamp((assessmentData['timestamp'] as Timestamp).toDate())
                        : 'Unknown'),
                  ] else
                    const Text('No assessment data available'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to client detail screen
                  // Implement navigation to full client profile
                },
                child: const Text('View Full Profile'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Error getting client details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load client details'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
} 