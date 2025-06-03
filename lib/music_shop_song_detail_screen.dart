// lib/music_shop_song_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'song_model.dart';
import 'payment_screen.dart';
import 'subscription_screen.dart' as sub_screen;
import 'song_detail_screen.dart' as local_player;
import 'main_tabs_screen.dart'; // برای homeScreenKey
import 'shared_pref_keys.dart';
import 'dart:math'; // برای min

// پکیج‌های جدید برای دانلود
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io'; // برای کلاس File
import 'package:permission_handler/permission_handler.dart';

class Comment {
  final String userId;
  final String text;
  final DateTime timestamp;
  int likes;
  int dislikes;

  Comment({
    required this.userId,
    required this.text,
    required this.timestamp,
    this.likes = 0,
    this.dislikes = 0,
  });
}

class MusicShopSongDetailScreen extends StatefulWidget {
  final Song shopSong;
  const MusicShopSongDetailScreen({super.key, required this.shopSong});

  @override
  State<MusicShopSongDetailScreen> createState() =>
      _MusicShopSongDetailScreenState();
}

class _MusicShopSongDetailScreenState extends State<MusicShopSongDetailScreen> {
  final AudioPlayer _samplePlayer = AudioPlayer();
  bool _isPlayingSample = false;
  double _userRating = 0.0;
  bool _isFavorite = false;
  sub_screen.SubscriptionTier _currentUserTier = sub_screen.SubscriptionTier.none;
  DateTime? _subscriptionExpiry;
  double _userCredit = 0.0;
  bool _isSongAccessible = false;
  bool _isSongDownloaded = false;
  List<Comment> _songComments = [];
  final TextEditingController _commentController = TextEditingController();
  SharedPreferences? _prefs;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    print("MusicShopSongDetailScreen: initState for ${widget.shopSong.title} (UID: ${widget.shopSong.uniqueIdentifier})");
    _initScreenDetails();

    if (widget.shopSong.sampleAudioUrl != null &&
        widget.shopSong.sampleAudioUrl!.isNotEmpty) {
      _initSampleAudioPlayer(widget.shopSong.sampleAudioUrl!);
    }
    _samplePlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingSample = state.playing;
        });
        if (state.processingState == ProcessingState.completed) {
          _samplePlayer.seek(Duration.zero);
          if (mounted) _samplePlayer.pause();
        }
      }
    });
  }

  Future<void> _initScreenDetails() async {
    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    await widget.shopSong.loadLyrics(_prefs!);
    await _loadUserSubscriptionAndCredit();
    await _checkIfFavorite();
    await _checkIfSongDownloaded();
    await _checkIfSongIsAccessible(); // <--- این متد باید تعریف شده باشد
    _loadSongCommentsFromServer();
  }

  Future<void> _loadUserSubscriptionAndCredit() async {
    if (_prefs == null) return;
    if (mounted) {
      setState(() {
        _currentUserTier = sub_screen.SubscriptionTier.values[
        _prefs!.getInt(SharedPrefKeys.userSubscriptionTier) ?? sub_screen.SubscriptionTier.none.index];
        final expiryMillis = _prefs!.getInt(SharedPrefKeys.userSubscriptionExpiry);
        _subscriptionExpiry = expiryMillis != null ? DateTime.fromMillisecondsSinceEpoch(expiryMillis) : null;
        _userCredit = _prefs!.getDouble(SharedPrefKeys.userCredit) ?? 0.0;

        if (_currentUserTier != sub_screen.SubscriptionTier.none &&
            _subscriptionExpiry != null &&
            _subscriptionExpiry!.isBefore(DateTime.now())) {
          _currentUserTier = sub_screen.SubscriptionTier.none;
        }
      });
    }
  }

  Future<void> _checkIfFavorite() async {
    if (_prefs == null) return;
    final List<String> favoriteIdsList = _prefs!.getStringList(SharedPrefKeys.favoriteSongIdentifiers) ?? [];
    if (mounted) {
      setState(() {
        _isFavorite = favoriteIdsList.contains(widget.shopSong.uniqueIdentifier);
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_prefs == null) return;
    final songToFavorite = widget.shopSong;

    List<String> currentFavoriteDataStrings = _prefs!.getStringList(SharedPrefKeys.favoriteSongsDataList) ?? [];
    List<String> currentFavoriteIds = _prefs!.getStringList(SharedPrefKeys.favoriteSongIdentifiers) ?? [];

    final uniqueId = songToFavorite.uniqueIdentifier;
    bool isCurrentlyPersistedAsFavorite = currentFavoriteIds.contains(uniqueId);
    String message;

    if (!isCurrentlyPersistedAsFavorite) {
      currentFavoriteIds.add(uniqueId);
      currentFavoriteDataStrings.add(songToFavorite.toDataString());
      message = '"${songToFavorite.title}" added to favorites.';
      if(mounted) setState(() => _isFavorite = true);
    } else {
      currentFavoriteIds.remove(uniqueId);
      currentFavoriteDataStrings.removeWhere((dataStr) {
        try {
          final songFromData = Song.fromDataString(dataStr);
          return songFromData.uniqueIdentifier == uniqueId;
        } catch (e) { return false; }
      });
      message = '"${songToFavorite.title}" removed from favorites.';
      if(mounted) setState(() => _isFavorite = false);
    }

    await _prefs!.setStringList(SharedPrefKeys.favoriteSongIdentifiers, currentFavoriteIds);
    await _prefs!.setStringList(SharedPrefKeys.favoriteSongsDataList, currentFavoriteDataStrings);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _checkIfSongDownloaded() async {
    if (_prefs == null) return;
    final List<String> downloadedDataStrings = _prefs!.getStringList(SharedPrefKeys.downloadedSongsDataList) ?? [];
    final String currentSongIdentifier = widget.shopSong.uniqueIdentifier;
    bool foundAndFileExists = false;
    String? localFilePath;

    for (String dataString in downloadedDataStrings) {
      try {
        final song = Song.fromDataString(dataString);
        if (song.uniqueIdentifier == currentSongIdentifier) {
          if (await File(song.audioUrl).exists()) {
            foundAndFileExists = true;
            localFilePath = song.audioUrl; // مسیر فایل محلی را ذخیره کن
            // اگر lyrics با آهنگ دانلود شده ذخیره شده، آن را هم بارگذاری کن
            // این کار بهتر است در song.loadLyrics انجام شود اگر به آنجا منتقل شده
            // widget.shopSong.lyrics = song.lyrics;
          } else {
            print("Downloaded song file not found for ${song.title} at ${song.audioUrl}. Consider removing from list.");
          }
          break;
        }
      } catch (e) {
        print("Error in _checkIfSongDownloaded parsing: $e");
      }
    }

    if (mounted) {
      setState(() {
        _isSongDownloaded = foundAndFileExists;
        if (foundAndFileExists && localFilePath != null) {
          // اگر لازم است audioUrl آهنگ ویجت را به مسیر محلی آپدیت کنیم برای دکمه Play
          // این کار را با احتیاط انجام دهید چون widget.shopSong نباید مستقیما تغییر کند.
          // بهتر است یک Song جدید بسازیم یا در _isSongDownloaded فقط فلگ را ست کنیم
          // و در دکمه Play از لیست دانلود شده‌ها آهنگ با مسیر محلی را پیدا کنیم.
        }
      });
      print("MusicShopSongDetail: Song '${widget.shopSong.title}' downloaded status: $_isSongDownloaded");
    }
  }

  // ***** تعریف متد _checkIfSongIsAccessible *****
  Future<void> _checkIfSongIsAccessible() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
      if(_prefs == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not determine song accessibility. Please try again.'))
        );
        return;
      }
    }
    if (!mounted) return;

    bool accessible = false;

    if (widget.shopSong.requiredAccessTier == SongAccessTier.free) {
      accessible = true;
    } else if (_isSongDownloaded) {
      accessible = true;
    } else if (_currentUserTier != sub_screen.SubscriptionTier.none &&
        _subscriptionExpiry != null &&
        _subscriptionExpiry!.isAfter(DateTime.now())) {
      if (widget.shopSong.requiredAccessTier == SongAccessTier.standard &&
          (_currentUserTier == sub_screen.SubscriptionTier.standard || _currentUserTier == sub_screen.SubscriptionTier.premium)) {
        accessible = true;
      } else if (widget.shopSong.requiredAccessTier == SongAccessTier.premium &&
          _currentUserTier == sub_screen.SubscriptionTier.premium) {
        accessible = true;
      }
    }

    if (!accessible && widget.shopSong.isAvailableForPurchase) {
      final List<String> purchasedSongIdentifiers = _prefs!.getStringList(SharedPrefKeys.purchasedSongIds) ?? [];
      if (purchasedSongIdentifiers.contains(widget.shopSong.uniqueIdentifier)) {
        accessible = true;
      }
    }

    if (mounted) {
      setState(() {
        _isSongAccessible = accessible;
      });
      print(
          "MusicShopSongDetail: Final song accessible status for '${widget.shopSong.title}': $_isSongAccessible. RequiredTier: ${widget.shopSong.requiredAccessTier}, UserTier: $_currentUserTier, isDownloaded: $_isSongDownloaded, Price: ${widget.shopSong.price}");
    }
  }
  // ***** پایان تعریف متد _checkIfSongIsAccessible *****


  Future<void> _downloadSong() async {
    if (!_isSongAccessible) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This song is not accessible for download yet.')));
      return;
    }
    if (_isSongDownloaded) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This song is already downloaded.')));
      return;
    }
    if (_isDownloading) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download already in progress...')));
      return;
    }

    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (status.isDenied) { // اگر قبلا رد شده یا اولین بار است
        status = await Permission.storage.request();
      }
      if (!status.isGranted) { // اگر پس از درخواست هم رد شد
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Storage permission denied. Cannot download song.')));
        if (status.isPermanentlyDenied && mounted) {
          showDialog(context: context, builder: (context) => AlertDialog(
            title: const Text("Permission Denied"),
            content: const Text("Storage permission is permanently denied. Please enable it from app settings."),
            actions: [TextButton(onPressed: ()=> Navigator.of(context).pop(), child: const Text("Cancel")), TextButton(onPressed: openAppSettings, child: const Text("Settings"))],
          ));
        }
        return;
      }
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      Dio dio = Dio();
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String fileName = "${widget.shopSong.uniqueIdentifier.replaceAll(RegExp(r'[^\w\.-]'), '_')}.mp3";
      String savePath = "${appDocDir.path}/$fileName";
      print("Downloading to: $savePath");

      await dio.download(
        widget.shopSong.audioUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() => _downloadProgress = received / total);
          }
        },
      );

      if (mounted) {
        _prefs ??= await SharedPreferences.getInstance();
        List<String> downloadedSongDataStrings = _prefs!.getStringList(SharedPrefKeys.downloadedSongsDataList) ?? [];
        final Song downloadedSongEntry = widget.shopSong.copyWith(
          audioUrl: savePath,
          isDownloaded: true,
          isLocal: true, // حالا آهنگ محلی است
          lyrics: widget.shopSong.lyrics,
        );
        final String songDataToStore = downloadedSongEntry.toDataString();
        final String uniqueId = widget.shopSong.uniqueIdentifier;

        downloadedSongDataStrings.removeWhere((data) {
          try { return Song.fromDataString(data).uniqueIdentifier == uniqueId; } catch (e) { return false; }
        });
        downloadedSongDataStrings.add(songDataToStore);
        await _prefs!.setStringList(SharedPrefKeys.downloadedSongsDataList, downloadedSongDataStrings);

        if (widget.shopSong.lyrics != null && widget.shopSong.lyrics!.isNotEmpty) {
          await downloadedSongEntry.saveLyrics(_prefs!, widget.shopSong.lyrics!); // ذخیره lyrics برای نسخه دانلود شده
        }

        setState(() {
          _isSongDownloaded = true;
          _isSongAccessible = true;
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${widget.shopSong.title}" downloaded successfully!')));
        homeScreenKey.currentState?.refreshDataOnReturn();
      }
    } catch (e) {
      print("Error downloading song: $e");
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to download "${widget.shopSong.title}". Error: ${e.toString().split(':').first}')));
      }
    }
  }


  Future<void> _initSampleAudioPlayer(String url) async {
    // ... (کد قبلی بدون تغییر)
  }
  Future<void> _loadSongCommentsFromServer() async {
    // ... (کد قبلی بدون تغییر)
  }
  Future<void> _submitRating(double rating) async {
    // ... (کد قبلی بدون تغییر)
  }
  Future<void> _purchaseSong() async {
    // ... (کد قبلی با SharedPrefKeys)
  }
  void _navigateToSubscriptionPage() {
    // ... (کد قبلی)
  }
  Future<void> _submitComment() async {
    // ... (کد قبلی)
  }
  @override
  void dispose() {
    _samplePlayer.dispose();
    _commentController.dispose();
    super.dispose();
  }
  String _formatTimestamp(DateTime timestamp) {
    // ... (کد قبلی)
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inSeconds < 60) return '${difference.inSeconds}s ago';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    Widget mainActionButton;
    String mainActionButtonText = "";
    VoidCallback? mainActionButtonOnPressed;
    Color mainActionButtonColor = colorScheme.primary;
    bool isMainButtonEnabled = true;

    if (_isDownloading) {
      mainActionButtonText = "Downloading... (${(_downloadProgress * 100).toStringAsFixed(0)}%)";
      mainActionButtonOnPressed = null;
      mainActionButtonColor = Colors.grey[700]!;
      isMainButtonEnabled = false;
    } else if (_isSongDownloaded) {
      mainActionButtonText = "Play Full Song (Downloaded)";
      mainActionButtonOnPressed = () async {
        _prefs ??= await SharedPreferences.getInstance();
        Song? songToPlay;
        final List<String> downloadedList = _prefs!.getStringList(SharedPrefKeys.downloadedSongsDataList) ?? [];
        for(String dataStr in downloadedList){
          try {
            final s = Song.fromDataString(dataStr);
            if (s.uniqueIdentifier == widget.shopSong.uniqueIdentifier) {
              await s.loadLyrics(_prefs!);
              songToPlay = s;
              break;
            }
          } catch (e) { print("Error finding downloaded song for playback: $e");}
        }
        if(songToPlay != null && mounted){
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => local_player.SongDetailScreen(
                      initialSong: songToPlay!,
                      songList: [songToPlay!], // یا می‌توانید لیست کامل دانلود شده‌ها را بفرستید
                      initialIndex: 0)));
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not find downloaded song details to play.")));
        }
      };
      mainActionButtonColor = Colors.greenAccent[700]!;
    } else if (_isSongAccessible) {
      mainActionButtonText = "Download";
      mainActionButtonOnPressed = _downloadSong;
      mainActionButtonColor = Colors.tealAccent[400]!;
    } else {
      isMainButtonEnabled = false;
      mainActionButtonOnPressed = null;
      mainActionButtonColor = colorScheme.surfaceVariant.withOpacity(0.8);
      switch (widget.shopSong.requiredAccessTier) {
        case SongAccessTier.standard: mainActionButtonText = "Requires Standard Plan"; break;
        case SongAccessTier.premium: mainActionButtonText = "Requires Premium Plan"; break;
        case SongAccessTier.free: mainActionButtonText = "Free (Access Issue?)"; break;
      }
    }

    mainActionButton = ElevatedButton.icon(
      icon: _isDownloading
          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(value: _downloadProgress > 0 ? _downloadProgress : null, strokeWidth: 2.5, color: Colors.white))
          : Icon(
        _isSongDownloaded ? Icons.play_circle_fill_rounded :
        _isSongAccessible ? Icons.download_for_offline_outlined : Icons.lock_outline_rounded,
        size: 20,
        color: isMainButtonEnabled ? (mainActionButtonColor == Colors.greenAccent[700] || mainActionButtonColor == Colors.tealAccent[400] ? Colors.black87 : colorScheme.onPrimary) : colorScheme.onSurface.withOpacity(0.7),
      ),
      label: Text(
          mainActionButtonText,
          style: TextStyle(color: isMainButtonEnabled ? (mainActionButtonColor == Colors.greenAccent[700] || mainActionButtonColor == Colors.tealAccent[400] ? Colors.black87 : colorScheme.onPrimary) : colorScheme.onSurface.withOpacity(0.7))
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: mainActionButtonColor,
        disabledBackgroundColor: _isDownloading ? Colors.grey[700] : colorScheme.surfaceVariant.withOpacity(0.5),
        disabledForegroundColor: colorScheme.onSurface.withOpacity(0.3),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        elevation: isMainButtonEnabled ? 2 : 0,
      ),
      onPressed: mainActionButtonOnPressed,
    );

    Widget subscriptionButton = Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: OutlinedButton.icon(
        icon: Icon(Icons.workspace_premium_outlined, color: Colors.amber[600]),
        label: Text(
            _currentUserTier == sub_screen.SubscriptionTier.none ? "Get Subscription" : "Manage/Upgrade Subscription",
            style: TextStyle(color: Colors.amber[600])
        ),
        style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.amber[600]!),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
        onPressed: _navigateToSubscriptionPage,
      ),
    );

    Widget lyricsDisplayWidget = const SizedBox.shrink();
    if (widget.shopSong.lyrics != null && widget.shopSong.lyrics!.isNotEmpty) {
      lyricsDisplayWidget = Padding(
        padding: const EdgeInsets.only(top: 24.0, left: 20.0, right: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Lyrics:", style: textTheme.titleLarge?.copyWith(color: colorScheme.onBackground, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.shopSong.lyrics!,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, height: 1.6),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          IconButton(
            icon: Icon(_isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _isFavorite ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.8),
                size: 28),
            onPressed: _toggleFavorite,
            tooltip: _isFavorite ? "Remove from favorites" : "Add to favorites",
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: screenHeight * 0.40,
              width: double.infinity,
              child: (widget.shopSong.coverImagePath != null &&
                  widget.shopSong.coverImagePath!.isNotEmpty)
                  ? Image.asset(
                widget.shopSong.coverImagePath!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[850],
                    child: Icon(Icons.album_rounded,
                        size: 100, color: Colors.grey[700])),
              )
                  : Container(
                  color: Colors.grey[850],
                  child: Icon(Icons.album_rounded,
                      size: 100, color: Colors.grey[700])),
            ),

            if (widget.shopSong.sampleAudioUrl != null &&
                widget.shopSong.sampleAudioUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                child: Center(
                  child: FloatingActionButton.extended(
                    onPressed: () async {
                      if (_samplePlayer.audioSource == null &&
                          widget.shopSong.sampleAudioUrl != null &&
                          widget.shopSong.sampleAudioUrl!.isNotEmpty) {
                        await _initSampleAudioPlayer(widget.shopSong.sampleAudioUrl!);
                      }
                      if (_samplePlayer.audioSource == null) return;
                      if (_isPlayingSample) {
                        await _samplePlayer.pause();
                      } else {
                        if (_samplePlayer.processingState == ProcessingState.completed) {
                          await _samplePlayer.seek(Duration.zero);
                        }
                        await _samplePlayer.play();
                      }
                    },
                    icon: Icon(
                        _isPlayingSample
                            ? Icons.pause_circle_filled_outlined
                            : Icons.play_circle_fill_outlined,
                        color: Colors.black87, size: 22),
                    label: Text(_isPlayingSample ? "Pause Sample" : "Play Sample",
                        style: const TextStyle(
                            color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 14)),
                    backgroundColor: Colors.tealAccent[400],
                    elevation: 2,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(widget.shopSong.title,
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onBackground,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(widget.shopSong.artist,
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onBackground.withOpacity(0.7))),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star_rounded, color: Colors.amber, size: 22),
                      const SizedBox(width: 5),
                      Text(widget.shopSong.averageRating.toStringAsFixed(1),
                          style: textTheme.titleMedium?.copyWith(color: colorScheme.onBackground)),
                      const SizedBox(width: 24),
                      Text("Rate it:",
                          style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onBackground.withOpacity(0.7))),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (index) {
                          return InkWell(
                            onTap: () => _submitRating(index + 1.0),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0),
                              child: Icon(
                                  index < _userRating
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: Colors.amber,
                                  size: 26),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  mainActionButton,
                  if (!(widget.shopSong.requiredAccessTier == SongAccessTier.free && _isSongAccessible))
                    subscriptionButton,
                  lyricsDisplayWidget,
                  const SizedBox(height: 24),
                  Divider(color: colorScheme.onSurface.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text("Comments (${_songComments.length})",
                      style: textTheme.titleLarge?.copyWith(
                          color: colorScheme.onBackground,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commentController,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: "Write a comment...",
                      hintStyle: theme.inputDecorationTheme.hintStyle?.copyWith(
                        color: (theme.inputDecorationTheme.hintStyle?.color ?? Colors.grey[600])?.withOpacity(0.7),
                      ) ?? TextStyle(color: Colors.grey[600]?.withOpacity(0.7)),
                      fillColor: theme.inputDecorationTheme.fillColor ?? const Color(0xFF2C2C2E), // از تم یا پیش‌فرض
                      filled: theme.inputDecorationTheme.filled ?? true,
                      suffixIcon: IconButton(
                        icon: Icon(Icons.send_rounded, color: colorScheme.primary),
                        onPressed: _submitComment,
                      ),
                      border: theme.inputDecorationTheme.border ?? OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide.none),
                      enabledBorder: theme.inputDecorationTheme.enabledBorder ?? OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide.none),
                      focusedBorder: theme.inputDecorationTheme.focusedBorder ?? OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: colorScheme.primary, width: 1.5)),
                      contentPadding: theme.inputDecorationTheme.contentPadding ?? const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
                    ),
                    maxLines: 3,
                    minLines: 1,
                  ),
                  const SizedBox(height: 16),
                  _songComments.isEmpty
                      ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Text(
                      "No comments yet. Be the first to share your thoughts!",
                      style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6)),
                      textAlign: TextAlign.center,
                    ),
                  )
                      : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _songComments.length, // <--- پارامتر الزامی
                    separatorBuilder: (context, index) => Divider( // <--- پارامتر الزامی
                        color: colorScheme.onSurface.withOpacity(0.1),
                        height: 24),
                    itemBuilder: (context, index) { // <--- پارامتر الزامی
                      final comment = _songComments[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                  backgroundColor: colorScheme.primary.withOpacity(0.2),
                                  radius: 16,
                                  child: Icon(Icons.person_outline, size: 18, color: colorScheme.primary)),
                              const SizedBox(width: 8),
                              Text(comment.userId,
                                  style: textTheme.titleSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Text(_formatTimestamp(comment.timestamp),
                                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.5))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 40.0, right: 8.0),
                            child: Text(comment.text,
                                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.9))),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 35.0),
                            child: Row(
                              children: [
                                IconButton(
                                    icon: Icon(Icons.thumb_up_alt_outlined, size: 16, color: Colors.grey[600]),
                                    onPressed: () { /* TODO: منطق لایک */ },
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4)),
                                Text(comment.likes.toString(), style: textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                                const SizedBox(width: 12),
                                IconButton(
                                    icon: Icon(Icons.thumb_down_alt_outlined, size: 16, color: Colors.grey[600]),
                                    onPressed: () { /* TODO: منطق دیسلایک */ },
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4)),
                                Text(comment.dislikes.toString(), style: textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                              ],
                            ),
                          )
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}