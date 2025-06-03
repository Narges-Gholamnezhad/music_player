// lib/song_model.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'shared_pref_keys.dart';
import 'dart:math'; // برای تابع min

enum SongAccessTier {
  free,
  standard,
  premium,
}

class Song {
  final String title;
  final String artist;
  final String? coverImagePath;
  final String audioUrl;
  final double price;
  final double averageRating;
  final String? sampleAudioUrl;
  String? lyrics;

  final bool isLocal;
  final bool isDownloaded;
  final int? mediaStoreId;
  final DateTime? dateAdded; // زمان افزودن توسط کاربر (دانلود، علاقه‌مندی و ...)
  final int? dateAddedMediaStore; // timestamp از on_audio_query (فقط برای آهنگ‌های محلی)

  final SongAccessTier requiredAccessTier;

  Song({
    required this.title,
    required this.artist,
    this.coverImagePath,
    required this.audioUrl,
    this.price = 0.0,
    this.averageRating = 0.0,
    this.sampleAudioUrl,
    this.lyrics,
    this.isLocal = false,
    this.isDownloaded = false,
    this.mediaStoreId,
    this.dateAdded,
    this.dateAddedMediaStore,
    this.requiredAccessTier = SongAccessTier.free,
  });

  DateTime? get effectiveDateAdded {
    if (dateAdded != null) return dateAdded; // اولویت با تاریخی که ما ست کردیم
    if (dateAddedMediaStore != null && dateAddedMediaStore! > 0) {
      // on_audio_query.SongModel.dateAdded معمولا به ثانیه است
      return DateTime.fromMillisecondsSinceEpoch(dateAddedMediaStore! * 1000);
    }
    return null; // اگر هیچ تاریخی موجود نباشد
  }

  String get uniqueIdentifier {
    if (isLocal && mediaStoreId != null && mediaStoreId! > 0) {
      return 'local_id_$mediaStoreId';
    }
    final safeTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final safeArtist = artist.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final urlHash = audioUrl.hashCode.toString();

    if (isLocal) {
      return 'local_url_${safeTitle}_${safeArtist}_$urlHash';
    } else {
      return 'shop_${safeTitle}_${safeArtist}_$urlHash';
    }
  }

  bool get isAvailableForPurchase => price > 0 && requiredAccessTier != SongAccessTier.free;

  factory Song.fromDataString(String dataString) {
    final parts = dataString.split(';;');
    // title;artist;audioUrl;coverPath;isLocal;mediaStoreId;isDownloaded;accessTier;price;dateAdded(ISO)
    if (parts.length < 10) { // قبلا ۹ بود، حالا باید ۱۰ باشد
      print("Song.fromDataString: Invalid data string format for song. Expected 10 parts, got ${parts.length}. Data: $dataString");
      throw FormatException("Invalid song data string format (missing dateAdded field?)");
    }
    try {
      return Song(
        title: parts[0],
        artist: parts[1],
        audioUrl: parts[2],
        coverImagePath: parts[3].isNotEmpty ? parts[3] : null,
        isLocal: parts[4] == 'true',
        mediaStoreId: parts[5] != 'null' && parts[5].isNotEmpty ? int.tryParse(parts[5]) : null,
        isDownloaded: parts[6] == 'true',
        requiredAccessTier: SongAccessTier.values.firstWhere(
              (e) => e.name == parts[7],
          orElse: () => SongAccessTier.free,
        ),
        price: double.tryParse(parts[8]) ?? 0.0,
        dateAdded: parts[9] != 'null' && parts[9].isNotEmpty ? DateTime.tryParse(parts[9]) : null,
        // dateAddedMediaStore از SharedPreferences خوانده نمی‌شود، فقط موقع ساخت از on_audio_query پر می‌شود
        lyrics: null, // Lyrics جداگانه بارگذاری می‌شوند
      );
    } catch (e) {
      print("Song.fromDataString: Error parsing song data: $e, Data: $dataString");
      throw FormatException("Error parsing song data string: $e");
    }
  }

  String toDataString() {
    final String localMediaStoreIdString = mediaStoreId?.toString() ?? 'null';
    final String localCoverPathString = coverImagePath ?? '';
    final String dateAddedString = dateAdded?.toIso8601String() ?? 'null'; // ذخیره به فرمت ISO 8601
    // dateAddedMediaStore در toDataString ذخیره نمی‌شود چون فقط برای آهنگ‌های محلی اسکن شده کاربرد دارد
    return '$title;;$artist;;$audioUrl;;$localCoverPathString;;$isLocal;;$localMediaStoreIdString;;$isDownloaded;;${requiredAccessTier.name};;$price;;$dateAddedString';
  }

  Song copyWith({
    String? title,
    String? artist,
    String? coverImagePath,
    String? audioUrl,
    double? price,
    double? averageRating,
    String? sampleAudioUrl,
    String? lyrics, // allow lyrics to be copied
    bool? isLocal,
    bool? isDownloaded,
    int? mediaStoreId,
    DateTime? dateAdded, // new
    int? dateAddedMediaStore, // new
    SongAccessTier? requiredAccessTier,
  }) {
    return Song(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      audioUrl: audioUrl ?? this.audioUrl,
      price: price ?? this.price,
      averageRating: averageRating ?? this.averageRating,
      sampleAudioUrl: sampleAudioUrl ?? this.sampleAudioUrl,
      lyrics: lyrics ?? this.lyrics,
      isLocal: isLocal ?? this.isLocal,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      mediaStoreId: mediaStoreId ?? this.mediaStoreId,
      dateAdded: dateAdded ?? this.dateAdded,
      dateAddedMediaStore: dateAddedMediaStore ?? this.dateAddedMediaStore,
      requiredAccessTier: requiredAccessTier ?? this.requiredAccessTier,
    );
  }

  Future<void> saveLyrics(SharedPreferences prefs, String lyricsText) async {
    await prefs.setString(SharedPrefKeys.lyricsDataKeyForSong(uniqueIdentifier), lyricsText);
    this.lyrics = lyricsText;
    // print("Lyrics saved for ${this.title}");
  }

  Future<void> loadLyrics(SharedPreferences prefs) async {
    this.lyrics = prefs.getString(SharedPrefKeys.lyricsDataKeyForSong(uniqueIdentifier));
    // print("Lyrics loaded for ${this.title}: ${this.lyrics != null && this.lyrics!.isNotEmpty ? 'Found' : 'Not Found'}");
  }
}