import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/emergency_service.dart';
import '../services/therapist_service.dart';
import '../models/therapist.dart';
import 'chat_screen.dart';
import 'therapist/therapist_chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _signOut() {
    try {
      FirebaseAuth.instance.signOut();
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  Future<void> _activateEmergencyProtocol(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Activating emergency protocol..."),
            ],
          ),
        );
      },
    );

    try {
      // Call emergency number
      final EmergencyService emergencyService = EmergencyService();
      final bool success = await emergencyService.callEmergencyServices();

      // Send alerts to emergency contacts
      await EmergencyService().sendEmergencyAlerts();

      // Close the loading dialog
      if (context.mounted) Navigator.of(context).pop();

      // Show result dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(success ? "Success" : "Action Required"),
              content: Text(
                success
                    ? "Emergency services have been called and your emergency contacts have been notified."
                    : "Please manually call 108 for emergency services. Your emergency contacts have been notified.",
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text("OK"),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      // Close the loading dialog
      if (context.mounted) Navigator.of(context).pop();

      // Show error dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Error"),
              content: Text("An error occurred: $e\nPlease manually call 108 for emergency services."),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text("OK"),
                ),
              ],
            );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hope Line'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Crisis Message Card
            Card(
              color: Colors.indigo.shade50,
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Are you in crisis?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'If you\'re experiencing thoughts of suicide or serious mental distress, help is available.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.indigo.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _callHotline,
                      icon: const Icon(Icons.call),
                      label: const Text('Call Emergency Hotline (108)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _sendEmergencyVoiceMessages,
                      icon: const Icon(Icons.message),
                      label: const Text('Send Emergency Alerts'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              'Support Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Main features grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  // AI Chat Feature Card
                  _buildFeatureCard(
                    context,
                    Icons.psychology,
                    'AI Therapist',
                    'Chat with our AI for immediate support and guidance.',
                    Colors.blue.shade100,
                    Colors.blue.shade700,
                    () => Navigator.pushNamed(context, '/ai_chat'),
                  ),
                  
                  // Talk to real therapist
                  _buildFeatureCard(
                    context,
                    Icons.support_agent,
                    'Talk to Therapist',
                    'Connect with a live therapist through secure messaging.',
                    Colors.green.shade100,
                    Colors.green.shade700,
                    () => _connectToTherapist(context),
                  ),
                  
                  // Emergency Contacts
                  _buildFeatureCard(
                    context,
                    Icons.contacts,
                    'Emergency Contacts',
                    'Manage your emergency contact list.',
                    Colors.purple.shade100,
                    Colors.purple.shade700,
                    () => Navigator.pushNamed(context, '/emergency_contacts'),
                  ),
                  
                  // Profile
                  _buildFeatureCard(
                    context,
                    Icons.person,
                    'Profile',
                    'View and update your profile information.',
                    Colors.amber.shade100,
                    Colors.amber.shade700,
                    () => Navigator.pushNamed(context, '/profile'),
                  ),
                  
                  // Switch to therapist mode
                  _buildFeatureCard(
                    context,
                    Icons.switch_account,
                    'Therapist Mode',
                    'Switch to therapist view to chat with clients.',
                    Colors.indigo.shade100,
                    Colors.indigo.shade700,
                    () => _switchToTherapistMode(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _callHotline() {
    _showEmergencyDialog();
  }
  
  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Emergency Call'),
          content: const Text(
            'Are you sure you want to call emergency services (108)? '
            'This will also notify your emergency contacts about your situation.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _activateEmergencyProtocol(context);
              },
              child: const Text('Yes, I Need Help'),
            ),
          ],
        );
      },
    );
  }

  void _connectToTherapist(BuildContext context) {
    try {
      // Get current user or create a unique ID for anonymous users
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'anonymous-${DateTime.now().millisecondsSinceEpoch}';
      final userName = user?.displayName ?? 'Anonymous User';
      
      // Define a conversation ID for the public chat that all users can access
      final conversationId = 'public-therapist-chat';
      
      // Navigate directly to chat screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TherapistChatScreen(
            conversationId: conversationId,
            clientId: userId,
            clientName: userName,
          ),
        ),
      );
    } catch (e) {
      // Show error dialog if something goes wrong
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to connect to therapist: $e'),
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

  void _sendEmergencyVoiceMessages() async {
    try {
      // Get emergency contacts first to check if there are any
      final emergencyService = EmergencyService();
      final contacts = await emergencyService.getEmergencyContacts();
      
      if (contacts.isEmpty) {
        // Show an error if there are no contacts
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You need to add emergency contacts first'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Launch SMS app with emergency message
      await emergencyService.sendEmergencyAlerts(useVoiceMessage: false);
      
      // Show success message after returning from SMS app
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency alert sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Show error message if SMS launch fails
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send emergency alerts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Function to switch to therapist mode
  void _switchToTherapistMode(BuildContext context) {
    try {
      // Get current user or create a unique ID for anonymous users
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'anonymous-${DateTime.now().millisecondsSinceEpoch}';
      final userName = user?.displayName ?? 'Default Therapist';
      
      // Use the same public conversation ID as client mode
      final conversationId = 'public-therapist-chat';
      
      // Navigate to therapist chat screen but with therapist role
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TherapistChatScreen(
            conversationId: conversationId,
            clientId: 'public-client', // Generic client ID for public chat
            clientName: 'Public Chat Room', // Indicate this is a public chat
            isTherapistMode: true, // Special flag to indicate therapist mode
          ),
        ),
      );
    } catch (e) {
      // Show error dialog if something goes wrong
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to switch to therapist mode: $e'),
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

  Widget _buildFeatureCard(BuildContext context, IconData icon, String title, String subtitle, Color backgroundColor, Color foregroundColor, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
              color: foregroundColor,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: foregroundColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}