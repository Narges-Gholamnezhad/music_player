// lib/auth_screen.dart
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    print("AuthScreen: build called");
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final Color innerContainerColor = colorScheme.primary;
    final Color buttonTextColor = colorScheme.onPrimary;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 60.0, bottom: 30.0),
              child: Text(
                'Welcome!',
                style: textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.secondary,
                    ) ??
                    TextStyle(
                      fontSize: 36.0,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.secondary,
                    ),
              ),
            ),
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      // کانتینر داخلی (کوچکتر)
                      width: screenWidth * 0.75,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 40.0),
                      decoration: BoxDecoration(
                        color: innerContainerColor.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          _buildAuthButton(
                            context: context,
                            text: 'Login',
                            buttonColor: Colors.white,
                            textColor: buttonTextColor,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const LoginScreen()),
                              );
                            },
                          ),
                          const SizedBox(height: 25.0),
                          _buildAuthButton(
                            context: context,
                            text: 'Sign Up',
                            buttonColor: Colors.white,
                            textColor: buttonTextColor,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const SignUpScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthButton({
    required BuildContext context,
    required String text,
    required Color buttonColor,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: textColor,
          padding: const EdgeInsets.symmetric(vertical: 18.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.0),
          ),
          elevation: 8,
          textStyle:
              const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        ),
        onPressed: onPressed,
        child: Text(text),
      ),
    );
  }
}
