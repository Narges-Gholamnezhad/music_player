// lib/song_model.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'shared_pref_keys.dart'; // <--- استفاده از کلیدهای مشترک
import 'dart:math'; // <--- اضافه کردن این import برای تابع min

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
  String? lyrics; // <--- قابل تغییر برای بارگذاری جداگانه

  final bool isLocal;
  final bool isDownloaded;
  final int? mediaStoreId;
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
    this.requiredAccessTier = SongAccessTier.free,
  });

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
    if (parts.length < 9) {
      print("Song.fromDataString: Invalid data string format: $dataString. Expected 9 parts, got ${parts.length}");
      throw FormatException("Invalid song data string format (lyrics excluded)");
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
        lyrics: null,
      );
    } catch (e) {
      print("Song.fromDataString: Error parsing song data: $e, Data: $dataString");
      throw FormatException("Error parsing song data string (lyrics excluded): $e");
    }
  }

  String toDataString() {
    final String localMediaStoreId = mediaStoreId?.toString() ?? 'null';
    final String localCoverPath = coverImagePath ?? '';
    return '$title;;$artist;;$audioUrl;;$localCoverPath;;$isLocal;;$localMediaStoreId;;$isDownloaded;;${requiredAccessTier.name};;$price';
  }

  Song copyWith({
    String? title,
    String? artist,
    String? coverImagePath,
    String? audioUrl,
    double? price,
    double? averageRating,
    String? sampleAudioUrl,
    String? lyrics,
    bool? isLocal,
    bool? isDownloaded,
    int? mediaStoreId,
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
      requiredAccessTier: requiredAccessTier ?? this.requiredAccessTier,
    );
  }

  Future<void> saveLyrics(SharedPreferences prefs, String lyricsText) async {
    await prefs.setString(SharedPrefKeys.lyricsDataKeyForSong(uniqueIdentifier), lyricsText);
    this.lyrics = lyricsText;
    print("Lyrics saved for ${this.title} with key ${SharedPrefKeys.lyricsDataKeyForSong(uniqueIdentifier)}");
  }

  Future<void> loadLyrics(SharedPreferences prefs) async {
    this.lyrics = prefs.getString(SharedPrefKeys.lyricsDataKeyForSong(uniqueIdentifier));
    // استفاده صحیح از تابع min از dart:math
    print("Lyrics loaded for ${this.title}: ${this.lyrics != null && this.lyrics!.isNotEmpty ? 'Found (${this.lyrics!.substring(0, min(15, this.lyrics!.length))}...)' : 'Not Found'} from key ${SharedPrefKeys.lyricsDataKeyForSong(uniqueIdentifier)}");
  }
}