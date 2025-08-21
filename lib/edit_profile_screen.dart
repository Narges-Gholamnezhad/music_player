// lib/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart'; // این import را اضافه کنید
import 'user_auth_provider.dart'; // این import را اضافه کنید
import 'socket_service.dart'; // این import را اضافه کنید
import 'dart:async'; // این import را اضافه کنید
// کلیدهای SharedPreferences برای نام و ایمیل
// **مهم:** این مقادیر باید دقیقاً با مقادیر مشابه در user_profile_screen.dart یکسان باشند
const String prefUserName = 'user_profile_name_v1';
const String prefUserEmail = 'user_profile_email_v1';
// const String prefUserPassword = 'user_profile_password_v1'; // برای ذخیره هش رمز عبور (سمت سرور بهتر است)

final SocketService _socketService = SocketService(); // یک نمونه از سرویس سوکت

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController =
      TextEditingController();

  bool _isLoading = false;
  SharedPreferences? _prefs;

  String _initialName = "";
  String _initialEmail = "";

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _loadCurrentUserData();
  }

  Future<void> _loadCurrentUserData() async {
    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _initialName = _prefs?.getString(prefUserName) ??
          "Narges Gholamnezhad"; // پیش‌فرض اولیه
      _initialEmail = _prefs?.getString(prefUserEmail) ??
          "nargesgholamnezhad02@gmail.com"; // پیش‌فرض اولیه
      _nameController.text = _initialName;
      _emailController.text = _initialEmail;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveProfileChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // گرفتن نام کاربری فعلی از Provider
      final currentUser = Provider.of<UserAuthProvider>(context, listen: false);
      if (!currentUser.isLoggedIn) {
        // ... مدیریت خطا ...
        setState(() => _isLoading = false);
        return;
      }
      final String username = currentUser.username!;

      // اتصال به سرور
      bool isConnected = await _socketService.connect();
      if (!isConnected && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot connect to server.')));
        setState(() => _isLoading = false);
        return;
      }

      // ساخت دستور برای سرور
      String command = "UPDATE_PROFILE::$username::${_emailController.text}";

      // یک listener موقت برای گرفتن پاسخ از سرور
      final completer = Completer<String>();
      StreamSubscription? subscription;
      subscription = _socketService.responses.listen((response) {
        if (!completer.isCompleted) {
          subscription?.cancel();
          completer.complete(response);
        }
      });

      _socketService.sendCommand(command);

      try {
        final serverResponse = await completer.future.timeout(const Duration(seconds: 5));

        if (serverResponse == "UPDATE_SUCCESS") {
          // اگر موفق بود، Provider را هم در فرانت‌اند آپدیت کن
          await Provider.of<UserAuthProvider>(context, listen: false)
              .updateProfile(username, _emailController.text);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile updated successfully!')),
            );
            Navigator.of(context).pop(true); // بازگشت به صفحه پروفایل
          }
        } else {
          final errorMessage = serverResponse.split("::").last.replaceAll("_", " ");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Update Failed: $errorMessage')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('An error occurred: $e')),
          );
        }
      } finally {
        subscription?.cancel();
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  if (value.length < 3) {
                    return 'Name must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
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
              const SizedBox(height: 24),
              Text("Change Password (Optional)",
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                  controller: _currentPasswordController,
                  decoration:
                      const InputDecoration(labelText: 'Current Password'),
                  obscureText: true,
                  // ولیدیتور برای این فیلد زمانی فعال می‌شود که کاربر قصد تغییر رمز را دارد
                  validator: (value) {
                    if (_newPasswordController.text.isNotEmpty &&
                        (value == null || value.isEmpty)) {
                      return 'Enter current password to change it';
                    }
                    return null;
                  }),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                decoration: const InputDecoration(
                    labelText:
                        'New Password (min. 8 chars, upper, lower, digit)'),
                obscureText: true,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
                      return 'Must contain an uppercase letter';
                    }
                    if (!RegExp(r'(?=.*[a-z])').hasMatch(value)) {
                      return 'Must contain a lowercase letter';
                    }
                    if (!RegExp(r'(?=.*\d)').hasMatch(value)) {
                      return 'Must contain a digit';
                    }
                  }
                  // اگر رمز فعلی وارد شده ولی رمز جدید خالی است
                  if (_currentPasswordController.text.isNotEmpty &&
                      (value == null || value.isEmpty)) {
                    return 'Please enter new password or clear current password field';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmNewPasswordController,
                decoration:
                    const InputDecoration(labelText: 'Confirm New Password'),
                obscureText: true,
                validator: (value) {
                  if (_newPasswordController.text.isNotEmpty &&
                      value != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveProfileChanges,
                      child: const Text('Save Changes'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
