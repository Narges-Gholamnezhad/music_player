// lib/user_auth_provider.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shared_pref_keys.dart';
import 'subscription_screen.dart' as sub_screen;

class UserAuthProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  String? _username;
  String? _email;
  String? _userToken;
  sub_screen.SubscriptionTier _userSubscriptionTier = sub_screen.SubscriptionTier.none;
  DateTime? _userSubscriptionExpiryDate;
  double _userCredit = 0.0;

  bool _isLoading = true;

  bool get isLoggedIn => _isLoggedIn;
  String? get username => _username;
  String? get email => _email;
  String? get userToken => _userToken;
  sub_screen.SubscriptionTier get userSubscriptionTier => _userSubscriptionTier;
  DateTime? get userSubscriptionExpiryDate => _userSubscriptionExpiryDate;
  double get userCredit => _userCredit;
  bool get isLoading => _isLoading;

  UserAuthProvider() {
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    await _loadUserFromPrefs();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool(SharedPrefKeys.userIsLoggedIn) ?? false;

    if (_isLoggedIn) {
      _username = prefs.getString(SharedPrefKeys.userProfileName);
      _email = prefs.getString(SharedPrefKeys.userProfileEmail);
      _userToken = prefs.getString(SharedPrefKeys.userToken);
      _userSubscriptionTier = sub_screen.SubscriptionTier.values[
      prefs.getInt(SharedPrefKeys.userSubscriptionTier) ??
          sub_screen.SubscriptionTier.none.index];
      final expiryMillis = prefs.getInt(SharedPrefKeys.userSubscriptionExpiry);
      _userSubscriptionExpiryDate = expiryMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(expiryMillis)
          : null;
      _userCredit = prefs.getDouble(SharedPrefKeys.userCredit) ?? 0.0;

      if (_userSubscriptionTier != sub_screen.SubscriptionTier.none &&
          _userSubscriptionExpiryDate != null &&
          _userSubscriptionExpiryDate!.isBefore(DateTime.now())) {
        _userSubscriptionTier = sub_screen.SubscriptionTier.none;
        _userSubscriptionExpiryDate = null;
      }
    } else {
      _username = null;
      _email = null;
      _userToken = null;
      _userSubscriptionTier = sub_screen.SubscriptionTier.none;
      _userSubscriptionExpiryDate = null;
      _userCredit = 0.0;
    }
  }

  Future<void> reloadUserDataFromPrefs() async {
    _isLoading = true;
    notifyListeners();
    await _loadUserFromPrefs();
    _isLoading = false;
    notifyListeners();
    print("UserAuthProvider: User data reloaded from prefs.");
  }

  Future<void> loginWithData({
    required String username,
    required String email,
    required String token,
    required double credit,
    required String tierString,
    required String expiryString,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = true;
    _userToken = token;
    _username = username;
    _email = email.isNotEmpty ? email : null;
    _userCredit = credit;

    _userSubscriptionTier = sub_screen.SubscriptionTier.values.firstWhere(
          (e) => e.name == tierString,
      orElse: () => sub_screen.SubscriptionTier.none,
    );

    if (expiryString != 'null' && expiryString.isNotEmpty) {
      _userSubscriptionExpiryDate = DateTime.tryParse(expiryString);
    } else {
      _userSubscriptionExpiryDate = null;
    }

    await prefs.setBool(SharedPrefKeys.userIsLoggedIn, true);
    await prefs.setString(SharedPrefKeys.userToken, token);
    await prefs.setString(SharedPrefKeys.userProfileName, _username!);
    if (_email != null) {
      await prefs.setString(SharedPrefKeys.userProfileEmail, _email!);
    }
    await prefs.setDouble(SharedPrefKeys.userCredit, _userCredit);
    await prefs.setInt(SharedPrefKeys.userSubscriptionTier, _userSubscriptionTier.index);
    if (_userSubscriptionExpiryDate != null) {
      await prefs.setInt(SharedPrefKeys.userSubscriptionExpiry, _userSubscriptionExpiryDate!.millisecondsSinceEpoch);
    } else {
      await prefs.remove(SharedPrefKeys.userSubscriptionExpiry);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateProfile(String newUsername, String newEmail) async {
    // این متد فقط UI را آپدیت می‌کند، چون سرور منبع اصلی اطلاعات است.
    // SharedPreferences هم توسط loginWithData یا reloadUserDataFromPrefs آپدیت می‌شود.
    _username = newUsername;
    _email = newEmail;

    // برای اطمینان می‌توانیم SharedPreferences را هم آپدیت کنیم
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SharedPrefKeys.userProfileName, newUsername);
    await prefs.setString(SharedPrefKeys.userProfileEmail, newEmail);

    notifyListeners();
  }
  Future<void> signUpAndLogin(
      String newUsername, String newEmail, String token) async {
    // پس از ثبت‌نام، کاربر را با اطلاعات اولیه و پیش‌فرض لاگین می‌کنیم.
    await loginWithData(
      username: newUsername,
      email: newEmail,
      token: token,
      credit: 0.0,            // اعتبار اولیه برای کاربر جدید
      tierString: "none",       // اشتراک اولیه
      expiryString: "null",     // تاریخ انقضای اولیه
    );
  }
  //++++++++++++ این متد اضافه شده است ++++++++++++
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = false;
    _username = null;
    _email = null;
    _userToken = null;
    _userSubscriptionTier = sub_screen.SubscriptionTier.none;
    _userSubscriptionExpiryDate = null;
    _userCredit = 0.0;

    // پاک کردن تمام اطلاعات کاربر از حافظه دستگاه
    await prefs.remove(SharedPrefKeys.userIsLoggedIn);
    await prefs.remove(SharedPrefKeys.userToken);
    await prefs.remove(SharedPrefKeys.userProfileName);
    await prefs.remove(SharedPrefKeys.userProfileEmail);
    await prefs.remove(SharedPrefKeys.userSubscriptionTier);
    await prefs.remove(SharedPrefKeys.userSubscriptionExpiry);
    await prefs.remove(SharedPrefKeys.userCredit);
    await prefs.remove(SharedPrefKeys.userProfileImagePath); // عکس پروفایل هم پاک شود

    _isLoading = false;
    notifyListeners();
  }
//++++++++++++++++++++++++++++++++++++++++++++++
}