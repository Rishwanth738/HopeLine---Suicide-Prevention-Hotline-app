import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'therapist_clients_screen.dart';
import 'therapist_appointments_screen.dart';
import 'therapist_profile_screen.dart';
import 'therapist_chat_screen.dart';
import '../../models/therapist.dart';
import '../../services/therapist_service.dart';

class TherapistDashboardScreen extends StatefulWidget {
  const TherapistDashboardScreen({Key? key}) : super(key: key);

  @override
  _TherapistDashboardScreenState createState() => _TherapistDashboardScreenState();
}

class _TherapistDashboardScreenState extends State<TherapistDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final therapistService = TherapistService();
  
  String _therapistId = '';
  String _therapistName = '';
  bool _isAvailable = false;
  int _activeClients = 0;
  int _pendingRequests = 0;
  int _totalSessions = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTherapistData();
    // Update therapist's last active timestamp regularly
    _updateLastActive();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTherapistData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _navigateToLogin();
        return;
      }

      _therapistId = currentUser.uid;
      
      // Get therapist data
      final therapistDoc = await FirebaseFirestore.instance
          .collection('therapists')
          .doc(_therapistId)
          .get();
      
      if (!therapistDoc.exists) {
        _navigateToLogin();
        return;
      }
      
      final therapistData = therapistDoc.data() as Map<String, dynamic>;
      
      // Get active clients count
      final activeClientsQuery = await FirebaseFirestore.instance
          .collection('conversations')
          .where('therapistId', isEqualTo: _therapistId)
          .where('status', isEqualTo: 'active')
          .get();
      
      // Get pending requests count
      final pendingRequestsQuery = await FirebaseFirestore.instance
          .collection('therapistRequests')
          .where('therapistId', isEqualTo: _therapistId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      // Get total sessions count
      final sessionsQuery = await FirebaseFirestore.instance
          .collection('sessions')
          .where('therapistId', isEqualTo: _therapistId)
          .get();
      
      setState(() {
        _therapistName = therapistData['fullName'] ?? 'Therapist';
        _isAvailable = therapistData['isAvailable'] ?? false;
        _activeClients = activeClientsQuery.docs.length;
        _pendingRequests = pendingRequestsQuery.docs.length;
        _totalSessions = sessionsQuery.docs.length;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading therapist data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateLastActive() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('therapists')
            .doc(currentUser.uid)
            .update({
              'lastActive': FieldValue.serverTimestamp(),
              'isOnline': true,
            });
      }
    } catch (e) {
      print('Error updating last active: $e');
    }
  }

  Future<void> _toggleAvailability() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Toggle availability in Firestore
      await therapistService.updateAvailability(_therapistId, !_isAvailable);
      
      // Refresh data
      await _loadTherapistData();
      
      // Show confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are now ${_isAvailable ? 'available' : 'unavailable'} for new clients'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error toggling availability: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update availability status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      // Set therapist as offline
      await FirebaseFirestore.instance
          .collection('therapists')
          .doc(_therapistId)
          .update({
            'isOnline': false,
            'lastActive': FieldValue.serverTimestamp(),
          });
      
      // Clear user role from shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userRole');
      
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      
      // Navigate to login
      _navigateToLogin();
    } catch (e) {
      print('Error signing out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to sign out'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Therapist Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.people), text: 'Clients'),
            Tab(icon: Icon(Icons.calendar_today), text: 'Schedule'),
            Tab(icon: Icon(Icons.person), text: 'Profile'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Overview Tab
                _buildOverviewTab(),
                
                // Clients Tab
                TherapistClientsScreen(therapistId: _therapistId),
                
                // Schedule Tab
                TherapistAppointmentsScreen(therapistId: _therapistId),
                
                // Profile Tab
                TherapistProfileScreen(therapistId: _therapistId),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadTherapistData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, $_therapistName',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Availability toggle
                    SwitchListTile(
                      title: const Text('Available for new clients'),
                      subtitle: Text(_isAvailable 
                          ? 'You are visible to potential clients' 
                          : 'You are not accepting new clients'),
                      value: _isAvailable,
                      onChanged: (value) => _toggleAvailability(),
                      secondary: Icon(
                        _isAvailable ? Icons.visibility : Icons.visibility_off,
                        color: _isAvailable ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Stats cards
            Row(
              children: [
                _buildStatCard(
                  'Active Clients',
                  _activeClients.toString(),
                  Icons.people,
                  Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Pending Requests',
                  _pendingRequests.toString(),
                  Icons.notifications,
                  Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatCard(
                  'Total Sessions',
                  _totalSessions.toString(),
                  Icons.history,
                  Colors.purple,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Rating',
                  '4.8',
                  Icons.star,
                  Colors.amber,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Recent activity
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildRecentActivityList(),
            
            const SizedBox(height: 24),
            
            // Upcoming appointments
            const Text(
              'Upcoming Appointments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildUpcomingAppointmentsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
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
                children: [
                  Icon(icon, color: color, size: 28),
                  const Spacer(),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivityList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('therapistActivity')
          .where('therapistId', isEqualTo: _therapistId)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No recent activity'),
            ),
          );
        }
        
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final activity = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final timestamp = activity['timestamp'] as Timestamp?;
            final formattedDate = timestamp != null
                ? DateFormat('MMM d, h:mm a').format(timestamp.toDate())
                : 'Unknown date';
                
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(_getActivityIcon(activity['type'] ?? '')),
                title: Text(activity['description'] ?? 'Unknown activity'),
                subtitle: Text(formattedDate),
                trailing: activity['type'] == 'message'
                    ? const Icon(Icons.arrow_forward_ios, size: 16)
                    : null,
                onTap: activity['type'] == 'message' && activity['conversationId'] != null
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Chat feature coming soon')),
                        );
                      }
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'message':
        return Icons.message;
      case 'appointment':
        return Icons.calendar_today;
      case 'client_request':
        return Icons.person_add;
      case 'session_completed':
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  Widget _buildUpcomingAppointmentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('therapistId', isEqualTo: _therapistId)
          .where('status', isEqualTo: 'confirmed')
          .where('startTime', isGreaterThan: Timestamp.fromDate(DateTime.now()))
          .orderBy('startTime')
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No upcoming appointments'),
            ),
          );
        }
        
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final appointment = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final startTime = appointment['startTime'] as Timestamp?;
            final formattedDate = startTime != null
                ? DateFormat('EEEE, MMM d, h:mm a').format(startTime.toDate())
                : 'Unknown date';
                
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.videocam, color: Colors.blue),
                title: Text(appointment['clientName'] ?? 'Unknown client'),
                subtitle: Text(formattedDate),
                trailing: _buildAppointmentActions(appointment),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAppointmentActions(Map<String, dynamic> appointment) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.video_call, color: Colors.green),
          tooltip: 'Start session',
          onPressed: () {
            // Handle starting video session
            if (appointment['videoLink'] != null) {
              // Launch video link
            } else {
              // Create new video session
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.message, color: Colors.blue),
          tooltip: 'Message client',
          onPressed: () {
            if (appointment['clientId'] != null && appointment['conversationId'] != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TherapistChatScreen(
                    conversationId: appointment['conversationId'],
                    clientId: appointment['clientId'],
                    clientName: appointment['clientName'] ?? 'Client',
                  ),
                ),
              );
            }
          },
        ),
      ],
    );
  }
} 