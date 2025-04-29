import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class TherapistProfileScreen extends StatefulWidget {
  const TherapistProfileScreen({super.key});

  @override
  State<TherapistProfileScreen> createState() => _TherapistProfileScreenState();
}

class _TherapistProfileScreenState extends State<TherapistProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  
  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();
  final _specialtiesController = TextEditingController();
  final _educationController = TextEditingController();
  final _experienceController = TextEditingController();
  final _rateController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  File? _profileImage;
  String? _profileImageUrl;
  List<String> _specialtiesList = [];
  List<String> _availableDays = [];
  Map<String, List<String>> _availableTimeSlots = {};
  
  // Predefined time slots
  final List<String> _timeSlots = [
    '9:00 AM', '10:00 AM', '11:00 AM', '12:00 PM',
    '1:00 PM', '2:00 PM', '3:00 PM', '4:00 PM', 
    '5:00 PM', '6:00 PM', '7:00 PM', '8:00 PM'
  ];
  
  // Predefined specialties
  final List<String> _availableSpecialties = [
    'Anxiety', 'Depression', 'Trauma', 'PTSD', 
    'Stress', 'Grief', 'Relationship Issues', 'Self-Esteem',
    'Career Counseling', 'Addiction', 'Family Conflicts',
    'Life Transitions', 'Bipolar Disorder', 'Anger Management',
    'OCD', 'Eating Disorders', 'Sleep Issues'
  ];

  @override
  void initState() {
    super.initState();
    _loadTherapistProfile();
  }

  Future<void> _loadTherapistProfile() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final docSnapshot = await _firestore.collection('therapists').doc(userId).get();
      
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        
        setState(() {
          _bioController.text = data['bio'] ?? '';
          _specialtiesList = List<String>.from(data['specialties'] ?? []);
          _specialtiesController.text = _specialtiesList.join(', ');
          _educationController.text = data['education'] ?? '';
          _experienceController.text = data['experience']?.toString() ?? '';
          _rateController.text = data['rate']?.toString() ?? '';
          _profileImageUrl = data['photoUrl'];
          
          // Load availability
          _availableDays = List<String>.from(data['availableDays'] ?? []);
          
          if (data['availableTimeSlots'] != null) {
            final slots = data['availableTimeSlots'] as Map<String, dynamic>;
            slots.forEach((key, value) {
              _availableTimeSlots[key] = List<String>.from(value);
            });
          }
        });
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      String? imageUrl = _profileImageUrl;
      
      // Upload new image if selected
      if (_profileImage != null) {
        final storageRef = _storage.ref().child('therapist_profiles/$userId.jpg');
        final uploadTask = storageRef.putFile(_profileImage!);
        final snapshot = await uploadTask.whenComplete(() {});
        imageUrl = await snapshot.ref.getDownloadURL();
        
        // Update auth profile photo
        await _auth.currentUser?.updatePhotoURL(imageUrl);
      }

      // Parse rate value
      double? rate;
      if (_rateController.text.isNotEmpty) {
        rate = double.tryParse(_rateController.text);
      }
      
      // Parse experience value
      int? experience;
      if (_experienceController.text.isNotEmpty) {
        experience = int.tryParse(_experienceController.text);
      }

      // Save profile data
      await _firestore.collection('therapists').doc(userId).set({
        'bio': _bioController.text.trim(),
        'specialties': _specialtiesList,
        'education': _educationController.text.trim(),
        'experience': experience,
        'rate': rate,
        'photoUrl': imageUrl,
        'availableDays': _availableDays,
        'availableTimeSlots': _availableTimeSlots,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update user display name if needed
      if (_auth.currentUser?.displayName == null || _auth.currentUser!.displayName!.isEmpty) {
        await _auth.currentUser?.updateDisplayName('Dr. ${_auth.currentUser?.email?.split('@')[0] ?? 'Therapist'}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  void _addSpecialty(String specialty) {
    if (!_specialtiesList.contains(specialty) && specialty.isNotEmpty) {
      setState(() {
        _specialtiesList.add(specialty);
        _specialtiesController.text = _specialtiesList.join(', ');
      });
    }
  }

  void _removeSpecialty(String specialty) {
    setState(() {
      _specialtiesList.remove(specialty);
      _specialtiesController.text = _specialtiesList.join(', ');
    });
  }

  void _toggleDay(String day) {
    setState(() {
      if (_availableDays.contains(day)) {
        _availableDays.remove(day);
        _availableTimeSlots.remove(day);
      } else {
        _availableDays.add(day);
        _availableTimeSlots[day] = [];
      }
    });
  }

  void _toggleTimeSlot(String day, String timeSlot) {
    if (!_availableDays.contains(day)) return;

    setState(() {
      if (_availableTimeSlots[day] == null) {
        _availableTimeSlots[day] = [];
      }

      if (_availableTimeSlots[day]!.contains(timeSlot)) {
        _availableTimeSlots[day]!.remove(timeSlot);
      } else {
        _availableTimeSlots[day]!.add(timeSlot);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Therapist Profile'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveProfile,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundImage: _profileImage != null
                                ? FileImage(_profileImage!)
                                : (_profileImageUrl != null
                                    ? NetworkImage(_profileImageUrl!)
                                    : null) as ImageProvider?,
                            child: (_profileImage == null && _profileImageUrl == null)
                                ? const Icon(Icons.person, size: 60)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: _pickImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.indigo,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Professional Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bioController,
                      decoration: const InputDecoration(
                        labelText: 'Professional Bio',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your professional bio';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _educationController,
                      decoration: const InputDecoration(
                        labelText: 'Education',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Ph.D in Clinical Psychology, Harvard University',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your education';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _experienceController,
                            decoration: const InputDecoration(
                              labelText: 'Years of Experience',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter years of experience';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _rateController,
                            decoration: const InputDecoration(
                              labelText: 'Hourly Rate (USD)',
                              border: OutlineInputBorder(),
                              prefixText: '\$ ',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter hourly rate';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter a valid rate';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Specialties',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _specialtiesController,
                      decoration: InputDecoration(
                        labelText: 'Your Specialties',
                        border: const OutlineInputBorder(),
                        hintText: 'Select from suggested specialties below',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _specialtiesList.clear();
                              _specialtiesController.clear();
                            });
                          },
                        ),
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _specialtiesList.map((specialty) {
                        return Chip(
                          label: Text(specialty),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => _removeSpecialty(specialty),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    const Text('Suggested Specialties:'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _availableSpecialties
                          .where((s) => !_specialtiesList.contains(s))
                          .map((specialty) {
                        return ActionChip(
                          label: Text(specialty),
                          onPressed: () => _addSpecialty(specialty),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Availability',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildAvailabilitySelector(),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save Profile'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAvailabilitySelector() {
    final weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: weekdays.map((day) {
            final isSelected = _availableDays.contains(day);
            return FilterChip(
              label: Text(day),
              selected: isSelected,
              onSelected: (selected) => _toggleDay(day),
              selectedColor: Colors.indigo.shade100,
              checkmarkColor: Colors.indigo,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        ..._availableDays.map((day) => _buildTimeSlotsForDay(day)).toList(),
      ],
    );
  }

  Widget _buildTimeSlotsForDay(String day) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            day,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Wrap(
          spacing: 8,
          children: _timeSlots.map((timeSlot) {
            final isSelected = _availableTimeSlots[day]?.contains(timeSlot) ?? false;
            return FilterChip(
              label: Text(timeSlot),
              selected: isSelected,
              onSelected: (selected) => _toggleTimeSlot(day, timeSlot),
              selectedColor: Colors.indigo.shade100,
              checkmarkColor: Colors.indigo,
            );
          }).toList(),
        ),
        const Divider(),
      ],
    );
  }

  @override
  void dispose() {
    _bioController.dispose();
    _specialtiesController.dispose();
    _educationController.dispose();
    _experienceController.dispose();
    _rateController.dispose();
    super.dispose();
  }
} 