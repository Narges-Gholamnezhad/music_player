// lib/user_auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shared_pref_keys.dart';
import 'subscription_screen.dart' as sub_screen; // <--- اطمینان از وجود این import

class UserAuthProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  String? _username;
  String? _email;
  String? _userToken;
  sub_screen.SubscriptionTier _userSubscriptionTier = sub_screen.SubscriptionTier.none; // مقدار اولیه
  DateTime? _userSubscriptionExpiryDate;
  double _userCredit = 0.0; // مقدار اولیه

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
        // اختیاری: پاک کردن از prefs
        // await prefs.remove(SharedPrefKeys.userSubscriptionTier);
        // await prefs.remove(SharedPrefKeys.userSubscriptionExpiry);
      }
    } else {
      _username = null;
      _email = null;
      _userToken = null;
      _userSubscriptionTier = sub_screen.SubscriptionTier.none;
      _userSubscriptionExpiryDate = null;
      _userCredit = 0.0;
    }
    // notifyListeners() در انتهای _initializeUser یا reloadUserDataFromPrefs فراخوانی می‌شود
  }

  Future<void> reloadUserDataFromPrefs() async {
    _isLoading = true;
    notifyListeners();
    await _loadUserFromPrefs();
    _isLoading = false;
    notifyListeners();
    print("UserAuthProvider: User data reloaded from prefs.");
  }

  Future<void> login(String usernameOrEmail, String token,
      {String? fetchedUsername, String? fetchedEmail}) async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = true;
    _userToken = token;
    _username = fetchedUsername ??
        (usernameOrEmail.contains('@')
            ? usernameOrEmail.split('@')[0]
            : usernameOrEmail);
    _email = fetchedEmail ??
        (usernameOrEmail.contains('@') ? usernameOrEmail : null);

    await prefs.setBool(SharedPrefKeys.userIsLoggedIn, true);
    await prefs.setString(SharedPrefKeys.userToken, token);
    if (_username != null) {
      await prefs.setString(SharedPrefKeys.userProfileName, _username!);
    }
    if (_email != null) {
      await prefs.setString(SharedPrefKeys.userProfileEmail, _email!);
    }

    await _loadUserFromPrefs(); // بارگذاری اطلاعات اشتراک و اعتبار
    _isLoading = false;
    notifyListeners();
  }

  Future<void> signUpAndLogin(
      String newUsername, String newEmail, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(SharedPrefKeys.userSubscriptionTier,
        sub_screen.SubscriptionTier.none.index);
    await prefs.remove(SharedPrefKeys.userSubscriptionExpiry);
    await prefs.setDouble(SharedPrefKeys.userCredit, 0.0);

    await login(newUsername, token,
        fetchedUsername: newUsername, fetchedEmail: newEmail);
  }

  Future<void> updateProfile(String newUsername, String newEmail) async {
    final prefs = await SharedPreferences.getInstance();
    _username = newUsername;
    _email = newEmail;
    await prefs.setString(SharedPrefKeys.userProfileName, newUsername);
    await prefs.setString(SharedPrefKeys.userProfileEmail, newEmail);
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = false;
    _username = null;
    _email = null;
    _userToken = null;
    _userSubscriptionTier = sub_screen.SubscriptionTier.none;
    _userSubscriptionExpiryDate = null;
    _userCredit = 0.0;

    await prefs.remove(SharedPrefKeys.userIsLoggedIn);
    await prefs.remove(SharedPrefKeys.userToken);
    await prefs.remove(SharedPrefKeys.userProfileName);
    await prefs.remove(SharedPrefKeys.userProfileEmail);
    await prefs.remove(SharedPrefKeys.userSubscriptionTier);
    await prefs.remove(SharedPrefKeys.userSubscriptionExpiry);
    await prefs.remove(SharedPrefKeys.userCredit);

    _isLoading = false;
    notifyListeners();
  }
}