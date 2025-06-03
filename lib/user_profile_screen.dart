// lib/user_profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'subscription_screen.dart' as sub_screen;
import 'favorites_screen.dart';
import 'edit_profile_screen.dart';
import 'main.dart'; // برای دسترسی به themePrefKey و activeThemeMode

// کلیدهای SharedPreferences برای نام و ایمیل کاربر (در edit_profile_screen هم استفاده شده)
const String prefUserProfileName = 'user_profile_name_v1';
const String prefUserProfileEmail = 'user_profile_email_v1';


class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  String _userName = "Loading...";
  String _userEmail = "Loading...";
  sub_screen.SubscriptionTier _currentUserSubscriptionTier = sub_screen.SubscriptionTier.none;
  DateTime? _userSubscriptionExpiryDate;
  String _userCreditString = "0.0";
  SharedPreferences? _prefs;

  File? _profileImageFile;
  final ImagePicker _picker = ImagePicker();
  static const String _profileImagePathKey = 'user_profile_image_path_v2';

  ThemeMode _currentAppTheme = ThemeMode.system; // برای نمایش در UI

  @override
  void initState() {
    super.initState();
    _loadUserProfileData();
    // مقدار اولیه تم را از ValueNotifier بخوان
    _currentAppTheme = activeThemeMode.value;
    // به تغییرات تم گوش بده تا UI آپدیت شود
    activeThemeMode.addListener(_updateLocalThemeState);
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

  Future<void> _loadUserProfileData() async {
    _prefs ??= await SharedPreferences.getInstance();
    if (!mounted) return;

    final String? imagePath = _prefs!.getString(_profileImagePathKey);
    File? tempImageFile;
    if (imagePath != null && imagePath.isNotEmpty) {
      tempImageFile = File(imagePath);
      if (!await tempImageFile.exists()) {
        tempImageFile = null;
        await _prefs!.remove(_profileImagePathKey);
      }
    }

    final loadedName = _prefs!.getString(prefUserProfileName) ?? "Narges Gholamnezhad";
    final loadedEmail = _prefs!.getString(prefUserProfileEmail) ?? "nargesgholamnezhad02@gmail.com";

    final loadedTier = sub_screen.SubscriptionTier.values[
    _prefs!.getInt(sub_screen.SubscriptionPreferences.prefUserSubscriptionTier) ?? sub_screen.SubscriptionTier.none.index];
    final expiryMillis = _prefs!.getInt(sub_screen.SubscriptionPreferences.prefUserSubscriptionExpiry);
    DateTime? loadedExpiryDate = expiryMillis != null ? DateTime.fromMillisecondsSinceEpoch(expiryMillis) : null;
    final loadedCredit = (_prefs!.getDouble(sub_screen.SubscriptionPreferences.prefUserCredit) ?? 0.0).toStringAsFixed(1);

    sub_screen.SubscriptionTier finalLoadedTier = loadedTier;
    if (loadedTier != sub_screen.SubscriptionTier.none &&
        loadedExpiryDate != null &&
        loadedExpiryDate.isBefore(DateTime.now())) {
      finalLoadedTier = sub_screen.SubscriptionTier.none;
      loadedExpiryDate = null; // اگر منقضی شده، تاریخ را هم null کن برای نمایش
    }

    final String savedTheme = _prefs!.getString(themePrefKey) ?? 'system';
    ThemeMode themeToSet;
    if (savedTheme == 'light') themeToSet = ThemeMode.light;
    else if (savedTheme == 'dark') themeToSet = ThemeMode.dark;
    else themeToSet = ThemeMode.system;


    setState(() {
      _profileImageFile = tempImageFile;
      _userName = loadedName;
      _userEmail = loadedEmail;
      _currentUserSubscriptionTier = finalLoadedTier;
      _userSubscriptionExpiryDate = loadedExpiryDate;
      _userCreditString = loadedCredit;
      _currentAppTheme = themeToSet; // آپدیت تم محلی
    });
    // فعال کردن تم اصلی برنامه اگر با مقدار اولیه تفاوت دارد
    if(activeThemeMode.value != themeToSet){
      activeThemeMode.value = themeToSet;
    }

    print("UserProfileScreen: Loaded/Refreshed data. Name: $_userName, Email: $_userEmail, Theme: $_currentAppTheme");
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
      } else { // iOS
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

          if (_profileImageFile != null && await _profileImageFile!.exists()) {
            try {
              if (_profileImageFile!.path != newPath) { // فقط اگر مسیر متفاوت است حذف کن
                await _profileImageFile!.delete();
                print("Old profile picture deleted: ${_profileImageFile!.path}");
              }
            } catch (e) {
              print("Error deleting old profile picture: $e");
            }
          }

          final File savedImage = await newImage.copy(newPath);
          print("New profile picture saved at: ${savedImage.path}");


          if(mounted){
            setState(() {
              _profileImageFile = savedImage;
            });
            await _prefs?.setString(_profileImagePathKey, savedImage.path);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile picture updated!")));
          }
        }
      } catch (e,s) {
        print("Error picking/saving image: $e\n$s");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update profile picture.")));
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(source == ImageSource.camera ? 'Camera permission permanently denied. Please enable it in settings.' : 'Gallery/Storage permission permanently denied. Please enable it in settings.'),
              action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
            )
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(source == ImageSource.camera ? 'Camera permission denied.' : 'Gallery/Storage permission denied.'))
        );
      }
    }
  }

  void _editProfile() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );
    if (result == true && mounted) {
      await _loadUserProfileData();
    } else if (mounted) {
      await _loadUserProfileData(); // رفرش در هر صورت
    }
  }

  void _navigateToFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FavoritesScreen()),
    );
  }

  void _manageSubscription() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const sub_screen.SubscriptionScreen()),
    );
    if ((result == true || result == null) && mounted) { // رفرش حتی اگر result null باشد (مثلا کاربر back زده)
      await _loadUserProfileData();
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
    _showActionDialog("Add Credit", "This feature (Add Credit) is not yet implemented. It will be available in a future update.");
    print("Add Credit tapped (TODO)");
  }

  void _contactSupport() {
    _showActionDialog("Contact Support", "This feature (Contact Support/Online Chat) is not yet implemented. It will be available in a future update.");
    print("Contact Support tapped (TODO)");
  }

  void _deleteAccount() {
    _showActionDialog(
        "Delete Account",
        "Are you sure you want to delete your account? This action cannot be undone and all your data will be lost.",
        onConfirm: () {
          print("Account deletion confirmed by user (TODO: Implement actual deletion logic with server)");
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account deletion process initiated (simulated).")));
          // TODO: در یک برنامه واقعی، باید کاربر را لاگ اوت کرده و به صفحه لاگین هدایت کنید.
          // Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => AuthScreen()), (route) => false);
        },
        confirmText: "Yes, Delete"
    );
  }

  void _logout() {
    _showActionDialog(
        "Logout",
        "Are you sure you want to logout?",
        onConfirm: () {
          print("Logout confirmed by user (TODO: Clear session/token and navigate to AuthScreen)");
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Logged out successfully (simulated).")));
          // TODO: پاک کردن SharedPreferences مربوط به لاگین و ناوبری به AuthScreen
          // SharedPreferences prefs = await SharedPreferences.getInstance();
          // await prefs.remove('isLoggedIn');
          // await prefs.remove('userToken');
          // Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => AuthScreen()), (route) => false);
        },
        confirmText: "Yes, Logout"
    );
  }

  Future<void> _changeThemeMode(ThemeMode? newMode) async {
    if (newMode == null || _prefs == null) return;
    String themeString;
    if (newMode == ThemeMode.light) themeString = 'light';
    else if (newMode == ThemeMode.dark) themeString = 'dark';
    else themeString = 'system';

    await _prefs!.setString(themePrefKey, themeString);
    activeThemeMode.value = newMode; // این باعث بازسازی MaterialApp در main.dart می‌شود
    if(mounted) {
      setState(() {
        _currentAppTheme = newMode;
      });
    }
  }

  String _themeModeToString(ThemeMode mode) {
    if (mode == ThemeMode.light) return "Light";
    if (mode == ThemeMode.dark) return "Dark";
    return "System Default";
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    String subscriptionStatusText;
    Color subscriptionTextColor = colorScheme.onSurface.withOpacity(0.8);

    if (_currentUserSubscriptionTier == sub_screen.SubscriptionTier.none ||
        _userSubscriptionExpiryDate == null ) { // تاریخ انقضا هم null باشد یعنی اشتراکی نیست یا منقضی شده
      subscriptionStatusText = "No Active Subscription";
    } else if (_userSubscriptionExpiryDate != null && _userSubscriptionExpiryDate!.isBefore(DateTime.now())) {
      subscriptionStatusText = "Subscription Expired";
      subscriptionTextColor = colorScheme.error;
    }
    else {
      subscriptionStatusText = "${_currentUserSubscriptionTier.name.toUpperCase()} Plan";
      if (_userSubscriptionExpiryDate != null) {
        subscriptionStatusText += " (Expires: ${_userSubscriptionExpiryDate!.day}/${_userSubscriptionExpiryDate!.month}/${_userSubscriptionExpiryDate!.year})";
      }
      subscriptionTextColor = Colors.green.shade400; // رنگ سبز برای اشتراک فعال
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadUserProfileData,
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
                        : null, // اگر عکسی نیست، null باشد تا از child استفاده شود
                    child: _profileImageFile == null || !_profileImageFile!.existsSync()
                        ? Icon(Icons.person, size: 70, color: colorScheme.onSurfaceVariant.withOpacity(0.5))
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: colorScheme.primary,
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
            Center(
              child: Text(
                _userName,
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                _userEmail,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
              ),
            ),
            const SizedBox(height: 24),
            _buildInfoCard(
              context,
              children: [
                _buildInfoRow(context,
                    label: "Subscription",
                    valueChild: Flexible(
                      child: Text(
                        subscriptionStatusText,
                        style: textTheme.bodyLarge?.copyWith(color: subscriptionTextColor, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    icon: Icons.card_membership_outlined,
                    trailingIcon: Icons.arrow_forward_ios_rounded,
                    isAction: true,
                    onTap: _manageSubscription),
                _buildDivider(context),
                _buildInfoRow(context,
                    label: "Edit Information",
                    icon: Icons.edit_outlined,
                    isAction: true,
                    onTap: _editProfile),
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
                            RadioListTile<ThemeMode>(
                              title: const Text('Light'),
                              value: ThemeMode.light,
                              groupValue: _currentAppTheme,
                              onChanged: _changeThemeMode,
                            ),
                            RadioListTile<ThemeMode>(
                              title: const Text('Dark'),
                              value: ThemeMode.dark,
                              groupValue: _currentAppTheme,
                              onChanged: _changeThemeMode,
                            ),
                            RadioListTile<ThemeMode>(
                              title: const Text('System Default'),
                              value: ThemeMode.system,
                              groupValue: _currentAppTheme,
                              onChanged: _changeThemeMode,
                            ),
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
                _buildInfoRow(context,
                    label: "Favorites",
                    icon: Icons.favorite_border_outlined,
                    trailingIcon: Icons.arrow_forward_ios_rounded,
                    isAction: true,
                    onTap: _navigateToFavorites),
                _buildDivider(context),
                _buildInfoRow(context,
                    label: "Credit",
                    valueChild: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text("$_userCreditString Credits", style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _addCredit,
                          child: Text("Add", style: TextStyle(fontSize: 13, color: colorScheme.primary)),
                          style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        )
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
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      side: BorderSide(color: colorScheme.primary.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete_forever_outlined, size: 20),
                    label: const Text("Delete Account"),
                    onPressed: _deleteAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.errorContainer,
                      foregroundColor: theme.colorScheme.onErrorContainer,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: _logout,
                child: Text("Logout", style: TextStyle(color: colorScheme.error)),
              ),
            ),
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
        padding: const EdgeInsets.all(8.0), // کاهش پدینگ کلی کارت
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
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0), // کمی کاهش پدینگ عمودی
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: colorScheme.onSurface.withOpacity(0.7), size: 22),
                const SizedBox(width: 18),
              ],
              Expanded(
                flex: 2, // دادن فضای بیشتر به لیبل
                child: Text(
                  label,
                  style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500),
                ),
              ),
              if (value != null)
                Expanded( // اجازه دادن به value برای گرفتن فضای بیشتر
                  flex: 3,
                  child: Text(
                    value,
                    style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.8)),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1, // اطمینان از تک خطی بودن
                  ),
                ),
              if (valueChild != null)
                Expanded( // اجازه دادن به valueChild برای گرفتن فضای بیشتر
                    flex: 3,
                    child: Align(alignment: Alignment.centerRight, child: valueChild)),
              if (trailingIcon != null || (isAction && onTap != null) ) ...[ // فقط اگر اکشن است و onTap دارد، آیکون را نشان بده
                const SizedBox(width: 12),
                Icon(
                  trailingIcon ?? Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isAction ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.5),
                ),
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
      thickness: 0.3, // نازک تر کردن خط جدا کننده
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08), // کمرنگ تر کردن
      indent: 50, // برای اینکه از زیر آیکون شروع شود
      endIndent: 16,
    );
  }
}