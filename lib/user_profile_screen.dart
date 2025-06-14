// lib/user_profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'subscription_screen.dart' as sub_screen;
import 'favorites_screen.dart';
import 'edit_profile_screen.dart';
import 'main.dart'; // برای دسترسی به activeThemeMode
import 'shared_pref_keys.dart';
import 'user_auth_provider.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  SharedPreferences? _prefs;
  File? _profileImageFile;
  final ImagePicker _picker = ImagePicker();
  ThemeMode _currentAppTheme = ThemeMode.system;
  bool _isScreenSpecificDataLoading = true;

  @override
  void initState() {
    super.initState();
    _currentAppTheme = activeThemeMode.value;
    activeThemeMode.addListener(_updateLocalThemeState);
    _loadScreenSpecificData();
  }

  @override
  void dispose() {
    activeThemeMode.removeListener(_updateLocalThemeState);
    super.dispose();
  }

  void _updateLocalThemeState() {
    if (mounted && _currentAppTheme != activeThemeMode.value) {
      setState(() {
        _currentAppTheme = activeThemeMode.value;
      });
    }
  }

  Future<void> _loadScreenSpecificData() async {
    setState(() => _isScreenSpecificDataLoading = true);
    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final String? imagePath = _prefs!.getString(SharedPrefKeys.userProfileImagePath);
    File? tempImageFile;
    if (imagePath != null && imagePath.isNotEmpty) {
      tempImageFile = File(imagePath);
      if (!await tempImageFile.exists()) {
        tempImageFile = null;
        if (_prefs != null) { // اطمینان از null نبودن prefs
          await _prefs!.remove(SharedPrefKeys.userProfileImagePath);
        }
      }
    }

    final String savedTheme = _prefs!.getString(SharedPrefKeys.appThemeMode) ?? 'system';
    ThemeMode themeToSet;
    if (savedTheme == 'light') themeToSet = ThemeMode.light;
    else if (savedTheme == 'dark') themeToSet = ThemeMode.dark;
    else themeToSet = ThemeMode.system;

    if (mounted) {
      setState(() {
        _profileImageFile = tempImageFile;
        if (_currentAppTheme != themeToSet) {
          _currentAppTheme = themeToSet;
        }
        _isScreenSpecificDataLoading = false;
      });
    }
  }

  Future<void> _showImageSourceActionSheet(BuildContext context) async {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('Gallery'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _pickImage(ImageSource.gallery);
                    }),
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Camera'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          );
        });
  }

  Future<void> _pickImage(ImageSource source) async {
    _prefs ??= await SharedPreferences.getInstance(); // اطمینان از مقداردهی اولیه
    PermissionStatus status;
    if (source == ImageSource.camera) {
      status = await Permission.camera.request();
    } else {
      if (Platform.isAndroid) {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        if (androidInfo.version.sdkInt >= 33) { // Android 13+
          status = await Permission.photos.request();
        } else {
          status = await Permission.storage.request();
        }
      } else { // iOS or other platforms
        status = await Permission.photos.request();
      }
    }

    if (status.isGranted) {
      try {
        final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 70, maxWidth: 800);
        if (pickedFile != null) {
          final File newImage = File(pickedFile.path);
          final Directory appDir = await getApplicationDocumentsDirectory();
          final String fileName = 'profile_pic_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final String newPath = '${appDir.path}/$fileName';

          // حذف عکس قبلی اگر وجود دارد و مسیرش متفاوت است
          if (_profileImageFile != null && await _profileImageFile!.exists()) {
            try {
              if (_profileImageFile!.path != newPath) { // فقط اگر مسیر متفاوت است حذف کن
                await _profileImageFile!.delete();
              }
            } catch (e) {
              print("Error deleting old profile picture: $e");
            }
          }

          final File savedImage = await newImage.copy(newPath);
          if (mounted) {
            setState(() => _profileImageFile = savedImage);
            await _prefs!.setString(SharedPrefKeys.userProfileImagePath, savedImage.path);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile picture updated!")));
          }
        }
      } catch (e,s) {
        print("Error picking/saving image: $e\n$s");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update profile picture.")));
      }
    } else if (status.isPermanentlyDenied && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(source == ImageSource.camera ? 'Camera permission permanently denied.' : 'Gallery/Storage permission permanently denied.'),
            action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
          )
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(source == ImageSource.camera ? 'Camera permission denied.' : 'Gallery/Storage permission denied.'))
      );
    }
  }

  void _editProfile() async {
    final userAuthProvider = Provider.of<UserAuthProvider>(context, listen: false);
    if (!userAuthProvider.isLoggedIn) {
      _promptLogin("edit your profile");
      return;
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );
    if (result == true && mounted) {
      await Provider.of<UserAuthProvider>(context, listen: false).reloadUserDataFromPrefs();
    }
  }

  void _navigateToFavorites() async {
    final userAuthProvider = Provider.of<UserAuthProvider>(context, listen: false);
    if (!userAuthProvider.isLoggedIn) {
      _promptLogin("view your favorites");
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (context) => const FavoritesScreen()));
  }

  void _manageSubscription() async {
    final userAuthProvider = Provider.of<UserAuthProvider>(context, listen: false);
    if (!userAuthProvider.isLoggedIn) {
      _promptLogin("manage your subscription");
      return;
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const sub_screen.SubscriptionScreen()),
    );
    if (mounted) {
      await Provider.of<UserAuthProvider>(context, listen: false).reloadUserDataFromPrefs();
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Subscription status may have changed.")),
        );
      }
    }
  }

  void _showActionDialog(String title, String content, {VoidCallback? onConfirm, String confirmText = "OK"}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            if (onConfirm != null)
              TextButton(
                child: Text(confirmText),
                onPressed: () {
                  Navigator.of(context).pop();
                  onConfirm();
                },
              ),
          ],
        );
      },
    );
  }

  void _addCredit() {
    _showActionDialog("Add Credit", "This feature (Add Credit) is not yet implemented.");
  }

  void _contactSupport() {
    _showActionDialog("Contact Support", "This feature (Contact Support/Online Chat) is not yet implemented.");
  }

  void _deleteAccount() {
    final userAuthProvider = Provider.of<UserAuthProvider>(context, listen: false);
    if (!userAuthProvider.isLoggedIn) {
      _promptLogin("delete your account");
      return;
    }
    _showActionDialog(
        "Delete Account",
        "Are you sure you want to delete your account? This action cannot be undone and all your data will be lost.",
        onConfirm: () {
          // TODO: پیاده‌سازی واقعی حذف حساب (ارتباط با بک‌اند)
          print("UserProfileScreen: Delete account confirmed (TODO: implement actual deletion)");
          // پس از حذف موفق از سرور، کاربر را logout کنید
          Provider.of<UserAuthProvider>(context, listen: false).logout();
          // UserProfileScreen خود به خود رفرش شده و حالت لاگین نشده را نشان می‌دهد
        },
        confirmText: "Yes, Delete"
    );
  }

  void _logout() {
    _showActionDialog(
        "Logout",
        "Are you sure you want to logout?",
        onConfirm: () async {
          await Provider.of<UserAuthProvider>(context, listen: false).logout();
        },
        confirmText: "Yes, Logout"
    );
  }

  Future<void> _changeThemeMode(ThemeMode? newMode) async {
    if (newMode == null) return;
    _prefs ??= await SharedPreferences.getInstance();
    String themeString;
    if (newMode == ThemeMode.light) themeString = 'light';
    else if (newMode == ThemeMode.dark) themeString = 'dark';
    else themeString = 'system';
    await _prefs!.setString(SharedPrefKeys.appThemeMode, themeString);
    activeThemeMode.value = newMode;
  }

  String _themeModeToString(ThemeMode mode) {
    if (mode == ThemeMode.light) return "Light";
    if (mode == ThemeMode.dark) return "Dark";
    return "System Default";
  }

  void _navigateToLogin() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  void _navigateToSignUp() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpScreen()));
  }

  void _promptLogin(String action) {
    if (mounted) { // بررسی mounted بودن قبل از نمایش SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please login or sign up to $action.'),
          action: SnackBarAction(
            label: 'Login',
            onPressed: _navigateToLogin,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAuthProvider = Provider.of<UserAuthProvider>(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    if (_isScreenSpecificDataLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!userAuthProvider.isLoggedIn) {
      // UI برای کاربر لاگین نکرده
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.account_circle_outlined, size: 80, color: colorScheme.primary.withOpacity(0.7)),
                const SizedBox(height: 24),
                Text(
                  'Welcome to Your Account',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Login or create an account to manage your profile, subscriptions, and favorites.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: _navigateToLogin,
                  child: const Text('Login'),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: _navigateToSignUp,
                  child: const Text('Sign Up'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // UI برای کاربر لاگین کرده
    final String userName = userAuthProvider.username ?? "User";
    final String userEmail = userAuthProvider.email ?? "No email";
    final sub_screen.SubscriptionTier currentUserSubscriptionTier = userAuthProvider.userSubscriptionTier;
    final DateTime? userSubscriptionExpiryDate = userAuthProvider.userSubscriptionExpiryDate;
    final String userCreditString = userAuthProvider.userCredit.toStringAsFixed(1);

    String subscriptionStatusText;
    Color subscriptionTextColor = colorScheme.onSurface.withOpacity(0.8);

    if (currentUserSubscriptionTier == sub_screen.SubscriptionTier.none ||
        userSubscriptionExpiryDate == null ||
        userSubscriptionExpiryDate.isBefore(DateTime.now())) {
      subscriptionStatusText = userSubscriptionExpiryDate != null && userSubscriptionExpiryDate.isBefore(DateTime.now())
          ? "Subscription Expired"
          : "No Active Subscription";
      if (userSubscriptionExpiryDate != null && userSubscriptionExpiryDate.isBefore(DateTime.now())) {
        subscriptionTextColor = colorScheme.error;
      }
    } else {
      subscriptionStatusText = "${currentUserSubscriptionTier.name.toUpperCase()} Plan";
      if (userSubscriptionExpiryDate != null) {
        subscriptionStatusText += " (Expires: ${userSubscriptionExpiryDate.day}/${userSubscriptionExpiryDate.month}/${userSubscriptionExpiryDate.year})";
      }
      subscriptionTextColor = Colors.green.shade400;
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadScreenSpecificData();
          if (mounted) {
            await Provider.of<UserAuthProvider>(context, listen: false).reloadUserDataFromPrefs();
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: <Widget>[
            const SizedBox(height: 20),
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: colorScheme.surfaceVariant,
                    backgroundImage: _profileImageFile != null && _profileImageFile!.existsSync()
                        ? FileImage(_profileImageFile!)
                        : null,
                    child: _profileImageFile == null || !_profileImageFile!.existsSync()
                        ? Icon(Icons.person, size: 70, color: colorScheme.onSurfaceVariant.withOpacity(0.5))
                        : null,
                  ),
                  Positioned(
                    right: 0, bottom: 0,
                    child: CircleAvatar(
                      radius: 20, backgroundColor: colorScheme.primary,
                      child: IconButton(
                        icon: Icon(Icons.camera_alt_outlined, color: theme.brightness == Brightness.dark ? Colors.black87: Colors.white , size: 20),
                        onPressed: () => _showImageSourceActionSheet(context),
                        tooltip: "Change profile picture",
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(child: Text(userName, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
            const SizedBox(height: 4),
            Center(child: Text(userEmail, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)))),
            const SizedBox(height: 24),
            _buildInfoCard(
              context,
              children: [
                _buildInfoRow(context,
                    label: "Subscription",
                    valueChild: Flexible(child: Text(subscriptionStatusText, style: textTheme.bodyLarge?.copyWith(color: subscriptionTextColor, fontWeight: FontWeight.w600), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, maxLines: 2)),
                    icon: Icons.card_membership_outlined,
                    trailingIcon: Icons.arrow_forward_ios_rounded,
                    isAction: true,
                    onTap: _manageSubscription),
                _buildDivider(context),
                _buildInfoRow(context, label: "Edit Information", icon: Icons.edit_outlined, isAction: true, onTap: _editProfile),
                _buildDivider(context),
                _buildInfoRow(
                  context,
                  label: "App Theme",
                  icon: Icons.palette_outlined,
                  isAction: true,
                  valueChild: Text(_themeModeToString(_currentAppTheme), style: textTheme.bodyLarge?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600)),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return SimpleDialog(
                          title: const Text('Select Theme'),
                          children: <Widget>[
                            RadioListTile<ThemeMode>(title: const Text('Light'), value: ThemeMode.light, groupValue: _currentAppTheme, onChanged: (val) { _changeThemeMode(val); Navigator.of(context).pop(); }),
                            RadioListTile<ThemeMode>(title: const Text('Dark'), value: ThemeMode.dark, groupValue: _currentAppTheme, onChanged: (val) { _changeThemeMode(val); Navigator.of(context).pop(); }),
                            RadioListTile<ThemeMode>(title: const Text('System Default'), value: ThemeMode.system, groupValue: _currentAppTheme, onChanged: (val) { _changeThemeMode(val); Navigator.of(context).pop(); }),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoCard(
              context,
              children: [
                _buildInfoRow(context, label: "Favorites", icon: Icons.favorite_border_outlined, trailingIcon: Icons.arrow_forward_ios_rounded, isAction: true, onTap: _navigateToFavorites),
                _buildDivider(context),
                _buildInfoRow(context,
                    label: "Credit",
                    valueChild: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text("$userCreditString Credits", style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        TextButton(onPressed: _addCredit, child: Text("Add", style: TextStyle(fontSize: 13, color: colorScheme.primary)), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap))
                      ],
                    ),
                    icon: Icons.account_balance_wallet_outlined),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.headset_mic_outlined, color: colorScheme.primary),
                    label: const Text("Contact Support"),
                    onPressed: _contactSupport,
                    style: OutlinedButton.styleFrom(foregroundColor: colorScheme.primary, side: BorderSide(color: colorScheme.primary.withOpacity(0.5)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0))),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete_forever_outlined, size: 20),
                    label: const Text("Delete Account"),
                    onPressed: _deleteAccount,
                    style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.errorContainer, foregroundColor: theme.colorScheme.onErrorContainer, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(child: TextButton(onPressed: _logout, child: Text("Logout", style: TextStyle(color: colorScheme.error)))),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, {required List<Widget> children}) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context, {
        required String label,
        String? value,
        Widget? valueChild,
        IconData? icon,
        IconData? trailingIcon,
        bool isAction = false,
        VoidCallback? onTap,
      }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isAction ? onTap : null,
        borderRadius: BorderRadius.circular(12.0),
        splashColor: colorScheme.primary.withOpacity(0.1),
        highlightColor: colorScheme.primary.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: colorScheme.onSurface.withOpacity(0.7), size: 22),
                const SizedBox(width: 18),
              ],
              Expanded(
                flex: 2,
                child: Text(label, style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
              ),
              if (value != null)
                Expanded(
                  flex: 3,
                  child: Text(value, style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.8)), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, maxLines: 1),
                ),
              if (valueChild != null)
                Expanded(flex: 3, child: Align(alignment: Alignment.centerRight, child: valueChild)),
              if (trailingIcon != null || (isAction && onTap != null) ) ...[
                const SizedBox(width: 12),
                Icon(trailingIcon ?? Icons.arrow_forward_ios_rounded, size: 16, color: isAction ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.5)),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 0.5,
      thickness: 0.3,
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
      indent: 50,
      endIndent: 16,
    );
  }
}