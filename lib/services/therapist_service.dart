// This file provides services for therapist registration, profile management,
// client communication, session management, and availability tracking.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/therapist.dart';

class TherapistService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = Uuid();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Stream controllers
  final StreamController<List<ChatMessageModel>> _messagesController = 
      StreamController<List<ChatMessageModel>>.broadcast();
  final StreamController<bool> _connectionStatusController = 
      StreamController<bool>.broadcast();
  
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _connectivitySubscription;
  
  String? _currentConversationId;
  String? _currentTherapistId;
  String? _currentUserId;
  bool _isConnected = false;
  
  // Expose streams
  Stream<List<ChatMessageModel>> get messagesStream => _messagesController.stream;
  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  
  // Socket for real-time connection
  IO.Socket? _socket;
  String? _userId;
  String? _therapistId;
  String? _conversationId;
  
  // Singleton instance
  static final TherapistService _instance = TherapistService._internal();
  factory TherapistService() => _instance;
  TherapistService._internal();
  
  // Get current user ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }
  
  // Check if current user is therapist
  Future<bool> isCurrentUserTherapist() async {
    final uid = getCurrentUserId();
    if (uid == null) return false;
    
    try {
      final doc = await _firestore.collection('therapists').doc(uid).get();
      return doc.exists;
    } catch (e) {
      print('Error checking if user is therapist: $e');
      return false;
    }
  }
  
  // THERAPIST REGISTRATION AND MANAGEMENT
  
  // Register a new therapist
  Future<Map<String, dynamic>> registerTherapist({
    required String email,
    required String password,
    required String fullName,
    required String specialty,
    required int yearsExperience,
    required String bio,
    String phoneNumber = '',
  }) async {
    try {
      // Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      await userCredential.user?.updateDisplayName(fullName);
      
      // Create therapist document
      final therapist = Therapist(
        id: userCredential.user!.uid,
        fullName: fullName,
        email: email,
        specialty: specialty,
        yearsExperience: yearsExperience,
        bio: bio,
        phoneNumber: phoneNumber,
        isAvailable: true,
      );
      
      // Add to Firestore
      await createTherapist(therapist);
      
      return {
        'success': true,
        'therapistId': userCredential.user!.uid,
      };
    } catch (e) {
      print('Error registering therapist: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Create a new therapist record in Firestore
  Future<bool> createTherapist(Therapist therapist) async {
    try {
      await _firestore.collection('therapists').doc(therapist.id).set(therapist.toMap());
      return true;
    } catch (e) {
      print('Error creating therapist: $e');
      return false;
    }
  }
  
  // Update therapist profile
  Future<Map<String, dynamic>> updateTherapistProfile({
    required String therapistId,
    String? fullName,
    String? specialty,
    int? yearsExperience,
    String? bio,
    String? phoneNumber,
    File? profileImage,
  }) async {
    try {
      Map<String, dynamic> updateData = {};
      
      if (fullName != null && fullName.isNotEmpty) {
        updateData['fullName'] = fullName;
        // Update Auth display name
        await _auth.currentUser?.updateDisplayName(fullName);
      }
      
      if (specialty != null && specialty.isNotEmpty) {
        updateData['specialty'] = specialty;
      }
      
      if (yearsExperience != null) {
        updateData['yearsExperience'] = yearsExperience;
      }
      
      if (bio != null && bio.isNotEmpty) {
        updateData['bio'] = bio;
      }
      
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        updateData['phoneNumber'] = phoneNumber;
      }
      
      // Upload new profile image if provided
      if (profileImage != null) {
        final ref = _storage.ref()
            .child('therapist_profile_images')
            .child('$therapistId.jpg');
            
        await ref.putFile(profileImage);
        String photoUrl = await ref.getDownloadURL();
        
        updateData['photoUrl'] = photoUrl;
        // Update Auth photo URL
        await _auth.currentUser?.updatePhotoURL(photoUrl);
      }
      
      await _firestore.collection('therapists').doc(therapistId).update(updateData);
      
      return {
        'success': true,
        'message': 'Profile updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update profile: $e',
      };
    }
  }
  
  // Update therapist availability
  Future<bool> updateAvailability(String therapistId, bool isAvailable) async {
    try {
      await _firestore.collection('therapists').doc(therapistId).update({
        'isAvailable': isAvailable,
        'lastActive': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating therapist availability: $e');
      return false;
    }
  }
  
  // Update online status
  Future<void> updateOnlineStatus(bool isOnline) async {
    try {
      final String? therapistId = _auth.currentUser?.uid;
      if (therapistId != null) {
        await _firestore.collection('therapists').doc(therapistId).update({
          'isOnline': isOnline,
          'lastActive': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating online status: $e');
    }
  }
  
  // THERAPIST DATA RETRIEVAL
  
  // Get therapist by ID
  Future<Therapist?> getTherapistById(String therapistId) async {
    try {
      final docSnapshot = await _firestore.collection('therapists').doc(therapistId).get();
      
      if (docSnapshot.exists) {
        return Therapist.fromDocument(docSnapshot);
      }
      return null;
    } catch (e) {
      print('Error getting therapist: $e');
      return null;
    }
  }
  
  // Get therapist profile data as a map
  Future<Map<String, dynamic>?> getTherapistProfile(String therapistId) async {
    try {
      final DocumentSnapshot doc = 
          await _firestore.collection('therapists').doc(therapistId).get();
      
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting therapist profile: $e');
      return null;
    }
  }
  
  // Get therapist details
  Future<Map<String, dynamic>?> getTherapistDetails(String therapistId) async {
    try {
      final docSnapshot = await _firestore.collection('therapists').doc(therapistId).get();
      
      if (docSnapshot.exists) {
        return docSnapshot.data();
      }
      return null;
    } catch (e) {
      print('Error getting therapist details: $e');
      return null;
    }
  }
  
  // Get list of available therapists
  Future<List<Therapist>> getAvailableTherapists() async {
    try {
      final snapshot = await _firestore
          .collection('therapists')
          .where('isAvailable', isEqualTo: true)
          .get();
      
      return snapshot.docs
          .map((doc) => Therapist.fromDocument(doc))
          .toList();
    } catch (e) {
      print('Error getting available therapists: $e');
      return [];
    }
  }
  
  // Get therapist's clients
  Future<List<Map<String, dynamic>>> getTherapistClients(String therapistId) async {
    try {
      // Get conversations where therapist is a participant
      final conversationsSnapshot = await _firestore
          .collection('conversations')
          .where('therapistId', isEqualTo: therapistId)
          .get();
      
      if (conversationsSnapshot.docs.isEmpty) return [];
      
      Set<String> clientIds = {};
      
      // Extract unique client IDs from conversations
      for (var doc in conversationsSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('clientId')) {
          clientIds.add(data['clientId'] as String);
        }
      }
      
      List<Map<String, dynamic>> clients = [];
      
      // Get client details
      for (var clientId in clientIds) {
        final clientDoc = await _firestore
            .collection('users')
            .doc(clientId)
            .get();
        
        if (clientDoc.exists) {
          final clientData = clientDoc.data() as Map<String, dynamic>;
          clients.add({
            'id': clientId,
            'name': clientData['displayName'] ?? clientData['fullName'] ?? 'Anonymous',
            'photoUrl': clientData['photoURL'] ?? clientData['photoUrl'] ?? '',
            'lastActive': clientData['lastActive'],
            'conversationId': '$therapistId-$clientId',
          });
        }
      }
      
      return clients;
    } catch (e) {
      print('Error getting therapist clients: $e');
      return [];
    }
  }
  
  // MESSAGING AND COMMUNICATION
  
  // Initialize and connect to therapist
  Future<bool> connectToTherapist(String therapistId) async {
    try {
      _currentTherapistId = therapistId;
      _currentUserId = _auth.currentUser?.uid;
      
      if (_currentUserId == null) {
        return false;
      }
      
      // Set up connectivity listener
      _connectivitySubscription = Connectivity()
          .onConnectivityChanged
          .listen((ConnectivityResult result) {
            _updateConnectionStatus(result);
          });
      
      // Check initial connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      _isConnected = connectivityResult != ConnectivityResult.none;
      _connectionStatusController.add(_isConnected);
      
      if (!_isConnected) {
        return false;
      }
      
      // Get or create conversation
      await _getOrCreateConversation();
      
      return true;
    } catch (e) {
      print('Error connecting to therapist: $e');
      return false;
    }
  }
  
  // Get or create a conversation
  Future<void> _getOrCreateConversation() async {
    if (_currentTherapistId == null || _currentUserId == null) return;
    
    _currentConversationId = '$_currentTherapistId-$_currentUserId';
    
    try {
      // Check if conversation exists
      final docSnapshot = await _firestore
          .collection('conversations')
          .doc(_currentConversationId)
          .get();
      
      if (!docSnapshot.exists) {
        // Create new conversation
        await _firestore.collection('conversations').doc(_currentConversationId).set({
          'therapistId': _currentTherapistId,
          'clientId': _currentUserId,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': 'Conversation started',
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'clientUnreadCount': 0,
          'therapistUnreadCount': 0,
        });
        
        // Add welcome message
        await sendSystemMessage('Welcome to your therapy conversation. Messages are encrypted and confidential.');
      }
      
      // Start listening for messages
      _subscribeToMessages();
      
    } catch (e) {
      print('Error getting or creating conversation: $e');
    }
  }
  
  // Listen for message updates
  void _subscribeToMessages() {
    if (_currentConversationId == null) return;
    
    _messagesSubscription?.cancel();
    
    _messagesSubscription = _firestore
        .collection('conversations')
        .doc(_currentConversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
          final messages = snapshot.docs
              .map((doc) => ChatMessageModel.fromMap({...doc.data(), 'id': doc.id}, doc.id))
              .toList();
          
          _messagesController.add(messages);
        }, onError: (error) {
          print('Error subscribing to messages: $error');
        });
  }
  
  // Send a message from therapist to client
  Future<bool> sendTherapistMessage(String conversationId, String text, {String? attachmentUrl, String? attachmentType}) async {
    try {
      final therapistId = _auth.currentUser?.uid;
      if (therapistId == null) return false;
      
      String messageId = _uuid.v4();
      
      // Get conversation details to know the client
      final convoDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();
      
      if (!convoDoc.exists) return false;
      
      final convoData = convoDoc.data() as Map<String, dynamic>;
      final clientId = convoData['clientId'] as String?;
      
      if (clientId == null) return false;
      
      // Prepare the message
      final message = {
        'id': messageId,
        'text': text,
        'senderId': therapistId,
        'senderType': 'therapist',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isRead': false,
      };
      
      if (attachmentUrl != null) {
        message['attachmentUrl'] = attachmentUrl;
        message['attachmentType'] = attachmentType ?? 'image';
      }
      
      // Add message to conversation
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .set(message);
      
      // Update conversation last message
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({
            'lastMessage': text,
            'lastMessageTimestamp': FieldValue.serverTimestamp(),
            'clientUnreadCount': FieldValue.increment(1),
          });
      
      return true;
    } catch (e) {
      print('Error sending therapist message: $e');
      return false;
    }
  }
  
  // Send a system message
  Future<bool> sendSystemMessage(String text) async {
    if (_currentConversationId == null) return false;
    
    try {
      String messageId = _uuid.v4();
      final message = ChatMessageModel(
        id: messageId,
        text: text,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        senderType: 'system',
        isRead: true,
      );
      
      await _firestore
          .collection('conversations')
          .doc(_currentConversationId)
          .collection('messages')
          .add(message.toMap());
      
      return true;
    } catch (e) {
      print('Error sending system message: $e');
      return false;
    }
  }
  
  // Mark messages as read
  Future<void> markMessagesAsRead(String conversationId, [String? userId]) async {
    try {
      await _firestore.collection('conversations').doc(conversationId).update({
        'therapistUnreadCount': 0,
      });
      
      // Mark individual messages as read
      final messagesSnapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .where('senderType', isEqualTo: 'client')
          .get();
      
      final batch = _firestore.batch();
      for (var doc in messagesSnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      
      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }
  
  // Get messages for a specific conversation
  Stream<QuerySnapshot> getMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }
  
  // Get conversations for therapist
  Stream<QuerySnapshot> getClientConversations() {
    final String? therapistId = _auth.currentUser?.uid;
    if (therapistId == null) {
      return const Stream.empty();
    }
    
    return _firestore
        .collection('conversations')
        .where('therapistId', isEqualTo: therapistId)
        .snapshots();
  }
  
  // Send message from therapist
  Future<bool> sendMessage(String text) async {
    try {
      if (_currentConversationId == null || _currentUserId == null) return false;
      
      // Add message to Firestore
      await _firestore.collection('messages').add({
        'conversationId': _currentConversationId,
        'senderId': _currentUserId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'text',
      });
      
      // Update conversation last message
      await _firestore.collection('conversations').doc(_currentConversationId).update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'clientUnreadCount': FieldValue.increment(1),
      });
      
      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }
  
  // CLIENT REQUEST MANAGEMENT
  
  // Request session with a therapist
  Future<bool> requestTherapistSession(String therapistId, String message) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.collection('therapist_requests').add({
        'clientId': user.uid,
        'therapistId': therapistId,
        'message': message,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'clientName': user.displayName ?? 'Anonymous',
        'clientPhotoUrl': user.photoURL ?? '',
      });

      return true;
    } catch (e) {
      print('Error requesting therapist session: $e');
      return false;
    }
  }
  
  // Get pending requests for therapist
  Stream<QuerySnapshot> getPendingRequests() {
    final String? therapistId = _auth.currentUser?.uid;
    if (therapistId == null) {
      return const Stream.empty();
    }
    
    return _firestore
        .collection('therapist_requests')
        .where('therapistId', isEqualTo: therapistId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }
  
  // Accept client request
  Future<bool> acceptClientRequest(String requestId) async {
    try {
      // Get request details
      final requestDoc = await _firestore
          .collection('therapist_requests')
          .doc(requestId)
          .get();
      
      if (!requestDoc.exists) return false;
      
      final requestData = requestDoc.data() as Map<String, dynamic>;
      final therapistId = requestData['therapistId'] as String;
      final clientId = requestData['clientId'] as String;
      
      // Update request status
      await _firestore
          .collection('therapist_requests')
          .doc(requestId)
          .update({'status': 'accepted'});
      
      // Create conversation if not exists
      final conversationId = '$therapistId-$clientId';
      final convoDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();
      
      if (!convoDoc.exists) {
        await _firestore.collection('conversations').doc(conversationId).set({
          'participants': [therapistId, clientId],
          'therapistId': therapistId,
          'clientId': clientId,
          'lastMessage': 'Conversation started',
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'clientUnreadCount': 0,
          'therapistUnreadCount': 0,
        });
        
        // Add welcome message
        await _firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .add({
              'id': _uuid.v4(),
              'text': 'Request accepted. You can now start your therapy session.',
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'senderType': 'system',
              'isRead': true,
            });
      }
      
      return true;
    } catch (e) {
      print('Error accepting client request: $e');
      return false;
    }
  }
  
  // Reject client request
  Future<bool> rejectClientRequest(String requestId) async {
    try {
      await _firestore
          .collection('therapist_requests')
          .doc(requestId)
          .update({'status': 'rejected'});
      return true;
    } catch (e) {
      print('Error rejecting client request: $e');
      return false;
    }
  }
  
  // APPOINTMENT MANAGEMENT
  
  // Create an appointment
  Future<bool> createAppointment({
    required String clientId,
    required String therapistId,
    required DateTime appointmentDate,
    required int durationMinutes,
    String notes = '',
  }) async {
    try {
      await _firestore.collection('appointments').add({
        'clientId': clientId,
        'therapistId': therapistId,
        'appointmentDate': Timestamp.fromDate(appointmentDate),
        'durationMinutes': durationMinutes,
        'notes': notes,
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      print('Error creating appointment: $e');
      return false;
    }
  }
  
  // Get therapist appointments
  Stream<QuerySnapshot> getTherapistAppointments() {
    final String? therapistId = _auth.currentUser?.uid;
    if (therapistId == null) {
      return const Stream.empty();
    }
    
    return _firestore
        .collection('appointments')
        .where('therapistId', isEqualTo: therapistId)
        .where('appointmentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
        .orderBy('appointmentDate')
        .snapshots();
  }
  
  // Update appointment status
  Future<bool> updateAppointmentStatus(String appointmentId, String status) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      print('Error updating appointment status: $e');
      return false;
    }
  }
  
  // SESSION NOTES MANAGEMENT
  
  // Add session notes
  Future<bool> addSessionNotes({
    required String clientId,
    required String sessionDate,
    required String notes,
    required String mood,
    required List<String> topics,
  }) async {
    try {
      final therapistId = _auth.currentUser?.uid;
      if (therapistId == null) return false;
      
      await _firestore.collection('session_notes').add({
        'therapistId': therapistId,
        'clientId': clientId,
        'sessionDate': sessionDate,
        'notes': notes,
        'mood': mood,
        'topics': topics,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      print('Error adding session notes: $e');
      return false;
    }
  }
  
  // Get client session notes
  Future<List<Map<String, dynamic>>> getClientSessionNotes(String clientId) async {
    try {
      final therapistId = _auth.currentUser?.uid;
      if (therapistId == null) return [];
      
      final snapshot = await _firestore
          .collection('session_notes')
          .where('therapistId', isEqualTo: therapistId)
          .where('clientId', isEqualTo: clientId)
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('Error getting client session notes: $e');
      return [];
    }
  }
  
  // Pick profile image
  Future<File?> pickProfileImage(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
      return null;
    }
  }
  
  // UTILITY FUNCTIONS
  
  // Update connection status based on connectivity changes
  void _updateConnectionStatus(ConnectivityResult result) {
    final bool wasConnected = _isConnected;
    _isConnected = result != ConnectivityResult.none;
    
    _connectionStatusController.add(_isConnected);
    
    // If reconnected, refresh messages
    if (!wasConnected && _isConnected) {
      _subscribeToMessages();
    }
  }
  
  // Get offline user ID for anonymous conversations
  Future<String> _getOfflineUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('offline_user_id');
    
    if (userId == null) {
      userId = 'offline-${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('offline_user_id', userId);
    }
    
    return userId;
  }
  
  // Disconnect from socket
  void disconnect() {
    _socket?.disconnect();
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      // Update online status before signing out
      final String? therapistId = _auth.currentUser?.uid;
      if (therapistId != null) {
        await _firestore.collection('therapists').doc(therapistId).update({
          'isOnline': false,
          'lastActive': FieldValue.serverTimestamp(),
        });
      }
      
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }
  
  // Cleanup resources
  void dispose() {
    disconnect();
    _messagesSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _messagesController.close();
    _connectionStatusController.close();
  }
} 