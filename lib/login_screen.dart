// lib/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'signup_screen.dart';
// import 'main_tabs_screen.dart'; // دیگر مستقیما به اینجا navigate نمی‌کنیم
import 'user_auth_provider.dart';
// import 'splash_screen.dart'; // دیگر لازم نیست

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
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

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please correct the errors in the form.')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    String usernameOrEmail = _usernameController.text;
    // String password = _passwordController.text; // برای ارسال به بک‌اند

    print('LoginScreen: Form is valid. Attempting to login...');
    print('Username/Email: $usernameOrEmail');

    // شبیه‌سازی ارتباط با بک‌اند
    await Future.delayed(const Duration(seconds: 1));

    bool loginSuccess = true; // فرض می‌کنیم لاگین همیشه موفق است
    String simulatedToken = "simulated_token_for_${usernameOrEmail.hashCode}";
    String fetchedUsername = usernameOrEmail.contains('@') ? usernameOrEmail.split('@')[0] : usernameOrEmail;
    String? fetchedEmail = usernameOrEmail.contains('@') ? usernameOrEmail : "$fetchedUsername@example.com";

    if (mounted) {
      if (loginSuccess) {
        try {
          await Provider.of<UserAuthProvider>(context, listen: false).login(
            usernameOrEmail,
            simulatedToken,
            fetchedUsername: fetchedUsername,
            fetchedEmail: fetchedEmail,
          );

          print('LoginScreen: Login successful. Navigating back...');
          if (mounted) { // بررسی مجدد mounted بودن
            Navigator.of(context).pop(); // <--- تغییر: فقط pop می‌کنیم
            // UserProfileScreen (یا هر صفحه‌ای که این را push کرده) با تغییر Provider آپدیت می‌شود.
          }
        } catch (e) {
          print('LoginScreen: Error during provider login: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('An error occurred during login: $e')),
            );
          }
        }
      } else {
        if (mounted) { // اطمینان از mounted بودن قبل از نمایش SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login failed. Invalid username or password.')),
          );
        }
      }
      if (mounted) { // بررسی مجدد mounted بودن
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleForgotPassword() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Forgot Password'),
          content: const Text('This feature is not yet implemented.'),
          actions: <Widget>[
            TextButton(child: const Text('OK'), onPressed: () => Navigator.of(context).pop()),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final Color iconColor = Colors.grey[500]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        // automaticallyImplyLeading: true, // حالا باید دکمه بازگشت نمایش داده شود
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('Welcome back!', textAlign: TextAlign.center, style: textTheme.headlineSmall?.copyWith(color: colorScheme.onBackground, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Enter your login information below', textAlign: TextAlign.center, style: textTheme.titleMedium?.copyWith(color: colorScheme.onBackground.withOpacity(0.7))),
                  const SizedBox(height: 40.0),
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(labelText: 'Username or Email', prefixIcon: Icon(Icons.person_outline, color: iconColor, size: 20)),
                    validator: _validateUsernameOrEmail,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20.0),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline, color: iconColor, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: iconColor, size: 20),
                        onPressed: _togglePasswordVisibility,
                      ),
                    ),
                    obscureText: !_isPasswordVisible,
                    validator: _validatePassword,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                  const SizedBox(height: 16.0),
                  Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _handleForgotPassword, child: const Text('Forgot password?'))),
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
                      Text("Don't have an account? ", style: TextStyle(color: colorScheme.onBackground.withOpacity(0.7), fontSize: 14.0)),
                      GestureDetector(
                        onTap: () {
                          // به جای pushReplacement، از push استفاده می‌کنیم تا کاربر بتواند به صفحه لاگین بازگردد
                          // یا اگر می‌خواهیم SignUp جایگزین Login شود و از SignUp نتوان به Login بازگشت:
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SignUpScreen()));
                        },
                        child: Text('Sign Up', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14.0)),
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