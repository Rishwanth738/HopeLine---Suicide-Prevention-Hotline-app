import 'package:cloud_firestore/cloud_firestore.dart';

class Therapist {
  final String id;
  final String fullName;
  final String email;
  final String specialty;
  final int yearsExperience;
  final String bio;
  final String photoUrl;
  final String phoneNumber;
  final bool isAvailable;
  final double rating;
  final int reviewCount;
  final List<String> clientIds;

  Therapist({
    required this.id,
    required this.fullName,
    required this.email,
    required this.specialty,
    required this.yearsExperience,
    required this.bio,
    this.photoUrl = '',
    this.phoneNumber = '',
    this.isAvailable = false,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.clientIds = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'specialty': specialty,
      'yearsOfExperience': yearsExperience,
      'bio': bio,
      'photoUrl': photoUrl,
      'phoneNumber': phoneNumber,
      'isAvailable': isAvailable,
      'rating': rating,
      'reviewCount': reviewCount,
      'clientIds': clientIds,
    };
  }

  factory Therapist.fromMap(Map<String, dynamic> map, String documentId) {
    final clientIds = map['clientIds'] as List?;
    
    return Therapist(
      id: documentId,
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      specialty: map['specialty'] ?? '',
      yearsExperience: map['yearsOfExperience'] ?? 0,
      bio: map['bio'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      isAvailable: map['isAvailable'] ?? false,
      rating: (map['rating'] ?? 0.0).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
      clientIds: clientIds != null 
          ? List<String>.from(clientIds) 
          : [],
    );
  }

  factory Therapist.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data was null');
    }
    
    final clientIds = data['clientIds'] as List?;
    
    return Therapist(
      id: doc.id,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      specialty: data['specialty'] ?? '',
      yearsExperience: data['yearsOfExperience'] ?? 0,
      bio: data['bio'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      isAvailable: data['isAvailable'] ?? false,
      rating: (data['rating'] ?? 0.0).toDouble(),
      reviewCount: data['reviewCount'] ?? 0,
      clientIds: clientIds != null 
          ? List<String>.from(clientIds) 
          : [],
    );
  }
} 