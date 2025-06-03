// lib/music_shop_song_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

import 'song_model.dart';
import 'payment_screen.dart';
import 'subscription_screen.dart' as sub_screen;
import 'song_detail_screen.dart' as local_player; // برای پخش آهنگ دانلود شده
import 'main_tabs_screen.dart'; // برای homeScreenKey و رفرش
import 'shared_pref_keys.dart';
import 'dart:math'; // برای min

// مدل Comment (بدون تغییر از کد قبلی شما)
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
  double _userRating = 0.0; // این باید از سرور یا SharedPreferences خوانده شود
  bool _isFavorite = false;
  sub_screen.SubscriptionTier _currentUserTier = sub_screen.SubscriptionTier.none;
  DateTime? _subscriptionExpiry;
  double _userCredit = 0.0;
  bool _isSongAccessible = false;
  bool _isSongDownloaded = false;
  List<Comment> _songComments = []; // این باید از سرور لود شود
  final TextEditingController _commentController = TextEditingController();
  SharedPreferences? _prefs;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  // نمونه کامنت‌ها برای نمایش (در یک برنامه واقعی از سرور می‌آید)
  final List<Comment> _sampleComments = [
    Comment(userId: "UserA", text: "Great song!", timestamp: DateTime.now().subtract(const Duration(hours: 2)), likes: 10, dislikes: 1),
    Comment(userId: "MusicFan", text: "Love the beat.", timestamp: DateTime.now().subtract(const Duration(days: 1)), likes: 5),
  ];


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
          if (mounted && _isPlayingSample) _samplePlayer.pause(); // فقط اگر در حال پخش بود، متوقف کن
        }
      }
    });
  }

  Future<void> _initScreenDetails() async {
    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    // بارگذاری متن آهنگ (اگر از قبل دانلود شده یا در SharedPreferences ذخیره شده)
    // در اینجا، shopSong معمولا lyrics ندارد مگر اینکه از جایی ست شده باشد.
    // اگر آهنگ دانلود شده، lyrics آن باید با نسخه دانلود شده بیاید.
    // await widget.shopSong.loadLyrics(_prefs!); // این ممکن است برای shopSong معنی ندهد

    await _loadUserSubscriptionAndCredit();
    await _checkIfFavorite();
    await _checkIfSongDownloaded(); // این متد ممکن است lyrics را برای آهنگ دانلود شده لود کند
    await _checkIfSongIsAccessible();
    _loadSongCommentsFromServer(); // در حال حاضر از نمونه استفاده می‌کند
  }

  Future<void> _initSampleAudioPlayer(String url) async {
    try {
      // اگر قبلا منبعی ست شده، اول stop کن
      if (_samplePlayer.audioSource != null) {
        await _samplePlayer.stop();
      }
      await _samplePlayer.setAudioSource(AudioSource.uri(Uri.parse(url)));
    } catch (e) {
      print("Error initializing sample audio player: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load song sample.')),
        );
      }
    }
  }


  Future<void> _loadUserSubscriptionAndCredit() async {
    _prefs ??= await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentUserTier = sub_screen.SubscriptionTier.values[
        _prefs!.getInt(SharedPrefKeys.userSubscriptionTier) ?? sub_screen.SubscriptionTier.none.index];
        final expiryMillis = _prefs!.getInt(SharedPrefKeys.userSubscriptionExpiry);
        _subscriptionExpiry = expiryMillis != null ? DateTime.fromMillisecondsSinceEpoch(expiryMillis) : null;
        _userCredit = _prefs!.getDouble(SharedPrefKeys.userCredit) ?? 0.0;

        // بررسی انقضای اشتراک
        if (_currentUserTier != sub_screen.SubscriptionTier.none &&
            _subscriptionExpiry != null &&
            _subscriptionExpiry!.isBefore(DateTime.now())) {
          _currentUserTier = sub_screen.SubscriptionTier.none;
          // اختیاری: پاک کردن از SharedPreferences
          // _prefs!.remove(SharedPrefKeys.userSubscriptionTier);
          // _prefs!.remove(SharedPrefKeys.userSubscriptionExpiry);
        }
      });
    }
  }

  Future<void> _checkIfFavorite() async {
    _prefs ??= await SharedPreferences.getInstance();
    final List<String> favoriteIdsList = _prefs!.getStringList(SharedPrefKeys.favoriteSongIdentifiers) ?? [];
    if (mounted) {
      setState(() {
        _isFavorite = favoriteIdsList.contains(widget.shopSong.uniqueIdentifier);
      });
    }
  }

  Future<void> _toggleFavorite() async {
    _prefs ??= await SharedPreferences.getInstance();
    final songToFavorite = widget.shopSong;

    List<String> currentFavoriteDataStrings = _prefs!.getStringList(SharedPrefKeys.favoriteSongsDataList) ?? [];
    List<String> currentFavoriteIds = _prefs!.getStringList(SharedPrefKeys.favoriteSongIdentifiers) ?? [];

    final uniqueId = songToFavorite.uniqueIdentifier;
    bool isCurrentlyPersistedAsFavorite = currentFavoriteIds.contains(uniqueId);
    String message;

    if (!isCurrentlyPersistedAsFavorite) {
      currentFavoriteIds.add(uniqueId);
      // <--- ثبت زمان هنگام افزودن به علاقه‌مندی‌ها --->
      final Song songWithDate = songToFavorite.copyWith(dateAdded: DateTime.now());
      currentFavoriteDataStrings.add(songWithDate.toDataString());
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
      // رفرش HomeScreen برای نمایش تغییر در علاقه‌مندی‌ها (اگر از آنجا باز شود)
      homeScreenKey.currentState?.refreshDataOnReturn();
    }
  }

  Future<void> _checkIfSongDownloaded() async {
    _prefs ??= await SharedPreferences.getInstance();
    final List<String> downloadedDataStrings = _prefs!.getStringList(SharedPrefKeys.downloadedSongsDataList) ?? [];
    final String currentSongIdentifier = widget.shopSong.uniqueIdentifier;
    bool foundAndFileExists = false;

    for (String dataString in downloadedDataStrings) {
      try {
        final downloadedSong = Song.fromDataString(dataString);
        if (downloadedSong.uniqueIdentifier == currentSongIdentifier) {
          // اینجا باید مسیر فایل واقعی را بررسی کنیم که در audioUrl آهنگ دانلود شده ذخیره شده
          if (await File(downloadedSong.audioUrl).exists()) {
            foundAndFileExists = true;
            // اگر آهنگ دانلود شده، متن آهنگ آن را هم به ویجت فعلی بدهیم (برای نمایش)
            // این فرض می‌کند که lyrics با آهنگ دانلود شده ذخیره شده است.
            if (downloadedSong.lyrics != null && downloadedSong.lyrics!.isNotEmpty) {
              widget.shopSong.lyrics = downloadedSong.lyrics; // این کار widget.shopSong را تغییر می‌دهد، که معمولا خوب نیست
              // بهتر است یک state محلی برای lyrics داشته باشیم
              // یا shopSong را copyWith کنیم.
              // برای سادگی فعلا اینطور می‌ماند.
            }
            break;
          } else {
            print("MusicShopSongDetail: Downloaded song file NOT FOUND for ${downloadedSong.title} at ${downloadedSong.audioUrl}. Consider removing from downloaded list.");
            // TODO: منطقی برای حذف آهنگ از لیست دانلود شده‌ها اگر فایلش وجود ندارد
          }
        }
      } catch (e) {
        print("Error in _checkIfSongDownloaded while parsing or checking file: $e");
      }
    }

    if (mounted) {
      setState(() {
        _isSongDownloaded = foundAndFileExists;
      });
      print("MusicShopSongDetail: Song '${widget.shopSong.title}' downloaded status: $_isSongDownloaded");
    }
  }

  Future<void> _checkIfSongIsAccessible() async {
    // ... (منطق _checkIfSongIsAccessible دقیقا مثل قبل، بدون تغییر)
    _prefs ??= await SharedPreferences.getInstance();
    if (!mounted) return;

    bool accessible = false;

    // 1. آهنگ رایگان است
    if (widget.shopSong.requiredAccessTier == SongAccessTier.free) {
      accessible = true;
    }
    // 2. آهنگ قبلا دانلود شده است
    else if (_isSongDownloaded) {
      accessible = true;
    }
    // 3. کاربر اشتراک معتبر دارد که به این آهنگ دسترسی می‌دهد
    else if (_currentUserTier != sub_screen.SubscriptionTier.none &&
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

    // 4. اگر با شرایط بالا قابل دسترس نیست، بررسی کن آیا آهنگ خریداری شده است
    // (این حالت برای زمانی است که آهنگ‌ها جداگانه هم قابل خرید باشند)
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

  Future<void> _downloadSong() async {
    // ... (بخش ابتدایی _downloadSong مثل قبل: بررسی دسترسی، دانلود در حال انجام، درخواست دسترسی)
    if (!_isSongAccessible) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This song is not accessible for download yet.')));
      return;
    }
    if (_isSongDownloaded) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This song is already downloaded.')));
      return;
    }
    if (_isDownloading) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download already in progress...')));
      return;
    }

    if (Platform.isAndroid) {
      var status = await Permission.storage.status; // یا Permission.manageExternalStorage برای SDK های بالاتر اگر لازم است
      if (status.isDenied || status.isRestricted) {
        status = await Permission.storage.request();
      }
      if (!status.isGranted) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Storage permission denied. Cannot download song.')));
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
    // برای iOS معمولا نیازی به درخواست صریح برای نوشتن در دایرکتوری اپ نیست.

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      Dio dio = Dio();
      Directory appDocDir = await getApplicationDocumentsDirectory();
      // استفاده از یک نام فایل یکتا و معتبر
      String fileName = "${widget.shopSong.uniqueIdentifier.replaceAll(RegExp(r'[^\w\.-]'), '_')}.mp3";
      String savePath = "${appDocDir.path}/$fileName";
      print("Downloading '${widget.shopSong.title}' from ${widget.shopSong.audioUrl} to: $savePath");

      await dio.download(
        widget.shopSong.audioUrl, // URL آهنگ از فروشگاه
        savePath, // مسیر ذخیره محلی
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() => _downloadProgress = received / total);
          }
        },
      );

      if (mounted) {
        _prefs ??= await SharedPreferences.getInstance();
        List<String> downloadedSongDataStrings = _prefs!.getStringList(SharedPrefKeys.downloadedSongsDataList) ?? [];

        // <--- ثبت زمان دانلود --->
        final Song downloadedSongEntry = widget.shopSong.copyWith(
          audioUrl: savePath, // URL حالا مسیر محلی است
          isDownloaded: true,
          isLocal: true, // چون روی دستگاه ذخیره شده
          lyrics: widget.shopSong.lyrics, // اگر این آهنگ shop lyrics داشت، آن را هم کپی کن
          dateAdded: DateTime.now(), // ثبت زمان دانلود
        );
        final String songDataToStore = downloadedSongEntry.toDataString();
        final String uniqueId = widget.shopSong.uniqueIdentifier;

        // حذف مورد قبلی اگر وجود دارد (برای جلوگیری از تکرار)
        downloadedSongDataStrings.removeWhere((data) {
          try { return Song.fromDataString(data).uniqueIdentifier == uniqueId; } catch (e) { return false; }
        });
        downloadedSongDataStrings.add(songDataToStore);
        await _prefs!.setStringList(SharedPrefKeys.downloadedSongsDataList, downloadedSongDataStrings);

        // اگر متن آهنگی برای نسخه فروشگاهی وجود داشت، آن را برای نسخه دانلود شده هم ذخیره کن
        if (widget.shopSong.lyrics != null && widget.shopSong.lyrics!.isNotEmpty) {
          await downloadedSongEntry.saveLyrics(_prefs!, widget.shopSong.lyrics!);
        }

        setState(() {
          _isSongDownloaded = true;
          _isSongAccessible = true; // چون دانلود شده، قابل دسترس است
          _isDownloading = false;
          _downloadProgress = 0.0;
          // اگر متن آهنگ اصلی (shopSong) را تغییر داده بودیم برای نمایش، اینجا می‌توانیم به حالت اولیه برگردانیم
          // یا اینکه UI از یک state محلی برای lyrics استفاده کند.
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${widget.shopSong.title}" downloaded successfully!')));
        homeScreenKey.currentState?.refreshDataOnReturn(); // رفرش HomeScreen (تب My Music)
      }
    } catch (e) {
      print("Error downloading song '${widget.shopSong.title}': $e");
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to download "${widget.shopSong.title}". Error: ${e.toString().split(':').first}')));
      }
    }
  }

  Future<void> _loadSongCommentsFromServer() async {
    // شبیه‌سازی بارگذاری کامنت‌ها
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _songComments = _sampleComments; // استفاده از کامنت‌های نمونه
      });
    }
  }

  Future<void> _submitRating(double rating) async {
    // TODO: ارسال امتیاز به سرور
    print("User rated ${widget.shopSong.title}: $rating stars");
    if (mounted) {
      setState(() {
        _userRating = rating; // فقط برای نمایش UI، امتیاز واقعی باید از سرور بیاید
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You rated this song $rating stars (simulation).')),
      );
    }
  }

  Future<void> _purchaseSong() async {
    // این منطق زمانی است که آهنگ‌ها جداگانه قابل خرید هستند
    if (_prefs == null) _prefs = await SharedPreferences.getInstance();
    if (widget.shopSong.price <= 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This song is not for sale or is free.')));
      return;
    }
    if (_userCredit < widget.shopSong.price) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not enough credit to purchase this song.')));
      // TODO: کاربر را به صفحه افزایش اعتبار هدایت کن
      return;
    }

    // شبیه‌سازی پرداخت و کسر اعتبار
    final paymentSuccessful = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          amount: widget.shopSong.price,
          itemName: "Song: ${widget.shopSong.title}",
        ),
      ),
    );

    if (paymentSuccessful == true && mounted) {
      double newCredit = _userCredit - widget.shopSong.price;
      await _prefs!.setDouble(SharedPrefKeys.userCredit, newCredit);

      List<String> purchasedIds = _prefs!.getStringList(SharedPrefKeys.purchasedSongIds) ?? [];
      if (!purchasedIds.contains(widget.shopSong.uniqueIdentifier)) {
        purchasedIds.add(widget.shopSong.uniqueIdentifier);
        await _prefs!.setStringList(SharedPrefKeys.purchasedSongIds, purchasedIds);
      }

      setState(() {
        _userCredit = newCredit;
        _isSongAccessible = true; // چون خریداری شده، قابل دسترس است
        // ممکن است بخواهید بلافاصله دانلود شود یا دکمه دانلود فعال شود
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${widget.shopSong.title}" purchased successfully!')),
      );
      // رفرش UserProfileScreen برای نمایش اعتبار جدید
      // این کار باید از طریق Provider یا callback انجام شود.
      // homeScreenKey.currentState?.refreshDataOnReturn(); // شاید به جای این، UserAuthProvider آپدیت شود
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Song purchase failed or was cancelled.')));
    }
  }


  void _navigateToSubscriptionPage() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const sub_screen.SubscriptionScreen()))
        .then((subscriptionChanged) {
      if (subscriptionChanged == true && mounted) {
        // رفرش اطلاعات کاربر و دسترسی به آهنگ
        _initScreenDetails();
      }
    });
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;
    // TODO: ارسال کامنت به سرور
    final newComment = Comment(
      userId: "CurrentUser", // باید از اطلاعات کاربر لاگین شده بیاید
      text: _commentController.text.trim(),
      timestamp: DateTime.now(),
    );
    if (mounted) {
      setState(() {
        _songComments.insert(0, newComment); // اضافه کردن به ابتدای لیست برای نمایش
        _commentController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment submitted (simulation).')),
      );
    }
  }

  @override
  void dispose() {
    _samplePlayer.dispose();
    _commentController.dispose();
    super.dispose();
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inSeconds < 60) return '${difference.inSeconds}s ago';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    // ... (بخش build تقریبا بدون تغییر، فقط مطمئن شوید که از متغیرهای state این کلاس استفاده می‌کند)
    // و دکمه اصلی (mainActionButton) بر اساس _isSongAccessible و _isSongDownloaded و _isDownloading تصمیم‌گیری می‌کند.
    // متن آهنگ (lyricsDisplayWidget) باید از widget.shopSong.lyrics بخواند (که ممکن است توسط _checkIfSongDownloaded آپدیت شده باشد).

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
      mainActionButtonOnPressed = null; // غیرفعال در حین دانلود
      mainActionButtonColor = Colors.grey[700]!; // یا هر رنگ مناسب دیگر
      isMainButtonEnabled = false;
    } else if (_isSongDownloaded) {
      mainActionButtonText = "Play Full Song"; // (Downloaded)
      mainActionButtonOnPressed = () async {
        _prefs ??= await SharedPreferences.getInstance();
        Song? songToPlay;
        // پیدا کردن آهنگ دانلود شده از لیست SharedPreferences
        final List<String> downloadedList = _prefs!.getStringList(SharedPrefKeys.downloadedSongsDataList) ?? [];
        for (String dataStr in downloadedList) {
          try {
            final s = Song.fromDataString(dataStr);
            if (s.uniqueIdentifier == widget.shopSong.uniqueIdentifier) {
              await s.loadLyrics(_prefs!); // لود کردن متن آهنگ برای نسخه دانلود شده
              songToPlay = s;
              break;
            }
          } catch (e) {
            print("Error finding downloaded song for playback: $e");
          }
        }

        if (songToPlay != null && mounted) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => local_player.SongDetailScreen( // استفاده از local_player
                      initialSong: songToPlay!,
                      // می‌توانید لیست کامل دانلود شده‌ها را به عنوان پلی‌لیست بفرستید
                      // یا فقط همین یک آهنگ را
                      songList: [songToPlay!],
                      initialIndex: 0)));
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not find downloaded song details to play.")));
        }
      };
      mainActionButtonColor = Colors.greenAccent[700]!; // رنگ برای آهنگ دانلود شده
    } else if (_isSongAccessible) {
      mainActionButtonText = "Download";
      mainActionButtonOnPressed = _downloadSong; // تابع دانلود
      mainActionButtonColor = Colors.tealAccent[400]!; // رنگ برای دکمه دانلود
    } else { // اگر نه دانلود شده و نه قابل دسترس است (نیاز به اشتراک یا خرید)
      // isMainButtonEnabled به صورت پیش‌فرض true است، اینجا false می‌کنیم
      isMainButtonEnabled = false;
      mainActionButtonOnPressed = null;
      mainActionButtonColor = colorScheme.surfaceVariant.withOpacity(0.8); // رنگ برای دکمه غیرفعال

      if (widget.shopSong.isAvailableForPurchase && _userCredit < widget.shopSong.price) {
        mainActionButtonText = "Purchase (${widget.shopSong.price.toStringAsFixed(0)} Cr.)";
        // اگر بخواهیم دکمه خرید حتی با اعتبار ناکافی نمایش داده شود و کاربر را به افزایش اعتبار هدایت کند
        // mainActionButtonOnPressed = _purchaseSong; // یا یک متد برای هدایت به افزایش اعتبار
        // isMainButtonEnabled = true;
        // اما فعلا غیرفعال می‌ماند اگر اعتبار کافی نیست
        mainActionButtonText = "Need ${widget.shopSong.price.toStringAsFixed(0)} Credits";
      } else if (widget.shopSong.isAvailableForPurchase) {
        mainActionButtonText = "Purchase (${widget.shopSong.price.toStringAsFixed(0)} Cr.)";
        mainActionButtonOnPressed = _purchaseSong;
        isMainButtonEnabled = true;
        mainActionButtonColor = colorScheme.secondary; // رنگ برای دکمه خرید
      } else { // اگر قابل خرید نیست و نیاز به اشتراک دارد
        switch (widget.shopSong.requiredAccessTier) {
          case SongAccessTier.standard:
            mainActionButtonText = "Requires Standard Plan";
            break;
          case SongAccessTier.premium:
            mainActionButtonText = "Requires Premium Plan";
            break;
          case SongAccessTier.free: // این حالت نباید اینجا رخ دهد اگر isSongAccessible false است
            mainActionButtonText = "Free (Access Issue?)";
            break;
        }
      }
    }

    mainActionButton = ElevatedButton.icon(
      icon: _isDownloading
          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(value: _downloadProgress > 0 ? _downloadProgress : null, strokeWidth: 2.5, color: Colors.white))
          : Icon(
        _isSongDownloaded ? Icons.play_circle_fill_rounded :
        (_isSongAccessible && !widget.shopSong.isAvailableForPurchase) ? Icons.download_for_offline_outlined : // آیکون دانلود اگر قابل دسترس است و فروشی نیست
        (isMainButtonEnabled && widget.shopSong.isAvailableForPurchase) ? Icons.shopping_cart_checkout_rounded : Icons.lock_outline_rounded, // آیکون خرید یا قفل
        size: 20,
        color: isMainButtonEnabled
            ? (mainActionButtonColor == Colors.greenAccent[700] || mainActionButtonColor == Colors.tealAccent[400] || mainActionButtonColor == colorScheme.secondary
            ? (theme.brightness == Brightness.dark ? Colors.black87 : Colors.white) // متن تیره روی پس زمینه روشن
            : colorScheme.onPrimary)
            : colorScheme.onSurface.withOpacity(0.7),
      ),
      label: Text(
          mainActionButtonText,
          style: TextStyle(
              color: isMainButtonEnabled
                  ? (mainActionButtonColor == Colors.greenAccent[700] || mainActionButtonColor == Colors.tealAccent[400] || mainActionButtonColor == colorScheme.secondary
                  ? (theme.brightness == Brightness.dark ? Colors.black87 : Colors.white)
                  : colorScheme.onPrimary)
                  : colorScheme.onSurface.withOpacity(0.7)
          )
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: mainActionButtonColor,
        disabledBackgroundColor: _isDownloading ? Colors.grey[700] : colorScheme.surfaceVariant.withOpacity(0.5),
        disabledForegroundColor: colorScheme.onSurface.withOpacity(0.3),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        elevation: isMainButtonEnabled ? 2 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      ),
      onPressed: mainActionButtonOnPressed,
    );

    Widget subscriptionButton = Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: OutlinedButton.icon(
        icon: Icon(Icons.workspace_premium_outlined, color: Colors.amber[600]),
        label: Text(
            _currentUserTier == sub_screen.SubscriptionTier.none ? "Get Subscription" : "Manage Subscription", // یا Upgrade
            style: TextStyle(color: Colors.amber[600])
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.amber[600]!),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        ),
        onPressed: _navigateToSubscriptionPage,
      ),
    );

    // نمایش متن آهنگ (اگر وجود دارد)
    // متن آهنگ widget.shopSong ممکن است توسط _checkIfSongDownloaded آپدیت شده باشد
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
            // ... (بخش کاور آهنگ مثل قبل)
            SizedBox(
              height: screenHeight * 0.40,
              width: double.infinity,
              child: (widget.shopSong.coverImagePath != null &&
                  widget.shopSong.coverImagePath!.isNotEmpty)
                  ? Image.asset(
                widget.shopSong.coverImagePath!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                    color: colorScheme.surfaceVariant.withOpacity(0.7), // رنگ پس زمینه در صورت خطا
                    child: Icon(Icons.album_rounded,
                        size: 100, color: colorScheme.onSurfaceVariant.withOpacity(0.5))),
              )
                  : Container( // اگر کاور وجود ندارد
                  color: colorScheme.surfaceVariant.withOpacity(0.7),
                  child: Icon(Icons.album_rounded,
                      size: 100, color: colorScheme.onSurfaceVariant.withOpacity(0.5))),
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
                      if (_samplePlayer.audioSource == null) return; // اگر هنوز هم نال است، کاری نکن

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
                        color: theme.brightness == Brightness.dark ? Colors.black87 : Colors.white, size: 22),
                    label: Text(_isPlayingSample ? "Pause Sample" : "Play Sample",
                        style: TextStyle(
                            color: theme.brightness == Brightness.dark ? Colors.black87 : Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
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
                  // ... (بخش امتیازدهی مثل قبل)
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
                                  index < _userRating // _userRating باید از state خوانده شود
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
                  mainActionButton, // دکمه اصلی (دانلود، پخش، خرید، یا نیاز به اشتراک)
                  // دکمه اشتراک فقط زمانی نمایش داده شود که آهنگ رایگان نیست و با اشتراک قابل دسترس می‌شود
                  // یا اگر کاربر بخواهد اشتراکش را مدیریت کند
                  if (!(widget.shopSong.requiredAccessTier == SongAccessTier.free && _isSongAccessible) || _currentUserTier != sub_screen.SubscriptionTier.none)
                    subscriptionButton,

                  lyricsDisplayWidget, // نمایش متن آهنگ

                  const SizedBox(height: 24),
                  Divider(color: colorScheme.onSurface.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text("Comments (${_songComments.length})",
                      style: textTheme.titleLarge?.copyWith(
                          color: colorScheme.onBackground,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  // ... (بخش کامنت‌ها مثل قبل)
                  TextField(
                    controller: _commentController,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: "Write a comment...",
                      hintStyle: theme.inputDecorationTheme.hintStyle?.copyWith(
                        color: (theme.inputDecorationTheme.hintStyle?.color ?? Colors.grey[600])?.withOpacity(0.7),
                      ) ?? TextStyle(color: Colors.grey[600]?.withOpacity(0.7)),
                      fillColor: theme.inputDecorationTheme.fillColor ?? const Color(0xFF2C2C2E),
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
                    itemCount: _songComments.length,
                    separatorBuilder: (context, index) => Divider(
                        color: colorScheme.onSurface.withOpacity(0.1),
                        height: 24),
                    itemBuilder: (context, index) {
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
                            padding: const EdgeInsets.only(left: 40.0, right: 8.0), // برای هم‌ترازی با آواتار
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
                                    constraints: const BoxConstraints(), // برای حذف padding اضافه
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