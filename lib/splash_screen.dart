// lib/splash_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'auth_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    print("SplashScreen: initState called");
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        print("SplashScreen: Timer finished, navigating to AuthScreen");
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (BuildContext context) => const AuthScreen(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    print("SplashScreen: build called");
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.music_note,
              size: 120.0,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 24.0),
            Text(
              'Music Player',
              style: textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onBackground,
                    fontWeight: FontWeight.bold,
                  ) ??
                  TextStyle(
                    fontSize: 28.0,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onBackground,
                  ),
            ),
            const SizedBox(height: 20.0),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
