import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
// import 'home_screen.dart';
import 'splash_screen.dart';
import 'notification_service.dart';

import 'alarm_screen.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma("vm:entry-point")
Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
  await AwesomeNotifications().resetGlobalBadge();
  if (receivedAction.payload != null && receivedAction.payload!['isAlarm'] == 'true') {
    final taskId = receivedAction.payload!['taskId'] ?? '';
    final taskTitle = receivedAction.payload!['taskTitle'] ?? 'Task';

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => AlarmScreen(
          taskId: taskId,
          taskTitle: taskTitle,
        ),
      ),
    );
  }
}

@pragma("vm:entry-point")
Future<void> onDismissActionReceivedMethod(ReceivedAction receivedAction) async {
  await AwesomeNotifications().decrementGlobalBadgeCounter();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  tz.initializeTimeZones();
  final notificationService = NotificationService();
  await notificationService.initialize();

  await AwesomeNotifications().resetGlobalBadge();

  AwesomeNotifications().setListeners(
    onActionReceivedMethod: onActionReceivedMethod,
    onDismissActionReceivedMethod: onDismissActionReceivedMethod,
  );
  runApp(const ToDoListApp());
}

class ToDoListApp extends StatelessWidget {
  const ToDoListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To Do List',
      navigatorKey: navigatorKey,
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