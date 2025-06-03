// lib/music_shop_song_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart'; // برای بررسی نسخه اندروید

import 'song_model.dart';
import 'payment_screen.dart';
import 'subscription_screen.dart' as sub_screen;
import 'song_detail_screen.dart' as local_player;
import 'main_tabs_screen.dart';
import 'shared_pref_keys.dart';
import 'dart:math';

class Comment {
  final String userId;
  String text;
  DateTime timestamp;
  int likes;
  int dislikes;

  Comment(
      {required this.userId,
      required this.text,
      required this.timestamp,
      this.likes = 0,
      this.dislikes = 0});
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
  sub_screen.SubscriptionTier _currentUserTier =
      sub_screen.SubscriptionTier.none;
  DateTime? _subscriptionExpiry;
  double _userCredit = 0.0;
  bool _isSongAccessible = false;
  bool _isSongDownloaded = false;
  List<Comment> _songComments = [];
  final TextEditingController _commentController = TextEditingController();
  SharedPreferences? _prefs;
  bool _isScreenLoading = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _displayLyrics;

  final List<Comment> _sampleComments = [
    Comment(
        userId: "UserAlpha",
        text: "Amazing vibes!",
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        likes: 5),
    Comment(
        userId: "MusicLover22",
        text: "This is my new favorite.",
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
        likes: 15,
        dislikes: 1),
  ];

  @override
  void initState() {
    super.initState();
    _initScreenDetails();
    if (widget.shopSong.sampleAudioUrl != null &&
        widget.shopSong.sampleAudioUrl!.isNotEmpty) {
      _initSampleAudioPlayer(widget.shopSong.sampleAudioUrl!);
    }
    _samplePlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlayingSample = state.playing);
        if (state.processingState == ProcessingState.completed) {
          _samplePlayer.seek(Duration.zero);
          if (mounted && _isPlayingSample) _samplePlayer.pause();
        }
      }
    });
  }

  Future<void> _initScreenDetails() async {
    setState(() => _isScreenLoading = true);
    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    await _loadUserSubscriptionAndCredit();
    await _checkIfFavorite();
    await _checkIfSongDownloadedAndUpdateLyrics();
    await _checkIfSongIsAccessible();
    _loadSongCommentsFromServer();
    if (mounted) setState(() => _isScreenLoading = false);
  }

  Future<void> _initSampleAudioPlayer(String url) async {
    try {
      if (_samplePlayer.audioSource != null) await _samplePlayer.stop();
      await _samplePlayer.setAudioSource(AudioSource.uri(Uri.parse(url)));
    } catch (e) {
      print("Error initializing sample audio player for URL $url: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not load song sample.')));
    }
  }

  Future<void> _loadUserSubscriptionAndCredit() async {
    _prefs ??= await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _currentUserTier = sub_screen.SubscriptionTier.values[
          _prefs!.getInt(SharedPrefKeys.userSubscriptionTier) ??
              sub_screen.SubscriptionTier.none.index];
      final expiryMillis =
          _prefs!.getInt(SharedPrefKeys.userSubscriptionExpiry);
      _subscriptionExpiry = expiryMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(expiryMillis)
          : null;
      _userCredit = _prefs!.getDouble(SharedPrefKeys.userCredit) ?? 0.0;
      if (_currentUserTier != sub_screen.SubscriptionTier.none &&
          _subscriptionExpiry != null &&
          _subscriptionExpiry!.isBefore(DateTime.now())) {
        _currentUserTier = sub_screen.SubscriptionTier.none;
      }
    });
  }

  Future<void> _checkIfFavorite() async {
    _prefs ??= await SharedPreferences.getInstance();
    final ids =
        _prefs!.getStringList(SharedPrefKeys.favoriteSongIdentifiers) ?? [];
    if (mounted)
      setState(
          () => _isFavorite = ids.contains(widget.shopSong.uniqueIdentifier));
  }

  Future<void> _toggleFavorite() async {
    _prefs ??= await SharedPreferences.getInstance();
    final songToFavorite = widget.shopSong;
    List<String> favData =
        _prefs!.getStringList(SharedPrefKeys.favoriteSongsDataList) ?? [];
    List<String> favIds =
        _prefs!.getStringList(SharedPrefKeys.favoriteSongIdentifiers) ?? [];
    final uniqueId = songToFavorite.uniqueIdentifier;
    bool isFav = favIds.contains(uniqueId);
    String msg;

    if (!isFav) {
      favIds.add(uniqueId);
      final songWithDetails = songToFavorite.copyWith(
          dateAdded: DateTime.now(),
          lyrics: _displayLyrics ?? songToFavorite.lyrics,
          shopUniqueIdentifierBasis: songToFavorite.uniqueIdentifier);
      favData.add(songWithDetails.toDataString());
      msg = '"${songToFavorite.title}" added to favorites.';
      if (mounted) setState(() => _isFavorite = true);
    } else {
      favIds.remove(uniqueId);
      favData.removeWhere((s) {
        try {
          return Song.fromDataString(s).uniqueIdentifier == uniqueId;
        } catch (_) {
          return false;
        }
      });
      msg = '"${songToFavorite.title}" removed from favorites.';
      if (mounted) setState(() => _isFavorite = false);
    }
    await _prefs!.setStringList(SharedPrefKeys.favoriteSongIdentifiers, favIds);
    await _prefs!.setStringList(SharedPrefKeys.favoriteSongsDataList, favData);
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    homeScreenKey.currentState?.refreshDataOnReturn();
  }

  Future<void> _checkIfSongDownloadedAndUpdateLyrics() async {
    _prefs ??= await SharedPreferences.getInstance();
    final downloadedStrings =
        _prefs!.getStringList(SharedPrefKeys.downloadedSongsDataList) ?? [];
    final currentId = widget.shopSong.uniqueIdentifier;
    bool found = false;
    String? lyrics;
    for (String data in downloadedStrings) {
      try {
        final song = Song.fromDataString(data);
        if (song.uniqueIdentifier == currentId) {
          if (await File(song.audioUrl).exists()) {
            found = true;
            await song.loadLyrics(_prefs!);
            lyrics = song.lyrics;
            break;
          }
        }
      } catch (e) {
        print("Error in _checkIfSongDownloadedAndUpdateLyrics: $e");
      }
    }
    if (mounted)
      setState(() {
        _isSongDownloaded = found;
        _displayLyrics = lyrics ?? widget.shopSong.lyrics;
      });
  }

  Future<void> _checkIfSongIsAccessible() async {
    _prefs ??= await SharedPreferences.getInstance();
    if (!mounted) return;
    bool accessible = false;
    if (widget.shopSong.requiredAccessTier == SongAccessTier.free)
      accessible = true;
    else if (_isSongDownloaded)
      accessible = true;
    else if (_currentUserTier != sub_screen.SubscriptionTier.none &&
        _subscriptionExpiry != null &&
        _subscriptionExpiry!.isAfter(DateTime.now())) {
      if (widget.shopSong.requiredAccessTier == SongAccessTier.standard &&
          (_currentUserTier == sub_screen.SubscriptionTier.standard ||
              _currentUserTier == sub_screen.SubscriptionTier.premium))
        accessible = true;
      else if (widget.shopSong.requiredAccessTier == SongAccessTier.premium &&
          _currentUserTier == sub_screen.SubscriptionTier.premium)
        accessible = true;
    }
    if (!accessible && widget.shopSong.isAvailableForPurchase) {
      final purchased =
          _prefs!.getStringList(SharedPrefKeys.purchasedSongIds) ?? [];
      if (purchased.contains(widget.shopSong.uniqueIdentifier))
        accessible = true;
    }
    if (mounted) setState(() => _isSongAccessible = accessible);
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isIOS)
      return true; // iOS doesn't require explicit permission for app's own directory

    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    PermissionStatus status;

    if (androidInfo.version.sdkInt >= 33) {
      // Android 13+
      // For saving in app-specific directories, no explicit media permissions are usually needed.
      // However, if you were reading *shared* media, you'd request Permission.photos, Permission.audio, etc.
      // Since we're writing to getApplicationDocumentsDirectory, this should be fine.
      print(
          "MusicShopSongDetail: Android 13+. App-specific directory write doesn't need explicit media permissions.");
      return true;
    } else {
      // Android 12 and below (targetSDK < 33)
      status = await Permission.storage.status;
      print(
          "MusicShopSongDetail: Storage permission status (Android <13): $status");
      if (!status.isGranted) {
        status = await Permission.storage.request();
        print(
            "MusicShopSongDetail: Storage permission requested. New status: $status");
      }
    }
    return status.isGranted;
  }

  Future<void> _downloadSong() async {
    if (!_isSongAccessible) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('This song is not accessible for download yet.')));
      return;
    }
    if (_isSongDownloaded) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This song is already downloaded.')));
      return;
    }
    if (_isDownloading) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download already in progress...')));
      return;
    }

    bool hasPermission = await _requestStoragePermission();

    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Storage permission is required to download songs.')));
        // چک کردن isPermanentlyDenied برای نمایش دیالوگ تنظیمات
        // این بخش نیاز به بازبینی دارد که آیا status.isPermanentlyDenied پس از _requestStoragePermission در دسترس است یا نه
        // اگر _requestStoragePermission فقط true/false برمی‌گرداند، باید status را جداگانه چک کنیم
        var currentStatus =
            await Permission.storage.status; // دوباره وضعیت را بگیر
        if (currentStatus.isPermanentlyDenied) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Permission Denied"),
              content: const Text(
                  "Storage permission was permanently denied. Please enable it from app settings to download songs."),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Cancel")),
                TextButton(
                    onPressed: openAppSettings, child: const Text("Settings")),
              ],
            ),
          );
        }
      }
      return;
    }

    print("MusicShopSongDetail: Permission granted. Proceeding with download.");
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      Dio dio = Dio();
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String fileName =
          "${widget.shopSong.uniqueIdentifier.replaceAll(RegExp(r'[^\w\.-]'), '_')}.mp3";
      String savePath = "${appDocDir.path}/$fileName";
      print("Downloading '${widget.shopSong.title}' to: $savePath");

      await dio.download(widget.shopSong.audioUrl, savePath,
          onReceiveProgress: (rec, total) {
        if (total != -1 && mounted)
          setState(() => _downloadProgress = rec / total);
      });

      if (mounted) {
        _prefs ??= await SharedPreferences.getInstance();
        List<String> downloadedList =
            _prefs!.getStringList(SharedPrefKeys.downloadedSongsDataList) ?? [];
        final Song downloadedEntry = widget.shopSong.copyWith(
            audioUrl: savePath,
            isDownloaded: true,
            isLocal: true,
            lyrics: _displayLyrics ?? widget.shopSong.lyrics,
            dateAdded: DateTime.now(),
            shopUniqueIdentifierBasis: widget.shopSong.uniqueIdentifier);
        final String dataToStore = downloadedEntry.toDataString();
        downloadedList.removeWhere((s) {
          try {
            return Song.fromDataString(s).uniqueIdentifier ==
                downloadedEntry.uniqueIdentifier;
          } catch (_) {
            return false;
          }
        });
        downloadedList.add(dataToStore);
        await _prefs!.setStringList(
            SharedPrefKeys.downloadedSongsDataList, downloadedList);
        if (downloadedEntry.lyrics != null &&
            downloadedEntry.lyrics!.isNotEmpty) {
          await downloadedEntry.saveLyrics(_prefs!, downloadedEntry.lyrics!);
        }

        setState(() {
          _isSongDownloaded = true;
          _isSongAccessible = true;
          _isDownloading = false;
          _downloadProgress = 0.0;
          _displayLyrics = downloadedEntry.lyrics;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${widget.shopSong.title}" downloaded!')));
        homeScreenKey.currentState?.refreshDataOnReturn();
      }
    } catch (e) {
      print("Error downloading song '${widget.shopSong.title}': $e");
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Download failed for "${widget.shopSong.title}". Error: ${e.toString().split(" ").take(5).join(" ")}...')));
      }
    }
  }

  Future<void> _loadSongCommentsFromServer() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) setState(() => _songComments = _sampleComments);
  }

  Future<void> _submitRating(double rating) async {
    if (mounted) {
      setState(() => _userRating = rating);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rated $rating stars (simulated).')));
    }
  }

  Future<void> _purchaseSong() async {
    _prefs ??= await SharedPreferences.getInstance();
    if (widget.shopSong.price <= 0 || _userCredit < widget.shopSong.price) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Cannot purchase this song or not enough credit.')));
      return;
    }
    final success = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => PaymentScreen(
                amount: widget.shopSong.price,
                itemName: widget.shopSong.title)));
    if (success == true && mounted) {
      double newCredit = _userCredit - widget.shopSong.price;
      await _prefs!.setDouble(SharedPrefKeys.userCredit, newCredit);
      List<String> purchased =
          _prefs!.getStringList(SharedPrefKeys.purchasedSongIds) ?? [];
      if (!purchased.contains(widget.shopSong.uniqueIdentifier))
        purchased.add(widget.shopSong.uniqueIdentifier);
      await _prefs!.setStringList(SharedPrefKeys.purchasedSongIds, purchased);
      setState(() {
        _userCredit = newCredit;
        _isSongAccessible = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '"${widget.shopSong.title}" purchased! You can now download it.')));
      // TODO: Notify UserAuthProvider to reload credit
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase failed or cancelled.')));
    }
  }

  void _navigateToSubscriptionPage() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const sub_screen.SubscriptionScreen())).then((_) {
      if (mounted) _initScreenDetails();
    });
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;
    final newComment = Comment(
        userId: "CurrentUser",
        text: _commentController.text.trim(),
        timestamp: DateTime.now());
    if (mounted) {
      setState(() {
        _songComments.insert(0, newComment);
        _commentController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment submitted (simulated).')));
    }
  }

  @override
  void dispose() {
    _samplePlayer.dispose();
    _commentController.dispose();
    super.dispose();
  }

  String _formatTimestamp(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    // ... (کد کامل build دقیقا مثل پاسخ قبلی که برای همین فایل دادم و شما تایید کردید)
    // از آنجایی که build طولانی است و تغییرات اصلی در منطق state بوده،
    // برای جلوگیری از طولانی شدن بیش از حد این پاسخ، آن را دوباره اینجا تکرار نمی‌کنم.
    // لطفا از کد build ارائه شده در پاسخ قبلی برای همین فایل استفاده کنید.
    // مهم این است که آن کد build، از متغیرهای state این کلاس که حالا کامل‌تر شده‌اند،
    // به درستی استفاده کند (مثلا _displayLyrics, _isDownloading, _isSongDownloaded, و غیره).

    // برای اطمینان، بخش منطق دکمه اصلی را اینجا می‌آورم:
    final screenHeight = MediaQuery.of(context).size.height;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    if (_isScreenLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Widget mainActionButton;
    String mainActionButtonText = "";
    VoidCallback? mainActionButtonOnPressed;
    Color mainActionButtonColor = colorScheme.primary;
    IconData mainActionButtonIcon = Icons.error;
    bool isMainButtonEnabled = true;

    if (_isDownloading) {
      mainActionButtonText =
          "Downloading... (${(_downloadProgress * 100).toStringAsFixed(0)}%)";
      mainActionButtonIcon = Icons.downloading_rounded;
      mainActionButtonOnPressed = null;
      mainActionButtonColor = Colors.grey[700]!;
      isMainButtonEnabled = false;
    } else if (_isSongDownloaded) {
      mainActionButtonText = "Play Full Song";
      mainActionButtonIcon = Icons.play_circle_fill_rounded;
      mainActionButtonOnPressed = () async {
        _prefs ??= await SharedPreferences.getInstance();
        Song? songToPlay;
        final list =
            _prefs!.getStringList(SharedPrefKeys.downloadedSongsDataList) ?? [];
        for (String data in list) {
          try {
            final s = Song.fromDataString(data);
            if (s.uniqueIdentifier == widget.shopSong.uniqueIdentifier) {
              await s.loadLyrics(_prefs!);
              songToPlay = s;
              break;
            }
          } catch (_) {}
        }
        if (songToPlay != null && mounted)
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => local_player.SongDetailScreen(
                      initialSong: songToPlay!,
                      songList: [songToPlay!],
                      initialIndex: 0)));
        else if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Could not play downloaded song.")));
      };
      mainActionButtonColor = Colors.greenAccent[700]!;
    } else if (_isSongAccessible) {
      mainActionButtonText = "Download";
      mainActionButtonIcon = Icons.download_for_offline_outlined;
      mainActionButtonOnPressed = _downloadSong;
      mainActionButtonColor = Colors.tealAccent[400]!;
    } else {
      isMainButtonEnabled = false;
      mainActionButtonOnPressed = null;
      mainActionButtonColor = colorScheme.surfaceVariant.withOpacity(0.8);
      mainActionButtonIcon = Icons.lock_outline_rounded;
      if (widget.shopSong.isAvailableForPurchase &&
          _userCredit < widget.shopSong.price)
        mainActionButtonText =
            "Need ${widget.shopSong.price.toStringAsFixed(0)} Cr.";
      else if (widget.shopSong.isAvailableForPurchase) {
        mainActionButtonText =
            "Purchase (${widget.shopSong.price.toStringAsFixed(0)} Cr.)";
        mainActionButtonIcon = Icons.shopping_cart_checkout_rounded;
        mainActionButtonOnPressed = _purchaseSong;
        isMainButtonEnabled = true;
        mainActionButtonColor = colorScheme.secondary;
      } else {
        switch (widget.shopSong.requiredAccessTier) {
          case SongAccessTier.standard:
            mainActionButtonText = "Requires Standard Plan";
            break;
          case SongAccessTier.premium:
            mainActionButtonText = "Requires Premium Plan";
            break;
          default:
            mainActionButtonText = "Not Available";
            break;
        }
      }
    }
    mainActionButton = ElevatedButton.icon(
      icon: _isDownloading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  value: _downloadProgress > 0 ? _downloadProgress : null,
                  strokeWidth: 2.5,
                  color: theme.brightness == Brightness.dark
                      ? Colors.black87
                      : Colors.white))
          : Icon(mainActionButtonIcon,
              size: 20,
              color: isMainButtonEnabled
                  ? (mainActionButtonColor == Colors.greenAccent[700] ||
                          mainActionButtonColor == Colors.tealAccent[400] ||
                          mainActionButtonColor == colorScheme.secondary
                      ? (theme.brightness == Brightness.dark
                          ? Colors.black87
                          : Colors.white)
                      : colorScheme.onPrimary)
                  : colorScheme.onSurface.withOpacity(0.7)),
      label: Text(mainActionButtonText,
          style: TextStyle(
              color: isMainButtonEnabled
                  ? (mainActionButtonColor == Colors.greenAccent[700] ||
                          mainActionButtonColor == Colors.tealAccent[400] ||
                          mainActionButtonColor == colorScheme.secondary
                      ? (theme.brightness == Brightness.dark
                          ? Colors.black87
                          : Colors.white)
                      : colorScheme.onPrimary)
                  : colorScheme.onSurface.withOpacity(0.7))),
      style: ElevatedButton.styleFrom(
          backgroundColor: mainActionButtonColor,
          disabledBackgroundColor: _isDownloading
              ? Colors.grey[700]
              : colorScheme.surfaceVariant.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: isMainButtonEnabled ? 2 : 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0))),
      onPressed: mainActionButtonOnPressed,
    );
    Widget subscriptionButton = Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: OutlinedButton.icon(
        icon: Icon(Icons.workspace_premium_outlined, color: Colors.amber[600]),
        label: Text(
            _currentUserTier == sub_screen.SubscriptionTier.none
                ? "Get Subscription"
                : "Manage Subscription",
            style: TextStyle(color: Colors.amber[600])),
        style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.amber[600]!),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0))),
        onPressed: _navigateToSubscriptionPage,
      ),
    );
    Widget lyricsDisplayWidget = const SizedBox.shrink();
    if (_displayLyrics != null && _displayLyrics!.isNotEmpty) {
      lyricsDisplayWidget = Padding(
          padding: const EdgeInsets.only(top: 24.0, left: 20.0, right: 20.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Lyrics:",
                style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.onBackground,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(_displayLyrics!,
                    style: textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurface, height: 1.6))),
          ]));
    }

    // بقیه کد build که شامل AppBar, SingleChildScrollView, Column و ... است
    // دقیقا مشابه کد build در پاسخ قبلی برای همین فایل است و اینجا برای اختصار حذف شده.
    // لطفا آن را کپی کنید.
    return Scaffold(
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: colorScheme.onSurface),
            actions: [
              IconButton(
                  icon: Icon(
                      _isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: _isFavorite
                          ? colorScheme.primary
                          : colorScheme.onSurface.withOpacity(0.8),
                      size: 28),
                  onPressed: _toggleFavorite,
                  tooltip: _isFavorite ? "Remove from favs" : "Add to favs")
            ]),
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
                          ? Image.asset(widget.shopSong.coverImagePath!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                  color: colorScheme.surfaceVariant
                                      .withOpacity(0.7),
                                  child: Icon(Icons.album_rounded,
                                      size: 100,
                                      color: colorScheme.onSurfaceVariant
                                          .withOpacity(0.5))))
                          : Container(
                              color:
                                  colorScheme.surfaceVariant.withOpacity(0.7),
                              child: Icon(Icons.album_rounded,
                                  size: 100,
                                  color: colorScheme.onSurfaceVariant
                                      .withOpacity(0.5)))),
                  if (widget.shopSong.sampleAudioUrl != null &&
                      widget.shopSong.sampleAudioUrl!.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Center(
                            child: FloatingActionButton.extended(
                                onPressed: () async {
                                  if (_samplePlayer.audioSource == null &&
                                      widget.shopSong.sampleAudioUrl != null)
                                    await _initSampleAudioPlayer(
                                        widget.shopSong.sampleAudioUrl!);
                                  if (_samplePlayer.audioSource == null) return;
                                  if (_isPlayingSample)
                                    await _samplePlayer.pause();
                                  else {
                                    if (_samplePlayer.processingState ==
                                        ProcessingState.completed)
                                      await _samplePlayer.seek(Duration.zero);
                                    await _samplePlayer.play();
                                  }
                                },
                                icon: Icon(
                                    _isPlayingSample
                                        ? Icons.pause_circle_filled_outlined
                                        : Icons.play_circle_fill_outlined,
                                    color: theme.brightness == Brightness.dark
                                        ? Colors.black87
                                        : Colors.white,
                                    size: 22),
                                label: Text(
                                    _isPlayingSample
                                        ? "Pause Sample"
                                        : "Play Sample",
                                    style: TextStyle(
                                        color:
                                            theme.brightness == Brightness.dark
                                                ? Colors.black87
                                                : Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                backgroundColor: Colors.tealAccent[400],
                                elevation: 2))),
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(widget.shopSong.title,
                                textAlign: TextAlign.center,
                                style: textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(widget.shopSong.artist,
                                textAlign: TextAlign.center,
                                style: textTheme.titleMedium?.copyWith(
                                    color: colorScheme.onBackground
                                        .withOpacity(0.7))),
                            const SizedBox(height: 16),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.star_rounded,
                                      color: Colors.amber, size: 22),
                                  const SizedBox(width: 5),
                                  Text(widget.shopSong.averageRating
                                      .toStringAsFixed(1)),
                                  const SizedBox(width: 24),
                                  Text("Rate it:"),
                                  const SizedBox(width: 8),
                                  Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: List.generate(
                                          5,
                                          (i) => InkWell(
                                              onTap: () =>
                                                  _submitRating(i + 1.0),
                                              child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 2),
                                                  child: Icon(
                                                      i < _userRating
                                                          ? Icons.star_rounded
                                                          : Icons
                                                              .star_border_rounded,
                                                      color: Colors.amber,
                                                      size: 26)))))
                                ]),
                            const SizedBox(height: 24),
                            mainActionButton,
                            if ((widget.shopSong.requiredAccessTier !=
                                        SongAccessTier.free ||
                                    _currentUserTier !=
                                        sub_screen.SubscriptionTier.none) &&
                                !_isSongDownloaded)
                              subscriptionButton,
                            lyricsDisplayWidget,
                            const SizedBox(height: 24),
                            Divider(
                                color: colorScheme.onSurface.withOpacity(0.2)),
                            const SizedBox(height: 16),
                            Text("Comments (${_songComments.length})",
                                style: textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            TextField(
                                controller: _commentController,
                                decoration: InputDecoration(
                                    hintText: "Write a comment...",
                                    suffixIcon: IconButton(
                                        icon: Icon(Icons.send_rounded,
                                            color: colorScheme.primary),
                                        onPressed: _submitComment)),
                                maxLines: 3,
                                minLines: 1),
                            const SizedBox(height: 16),
                            _songComments.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 24),
                                    child: Text("No comments yet.",
                                        textAlign: TextAlign.center))
                                : ListView.separated(
                                    shrinkWrap: true,
                                    physics: NeverScrollableScrollPhysics(),
                                    itemCount: _songComments.length,
                                    separatorBuilder: (_, __) => Divider(
                                        height: 24,
                                        color: colorScheme.onSurface
                                            .withOpacity(0.1)),
                                    itemBuilder: (c, i) {
                                      final com = _songComments[i];
                                      return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              CircleAvatar(
                                                  radius: 16,
                                                  child: Icon(
                                                      Icons.person_outline,
                                                      size: 18)),
                                              const SizedBox(width: 8),
                                              Text(com.userId,
                                                  style: textTheme.titleSmall
                                                      ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold)),
                                              const Spacer(),
                                              Text(
                                                  _formatTimestamp(
                                                      com.timestamp),
                                                  style: textTheme.bodySmall)
                                            ]),
                                            const SizedBox(height: 6),
                                            Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 40, right: 8),
                                                child: Text(com.text)),
                                            const SizedBox(height: 8),
                                            Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 35),
                                                child: Row(children: [
                                                  IconButton(
                                                      icon: Icon(
                                                          Icons
                                                              .thumb_up_alt_outlined,
                                                          size: 16),
                                                      onPressed: () {}),
                                                  Text(com.likes.toString()),
                                                  const SizedBox(width: 12),
                                                  IconButton(
                                                      icon: Icon(
                                                          Icons
                                                              .thumb_down_alt_outlined,
                                                          size: 16),
                                                      onPressed: () {}),
                                                  Text(com.dislikes.toString())
                                                ]))
                                          ]);
                                    })
                          ]))
                ])));
  }
}
