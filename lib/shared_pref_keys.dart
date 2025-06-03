// lib/shared_pref_keys.dart
class SharedPrefKeys {
  // Favorites
  static const String favoriteSongsDataList = 'favorite_songs_data_list_v2'; // لیست داده کامل آهنگ‌های محبوب (برای FavoritesScreen)
  static const String favoriteSongIdentifiers = 'favorite_song_identifiers_v2'; // لیست شناسه‌های آهنگ‌های محبوب (برای بررسی سریع)

  // Lyrics (الگوی کلید - خود کلید بر اساس شناسه آهنگ ساخته می‌شود)
  static String lyricsDataKeyForSong(String songUniqueIdentifier) => 'song_lyrics_data_$songUniqueIdentifier';

  // Downloads
  static const String downloadedSongsDataList = 'downloaded_songs_data_list_v2';

  // Purchases
  static const String purchasedSongIds = 'purchased_song_ids_v2';

  // User Profile
  static const String userProfileName = 'user_profile_name_v1';
  static const String userProfileEmail = 'user_profile_email_v1';
  static const String userProfileImagePath = 'user_profile_image_path_v2';

  // Subscription
  static const String userSubscriptionTier = 'user_subscription_tier_global_v2';
  static const String userSubscriptionExpiry = 'user_subscription_expiry_global_v2';
  static const String userCredit = 'user_credit_global_v2';

  // Theme
  static const String appThemeMode = 'app_theme_mode_v1';
  static const String userIsLoggedIn = 'user_is_logged_in_status_v1';
  static const String userToken = 'user_auth_token_v1'; // یا هر نام مناسب دیگری
}