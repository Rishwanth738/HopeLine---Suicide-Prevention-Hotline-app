import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'twilio_service.dart';

class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relation;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relation,
  });

  factory EmergencyContact.fromMap(Map<String, dynamic> map, String id) {
    return EmergencyContact(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      relation: map['relation'] ?? '',
    );
  }
}

class EmergencyService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final EmergencyService _instance = EmergencyService._internal();
  static const String EMERGENCY_CONTACTS_KEY = 'emergency_contacts';

  factory EmergencyService() {
    return _instance;
  }

  EmergencyService._internal();

  // Emergency services number - in a real app, this could be configurable
  // Using 108 as an example for India's emergency services
  static const String EMERGENCY_NUMBER = '108';
  
  /// Call emergency services (e.g., 108 in India)
  Future<bool> callEmergencyServices() async {
    try {
      bool? success = await FlutterPhoneDirectCaller.callNumber(EMERGENCY_NUMBER);
      if (success == true) {
        _logEmergencyCall();
      }
      return success ?? false;
    } catch (e) {
      print('Failed to call emergency services: $e');
      return false;
    }
  }
  
  /// Send emergency alerts to all registered emergency contacts
  Future<void> sendEmergencyAlerts({bool useVoiceMessage = false}) async {
    try {
      // Get emergency contacts
      final contacts = await getEmergencyContacts();
      if (contacts.isEmpty) {
        return;
      }
      
      // Get current location to include in the alert
      Position? position;
      try {
        position = await _getCurrentLocation();
      } catch (e) {
        print('Failed to get location: $e');
      }
      
      // Standard emergency message
      String message = 'EMERGENCY ALERT: I need immediate help. ';
      if (position != null) {
        message += 'My location: https://maps.google.com/?q=${position.latitude},${position.longitude}';
      } else {
        message += 'Please contact me as soon as possible.';
      }
      
      // Build recipient list
      String recipients = '';
      for (var contact in contacts) {
        final phone = contact['phone'] as String?;
        if (phone != null && phone.isNotEmpty) {
          recipients += '$phone,';
        }
      }
      
      // Remove trailing comma
      if (recipients.endsWith(',')) {
        recipients = recipients.substring(0, recipients.length - 1);
      }
      
      // If we have recipients, launch SMS
      if (recipients.isNotEmpty) {
        final Uri smsUri = Uri(
          scheme: 'sms',
          path: recipients,
          queryParameters: {'body': message},
        );
        
        if (await canLaunchUrl(smsUri)) {
          await launchUrl(smsUri);
          return;
        } else {
          throw Exception('Could not launch SMS app');
        }
      }
      
      return;
    } catch (e) {
      print('Error sending emergency alerts: $e');
      throw e;
    }
  }

  /// Send alerts to emergency contacts
  Future<Map<String, dynamic>> alertEmergencyContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? contacts = prefs.getStringList(EMERGENCY_CONTACTS_KEY);
    
    if (contacts == null || contacts.isEmpty) {
      return {
        'success': false,
        'message': 'No emergency contacts found',
        'contactsNotified': 0
      };
    }

    int successCount = 0;
    List<String> failedContacts = [];
    
    // Get current location to include in the alert
    Position? position;
    try {
      position = await _getCurrentLocation();
    } catch (e) {
      print('Failed to get location: $e');
    }
    
    String locationText = position != null 
        ? 'Location: https://maps.google.com/?q=${position.latitude},${position.longitude}'
        : 'Location unavailable';

    // Standard emergency message
    String message = 'EMERGENCY ALERT: I need immediate help. $locationText';
    
    // In a real app, you would send SMS or use a notification service here
    // For this demo, we'll just simulate sending alerts
    for (String contact in contacts) {
      try {
        // Simulate sending an SMS or notification
        await Future.delayed(const Duration(milliseconds: 500));
        
        // In a real implementation, you would use a service like Twilio or Firebase Cloud Messaging
        // Example: await sendSMS(contact, message);
        
        successCount++;
      } catch (e) {
        failedContacts.add(contact);
      }
    }
    
    return {
      'success': successCount > 0,
      'message': successCount > 0 
          ? 'Alerted $successCount emergency contacts' 
          : 'Failed to alert any emergency contacts',
      'contactsNotified': successCount,
      'failedContacts': failedContacts
    };
  }
  
  /// Log emergency alert to Firebase
  Future<void> _logEmergencyAlert(Map<String, dynamic> result) async {
    try {
      final userId = _auth.currentUser?.uid;
      
      Position? position;
      try {
        position = await _getCurrentLocation();
      } catch (e) {
        print('Failed to get location for logging: $e');
      }
      
      await _firestore.collection('emergency_alerts').add({
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'success': result['success'],
        'contactsNotified': result['contactsNotified'],
        'location': position != null
            ? GeoPoint(position.latitude, position.longitude)
            : null,
      });
    } catch (e) {
      print('Failed to log emergency alert: $e');
    }
  }
  
  /// Add an emergency contact
  Future<bool> addEmergencyContact(String name, String phone) async {
    if (phone.isEmpty) return false;
    
    final prefs = await SharedPreferences.getInstance();
    final List<String> existingContacts = prefs.getStringList(EMERGENCY_CONTACTS_KEY) ?? [];
    
    String contactEntry = '$name:$phone';
    
    if (existingContacts.any((contact) => contact.split(':')[1] == phone)) {
      return false; // Contact already exists
    }
    
    existingContacts.add(contactEntry);
    return await prefs.setStringList(EMERGENCY_CONTACTS_KEY, existingContacts);
  }
  
  /// Remove an emergency contact
  Future<bool> removeEmergencyContact(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> existingContacts = prefs.getStringList(EMERGENCY_CONTACTS_KEY) ?? [];
    
    final updatedContacts = existingContacts
        .where((contact) => contact.split(':')[1] != phone)
        .toList();
    
    if (updatedContacts.length == existingContacts.length) {
      return false; // Contact was not found
    }
    
    return await prefs.setStringList(EMERGENCY_CONTACTS_KEY, updatedContacts);
  }
  
  /// Get all emergency contacts
  Future<List<Map<String, String>>> getEmergencyContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> contactStrings = prefs.getStringList(EMERGENCY_CONTACTS_KEY) ?? [];
    
    return contactStrings.map((contactString) {
      final parts = contactString.split(':');
      return {
        'name': parts[0],
        'phone': parts.length > 1 ? parts[1] : '',
      };
    }).toList();
  }
  
  /// Get the current location
  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }

    return await Geolocator.getCurrentPosition();
  }
  
  /// Log emergency call to Firebase (for record keeping and analytics)
  Future<void> _logEmergencyCall() async {
    try {
      Position? position;
      try {
        position = await _getCurrentLocation();
      } catch (e) {
        print('Failed to get location for logging: $e');
      }
      
      await FirebaseFirestore.instance.collection('emergency_calls').add({
        'timestamp': FieldValue.serverTimestamp(),
        'location': position != null
            ? GeoPoint(position.latitude, position.longitude)
            : null,
        'type': 'emergency_services',
      });
    } catch (e) {
      print('Failed to log emergency call: $e');
    }
  }
  
  /// Show emergency contacts management UI
  static Future<void> showEmergencyContactsManager(BuildContext context) async {
    try {
      final emergencyService = EmergencyService();
      final contacts = await emergencyService.getEmergencyContacts();
      
      if (!context.mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => _EmergencyContactsDialog(
          contacts: contacts,
          emergencyService: emergencyService,
        ),
      );
    } catch (e) {
      debugPrint('Error showing emergency contacts manager: $e');
      if (!context.mounted) return;
      
      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Connection Error'),
          content: const Text(
            'Unable to load emergency contacts. Please check your internet connection and try again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  // Get emergency contacts for current user
  static Future<List<EmergencyContact>> getUserEmergencyContacts() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return await _getLocalEmergencyContacts(); // Allow access without login
      }

      try {
        final snapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('emergencyContacts')
            .get();

        return snapshot.docs
            .map((doc) => EmergencyContact.fromMap(doc.data(), doc.id))
            .toList();
      } catch (e) {
        debugPrint('Error getting emergency contacts from Firebase: $e');
        // Fall back to local contacts if Firebase fails
        return await _getLocalEmergencyContacts();
      }
    } catch (e) {
      debugPrint('Error in getUserEmergencyContacts: $e');
      return [];
    }
  }

  // Get emergency contacts from local storage as fallback
  static Future<List<EmergencyContact>> _getLocalEmergencyContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> contactStrings = prefs.getStringList(EMERGENCY_CONTACTS_KEY) ?? [];
      
      return contactStrings.map((contactString) {
        final parts = contactString.split(':');
        return EmergencyContact(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: parts[0],
          phone: parts.length > 1 ? parts[1] : '',
          relation: parts.length > 2 ? parts[2] : 'Contact',
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting local emergency contacts: $e');
      return [];
    }
  }

  // Request permissions needed for emergency services
  static Future<bool> _requestPermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.sms,
        Permission.phone,
        Permission.location,
      ].request();
      
      return statuses.values.every((status) => status.isGranted);
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      // Return true in offline mode to allow basic functionality
      return true;
    }
  }

  // Get current location for alerts
  static Future<String> _getLocationForAlerts() async {
    try {
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      return 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
    } catch (e) {
      debugPrint('Error getting location: $e');
      return 'Location unavailable';
    }
  }

  // Send SMS to all emergency contacts
  static Future<void> _sendSMSToContacts(
      List<EmergencyContact> contacts, String userName, String locationLink) async {
    try {
      List<String> recipients = contacts.map((contact) => contact.phone).toList();
      String message = 'EMERGENCY ALERT: $userName needs urgent help. '
          'This is an automated message from Hope Line. '
          'Please try to contact them immediately. '
          'Their last known location is: $locationLink';

      for (String recipient in recipients) {
        await sendSMS(recipient, message);
      }
    } catch (e) {
      debugPrint('Error sending SMS: $e');
      throw Exception('Failed to send SMS alerts');
    }
  }

  // Call contacts one by one with delays
  static void _callContactsSequentially(List<EmergencyContact> contacts) async {
    for (var i = 0; i < contacts.length; i++) {
      // Delay between calls to allow time for answering
      if (i > 0) {
        await Future.delayed(const Duration(seconds: 30));
      }
      
      try {
        await FlutterPhoneDirectCaller.callNumber(contacts[i].phone);
      } catch (e) {
        debugPrint('Error calling contact ${contacts[i].name}: $e');
        continue; // Continue to next contact if call fails
      }
    }
  }

  // Send an SMS using url_launcher
  static Future<String> sendDirectSMS(String phoneNumber, String message) async {
    try {
      await sendSMS(phoneNumber, message);
      return 'SMS sent via launcher';
    } catch (e) {
      debugPrint('Error with direct SMS: $e');
      return 'Failed to send SMS';
    }
  }

  // SMS method using URL launcher (requires user interaction)
  static Future<void> sendSMS(String phoneNumber, String message) async {
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: {'body': message},
    );
    
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      debugPrint('Could not launch $smsUri');
    }
  }

  // Make a phone call using url_launcher (requires user interaction)
  static Future<void> makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      debugPrint('Could not launch $phoneUri');
    }
  }
}

/// Dialog for managing emergency contacts
class _EmergencyContactsDialog extends StatefulWidget {
  final List<Map<String, String>> contacts;
  final EmergencyService emergencyService;

  const _EmergencyContactsDialog({
    Key? key,
    required this.contacts,
    required this.emergencyService,
  }) : super(key: key);

  @override
  State<_EmergencyContactsDialog> createState() => _EmergencyContactsDialogState();
}

class _EmergencyContactsDialogState extends State<_EmergencyContactsDialog> {
  late List<Map<String, String>> _contacts;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _contacts = List.from(widget.contacts);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Emergency Contacts'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'These contacts will be notified in case of an emergency',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (_contacts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No emergency contacts added'),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    return ListTile(
                      title: Text(contact['name'] ?? 'Unknown'),
                      subtitle: Text(contact['phone'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () async {
                          await widget.emergencyService
                              .removeEmergencyContact(contact['phone'] ?? '');
                          setState(() {
                            _contacts.removeAt(index);
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _showAddContactDialog,
              child: const Text('Add Contact'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  void _showAddContactDialog() {
    _nameController.clear();
    _phoneController.clear();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Emergency Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter contact name',
              ),
            ),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter phone number',
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_nameController.text.isNotEmpty && 
                  _phoneController.text.isNotEmpty) {
                final success = await widget.emergencyService.addEmergencyContact(
                  _nameController.text,
                  _phoneController.text,
                );
                
                if (success) {
                  setState(() {
                    _contacts.add({
                      'name': _nameController.text,
                      'phone': _phoneController.text,
                    });
                  });
                  Navigator.of(context).pop();
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}