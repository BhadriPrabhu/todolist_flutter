import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'home_screen.dart';
import 'splash_screen.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  final notificationService = NotificationService();
  await notificationService.initialize();
  runApp(const ToDoListApp());
}

class ToDoListApp extends StatelessWidget {
  const ToDoListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To Do List',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Poppins'),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF212121),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Poppins'),
      ),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}