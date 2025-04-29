import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'therapist_chat_screen.dart';

class TherapistDashboardScreen extends StatefulWidget {
  const TherapistDashboardScreen({super.key});

  @override
  State<TherapistDashboardScreen> createState() => _TherapistDashboardScreenState();
}

class _TherapistDashboardScreenState extends State<TherapistDashboardScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isAvailable = true;
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic> _therapistData = {};
  List<Map<String, dynamic>> _activeConversations = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  late TabController _tabController;
  List<Map<String, dynamic>> _clientList = [];
  List<Map<String, dynamic>> _appointmentList = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTherapistData();
    _loadConversations();
    _loadClients();
    _loadAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTherapistData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final therapistId = _auth.currentUser?.uid;
      if (therapistId == null) {
        throw Exception('Not authenticated');
      }

      final doc = await _firestore.collection('therapists').doc(therapistId).get();
      if (!doc.exists) {
        throw Exception('Therapist profile not found');
      }

      setState(() {
        _therapistData = doc.data()!;
        _isAvailable = _therapistData['status'] == 'available';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading profile: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadConversations() async {
    try {
      final therapistId = _auth.currentUser?.uid;
      if (therapistId == null) return;

      // Get active conversations
      final activeSnapshot = await _firestore
          .collection('conversations')
          .where('therapistId', isEqualTo: therapistId)
          .where('status', isEqualTo: 'active')
          .get();

      final active = await Future.wait(
        activeSnapshot.docs.map((doc) async {
          final userData = await _firestore.collection('users').doc(doc['clientId']).get();
          return {
            'id': doc.id,
            'clientId': doc['clientId'],
            'clientName': userData.exists ? userData['name'] : 'Unknown User',
            'lastMessage': await _getLastMessage(doc.id),
            'updatedAt': doc['updatedAt'] ?? Timestamp.now(),
          };
        }),
      );

      // Get pending requests (could be implemented with a different collection)
      final pendingSnapshot = await _firestore
          .collection('therapist_requests')
          .where('therapistId', isEqualTo: therapistId)
          .where('status', isEqualTo: 'pending')
          .get();

      final pending = await Future.wait(
        pendingSnapshot.docs.map((doc) async {
          final userData = await _firestore.collection('users').doc(doc['clientId']).get();
          return {
            'id': doc.id,
            'clientId': doc['clientId'],
            'clientName': userData.exists ? userData['name'] : 'Unknown User',
            'message': doc['message'] ?? 'No message provided',
            'createdAt': doc['createdAt'] ?? Timestamp.now(),
          };
        }),
      );

      setState(() {
        _activeConversations = List<Map<String, dynamic>>.from(active);
        _pendingRequests = List<Map<String, dynamic>>.from(pending);
      });
    } catch (e) {
      print('Error loading conversations: $e');
    }
  }

  Future<String> _getLastMessage(String conversationId) async {
    try {
      final messagesSnapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (messagesSnapshot.docs.isEmpty) {
        return 'No messages yet';
      }

      return messagesSnapshot.docs.first['text'] ?? 'No text';
    } catch (e) {
      return 'Error loading message';
    }
  }

  Future<void> _toggleAvailability() async {
    try {
      final therapistId = _auth.currentUser?.uid;
      if (therapistId == null) return;

      setState(() {
        _isAvailable = !_isAvailable;
      });

      await _firestore.collection('therapists').doc(therapistId).update({
        'status': _isAvailable ? 'available' : 'unavailable',
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error updating status: $e';
        _isAvailable = !_isAvailable; // Revert on error
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      setState(() {
        _errorMessage = 'Error signing out: $e';
      });
    }
  }

  Future<void> _loadClients() async {
    try {
      final String therapistId = _auth.currentUser!.uid;
      final snapshot = await _firestore
          .collection('conversations')
          .where('therapistId', isEqualTo: therapistId)
          .get();
      
      List<Map<String, dynamic>> clients = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final clientId = data['userId'];
        final userDoc = await _firestore.collection('users').doc(clientId).get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          clients.add({
            'id': clientId,
            'name': userData['fullName'] ?? 'Unknown',
            'email': userData['email'] ?? 'No email',
            'conversationId': doc.id,
            'lastMessage': data['lastMessage'] ?? '',
            'lastMessageTime': data['lastMessageTime'],
            'unreadCount': data['therapistUnreadCount'] ?? 0,
          });
        }
      }
      
      setState(() {
        _clientList = clients;
      });
    } catch (e) {
      print('Error loading clients: $e');
    }
  }

  Future<void> _loadAppointments() async {
    try {
      final String therapistId = _auth.currentUser!.uid;
      final snapshot = await _firestore
          .collection('appointments')
          .where('therapistId', isEqualTo: therapistId)
          .orderBy('startTime')
          .get();
      
      List<Map<String, dynamic>> appointments = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final clientId = data['userId'];
        final userDoc = await _firestore.collection('users').doc(clientId).get();
        String clientName = 'Unknown Client';
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          clientName = userData['fullName'] ?? 'Unknown Client';
        }
        
        appointments.add({
          'id': doc.id,
          'clientId': clientId,
          'clientName': clientName,
          'startTime': data['startTime'],
          'endTime': data['endTime'],
          'status': data['status'] ?? 'scheduled',
          'notes': data['notes'] ?? '',
          'type': data['type'] ?? 'video',
        });
      }
      
      setState(() {
        _appointmentList = appointments;
      });
    } catch (e) {
      print('Error loading appointments: $e');
    }
  }

  Future<void> _updateAppointmentStatus(String appointmentId, String status) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': status,
      });
      _loadAppointments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update appointment status: $e'))
      );
    }
  }

  void _navigateToChatScreen(String conversationId, String clientId, String clientName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TherapistChatScreen(
          conversationId: conversationId,
          clientId: clientId,
          clientName: clientName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Therapist Dashboard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          Switch(
            value: _isAvailable,
            onChanged: (value) => _toggleAvailability(),
            activeColor: Colors.green,
            inactiveThumbColor: Colors.red,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Profile'),
            Tab(icon: Icon(Icons.people), text: 'Clients'),
            Tab(icon: Icon(Icons.calendar_today), text: 'Appointments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProfileTab(),
          _buildClientsTab(),
          _buildAppointmentsTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 2 
          ? FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () {
                // Navigate to create appointment screen
              },
            )
          : null,
    );
  }

  Widget _buildProfileTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _therapistData['photoUrl'] != null 
                        ? NetworkImage(_therapistData['photoUrl']) 
                        : null,
                    child: _therapistData['photoUrl'] == null 
                        ? const Icon(Icons.person, size: 50) 
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _therapistData['fullName'] ?? 'No name',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _profileItem(Icons.medical_services, 'Specialty', 
                          _therapistData['specialty'] ?? 'Not specified'),
                        _profileItem(Icons.school, 'Experience', 
                          '${_therapistData['yearsOfExperience'] ?? '0'} years'),
                        _profileItem(Icons.email, 'Email', 
                          _therapistData['email'] ?? 'No email'),
                        _profileItem(Icons.person_pin, 'License Number', 
                          _therapistData['licenseNumber'] ?? 'Not provided'),
                      ],
                    ),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'About Me',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(_therapistData['bio'] ?? 'No bio provided'),
                      ],
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to edit profile screen
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Edit Profile'),
                ),
              ],
            ),
          );
  }

  Widget _profileItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClientsTab() {
    return _clientList.isEmpty
        ? const Center(child: Text('No clients yet'))
        : ListView.builder(
            itemCount: _clientList.length,
            itemBuilder: (context, index) {
              final client = _clientList[index];
              final lastMessageTime = client['lastMessageTime'] != null
                  ? (client['lastMessageTime'] as Timestamp).toDate()
                  : DateTime.now();
              final formattedTime = DateFormat.yMd().add_jm().format(lastMessageTime);
              
              return ListTile(
                leading: CircleAvatar(
                  child: Text(client['name'][0]),
                ),
                title: Row(
                  children: [
                    Text(client['name']),
                    if (client['unreadCount'] > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${client['unreadCount']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client['lastMessage'] ?? 'No messages yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      formattedTime,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                onTap: () => _navigateToChatScreen(
                  client['conversationId'],
                  client['id'],
                  client['name'],
                ),
              );
            },
          );
  }

  Widget _buildAppointmentsTab() {
    return _appointmentList.isEmpty
        ? const Center(child: Text('No appointments scheduled'))
        : ListView.builder(
            itemCount: _appointmentList.length,
            itemBuilder: (context, index) {
              final appointment = _appointmentList[index];
              final startTime = (appointment['startTime'] as Timestamp).toDate();
              final endTime = (appointment['endTime'] as Timestamp).toDate();
              final formattedDate = DateFormat.yMMMd().format(startTime);
              final formattedTime = '${DateFormat.jm().format(startTime)} - ${DateFormat.jm().format(endTime)}';
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            appointment['clientName'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(appointment['status']),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              appointment['status'].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(formattedDate),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(formattedTime),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            appointment['type'] == 'video' ? Icons.videocam : Icons.chat,
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Text(appointment['type'] == 'video' ? 'Video Session' : 'Chat Session'),
                        ],
                      ),
                      if (appointment['notes'].isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Notes:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(appointment['notes']),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (appointment['status'] == 'scheduled')
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle, size: 16),
                              label: const Text('Complete'),
                              onPressed: () => _updateAppointmentStatus(appointment['id'], 'completed'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                            ),
                          if (appointment['status'] == 'scheduled')
                            ElevatedButton.icon(
                              icon: const Icon(Icons.cancel, size: 16),
                              label: const Text('Cancel'),
                              onPressed: () => _updateAppointmentStatus(appointment['id'], 'cancelled'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                            ),
                          if (appointment['type'] == 'chat')
                            ElevatedButton.icon(
                              icon: const Icon(Icons.chat, size: 16),
                              label: const Text('Chat'),
                              onPressed: () {
                                // Find conversation and navigate to chat
                                final client = _clientList.firstWhere(
                                  (c) => c['id'] == appointment['clientId'],
                                  orElse: () => <String, dynamic>{},
                                );
                                
                                if (client.isNotEmpty) {
                                  _navigateToChatScreen(
                                    client['conversationId'],
                                    client['id'],
                                    client['name'],
                                  );
                                }
                              },
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'scheduled':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
} 