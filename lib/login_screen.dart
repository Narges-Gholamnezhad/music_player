import 'package:flutter/material.dart';
import 'socket_service.dart'; // برای ارتباط با سرور
import 'dart:async'; // برای Completer و Timeout
import 'package:provider/provider.dart';
import 'signup_screen.dart';
import 'user_auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // --- بخش ۱: متغیرها ---
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  // ایجاد یک نمونه از سرویس سوکت
  final SocketService _socketService = SocketService();

  // --- بخش ۲: متدهای چرخه حیات (initState, dispose) ---
  @override
  void initState() {
    super.initState();
    // تلاش برای اتصال به سرور به محض باز شدن صفحه
    _socketService.connect();
  }

  @override
  void dispose() {
    // Controller ها را حتما dispose کنید تا از memory leak جلوگیری شود
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- بخش ۳: متدهای منطقی (login, validators, etc.) ---

  // متد اصلی برای ورود کاربر که با سرور ارتباط برقرار می‌کند
  Future<void> _login() async {
    // ۱. بررسی اعتبار فرم
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    // ۲. اطمینان از اتصال به سرور
    bool isConnected = await _socketService.connect();
    if (!isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot connect to the server.')),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    // ۳. آماده‌سازی دستور برای ارسال
    String username = _usernameController.text.trim();
    String password = _passwordController.text;
    String command = "LOGIN::$username::$password";

    // ۴. ایجاد یک listener موقت برای گرفتن اولین پاسخ از سرور
    final completer = Completer<String>();
    StreamSubscription? subscription;
    subscription = _socketService.responses.listen((response) {
      if (!completer.isCompleted) {
        subscription?.cancel(); // بعد از دریافت پاسخ، listener را غیرفعال کن
        completer.complete(response);
      }
    });

    // ۵. ارسال دستور به سرور
    _socketService.sendCommand(command);

    // ۶. منتظر ماندن برای پاسخ و مدیریت نتایج
    try {
      final serverResponse =
          await completer.future.timeout(const Duration(seconds: 5));

      // Find the old "if (serverResponse == "LOGIN_SUCCESS")" and replace it with this

      if (serverResponse.startsWith("LOGIN_SUCCESS")) {
        final parts = serverResponse.split("::");
        // parts[0] is LOGIN_SUCCESS
        // parts[1] is the username from the file
        // parts[2] is the email from the file
        if (parts.length == 3) {
          String tokenFromServer =
              "real-token-for-${parts[1]}"; // Example token

          // Give the provider the REAL username and email from the server
          await Provider.of<UserAuthProvider>(context, listen: false).login(
              username, // The username the user typed in
              tokenFromServer,
              fetchedUsername: parts[1], // The username from the file
              fetchedEmail: parts[2] // The email from the file
              );

          if (mounted) {
            // Close the login screen and go back to the profile page
            Navigator.of(context).pop();
          }
        } else {
          // This happens if the server sent a bad response
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Login Failed: Bad server response.')));
          }
        }
      } else {
        // This handles LOGIN_FAILED responses
        final errorMessage =
            serverResponse.split("::").last.replaceAll("_", " ");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login Failed: $errorMessage')),
          );
        }
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server did not respond in time.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    } finally {
      subscription?.cancel(); // حتما listener را در انتها پاک کن
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  String? _validateUsernameOrEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your username or email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    return null;
  }

  void _handleForgotPassword() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Forgot Password'),
          content: const Text('This feature is not yet implemented.'),
          actions: <Widget>[
            TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop()),
          ],
        );
      },
    );
  }

  // --- بخش ۴: متد Build (رابط کاربری) ---
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final Color iconColor = Colors.grey[500]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
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
                  Text('Welcome back!',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onBackground,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Enter your login information below',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onBackground.withOpacity(0.7))),
                  const SizedBox(height: 40.0),
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                        labelText: 'Username or Email',
                        prefixIcon: Icon(Icons.person_outline,
                            color: iconColor, size: 20)),
                    validator: _validateUsernameOrEmail,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20.0),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon:
                          Icon(Icons.lock_outline, color: iconColor, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: iconColor,
                            size: 20),
                        onPressed: _togglePasswordVisibility,
                      ),
                    ),
                    obscureText: !_isPasswordVisible,
                    validator: _validatePassword,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                  const SizedBox(height: 16.0),
                  Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                          onPressed: _handleForgotPassword,
                          child: const Text('Forgot password?'))),
                  const SizedBox(height: 24.0),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          style: theme.elevatedButtonTheme.style,
                          onPressed: _login,
                          child: const Text('Login'),
                        ),
                  const SizedBox(height: 40.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account? ",
                          style: TextStyle(
                              color: colorScheme.onBackground.withOpacity(0.7),
                              fontSize: 14.0)),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const SignUpScreen()));
                        },
                        child: Text('Sign Up',
                            style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.0)),
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
