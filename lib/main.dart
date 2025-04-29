import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/home_screen.dart';
import 'screens/emergency_contacts_screen.dart';
import 'services/ai_service.dart';
import 'screens/therapist/therapist_chat_screen.dart';
import 'models/chat_message.dart';
import 'models/chat_message_widget.dart';
import 'services/emergency_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/therapist_register_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/therapist/therapist_dashboard_screen.dart';
import 'screens/therapist/clients_list_screen.dart';
import 'screens/therapist_profile.dart';
import 'screens/ai_chat_screen.dart';
import 'firebase_options.dart';
import 'routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    print("Firebase initialized successfully");
    
    AIService.initialize().then((_) {
      print("AI service initialized successfully");
    }).catchError((e) {
      print("Error initializing AI service: $e");
    });
  } catch (e) {
    print("Error initializing Firebase: $e");
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hope Line',
      theme: ThemeData(
        primaryColor: Colors.indigo,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          secondary: Colors.pinkAccent,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 3,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
      routes: routes,
      debugShowCheckedModeBanner: false,
    );
  }
}
