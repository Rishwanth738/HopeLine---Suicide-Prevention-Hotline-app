import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/therapist_service.dart';

class TherapistAppointmentsScreen extends StatefulWidget {
  final String therapistId;
  
  const TherapistAppointmentsScreen({
    Key? key,
    required this.therapistId,
  }) : super(key: key);

  @override
  State<TherapistAppointmentsScreen> createState() => _TherapistAppointmentsScreenState();
}

class _TherapistAppointmentsScreenState extends State<TherapistAppointmentsScreen> {
  final TherapistService _therapistService = TherapistService();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: StreamBuilder<QuerySnapshot>(
          stream: _therapistService.getTherapistAppointments(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Text('No appointments scheduled');
            }

            return ListView.builder(
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                return const Card(
                  child: ListTile(
                    title: Text('Appointment'),
                    subtitle: Text('Appointment details will be shown here'),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
} 