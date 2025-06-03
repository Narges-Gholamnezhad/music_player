// lib/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// کلیدهای SharedPreferences برای نام و ایمیل
// **مهم:** این مقادیر باید دقیقاً با مقادیر مشابه در user_profile_screen.dart یکسان باشند
const String prefUserName = 'user_profile_name_v1';
const String prefUserEmail = 'user_profile_email_v1';
// const String prefUserPassword = 'user_profile_password_v1'; // برای ذخیره هش رمز عبور (سمت سرور بهتر است)

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController = TextEditingController();

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
      _initialName = _prefs?.getString(prefUserName) ?? "Narges Gholamnezhad"; // پیش‌فرض اولیه
      _initialEmail = _prefs?.getString(prefUserEmail) ?? "nargesgholamnezhad02@gmail.com"; // پیش‌فرض اولیه
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

      bool passwordChanged = _newPasswordController.text.isNotEmpty;
      bool canSaveChanges = true;

      if (passwordChanged) {
        if (_currentPasswordController.text.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter your current password to set a new one.'))
            );
          }
          canSaveChanges = false;
        }
        // TODO: اعتبارسنجی رمز عبور فعلی با مقدار ذخیره شده (ایده‌آل در بک‌اند).
        // در فرانت‌اند، بدون دسترسی به رمز فعلی (که نباید ذخیره شود)، این اعتبارسنجی ممکن نیست.
        // این بخش باید توسط سرور انجام شود.
        // مثال: bool isCurrentPasswordValid = await AuthService.verifyPassword(_currentPasswordController.text);
        // if (!isCurrentPasswordValid) {
        //   if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Current password is incorrect.')));
        //   canSaveChanges = false;
        // }
      }

      if (canSaveChanges) {
        _prefs ??= await SharedPreferences.getInstance();

        await _prefs?.setString(prefUserName, _nameController.text);
        await _prefs?.setString(prefUserEmail, _emailController.text);
        print("EditProfileScreen: Saved new name: ${_nameController.text}, email: ${_emailController.text}");

        if (passwordChanged) {
          // TODO: هش کردن و ذخیره رمز عبور جدید باید در بک‌اند انجام شود.
          // فرانت‌اند فقط رمز جدید را به صورت امن (HTTPS) به سرور ارسال می‌کند.
          // مثال: await AuthService.changePassword(_newPasswordController.text);
          print("Password change requested. New password (raw, for demo): ${_newPasswordController.text}");
          // در یک برنامه واقعی، رمز عبور خام هرگز نباید چاپ یا به راحتی ذخیره شود.
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
          Navigator.of(context).pop(true); // برگرداندن true برای نشان دادن موفقیت و رفرش صفحه پروفایل
        }
      }
      if (mounted) {
        setState(() => _isLoading = false);
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
                  if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text("Change Password (Optional)", style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                  controller: _currentPasswordController,
                  decoration: const InputDecoration(labelText: 'Current Password'),
                  obscureText: true,
                  // ولیدیتور برای این فیلد زمانی فعال می‌شود که کاربر قصد تغییر رمز را دارد
                  validator: (value) {
                    if (_newPasswordController.text.isNotEmpty && (value == null || value.isEmpty)) {
                      return 'Enter current password to change it';
                    }
                    return null;
                  }
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                decoration: const InputDecoration(labelText: 'New Password (min. 8 chars, upper, lower, digit)'),
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
                  if (_currentPasswordController.text.isNotEmpty && (value == null || value.isEmpty)) {
                    return 'Please enter new password or clear current password field';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmNewPasswordController,
                decoration: const InputDecoration(labelText: 'Confirm New Password'),
                obscureText: true,
                validator: (value) {
                  if (_newPasswordController.text.isNotEmpty && value != _newPasswordController.text) {
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