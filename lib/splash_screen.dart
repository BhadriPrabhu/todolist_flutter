import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _opacity = 0.0;
  double _offsetY = 30.0;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      setState(() {
        _opacity = 1.0;
        _offsetY = 0.0;
      });
      Future.delayed(const Duration(seconds: 3), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // High-contrast white background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedOpacity(
              opacity: _opacity,
              duration: const Duration(milliseconds: 1800),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 1800),
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(0, _offsetY, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/image/logo.png',
                    width: 100,
                    height: 100,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            AnimatedOpacity(
              opacity: _opacity,
              duration: const Duration(milliseconds: 1800),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 1800),
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(0, _offsetY, 0),
                child: Text(
                  'To-Do List',
                  style: GoogleFonts.poppins(
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87, // High-contrast text
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            AnimatedOpacity(
              opacity: _opacity,
              duration: const Duration(milliseconds: 1800),
              child: Text(
                'Crafted by Bhadri Prabhu K',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[700], // Improved secondary text contrast
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}