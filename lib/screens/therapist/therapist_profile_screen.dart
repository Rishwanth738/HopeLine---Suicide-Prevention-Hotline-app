import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/therapist_service.dart';
import '../../models/therapist.dart';

class TherapistProfileScreen extends StatefulWidget {
  final String? therapistId;
  
  const TherapistProfileScreen({
    Key? key,
    this.therapistId,
  }) : super(key: key);

  @override
  State<TherapistProfileScreen> createState() => _TherapistProfileScreenState();
}

class _TherapistProfileScreenState extends State<TherapistProfileScreen> {
  final TherapistService _therapistService = TherapistService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  Therapist? _therapist;
  File? _newProfileImage;
  
  // Form controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadTherapistProfile();
  }
  
  @override
  void dispose() {
    _fullNameController.dispose();
    _specialtyController.dispose();
    _experienceController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
  
  Future<void> _loadTherapistProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final String therapistId = widget.therapistId ?? 
          FirebaseAuth.instance.currentUser?.uid ?? '';
      
      if (therapistId.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final therapist = await _therapistService.getTherapistById(therapistId);
      
      setState(() {
        _therapist = therapist;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading therapist profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _pickImage() async {
    try {
      final pickedFile = await _therapistService.pickProfileImage(context);
      if (pickedFile != null) {
        setState(() {
          _newProfileImage = pickedFile;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }
  
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      final result = await _therapistService.updateTherapistProfile(
        therapistId: _therapist!.id,
        fullName: _fullNameController.text,
        specialty: _specialtyController.text,
        yearsExperience: int.parse(_experienceController.text),
        bio: _bioController.text,
        phoneNumber: _phoneController.text,
        profileImage: _newProfileImage,
      );
      
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        
        setState(() {
          _isEditing = false;
          _newProfileImage = null;
        });
        
        await _loadTherapistProfile();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Therapist Profile'),
        actions: [
          if (!_isEditing && !_isLoading)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _therapist == null
              ? const Center(child: Text('Therapist not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: _isEditing ? _buildEditForm() : _buildProfileView(),
                ),
    );
  }
  
  Widget _buildProfileView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: CircleAvatar(
            radius: 50,
            backgroundImage: _therapist!.photoUrl.isNotEmpty
                ? NetworkImage(_therapist!.photoUrl)
                : null,
            child: _therapist!.photoUrl.isEmpty
                ? Text(
                    _therapist!.fullName.substring(0, 1),
                    style: const TextStyle(fontSize: 40),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _therapist!.fullName,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        Center(
          child: Text(
            _therapist!.specialty,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 24),
        _buildInfoSection(),
      ],
    );
  }
  
  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 70,
                  backgroundImage: _newProfileImage != null
                      ? FileImage(_newProfileImage!) as ImageProvider
                      : _therapist!.photoUrl.isNotEmpty
                          ? NetworkImage(_therapist!.photoUrl)
                          : null,
                  child: _newProfileImage == null && _therapist!.photoUrl.isEmpty
                      ? Text(
                          _therapist!.fullName.substring(0, 1),
                          style: const TextStyle(fontSize: 70),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      onPressed: _pickImage,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _fullNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _specialtyController,
            decoration: const InputDecoration(
              labelText: 'Specialty',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your specialty';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _experienceController,
            decoration: const InputDecoration(
              labelText: 'Years of Experience',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your years of experience';
              }
              if (int.tryParse(value) == null) {
                return 'Please enter a valid number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _bioController,
            decoration: const InputDecoration(
              labelText: 'Professional Bio',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 5,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your bio';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Changes'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          setState(() {
                            _isEditing = false;
                            _newProfileImage = null;
                            
                            // Reset controllers to original values
                            _fullNameController.text = _therapist!.fullName;
                            _specialtyController.text = _therapist!.specialty;
                            _experienceController.text = _therapist!.yearsExperience.toString();
                            _bioController.text = _therapist!.bio;
                            _phoneController.text = _therapist!.phoneNumber ?? '';
                          });
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'About',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text(_therapist!.bio),
            const SizedBox(height: 16),
            _buildInfoRow('Specialty', _therapist!.specialty),
            _buildInfoRow('Experience', '${_therapist!.yearsExperience} years'),
            _buildInfoRow('Email', _therapist!.email),
            if (_therapist!.phoneNumber.isNotEmpty)
              _buildInfoRow('Phone', _therapist!.phoneNumber),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
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