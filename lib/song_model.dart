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
  final String audioUrl; // می‌تواند URL آنلاین یا مسیر محلی باشد
  final double price;
  final double averageRating;
  final String? sampleAudioUrl;
  String? lyrics;

  final bool isLocal; // آیا آهنگ از اسکن حافظه محلی آمده یا از شاپ؟
  final bool isDownloaded; // آیا این آهنگ (که می‌تواند از شاپ باشد) روی دستگاه دانلود شده؟
  final int? mediaStoreId; // برای آهنگ‌های محلی از on_audio_query
  final DateTime? dateAdded; // زمان افزودن توسط کاربر (دانلود، علاقه‌مندی و ...)
  final int? dateAddedMediaStore; // timestamp از on_audio_query (فقط برای آهنگ‌های محلی اسکن شده)

  final SongAccessTier requiredAccessTier;

  // یک فیلد برای نگهداری شناسه اصلی آهنگ از شاپ، حتی پس از دانلود
  // این فیلد هنگام ساخت آهنگ از شاپ مقداردهی می‌شود و در copyWith حفظ می‌شود.
  final String? shopUniqueIdentifierBasis;


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
    this.shopUniqueIdentifierBasis, // اضافه شد
  });

  DateTime? get effectiveDateAdded {
    if (dateAdded != null) return dateAdded;
    if (dateAddedMediaStore != null && dateAddedMediaStore! > 0) {
      return DateTime.fromMillisecondsSinceEpoch(dateAddedMediaStore! * 1000);
    }
    return null;
  }

  // شناسه یکتا برای هر آهنگ
  String get uniqueIdentifier {
    // ۱. آهنگ‌های محلی که از اسکن دستگاه آمده‌اند (و از شاپ دانلود نشده‌اند)
    if (isLocal && mediaStoreId != null && mediaStoreId! > 0 && !isDownloaded) {
      return 'local_media_$mediaStoreId';
    }
    // ۲. آهنگ‌های فروشگاه (چه دانلود شده باشند چه نه)
    // از یک مبنای ثابت استفاده می‌کنیم که با دانلود تغییر نکند.
    // اگر shopUniqueIdentifierBasis از قبل وجود دارد (مثلا هنگام copyWith از یک آهنگ شاپ)
    if (shopUniqueIdentifierBasis != null && shopUniqueIdentifierBasis!.isNotEmpty) {
      return shopUniqueIdentifierBasis!;
    }
    // اگر آهنگ از شاپ است و هنوز shopUniqueIdentifierBasis برایش ساخته نشده
    if (!isLocal || isDownloaded) { // آهنگ شاپ یا آهنگ دانلود شده از شاپ
      final safeTitle = title.replaceAll(RegExp(r'[^\w-]'), '').toLowerCase();
      final safeArtist = artist.replaceAll(RegExp(r'[^\w-]'), '').toLowerCase();
      // یک هش ساده از عنوان و خواننده به عنوان مبنای شناسه آهنگ شاپ
      return 'shop_${safeTitle}_${safeArtist}_${(title+artist).hashCode}';
    }
    // ۳. آهنگ‌های محلی که کاربر خودش اضافه کرده (نه از اسکن و نه از شاپ - فعلا این حالت را نداریم)
    // fallback به روش قبلی برای آهنگ‌های محلی که mediaStoreId ندارند (نباید اتفاق بیفتد)
    final safeTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final safeArtist = artist.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final urlHash = audioUrl.hashCode.toString();
    return 'local_path_${safeTitle}_${safeArtist}_$urlHash';
  }


  bool get isAvailableForPurchase => price > 0 && requiredAccessTier != SongAccessTier.free;

  factory Song.fromDataString(String dataString) {
    final parts = dataString.split(';;');
    // title;artist;audioUrl;coverPath;isLocal;mediaStoreId;isDownloaded;accessTier;price;dateAdded(ISO);shopUniqueIdentifierBasis
    if (parts.length < 11) { // قبلا ۱۰ بود، حالا باید ۱۱ باشد
      print("Song.fromDataString: Invalid data string. Expected 11 parts, got ${parts.length}. Data: $dataString");
      throw FormatException("Invalid song data string format (missing shopUniqueIdentifierBasis field?)");
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
        shopUniqueIdentifierBasis: parts[10] != 'null' && parts[10].isNotEmpty ? parts[10] : null, // اضافه شد
        // dateAddedMediaStore از SharedPreferences خوانده نمی‌شود
        lyrics: null,
      );
    } catch (e) {
      print("Song.fromDataString: Error parsing song data: $e, Data: $dataString");
      throw FormatException("Error parsing song data string: $e");
    }
  }

  String toDataString() {
    final String localMediaStoreIdString = mediaStoreId?.toString() ?? 'null';
    final String localCoverPathString = coverImagePath ?? '';
    final String dateAddedString = dateAdded?.toIso8601String() ?? 'null';
    // shopUniqueIdentifierBasis از uniqueIdentifier گرفته می‌شود اگر این آهنگ از شاپ باشد
    // یا اگر از قبل ست شده باشد.
    final String basisToStore = shopUniqueIdentifierBasis ??
        ((!isLocal || isDownloaded) ? uniqueIdentifier : 'null');

    return '$title;;$artist;;$audioUrl;;$localCoverPathString;;$isLocal;;$localMediaStoreIdString;;$isDownloaded;;${requiredAccessTier.name};;$price;;$dateAddedString;;$basisToStore';
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
    DateTime? dateAdded,
    int? dateAddedMediaStore,
    SongAccessTier? requiredAccessTier,
    String? shopUniqueIdentifierBasis, // اضافه شد
  }) {
    // اگر shopUniqueIdentifierBasis جدید پاس داده نشده، از مقدار فعلی یا uniqueIdentifier فعلی (اگر آهنگ شاپ است) استفاده کن
    String? effectiveShopBasis = shopUniqueIdentifierBasis ?? this.shopUniqueIdentifierBasis;
    if (effectiveShopBasis == null && (! (this.isLocal) || (this.isDownloaded) ) ) {
      effectiveShopBasis = this.uniqueIdentifier;
    }


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
      shopUniqueIdentifierBasis: effectiveShopBasis, // اضافه شد
    );
  }

  Future<void> saveLyrics(SharedPreferences prefs, String lyricsText) async {
    await prefs.setString(SharedPrefKeys.lyricsDataKeyForSong(uniqueIdentifier), lyricsText);
    this.lyrics = lyricsText;
  }

  Future<void> loadLyrics(SharedPreferences prefs) async {
    this.lyrics = prefs.getString(SharedPrefKeys.lyricsDataKeyForSong(uniqueIdentifier));
  }
}