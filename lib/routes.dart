import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/therapist_register_screen.dart';
import 'screens/emergency_contacts_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/therapist/therapist_dashboard_screen.dart';
import 'screens/therapist/clients_list_screen.dart';
import 'screens/therapist_profile.dart';
import 'screens/therapist_list_screen.dart';
import 'screens/ai_chat_screen.dart';

// Define application routes
final Map<String, WidgetBuilder> routes = {
  '/login': (context) => const LoginScreen(),
  '/home': (context) => const HomeScreen(),
  '/therapist_register': (context) => const TherapistRegisterScreen(),
  '/emergency_contacts': (context) => const EmergencyContactsScreen(),
  '/profile': (context) => const ProfileScreen(),
  '/chat': (context) => const ChatScreen(),
  '/therapist_list': (context) => const TherapistListScreen(),
  '/therapist_dashboard': (context) => const TherapistDashboardScreen(),
  '/therapist_clients': (context) => const ClientsListScreen(),
  '/therapist_profile': (context) => const TherapistProfileScreen(),
  '/ai_chat': (context) => const AIChatScreen(),
}; 