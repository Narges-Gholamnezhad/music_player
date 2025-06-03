// lib/splash_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'auth_screen.dart';
import 'main_tabs_screen.dart';
import 'user_auth_provider.dart';

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
    _checkLoginStatusAndNavigate();
  }

  Future<void> _checkLoginStatusAndNavigate() async {
    // UserAuthProvider در main.dart ساخته شده و _loadUserFromPrefs را در سازنده خود فراخوانی می‌کند.
    // بنابراین، وقتی به اینجا می‌رسیم، باید وضعیت اولیه بارگذاری شده باشد.
    // با این حال، برای اطمینان، می‌توانیم با یک تاخیر بسیار کوچک منتظر بمانیم یا
    // از addPostFrameCallback استفاده کنیم تا مطمئن شویم Provider کاملا مقداردهی اولیه شده.

    // استفاده از addPostFrameCallback برای اطمینان از اینکه build اولیه تمام شده
    // و context برای Provider.of در دسترس است.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userAuthProvider = Provider.of<UserAuthProvider>(context, listen: false);
      print("SplashScreen: UserAuthProvider.isLoggedIn after initial load: ${userAuthProvider.isLoggedIn}");

      Timer(const Duration(seconds: 2), () { // تاخیر کلی 2 ثانیه‌ای برای نمایش اسپلش
        if (mounted) {
          if (userAuthProvider.isLoggedIn) {
            print("SplashScreen: User is logged in, navigating to MainTabsScreen");
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (BuildContext context) => const MainTabsScreen()),
            );
          } else {
            print("SplashScreen: User is NOT logged in, navigating to AuthScreen");
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (BuildContext context) => const AuthScreen()),
            );
          }
        }
      });
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