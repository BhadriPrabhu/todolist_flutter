import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NativeSpeechService {
  static const MethodChannel _channel = MethodChannel('com.example.todo/speech');
  
  // Paste your API key here (Note: In a production app, you'd hide this in a .env file)
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  Future<String?> startListening() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      debugPrint('Microphone permission was denied by the user.');
      return null;
    }

    try {
      debugPrint('Calling native Android speech recognizer...');
      final String? result = await _channel.invokeMethod('startListening');
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed to recognize speech: '${e.message}'.");
      return null;
    }
  }

  Future<String?> parseTaskWithAI(String text) async {
    try {
      debugPrint('Sending text to Gemini Cloud API for parsing...');
      
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
        systemInstruction: Content.system('''
          You are a task extraction assistant. Extract the task details from the following text and return a valid JSON object.
          
          Output schema:
          {
            "title": "Main task name (max 50 chars)",
            "description": "More context or details",
            "notes": "Any extra conditions or items mentioned",
            "category": "Work, Personal, Urgent, or null",
            "priority": "high or low"
          }
        '''),
      );

      final response = await model.generateContent([Content.text(text)]);
      
      return response.text;
    } catch (e) {
      debugPrint("Failed to parse task with Cloud AI: '$e'");
      return null;
    }
  }

  String _offlineFallbackParse(String rawText) {
    // Truncate title to 50 chars to match your schema
    String safeTitle = rawText.length > 50 ? '${rawText.substring(0, 47)}...' : rawText;
    
    // Check for basic keywords to guess priority/category offline
    String priority = rawText.toLowerCase().contains('urgent') ? 'high' : 'low';
    String? category;
    if (rawText.toLowerCase().contains('work')) category = 'Work';
    if (rawText.toLowerCase().contains('buy') || rawText.toLowerCase().contains('groceries')) category = 'Personal';

    return '''
    {
      "title": "$safeTitle",
      "description": "Created via voice offline.",
      "notes": "Original text: $rawText",
      "category": ${category != null ? '"$category"' : "null"},
      "priority": "$priority"
    }
    ''';
  }
}