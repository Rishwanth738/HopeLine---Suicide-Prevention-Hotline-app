import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'therapist_chat_screen.dart';

class ClientsListScreen extends StatefulWidget {
  const ClientsListScreen({super.key});

  @override
  State<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends State<ClientsListScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _activeClients = [];
  List<Map<String, dynamic>> _pendingClients = [];
  List<Map<String, dynamic>> _pastClients = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadClients();
  }
  
  Future<void> _loadClients() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final therapistId = _auth.currentUser?.uid;
      if (therapistId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Load active clients (with active sessions)
      final activeClientsQuery = await _firestore
          .collection('conversations')
          .where('therapistId', isEqualTo: therapistId)
          .where('status', isEqualTo: 'active')
          .get();
      
      // Load pending clients (requested but not accepted yet)
      final pendingClientsQuery = await _firestore
          .collection('therapist_requests')
          .where('therapistId', isEqualTo: therapistId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      // Load past clients (sessions ended)
      final pastClientsQuery = await _firestore
          .collection('conversations')
          .where('therapistId', isEqualTo: therapistId)
          .where('status', isEqualTo: 'completed')
          .get();
          
      _activeClients = [];
      _pendingClients = [];
      _pastClients = [];
      
      // Process active clients
      for (var doc in activeClientsQuery.docs) {
        final data = doc.data();
        final clientId = data['clientId'] as String?;
        if (clientId != null) {
          final clientDoc = await _firestore.collection('users').doc(clientId).get();
          if (clientDoc.exists) {
            final clientData = clientDoc.data() as Map<String, dynamic>;
            _activeClients.add({
              'conversationId': doc.id,
              'clientId': clientId,
              'name': clientData['displayName'] ?? 'Anonymous',
              'photoUrl': clientData['photoUrl'],
              'lastMessage': data['lastMessage'] ?? 'No messages yet',
              'lastMessageTime': data['lastMessageTime'] ?? Timestamp.now(),
              'unreadCount': data['therapistUnreadCount'] ?? 0,
              'startDate': data['createdAt'] ?? Timestamp.now(),
            });
          }
        }
      }
      
      // Process pending clients
      for (var doc in pendingClientsQuery.docs) {
        final data = doc.data();
        final clientId = data['clientId'] as String?;
        if (clientId != null) {
          final clientDoc = await _firestore.collection('users').doc(clientId).get();
          if (clientDoc.exists) {
            final clientData = clientDoc.data() as Map<String, dynamic>;
            _pendingClients.add({
              'requestId': doc.id,
              'clientId': clientId,
              'name': clientData['displayName'] ?? 'Anonymous',
              'photoUrl': clientData['photoUrl'],
              'reason': data['reason'] ?? 'No reason provided',
              'requestDate': data['createdAt'] ?? Timestamp.now(),
            });
          }
        }
      }
      
      // Process past clients
      for (var doc in pastClientsQuery.docs) {
        final data = doc.data();
        final clientId = data['clientId'] as String?;
        if (clientId != null) {
          final clientDoc = await _firestore.collection('users').doc(clientId).get();
          if (clientDoc.exists) {
            final clientData = clientDoc.data() as Map<String, dynamic>;
            _pastClients.add({
              'conversationId': doc.id,
              'clientId': clientId,
              'name': clientData['displayName'] ?? 'Anonymous',
              'photoUrl': clientData['photoUrl'],
              'totalSessions': data['sessionCount'] ?? 0,
              'endDate': data['endedAt'] ?? Timestamp.now(),
              'startDate': data['createdAt'] ?? Timestamp.now(),
            });
          }
        }
      }
      
      // Sort clients by last message time or request date
      _activeClients.sort((a, b) => (b['lastMessageTime'] as Timestamp)
          .compareTo(a['lastMessageTime'] as Timestamp));
      
      _pendingClients.sort((a, b) => (b['requestDate'] as Timestamp)
          .compareTo(a['requestDate'] as Timestamp));
      
      _pastClients.sort((a, b) => (b['endDate'] as Timestamp)
          .compareTo(a['endDate'] as Timestamp));
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading clients: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading clients: $e')),
      );
    }
  }

  Future<void> _handleClientRequest(String requestId, bool accept) async {
    try {
      final requestData = _pendingClients.firstWhere((client) => client['requestId'] == requestId);
      final clientId = requestData['clientId'];
      
      // Update request status
      await _firestore.collection('therapist_requests').doc(requestId).update({
        'status': accept ? 'accepted' : 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (accept) {
        // Create a new conversation document
        final conversationRef = _firestore.collection('conversations').doc();
        await conversationRef.set({
          'therapistId': _auth.currentUser!.uid,
          'clientId': clientId,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessage': 'Conversation started',
          'therapistUnreadCount': 0,
          'clientUnreadCount': 1,
        });
        
        // Create initial system message
        await _firestore.collection('messages').add({
          'conversationId': conversationRef.id,
          'senderId': 'system',
          'text': 'Therapist has accepted your request. You can now start chatting.',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'type': 'text',
        });
        
        // Update client's notification
        await _firestore.collection('notifications').add({
          'userId': clientId,
          'title': 'Request Accepted',
          'body': 'Your therapist request has been accepted. You can now start chatting.',
          'type': 'request_accepted',
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
          'data': {
            'conversationId': conversationRef.id,
          },
        });
      } else {
        // Update client's notification for rejection
        await _firestore.collection('notifications').add({
          'userId': clientId,
          'title': 'Request Declined',
          'body': 'Your therapist request could not be accepted at this time.',
          'type': 'request_rejected',
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }
      
      // Refresh client list
      _loadClients();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accept 
          ? 'Client request accepted successfully' 
          : 'Client request declined')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing request: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Clients'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Requests'),
            Tab(text: 'Past'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadClients,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildActiveClientsList(),
                _buildPendingClientsList(),
                _buildPastClientsList(),
              ],
            ),
    );
  }
  
  Widget _buildActiveClientsList() {
    if (_activeClients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No active clients',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your active client sessions will appear here',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _activeClients.length,
      itemBuilder: (context, index) {
        final client = _activeClients[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.indigo.shade100,
              backgroundImage: client['photoUrl'] != null 
                  ? NetworkImage(client['photoUrl'] as String) 
                  : null,
              child: client['photoUrl'] == null 
                  ? Text(client['name'].toString().substring(0, 1).toUpperCase()) 
                  : null,
            ),
            title: Text(
              client['name'] as String,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  client['lastMessage'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Since ${DateFormat('MMM d, yyyy').format((client['startDate'] as Timestamp).toDate())}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateFormat('h:mm a').format((client['lastMessageTime'] as Timestamp).toDate()),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                if ((client['unreadCount'] as int) > 0)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      client['unreadCount'].toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TherapistChatScreen(
                    conversationId: client['conversationId'],
                    clientId: client['clientId'],
                    clientName: client['name'],
                  ),
                ),
              ).then((_) => _loadClients());
            },
          ),
        );
      },
    );
  }
  
  Widget _buildPendingClientsList() {
    if (_pendingClients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pending_actions, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No pending requests',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'New client requests will appear here',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _pendingClients.length,
      itemBuilder: (context, index) {
        final client = _pendingClients[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.indigo.shade100,
                      backgroundImage: client['photoUrl'] != null 
                          ? NetworkImage(client['photoUrl'] as String) 
                          : null,
                      child: client['photoUrl'] == null 
                          ? Text(client['name'].toString().substring(0, 1).toUpperCase()) 
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            client['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Requested ${DateFormat('MMM d, yyyy').format((client['requestDate'] as Timestamp).toDate())}',
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
                const SizedBox(height: 16),
                Text(
                  'Reason for request:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  client['reason'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => _handleClientRequest(client['requestId'] as String, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text('Decline'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () => _handleClientRequest(client['requestId'] as String, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
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
  }
  
  Widget _buildPastClientsList() {
    if (_pastClients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No past clients',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your completed sessions will appear here',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _pastClients.length,
      itemBuilder: (context, index) {
        final client = _pastClients[index];
        final startDate = (client['startDate'] as Timestamp).toDate();
        final endDate = (client['endDate'] as Timestamp).toDate();
        
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.indigo.shade100,
              backgroundImage: client['photoUrl'] != null 
                  ? NetworkImage(client['photoUrl'] as String) 
                  : null,
              child: client['photoUrl'] == null 
                  ? Text(client['name'].toString().substring(0, 1).toUpperCase()) 
                  : null,
            ),
            title: Text(
              client['name'] as String,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('MMM d, yyyy').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${client['totalSessions']} sessions completed',
                  style: const TextStyle(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              onPressed: () {
                // View client history details
                // Implement in future versions
              },
            ),
          ),
        );
      },
    );
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
} 