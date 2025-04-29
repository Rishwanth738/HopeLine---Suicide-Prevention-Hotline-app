import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class EmergencyContactsPage extends StatefulWidget {
  @override
  _EmergencyContactsPageState createState() => _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends State<EmergencyContactsPage> {
  List<Contact> _emergencyContacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmergencyContacts();
  }

  Future<void> _loadEmergencyContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = prefs.getStringList('emergency_contacts') ?? [];
    setState(() {
      _emergencyContacts = contactsJson
          .map((json) => Contact.fromMap(jsonDecode(json) as Map<String, dynamic>))
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _saveEmergencyContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = _emergencyContacts
        .map((contact) => jsonEncode(contact.toMap()))
        .toList();
    await prefs.setStringList('emergency_contacts', contactsJson);
  }

  Future<void> _pickContact() async {
    final permission = await Permission.contacts.request();
    
    if (permission.isGranted) {
      try {
        final Contact? contact = await ContactsService.openDeviceContactPicker();
        if (contact != null) {
          setState(() {
            _emergencyContacts.add(contact);
          });
          await _saveEmergencyContacts();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing contacts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Permission to access contacts denied'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeContact(int index) async {
    setState(() {
      _emergencyContacts.removeAt(index);
    });
    await _saveEmergencyContacts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Emergency Contacts',
          style: TextStyle(color: Colors.deepPurple),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.deepPurple),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFF0F0F5)],
          ),
        ),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'These contacts will be notified in case of emergency',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _emergencyContacts.length,
                      padding: EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final contact = _emergencyContacts[index];
                        return Card(
                          elevation: 0,
                          margin: EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: Colors.deepPurple.withOpacity(0.1),
                              child: Text(
                                contact.displayName?[0] ?? '?',
                                style: TextStyle(
                                  color: Colors.deepPurple,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              contact.displayName ?? 'No name',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              contact.phones?.first.value ?? 'No phone number',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _removeContact(index),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickContact,
        icon: Icon(Icons.add),
        label: Text('Add Contact'),
        backgroundColor: Colors.deepPurple,
      ),
    );
  }
} 