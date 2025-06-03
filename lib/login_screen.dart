// lib/login_screen.dart
import 'package:flutter/material.dart';
import 'signup_screen.dart';
import 'main_tabs_screen.dart'; // یا هر صفحه‌ای که بعد از لاگین موفق باید برود

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
  bool _isLoading = false; // برای نمایش CircularProgressIndicator

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
    // می‌توانید شرط‌های بیشتری برای فرمت ایمیل یا طول نام کاربری اضافه کنید
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    // می‌توانید شرط حداقل طول رمز عبور را اینجا هم اضافه کنید
    // if (value.length < 8) {
    //   return 'Password must be at least 8 characters';
    // }
    return null;
  }

  Future<void> _login() async {
    // ابتدا اعتبارسنجی فرم
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true); // نمایش لودینگ

      // فرم معتبر است، اینجا باید اطلاعات به بک‌اند ارسال شود
      String usernameOrEmail = _usernameController.text;
      String password = _passwordController.text;

      print('LoginScreen: Form is valid. Attempting to login...');
      print('Username/Email: $usernameOrEmail');
      // print('Password: $password'); // از چاپ رمز عبور در لاگ‌های نهایی خودداری کنید

      // شبیه‌سازی تاخیر شبکه و ارتباط با بک‌اند
      await Future.delayed(const Duration(seconds: 2));

      // TODO: اینجا باید با بک‌اند ارتباط برقرار کنید و پاسخ را بررسی کنید.
      // bool loginSuccess = await AuthService.login(usernameOrEmail, password); // مثال
      bool loginSuccess = true; // برای تست، فرض می‌کنیم لاگین همیشه موفق است
      // در پروژه واقعی، این مقدار باید از پاسخ سرور بیاید

      if (mounted) { // بررسی اینکه ویجت هنوز در درخت ویجت‌ها وجود دارد
        if (loginSuccess) {
          // TODO: ذخیره اطلاعات کاربر یا توکن در SharedPreferences
          // await PrefsService.setUserLoggedIn(true);
          // await PrefsService.saveUserToken("some_auth_token");

          Navigator.pushReplacement( // استفاده از pushReplacement تا کاربر نتواند به صفحه لاگین برگردد
            context,
            MaterialPageRoute(builder: (context) => const MainTabsScreen()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login failed. Invalid username or password.')),
          );
        }
        setState(() => _isLoading = false); // پنهان کردن لودینگ
      }
    } else {
      // اگر فرم معتبر نیست، پیام مناسب توسط validator ها نمایش داده می‌شود.
      print('LoginScreen: Form is invalid.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please correct the errors in the form.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final Color iconColor = Colors.grey[500]!; // یا از theme.inputDecorationTheme.prefixIconColor

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        // می‌توانید leading را برای بازگشت به AuthScreen اضافه کنید اگر لازم است
        // leading: IconButton(
        //   icon: Icon(Icons.arrow_back),
        //   onPressed: () => Navigator.of(context).pop(),
        // ),
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
                  Text(
                    'Welcome back!',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onBackground,
                      fontWeight: FontWeight.bold, // اضافه کردن bold برای تاکید
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your login information below', // تغییر متن برای وضوح بیشتر
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onBackground.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 40.0),
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username or Email', // استفاده از labelText
                      // hintText: 'Username / Email', // hintText در صورت نیاز
                      prefixIcon: Icon(Icons.person_outline, color: iconColor, size: 20),
                      // بقیه استایل‌ها از theme.inputDecorationTheme خوانده می‌شوند
                    ),
                    validator: _validateUsernameOrEmail,
                    autovalidateMode: AutovalidateMode.onUserInteraction, // اعتبارسنجی هنگام تعامل کاربر
                    keyboardType: TextInputType.emailAddress, // برای نمایش کیبورد مناسب
                  ),
                  const SizedBox(height: 20.0),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline, color: iconColor, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: iconColor,
                          size: 20,
                        ),
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
                      onPressed: () {
                        // TODO: پیاده‌سازی فراموشی رمز عبور
                        print('LoginScreen: Forgot password pressed (TODO)');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Forgot password functionality is not implemented yet.')),
                        );
                      },
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 24.0),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                    style: theme.elevatedButtonTheme.style, // استفاده از تم تعریف شده در main.dart
                    onPressed: _login,
                    child: const Text('Login'),
                  ),
                  const SizedBox(height: 40.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account? ",
                          style: TextStyle(color: colorScheme.onBackground.withOpacity(0.7), fontSize: 14.0)),
                      GestureDetector(
                        onTap: () {
                          Navigator.push( // استفاده از push به جای pushReplacement تا کاربر بتواند به صفحه لاگین برگردد اگر بخواهد
                            context,
                            MaterialPageRoute(builder: (context) => const SignUpScreen()),
                          );
                        },
                        child: Text(
                          'Sign Up',
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