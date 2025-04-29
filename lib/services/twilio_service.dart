import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TwilioService {
  static const String _serverUrl = "https://hope-line-server.herokuapp.com";
  static const String _accountSid = 'account_sid';
  static const String _authToken = 'authtoken';
  static const String _twilioPhoneNumber = 'phone_no';

  static Future<Map<String, dynamic>> makeVoiceCall(String phoneNumber, {String? message}) async {
    try {
      // If the number doesn’t start with +, assume it’s missing a country code
      if (!phoneNumber.startsWith('+')) {
        phoneNumber = '+1$phoneNumber'; // Default fallback country code
      }

      debugPrint('Initiating voice call to: $phoneNumber');

      // Simulated response for testing without a real backend
      return {
        'success': true,
        'message': 'Voice call initiated successfully',
        'callSid': 'CA${DateTime.now().millisecondsSinceEpoch}',
      };

      // Actual API call should look something like this:
      // final response = await http.get(
      //   Uri.parse('$_serverUrl/make-call?to=$phoneNumber&message=${message ?? ""}'),
      // );
      //
      // if (response.statusCode == 200) {
      //   return json.decode(response.body);
      // } else {
      //   return {
      //     'success': false,
      //     'message': 'Failed to initiate call: ${response.body}',
      //   };
      // }

    } catch (e) {
      debugPrint('Error making voice call: $e');
      return {
        'success': false,
        'message': 'Error making voice call: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> sendVoiceMessage(String phoneNumber, String message) async {
    return await makeVoiceCall(phoneNumber, message: message);
  }

  static Future<List<Map<String, dynamic>>> sendVoiceMessagesToContacts(
      List<Map<String, String>> contacts, String message) async {
    List<Map<String, dynamic>> results = [];

    for (var contact in contacts) {
      final result = await sendVoiceMessage(contact['phone'] ?? '', message);
      results.add({
        'contact': contact['name'],
        'phone': contact['phone'],
        'result': result,
      });
    }

    return results;
  }
}
