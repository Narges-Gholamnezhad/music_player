// lib/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// کلیدهای SharedPreferences برای نام و ایمیل
// **مهم:** این مقادیر باید دقیقاً با مقادیر مشابه در user_profile_screen.dart یکسان باشند
const String prefUserName = 'user_profile_name_v1';
const String prefUserEmail = 'user_profile_email_v1';
// const String prefUserPassword = 'user_profile_password_v1'; // برای ذخیره هش رمز عبور

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
      _initialName = _prefs?.getString(prefUserName) ?? "Narges Gholamnezhad";
      _initialEmail = _prefs?.getString(prefUserEmail) ?? "nargesgholamnezhad02@gmail.com";
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
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter current password to change password.')));
          canSaveChanges = false;
        }
        // TODO: اعتبارسنجی رمز عبور فعلی با مقدار ذخیره شده در سرور/prefs
      }

      if (canSaveChanges) {
        // اطمینان از مقداردهی _prefs
        _prefs ??= await SharedPreferences.getInstance();

        await _prefs?.setString(prefUserName, _nameController.text);
        await _prefs?.setString(prefUserEmail, _emailController.text);
        print("EditProfileScreen: Saved new name: ${_nameController.text}, email: ${_emailController.text}");


        if (passwordChanged) {
          // TODO: هش کردن و ذخیره رمز عبور جدید
          print("Password would be changed to: ${_newPasswordController.text}");
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
          Navigator.of(context).pop(true); // برگرداندن true برای نشان دادن موفقیت
        }
      }
      // setState باید خارج از if (canSaveChanges) باشد تا isLoading در هر صورت false شود
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
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
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
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                decoration: const InputDecoration(labelText: 'New Password'),
                obscureText: true,
                validator: (value) {
                  if (value != null && value.isNotEmpty && value.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  if (_currentPasswordController.text.isNotEmpty && (value == null || value.isEmpty)) {
                    return 'Please enter new password if changing';
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