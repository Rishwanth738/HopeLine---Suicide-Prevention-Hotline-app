import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  static const String _apiKey = "api_key";
  static const String _apiUrl = "base_url";
  static const String _model = "chat";

  static Future<String> getChatResponse(String userMessage) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_apiKey",
          "HTTP-Referer": "http://your-app-domain.com",
          "X-Title": "HopeLine",
        },
        body: jsonEncode({
          "model": _model,
          "messages": [
            {"role": "system", "content": "You are a compassionate AI therapist."},
            {"role": "user", "content": userMessage}
          ],
          "temperature": 0.7,
          "max_tokens": 512
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["choices"][0]["message"]["content"].trim();
      } else {
        return "OpenRouter error: ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      return "Something went wrong: $e";
    }
  }

  static Future<void> initialize() async {
  }

  static void dispose() {
  }
}
