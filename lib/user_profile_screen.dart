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
import 'edit_profile_screen.dart'; // Import صفحه ویرایش پروفایل
// import 'auth_screen.dart';

// کلیدهای SharedPreferences برای نام و ایمیل کاربر
// **مهم:** این مقادیر باید دقیقاً با مقادیر مشابه در edit_profile_screen.dart یکسان باشند
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

  @override
  void initState() {
    super.initState();
    _loadUserProfileData();
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

    // خواندن نام و ایمیل از SharedPreferences در هر بار لود شدن
    final loadedName = _prefs!.getString(prefUserProfileName) ?? "Narges Gholamnezhad";
    final loadedEmail = _prefs!.getString(prefUserProfileEmail) ?? "nargesgholamnezhad02@gmail.com";

    final loadedTier = sub_screen.SubscriptionTier.values[
    _prefs!.getInt(sub_screen.SubscriptionPreferences.prefUserSubscriptionTier) ?? sub_screen.SubscriptionTier.none.index];
    final expiryMillis = _prefs!.getInt(sub_screen.SubscriptionPreferences.prefUserSubscriptionExpiry);
    final loadedExpiryDate = expiryMillis != null ? DateTime.fromMillisecondsSinceEpoch(expiryMillis) : null;
    final loadedCredit = (_prefs!.getDouble(sub_screen.SubscriptionPreferences.prefUserCredit) ?? 0.0).toStringAsFixed(1);

    sub_screen.SubscriptionTier finalLoadedTier = loadedTier;
    if (loadedTier != sub_screen.SubscriptionTier.none &&
        loadedExpiryDate != null &&
        loadedExpiryDate.isBefore(DateTime.now())) {
      finalLoadedTier = sub_screen.SubscriptionTier.none;
    }

    // فقط اگر چیزی تغییر کرده باشد setState کن (یا اولین بار باشد)
    // این بهینه سازی را فعلا حذف می‌کنیم تا همیشه setState شود و از نمایش صحیح مطمئن شویم.
    // بعدا می‌توان اضافه کرد.
    setState(() {
      _profileImageFile = tempImageFile;
      _userName = loadedName;
      _userEmail = loadedEmail;
      _currentUserSubscriptionTier = finalLoadedTier;
      _userSubscriptionExpiryDate = loadedExpiryDate;
      _userCreditString = loadedCredit;
    });

    print("UserProfileScreen: Loaded/Refreshed data. Name: $_userName, Email: $_userEmail");
  }

  Future<void> _showImageSourceActionSheet(BuildContext context) async {
    // ... (کد مثل قبل)
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
    // ... (کد مثل قبل)
    PermissionStatus status;
    if (source == ImageSource.camera) {
      status = await Permission.camera.request();
    } else {
      if (Platform.isAndroid) {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          status = await Permission.photos.request();
        } else {
          status = await Permission.storage.request();
        }
      } else {
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
              if (_profileImageFile!.path != newPath) {
                await _profileImageFile!.delete();
              }
            } catch (e) {
              print("Error deleting old profile picture: $e");
            }
          }

          final File savedImage = await newImage.copy(newPath);

          setState(() {
            _profileImageFile = savedImage;
          });
          await _prefs?.setString(_profileImagePathKey, savedImage.path);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile picture updated!")));
        }
      } catch (e) {
        print("Error picking/saving image: $e");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update profile picture.")));
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(source == ImageSource.camera ? 'Camera permission permanently denied. Please enable it in settings.' : 'Gallery permission permanently denied. Please enable it in settings.'),
              action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
            )
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(source == ImageSource.camera ? 'Camera permission denied.' : 'Gallery permission denied.'))
        );
      }
    }
  }

  void _editProfile() async {
    print("UserProfileScreen: Edit Profile tapped, navigating to EditProfileScreen.");
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );
    if (result == true && mounted) {
      print("UserProfileScreen: Returned from EditProfileScreen with success, reloading profile data.");
      await _loadUserProfileData(); // فراخوانی برای خواندن اطلاعات جدید
    } else if(mounted) {
      print("UserProfileScreen: Returned from EditProfileScreen without confirmed save, reloading data anyway.");
      await _loadUserProfileData(); // برای اطمینان، حتی اگر false یا null بود، داده‌ها را رفرش کن
    }
  }

  // ... (سایر متدها: _navigateToFavorites, _manageSubscription, و غیره مثل قبل)
  void _navigateToFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FavoritesScreen()),
    );
  }

  void _manageSubscription() async {
    print("UserProfileScreen: Manage Subscription tapped, navigating to SubscriptionScreen.");
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const sub_screen.SubscriptionScreen()),
    );
    if (result == true && mounted) {
      await _loadUserProfileData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Subscription status updated!")),
      );
    } else if (mounted) {
      await _loadUserProfileData();
    }
  }

  void _addCredit() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Add Credit (TODO)")));
  }

  void _contactSupport() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Contact Support (TODO)")));
  }

  void _deleteAccount() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Delete Account (TODO)")));
  }

  void _logout() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Logout (TODO)")));
  }

  @override
  Widget build(BuildContext context) {
    // ... (کد UI مثل قبل، اطمینان حاصل کنید که onTap مربوط به "Edit Information" به _editProfile متصل است)
    // و مقادیر _userName و _userEmail از state خوانده می‌شوند.
    // کد build از پیام قبلی شما کپی شده و باید کار کند.
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    String subscriptionStatusText;
    Color subscriptionTextColor = colorScheme.onSurface.withOpacity(0.8);

    if (_currentUserSubscriptionTier == sub_screen.SubscriptionTier.none ||
        _userSubscriptionExpiryDate == null ||
        _userSubscriptionExpiryDate!.isBefore(DateTime.now())) {
      subscriptionStatusText = "No Active Subscription";
    } else {
      subscriptionStatusText = "${_currentUserSubscriptionTier.name.toUpperCase()} Plan";
      if (_userSubscriptionExpiryDate != null) {
        subscriptionStatusText += " (Expires: ${_userSubscriptionExpiryDate!.day}/${_userSubscriptionExpiryDate!.month}/${_userSubscriptionExpiryDate!.year})";
      }
      subscriptionTextColor = colorScheme.primary;
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
                        : const AssetImage('assets/images/cute-photos04-21.jpg') as ImageProvider,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: colorScheme.primary,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 20),
                        onPressed: () {
                          _showImageSourceActionSheet(context);
                        },
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
                _userName, // نمایش نام خوانده شده از prefs
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                _userEmail, // نمایش ایمیل خوانده شده از prefs
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
                        style: textTheme.bodyLarge?.copyWith(color: subscriptionTextColor),
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
                    onTap: _editProfile), // <--- اتصال به متد _editProfile
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
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: colorScheme.onSurface.withOpacity(0.7), size: 22),
                const SizedBox(width: 18),
              ],
              Expanded(
                child: Text(
                  label,
                  style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500),
                ),
              ),
              if (value != null)
                Flexible(
                  child: Text(
                    value,
                    style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.8)),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (valueChild != null)
                Expanded(
                    flex: 2,
                    child: Align(alignment: Alignment.centerRight, child: valueChild)),
              if (trailingIcon != null || isAction) ...[
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
      thickness: 0.5,
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
      indent: 16,
      endIndent: 16,
    );
  }
}