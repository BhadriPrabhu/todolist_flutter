import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class NativeSpeechService {
  static const MethodChannel _channel = MethodChannel('com.example.todo/speech');

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
}