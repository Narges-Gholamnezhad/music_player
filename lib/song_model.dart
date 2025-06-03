// lib/song_model.dart

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
  final String? lyrics; // <--- فیلد جدید برای متن آهنگ

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
    this.lyrics, // <--- اضافه شده به constructor
    this.isLocal = false,
    this.isDownloaded = false,
    this.mediaStoreId,
    this.requiredAccessTier = SongAccessTier.free,
  });

  bool get isAvailableForPurchase => price > 0 && requiredAccessTier != SongAccessTier.free;

  factory Song.fromDataString(String dataString) {
    final parts = dataString.split(';;');
    // title;;artist;;audioUrl;;coverPath;;isLocal;;mediaStoreId;;isDownloaded;;requiredAccessTier_name;;price;;lyrics
    if (parts.length < 10) { // <--- افزایش به 10 برای lyrics
      print("Song.fromDataString: Invalid data string format: $dataString. Expected 10 parts, got ${parts.length}");
      throw FormatException("Invalid song data string format");
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
        lyrics: parts[9].isNotEmpty ? parts[9].replaceAll('\\n', '\n') : null, // <--- خواندن lyrics و جایگزینی \\n
      );
    } catch (e) {
      print("Song.fromDataString: Error parsing song data: $e, Data: $dataString");
      throw FormatException("Error parsing song data string: $e");
    }
  }

  String toDataString() {
    final String localMediaStoreId = mediaStoreId?.toString() ?? 'null';
    final String localCoverPath = coverImagePath ?? '';
    final String localLyrics = lyrics?.replaceAll('\n', '\\n') ?? ''; // <--- ذخیره lyrics با جایگزینی \n
    // title;;artist;;audioUrl;;coverPath;;isLocal;;mediaStoreId;;isDownloaded;;requiredAccessTier_name;;price;;lyrics
    return '$title;;$artist;;$audioUrl;;$localCoverPath;;$isLocal;;$localMediaStoreId;;$isDownloaded;;${requiredAccessTier.name};;$price;;$localLyrics';
  }

  Song copyWith({
    String? title,
    String? artist,
    String? coverImagePath,
    String? audioUrl,
    double? price,
    double? averageRating,
    String? sampleAudioUrl,
    String? lyrics, // <--- اضافه شده به copyWith
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
      lyrics: lyrics ?? this.lyrics, // <--- استفاده شده در copyWith
      isLocal: isLocal ?? this.isLocal,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      mediaStoreId: mediaStoreId ?? this.mediaStoreId,
      requiredAccessTier: requiredAccessTier ?? this.requiredAccessTier,
    );
  }
}