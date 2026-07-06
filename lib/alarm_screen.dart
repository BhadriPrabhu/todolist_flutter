import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
// Import your theme config file here
import 'home_screen.dart'; 

class AlarmScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;

  const AlarmScreen({super.key, required this.taskId, required this.taskTitle});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    
    _startVibrationPattern();
  }

  void _startVibrationPattern() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [500, 1000, 500, 1000], repeat: 1);
    }
  }

  void _stopAlarm() async {
    Vibration.cancel();
    
    await AwesomeNotifications().cancel(widget.taskId.hashCode);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    Vibration.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.darkBackground,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                Icon(
                  Icons.alarm,
                  size: 60,
                  color: ThemeConfig.secondaryTextColor,
                ),
                const SizedBox(height: 20),
                Text(
                  'Task Due Now!',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    color: ThemeConfig.secondaryTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    widget.taskTitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      color: ThemeConfig.primaryTextColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            
            // Pulsing Alarm Icon
            ScaleTransition(
              scale: Tween(begin: 0.8, end: 1.2).animate(
                CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
              ),
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ThemeConfig.secondaryColor.withOpacity(0.2),
                ),
                child: Icon(
                  Icons.notifications_active,
                  size: 100,
                  color: ThemeConfig.secondaryColor,
                ),
              ),
            ),

            // Swipe to Stop Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ElevatedButton(
                onPressed: _stopAlarm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConfig.secondaryColor,
                  minimumSize: const Size(double.infinity, 65),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  'STOP ALARM',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}