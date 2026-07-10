import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class NativeSpeechService {
  static const MethodChannel _channel = MethodChannel('com.example.todo/speech');
  
  Future<String?> startListening() async {
    try {
      debugPrint('Calling native Android speech recognizer...');
      final String? result = await _channel.invokeMethod('startListening');
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed to recognize speech: '${e.message}'.");
      return null;
    }
  }
}