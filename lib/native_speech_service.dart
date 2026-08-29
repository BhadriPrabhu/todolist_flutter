import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NativeSpeechService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.todo/speech',
  );

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
      debugPrint('Sending text to Gemini Cloud API...');

      // 1. Get the current time and its exact timezone offset
      final now = DateTime.now();
      final String currentTime = now.toIso8601String();
      final String timeZoneName = now.timeZoneName;
      final Duration offset = now.timeZoneOffset;
      final String formattedOffset =
          '${offset.isNegative ? '-' : '+'}${offset.inHours.abs().toString().padLeft(2, '0')}:${(offset.inMinutes.abs() % 60).toString().padLeft(2, '0')}';

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
        // 2. Update the system instruction with the new offset
        systemInstruction: Content.system('''
        You are a strict data extraction API for a to-do list app. Extract the task details from the following text and return ONLY a valid JSON object.
        
        CRITICAL CONTEXT: 
        - The current local date and time is $currentTime.
        - The user's timezone is $timeZoneName (UTC $formattedOffset).
        - Use this EXACT timezone and current time to calculate absolute dates for relative terms spoken by the user (like "tomorrow at 9 AM").
        - Always return the `dueDate` as a strict UTC ISO-8601 formatted date string (ending in 'Z') that correctly offsets the calculated local time.
        
        RULES:
        1. The "description" field is MANDATORY. Do not leave it empty or null. If no extra details are spoken, set the description to the exact raw text the user spoke.
        2. The "alarm" field must be STRICTLY `true` ONLY if the user explicitly mentions words like "alarm", "ring", "alert", or "wake me up". If they only mention a due date or time (e.g., "reminder for tomorrow at 9 AM"), "alarm" must be `false` (even if a time is present).
        3. Do not include markdown formatting or conversational filler.
        
        Output schema:
        {
          "title": "Main task name (max 50 chars)",
          "description": "More context or details (MANDATORY. If no extra context, put the exact raw spoken text here)",
          "notes": "Any extra conditions or items mentioned",
          "category": "Work, Personal, Urgent, or null",
          "priority": "high or low",
          "dueDate": "A strict UTC ISO-8601 formatted date string (e.g., 2026-09-06T03:30:00Z) or null if no time is mentioned",
          "alarm": true if a specific time was mentioned, otherwise false
        }
      '''),
      );

      final response = await model.generateContent([Content.text(text)]);
      return response.text;
    } catch (e) {
      debugPrint(
        "Cloud AI failed (Limit/Network). Using offline fallback. Error: '$e'",
      );
      return _offlineFallbackParse(text);
    }
  }

  String _offlineFallbackParse(String rawText) {
    // Truncate title to 50 chars to match your schema
    String safeTitle =
        rawText.length > 50 ? '${rawText.substring(0, 47)}...' : rawText;

    // Check for basic keywords to guess priority/category offline
    String priority = rawText.toLowerCase().contains('urgent') ? 'high' : 'low';
    String? category;
    if (rawText.toLowerCase().contains('work')) category = 'Work';
    if (rawText.toLowerCase().contains('buy') ||
        rawText.toLowerCase().contains('groceries'))
      category = 'Personal';

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
