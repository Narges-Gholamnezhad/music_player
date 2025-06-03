// lib/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'login_screen.dart';
import 'main_tabs_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
    });
  }

  void _signUp() {
    print(
        'SignUpScreen: Sign Up button pressed. Navigating to MainTabsScreen (validation & actual signup skipped).');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainTabsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    print("SignUpScreen: build called");
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final Color iconColor = Colors.grey[500]!;
    final Color secondaryTextColor = colorScheme.onSurface.withOpacity(0.6);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 10),
                  Text(
                    'Create your account',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 30.0),
                  TextFormField(
                    controller: _usernameController,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Username',
                      hintStyle: theme.inputDecorationTheme.hintStyle ??
                          TextStyle(color: Colors.grey[600]),
                      fillColor: theme.inputDecorationTheme.fillColor ??
                          const Color(0xFF2C2C2C),
                      filled: theme.inputDecorationTheme.filled ?? true,
                      prefixIcon: Icon(Icons.person_outline,
                          color: iconColor, size: 20),
                      contentPadding: theme.inputDecorationTheme.contentPadding,
                      border: theme.inputDecorationTheme.border,
                      enabledBorder: theme.inputDecorationTheme.enabledBorder,
                      focusedBorder: theme.inputDecorationTheme.focusedBorder,
                      errorBorder: theme.inputDecorationTheme.errorBorder,
                      focusedErrorBorder:
                          theme.inputDecorationTheme.focusedErrorBorder,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20.0),
                  TextFormField(
                    controller: _emailController,
                    style: TextStyle(color: colorScheme.onSurface),
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Email',
                      hintStyle: theme.inputDecorationTheme.hintStyle ??
                          TextStyle(color: Colors.grey[600]),
                      fillColor: theme.inputDecorationTheme.fillColor ??
                          const Color(0xFF2C2C2C),
                      filled: theme.inputDecorationTheme.filled ?? true,
                      prefixIcon: Icon(Icons.email_outlined,
                          color: iconColor, size: 20),
                      contentPadding: theme.inputDecorationTheme.contentPadding,
                      border: theme.inputDecorationTheme.border,
                      enabledBorder: theme.inputDecorationTheme.enabledBorder,
                      focusedBorder: theme.inputDecorationTheme.focusedBorder,
                      errorBorder: theme.inputDecorationTheme.errorBorder,
                      focusedErrorBorder:
                          theme.inputDecorationTheme.focusedErrorBorder,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(
                              r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                          .hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20.0),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: theme.inputDecorationTheme.hintStyle ??
                          TextStyle(color: Colors.grey[600]),
                      fillColor: theme.inputDecorationTheme.fillColor ??
                          const Color(0xFF2C2C2C),
                      filled: theme.inputDecorationTheme.filled ?? true,
                      prefixIcon:
                          Icon(Icons.lock_outline, color: iconColor, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: iconColor,
                          size: 20,
                        ),
                        onPressed: _togglePasswordVisibility,
                      ),
                      contentPadding: theme.inputDecorationTheme.contentPadding,
                      border: theme.inputDecorationTheme.border,
                      enabledBorder: theme.inputDecorationTheme.enabledBorder,
                      focusedBorder: theme.inputDecorationTheme.focusedBorder,
                      errorBorder: theme.inputDecorationTheme.errorBorder,
                      focusedErrorBorder:
                          theme.inputDecorationTheme.focusedErrorBorder,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 8) {
                        return 'Password must be at least 8 characters long';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20.0),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_isConfirmPasswordVisible,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Confirm Password',
                      hintStyle: theme.inputDecorationTheme.hintStyle ??
                          TextStyle(color: Colors.grey[600]),
                      fillColor: theme.inputDecorationTheme.fillColor ??
                          const Color(0xFF2C2C2C),
                      filled: theme.inputDecorationTheme.filled ?? true,
                      prefixIcon:
                          Icon(Icons.lock_outline, color: iconColor, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: iconColor,
                          size: 20,
                        ),
                        onPressed: _toggleConfirmPasswordVisibility,
                      ),
                      contentPadding: theme.inputDecorationTheme.contentPadding,
                      border: theme.inputDecorationTheme.border,
                      enabledBorder: theme.inputDecorationTheme.enabledBorder,
                      focusedBorder: theme.inputDecorationTheme.focusedBorder,
                      errorBorder: theme.inputDecorationTheme.errorBorder,
                      focusedErrorBorder:
                          theme.inputDecorationTheme.focusedErrorBorder,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 30.0),
                  ElevatedButton(
                    style: theme.elevatedButtonTheme.style?.copyWith(
                      backgroundColor:
                          MaterialStateProperty.all(colorScheme.primary),
                      foregroundColor:
                          MaterialStateProperty.all(colorScheme.onPrimary),
                    ),
                    onPressed: _signUp,
                    child: const Text('Sign up'),
                  ),
                  const SizedBox(height: 24.0),
                  Row(
                    children: <Widget>[
                      Expanded(
                          child: Divider(
                              color: secondaryTextColor.withOpacity(0.5))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('Or',
                            style: TextStyle(color: secondaryTextColor)),
                      ),
                      Expanded(
                          child: Divider(
                              color: secondaryTextColor.withOpacity(0.5))),
                    ],
                  ),
                  const SizedBox(height: 24.0),
                  OutlinedButton.icon(
                    icon: FaIcon(FontAwesomeIcons.google,
                        size: 20.0, color: colorScheme.primary),
                    label: Text(
                      'Sign Up with Google',
                      style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w500),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      side: BorderSide(
                          color: secondaryTextColor.withOpacity(0.7)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    onPressed: () {
                      print('SignUpScreen: Sign Up with Google pressed (TODO)');
                    },
                  ),
                  const SizedBox(height: 30.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Already have an account? ",
                          style: TextStyle(
                              color: secondaryTextColor, fontSize: 14.0)),
                      GestureDetector(
                        onTap: () {
                          print(
                              "SignUpScreen: Login link tapped, navigating to LoginScreen.");
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const LoginScreen()),
                            );
                          }
                        },
                        child: Text(
                          'Login',
                          style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20.0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
