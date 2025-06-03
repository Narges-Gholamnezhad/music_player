// lib/splash_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart'; // لازم نیست اگر مستقیما UserAuthProvider را چک نمی‌کنیم
import 'main_tabs_screen.dart';
// import 'auth_screen.dart'; // دیگر لازم نیست
// import 'user_auth_provider.dart'; // دیگر لازم نیست مستقیما اینجا چک شود

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
    _navigateToMainTabs(); // تغییر نام متد
  }

  Future<void> _navigateToMainTabs() async {
    // UserAuthProvider در main.dart نمونه‌سازی شده و وضعیت اولیه را از SharedPreferences می‌خواند.
    // ما مستقیما به MainTabsScreen می‌رویم و آنجا UserProfileScreen وضعیت لاگین را بررسی می‌کند.
    Timer(const Duration(seconds: 2), () { // تاخیر برای نمایش اسپلش
      if (mounted) {
        print("SplashScreen: Navigating to MainTabsScreen");
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (BuildContext context) => const MainTabsScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    print("SplashScreen: build called");
    // ... (بقیه کد build بدون تغییر) ...
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