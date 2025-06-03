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
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false; // برای نمایش CircularProgressIndicator هنگام ثبت نام

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

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      String username = _usernameController.text;
      String email = _emailController.text;
      // String password = _passwordController.text; // از چاپ رمز عبور خودداری کنید

      print('SignUpScreen: Form is valid. Attempting to sign up...');
      print('Username: $username, Email: $email');

      // شبیه‌سازی تاخیر شبکه و ارتباط با بک‌اند برای ثبت نام
      await Future.delayed(const Duration(seconds: 2));

      // TODO: اینجا باید با بک‌اند ارتباط برقرار کنید، نام کاربری را برای تکراری نبودن بررسی کنید
      // و در صورت موفقیت، کاربر را ثبت کنید.
      bool signupSuccess = true; // برای تست، فرض می‌کنیم ثبت نام همیشه موفق است

      if (mounted) {
        if (signupSuccess) {
          // TODO: پس از ثبت نام موفق و دریافت پاسخ از سرور (مثلا توکن یا اطلاعات کاربر)
          // می‌توانید آن‌ها را در SharedPreferences ذخیره کنید، مشابه آنچه در LoginScreen گفته شد.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Signup successful! Welcome, $username!')),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainTabsScreen()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Signup failed. Username or email might be taken, or server error.')),
          );
        }
        setState(() => _isLoading = false);
      }
    } else {
      print('SignUpScreen: Form is invalid.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please correct the errors in the form.')),
        );
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
    // PDF: "و نباید دقیقا شامل نام کاربری باشد"
    // این بررسی در فرانت‌اند کمی پیچیده‌تر است چون نیاز به دسترسی به مقدار فیلد نام کاربری دارد.
    // یک راه حل، بررسی این مورد در متد _signUp قبل از ارسال به سرور است.
    // if (_usernameController.text.isNotEmpty && value.toLowerCase().contains(_usernameController.text.toLowerCase())) {
    //   return 'Password should not contain your username';
    // }
    return null;
  }

  void _signUpWithGoogle() {
    // TODO: پیاده‌سازی واقعی ثبت نام با گوگل
    print('SignUpScreen: Sign Up with Google pressed (TODO)');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign up with Google is not yet implemented.')),
    );
  }

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
              autovalidateMode: AutovalidateMode.onUserInteraction, // برای نمایش خطاها به محض تایپ
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
                    validator: _validatePassword, // استفاده از ولیدیتور جدید
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
                    onPressed: _signUpWithGoogle, // استفاده از متد جدید
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