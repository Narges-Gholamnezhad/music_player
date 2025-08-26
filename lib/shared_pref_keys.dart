// lib/shared_pref_keys.dart

class SharedPrefKeys {
  // --- USER-SPECIFIC KEYS ---
  // These are now methods that create a unique key for each user.

  // For Favorites
  static String favoriteSongsDataListForUser(String username) => 'favorite_songs_data_list_for_user_$username';
  static String favoriteSongIdentifiersForUser(String username) => 'favorite_song_identifiers_for_user_$username';

  // For Downloads
  static String downloadedSongsDataListForUser(String username) => 'downloaded_songs_data_list_for_user_$username';

  // --- GENERAL KEYS ---

  // Lyrics (Pattern for individual songs)
  static String lyricsDataKeyForSong(String songUniqueIdentifier) => 'song_lyrics_data_$songUniqueIdentifier';

  // Purchases
  static const String purchasedSongIds = 'purchased_song_ids_v2';

  // User Profile
  static const String userProfileName = 'user_profile_name_v1';
  static const String userProfileEmail = 'user_profile_email_v1';
  static const String userProfileImagePath = 'user_profile_image_path_v2';

  // Subscription & Credit
  static const String userSubscriptionTier = 'user_subscription_tier_global_v2';
  static const String userSubscriptionExpiry = 'user_subscription_expiry_global_v2';
  static const String userCredit = 'user_credit_global_v2';

  // App Settings & Auth Status
  static const String appThemeMode = 'app_theme_mode_v1';
  static const String userIsLoggedIn = 'user_is_logged_in_status_v1';
  static const String userToken = 'user_auth_token_v1';
}