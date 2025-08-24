// lib/signup_screen.dart
import 'socket_service.dart';
import 'dart:async'; // برای استفاده از Completer
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart'; // <--- اضافه شد
import 'login_screen.dart';

// import 'main_tabs_screen.dart'; // دیگر مستقیما به اینجا navigate نمی‌کنیم
import 'user_auth_provider.dart'; // <--- اضافه شد

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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _socketService.connect(); // به سرور وصل شو
  }

  @override
  void dispose() {
    // _socketService.disconnect(); // ما فعلا قطع نمی‌کنیم تا بین صفحات اتصال حفظ شود
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

  Future<void> _signUp() async {
    // بررسی اعتبار فرم
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    // اتصال به سرور (اگر وصل نیست)
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

    String username = _usernameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text;

    // ساخت دستور برای ارسال به سرور
    String command = "REGISTER::$username::$email::$password";

    // یک listener موقت برای گرفتن اولین پاسخ از سرور
    final completer = Completer<String>();
    StreamSubscription? subscription;
    subscription = _socketService.responses.listen((response) {
      // مطمئن می‌شویم که listener فقط یک بار پاسخ را دریافت کند
      if (!completer.isCompleted) {
        subscription?.cancel(); // بعد از دریافت پاسخ، listener را غیرفعال کن
        completer.complete(response);
      }
    });

    // ارسال دستور
    _socketService.sendCommand(command);

    try {
      // منتظر پاسخ از سرور برای حداکثر 5 ثانیه
      final serverResponse =
          await completer.future.timeout(const Duration(seconds: 5));

      if (serverResponse == "REGISTER_SUCCESS") {
        // در سناریوی واقعی، سرور باید توکن را برگرداند
        String simulatedToken = "real-token-from-server-would-go-here";
        await Provider.of<UserAuthProvider>(context, listen: false)
            .signUpAndLogin(username, email, simulatedToken);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Welcome, $username! Signup was successful.')),
          );
          // بازگشت به صفحه پروفایل که حالا حالت لاگین شده را نشان می‌دهد
          Navigator.of(context).pop();
        }
      } else {
        // نمایش خطای دریافت شده از سرور
        final errorMessage =
            serverResponse.split("::").last.replaceAll("_", " ");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Signup Failed: $errorMessage')),
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
      // لغو listener در صورت بروز خطا یا تایم‌اوت
      subscription?.cancel();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'(?=.*[a-z])').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!RegExp(r'(?=.*\d)').hasMatch(value)) {
      return 'Password must contain at least one digit';
    }
    // اگر می‌خواهید ولیدیتور نام کاربری در پسورد را فعال کنید:
    // if (_usernameController.text.isNotEmpty && value.toLowerCase().contains(_usernameController.text.toLowerCase())) {
    //   return 'Password should not contain your username';
    // }
    return null;
  }

  void _signUpWithGoogle() {
    print('SignUpScreen: Sign Up with Google pressed (TODO)');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Sign up with Google is not yet implemented.')),
      );
    }
  }

  final SocketService _socketService =
      SocketService(); // <-- این خط را اضافه کنید

  @override
  Widget build(BuildContext context) {
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
              autovalidateMode: AutovalidateMode.onUserInteraction,
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
                      prefixIcon: Icon(Icons.person_outline,
                          color: iconColor, size: 20),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a username';
                      }
                      if (value.length < 4) {
                        return 'Username must be at least 4 characters';
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
                      prefixIcon: Icon(Icons.email_outlined,
                          color: iconColor, size: 20),
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
                    ),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 20.0),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_isConfirmPasswordVisible,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Confirm Password',
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
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          style: theme.elevatedButtonTheme.style?.copyWith(
                            backgroundColor:
                                MaterialStateProperty.all(colorScheme.primary),
                            foregroundColor: MaterialStateProperty.all(
                                colorScheme.onPrimary),
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
                    onPressed: _signUpWithGoogle,
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
                          // اگر از صفحه لاگین به اینجا آمده‌ایم، pop می‌کنیم
                          // اگر مستقیما از UserProfileScreen به SignUp آمده‌ایم، باز هم pop می‌کنیم

                          // این حالت نباید زیاد پیش بیاید در سناریوی جدید
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const LoginScreen()),
                          );
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
