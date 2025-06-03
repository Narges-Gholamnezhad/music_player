// lib/music_shop_song_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:path_provider/path_provider.dart'; // در صورت پیاده‌سازی دانلود واقعی
// import 'dart:io'; // در صورت پیاده‌سازی دانلود واقعی
import 'song_model.dart'; // SongAccessTier از اینجا میاد
import 'payment_screen.dart';
import 'subscription_screen.dart' as sub_screen; // برای دسترسی به SubscriptionPreferences
import 'song_detail_screen.dart' as local_player;
import 'main_tabs_screen.dart'; // برای دسترسی به GlobalKey مربوط به HomeScreen

// فرض بر این است که کلاس Comment قبلاً تعریف شده است
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
  double _userRating = 0.0; // فرض کنید از ۰ تا ۵ است
  bool _isFavorite = false;

  sub_screen.SubscriptionTier _currentUserTier = sub_screen.SubscriptionTier.none;
  DateTime? _subscriptionExpiry;
  double _userCredit = 0.0; // اعتبار کاربر

  bool _isSongAccessible = false; // آیا کاربر به این آهنگ دسترسی دارد (برای پخش کامل/دانلود)
  bool _isSongDownloaded = false; // آیا این آهنگ قبلاً دانلود شده است

  List<Comment> _songComments = [];
  final TextEditingController _commentController = TextEditingController();
  SharedPreferences? _prefs;

  // کلیدهای SharedPreferences
  // ارجاع صحیح به کلیدهای const تعریف شده در SubscriptionPreferences
  static const String prefUserSubscriptionTierGlobal = sub_screen.SubscriptionPreferences.prefUserSubscriptionTier;
  static const String prefUserSubscriptionExpiryGlobal = sub_screen.SubscriptionPreferences.prefUserSubscriptionExpiry;
  static const String prefUserCreditGlobal = sub_screen.SubscriptionPreferences.prefUserCredit;

  // کلیدهای مربوط به این صفحه
  static const String _favoriteSongsPrefKey = 'favorite_songs_data_list'; // اطمینان از یکسان بودن با favorites_screen
  static const String _purchasedSongsPrefKey = 'purchased_song_ids_v2';
  static const String prefDownloadedSongsDataKey = 'downloaded_songs_data_list_v2';


  @override
  void initState() {
    super.initState();
    print("MusicShopSongDetailScreen: initState for ${widget.shopSong.title}");
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
          _samplePlayer.pause();
        }
      }
    });
  }

  Future<void> _initScreenDetails() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadUserSubscriptionAndCredit();
    await _checkIfFavorite();
    await _checkIfSongDownloaded();
    await _checkIfSongIsAccessible(); // این باید بعد از بقیه اجرا شود
    _loadSongCommentsFromServer(); // این می‌تواند همزمان اجرا شود
  }

  Future<void> _loadUserSubscriptionAndCredit() async {
    if (_prefs == null) {
      print("MusicShopSongDetailScreen: SharedPreferences not initialized in _loadUserSubscriptionAndCredit.");
      return;
    }
    if (mounted) {
      setState(() {
        _currentUserTier = sub_screen.SubscriptionTier.values[
        _prefs!.getInt(prefUserSubscriptionTierGlobal) ?? sub_screen.SubscriptionTier.none.index];
        final expiryMillis = _prefs!.getInt(prefUserSubscriptionExpiryGlobal);
        _subscriptionExpiry = expiryMillis != null
            ? DateTime.fromMillisecondsSinceEpoch(expiryMillis)
            : null;
        _userCredit = _prefs!.getDouble(prefUserCreditGlobal) ?? 0.0;

        // بررسی انقضای اشتراک
        if (_currentUserTier != sub_screen.SubscriptionTier.none &&
            _subscriptionExpiry != null &&
            _subscriptionExpiry!.isBefore(DateTime.now())) {
          _currentUserTier = sub_screen.SubscriptionTier.none;
          //می‌توانید اشتراک منقضی شده را از SharedPreferences هم پاک کنید
          // await _prefs!.remove(prefUserSubscriptionTierGlobal);
          // await _prefs!.remove(prefUserSubscriptionExpiryGlobal);
          print("User subscription has expired. Reset to None.");
        }
      });
      print("MusicShopSongDetail: Loaded user status. Tier: $_currentUserTier, Credit: $_userCredit, Expiry: $_subscriptionExpiry");
    }
  }

  Future<void> _checkIfSongDownloaded() async {
    if (_prefs == null) return;
    final List<String> downloadedDataStrings = _prefs!.getStringList(prefDownloadedSongsDataKey) ?? [];
    // final String currentSongIdentifier = "${widget.shopSong.title};;${widget.shopSong.artist}"; // بخشی از شناسه

    bool found = downloadedDataStrings.any((dataString) {
      try {
        final song = Song.fromDataString(dataString);
        return song.title == widget.shopSong.title && song.artist == widget.shopSong.artist;
      } catch (e) { return false; }
    });

    if (mounted) {
      setState(() {
        _isSongDownloaded = found;
      });
      print("MusicShopSongDetail: Song '${widget.shopSong.title}' downloaded status: $_isSongDownloaded");
    }
  }

  Future<void> _checkIfSongIsAccessible() async {
    if (_prefs == null) return;

    bool accessible = false;

    // ۱. آیا آهنگ رایگان است؟
    if (widget.shopSong.requiredAccessTier == SongAccessTier.free) {
      accessible = true;
    }
    // ۲. آیا آهنگ قبلاً دانلود شده است؟ (اگر دانلود شده، یعنی قبلا به نحوی به آن دسترسی داشته)
    else if (_isSongDownloaded) {
      accessible = true; // اگر دانلود شده، پس قابل دسترس برای پخش است
    }
    // ۳. آیا کاربر اشتراک لازم را دارد؟
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
    // ۴. آیا آهنگ قبلاً به صورت تکی خریداری شده است؟
    if (!accessible && widget.shopSong.isAvailableForPurchase) {
      final List<String> purchasedSongIdentifiers = _prefs!.getStringList(_purchasedSongsPrefKey) ?? [];
      final String songPurchaseIdentifier = "${widget.shopSong.title}-${widget.shopSong.artist}";
      if (purchasedSongIdentifiers.contains(songPurchaseIdentifier)) {
        accessible = true;
      }
    }

    if (mounted) {
      setState(() {
        _isSongAccessible = accessible;
      });
      print(
          "MusicShopSongDetail: Song accessible for full play/download for '${widget.shopSong.title}': $_isSongAccessible. RequiredTier: ${widget.shopSong.requiredAccessTier}, UserTier: $_currentUserTier, isDownloaded: $_isSongDownloaded");
    }
  }

  Future<void> _initSampleAudioPlayer(String url) async {
    try {
      await _samplePlayer.setUrl(url);
    } catch (e, s) {
      print("!!! EXCEPTION in _initSampleAudioPlayer for sample of ${widget.shopSong.title}: $e\n$s");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error loading sample for "${widget.shopSong.title}". Check URL or network.')));
      }
    }
  }

  Future<void> _loadSongCommentsFromServer() async {
    await Future.delayed(const Duration(milliseconds: 300)); // شبیه سازی تاخیر شبکه
    if (mounted) {
      setState(() {
        // اطلاعات نمونه برای کامنت‌ها
        _songComments = [
          Comment(userId: "UserX", text: "Awesome track! Totally worth it.", timestamp: DateTime.now().subtract(const Duration(hours: 2)), likes: 15, dislikes: 1),
          Comment(userId: "MusicFan", text: "Good vibes, but a bit short.", timestamp: DateTime.now().subtract(const Duration(minutes: 45)), likes: 5),
        ];
      });
    }
  }

  Future<void> _checkIfFavorite() async {
    if (_prefs == null) return;
    final List<String> favoriteDataStrings = _prefs!.getStringList(_favoriteSongsPrefKey) ?? [];
    // final String songIdentifierToMatch = "${widget.shopSong.title};;${widget.shopSong.artist}";

    bool found = favoriteDataStrings.any((dataString) {
      try {
        final favSong = Song.fromDataString(dataString);
        return favSong.title == widget.shopSong.title && favSong.artist == widget.shopSong.artist;
      } catch (e) {
        print("Error parsing favorite string in _checkIfFavorite: $dataString, $e");
        return false;
      }
    });

    if (mounted) {
      if (_isFavorite != found) {
        setState(() {
          _isFavorite = found;
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_prefs == null) return;
    List<String> favoriteDataStrings = _prefs!.getStringList(_favoriteSongsPrefKey) ?? [];
    String songDataForFavorite = widget.shopSong.toDataString();
    // final String songIdentifierToMatch = "${widget.shopSong.title};;${widget.shopSong.artist}";

    bool currentlyIsFavoriteBasedOnState = _isFavorite;
    int foundIndex = -1;
    for(int i=0; i < favoriteDataStrings.length; i++) {
      try {
        final favSong = Song.fromDataString(favoriteDataStrings[i]);
        if (favSong.title == widget.shopSong.title && favSong.artist == widget.shopSong.artist) {
          foundIndex = i;
          break;
        }
      } catch (e) {
        // رشته نامعتبر
      }
    }

    if (mounted) {
      setState(() {
        _isFavorite = !currentlyIsFavoriteBasedOnState;
        if (_isFavorite) {
          if (foundIndex == -1) {
            favoriteDataStrings.add(songDataForFavorite);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('"${widget.shopSong.title}" added to favorites.')));
          }
        } else {
          if (foundIndex != -1) {
            favoriteDataStrings.removeAt(foundIndex);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('"${widget.shopSong.title}" removed from favorites.')));
          }
        }
      });
    }
    await _prefs!.setStringList(_favoriteSongsPrefKey, favoriteDataStrings);
  }


  Future<void> _submitRating(double rating) async {
    if (mounted) setState(() => _userRating = rating);
    print("User rated ${widget.shopSong.title}: $rating stars (TODO: Send to server)");
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('You rated "${widget.shopSong.title}" $rating stars.')));
  }

  Future<void> _purchaseSong() async {
    if (_prefs == null) return;
    double songPrice = widget.shopSong.price;

    if (!widget.shopSong.isAvailableForPurchase) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This song is not available for direct purchase.')));
      return;
    }

    if (_userCredit >= songPrice) {
      final paymentSuccessful = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (context) => PaymentScreen(
                amount: songPrice, itemName: widget.shopSong.title)),
      );
      if (paymentSuccessful == true && mounted) {
        final newCredit = _userCredit - songPrice;
        await _prefs!.setDouble(prefUserCreditGlobal, newCredit);

        final List<String> purchasedIds = _prefs!.getStringList(_purchasedSongsPrefKey) ?? [];
        final String songPurchaseIdentifier = "${widget.shopSong.title}-${widget.shopSong.artist}";
        if (!purchasedIds.contains(songPurchaseIdentifier)) {
          purchasedIds.add(songPurchaseIdentifier);
          await _prefs!.setStringList(_purchasedSongsPrefKey, purchasedIds);
        }

        setState(() {
          _userCredit = newCredit;
          _isSongAccessible = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '"${widget.shopSong.title}" purchased! Remaining Credit: $_userCredit')));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment cancelled or failed.')));
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough credit to purchase.')));
    }
  }

  Future<void> _downloadSong() async {
    if (!_isSongAccessible) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This song is not accessible for download yet.')));
      return;
    }
    if (_isSongDownloaded) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This song is already downloaded.')));
      return;
    }

    final String downloadUrl = widget.shopSong.audioUrl;
    print("Attempting to download ${widget.shopSong.title} from $downloadUrl");
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Downloading "${widget.shopSong.title}"... (Simulation)')));

    await Future.delayed(const Duration(seconds: 2));

    if (_prefs == null) _prefs = await SharedPreferences.getInstance();
    List<String> downloadedSongDataStrings = _prefs!.getStringList(prefDownloadedSongsDataKey) ?? [];

    final Song downloadedSong = widget.shopSong.copyWith(isDownloaded: true, isLocal: false);
    final String songDataToStore = downloadedSong.toDataString();

    // final String currentSongIdentifierForCheck = "${widget.shopSong.title};;${widget.shopSong.artist}";
    if (!downloadedSongDataStrings.any((data) {
      try {
        final s = Song.fromDataString(data);
        return s.title == widget.shopSong.title && s.artist == widget.shopSong.artist;
      } catch (e) { return false; }
    })) {
      downloadedSongDataStrings.add(songDataToStore);
      await _prefs!.setStringList(prefDownloadedSongsDataKey, downloadedSongDataStrings);
      if (mounted) {
        setState(() {
          _isSongDownloaded = true;
          _isSongAccessible = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('"${widget.shopSong.title}" downloaded and added to My Music!')));

        homeScreenKey.currentState?.refreshDataOnReturn();
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Song was already in downloaded list.')));
      if(!_isSongDownloaded) {
        setState(() {
          _isSongDownloaded = true;
          _isSongAccessible = true;
        });
      }
    }
  }

  void _navigateToSubscriptionPage() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const sub_screen.SubscriptionScreen()))
        .then((subscriptionChanged) {
      if (subscriptionChanged == true && mounted) {
        print("Returned from subscription page, user status might have changed. Reloading...");
        _loadUserSubscriptionAndCredit().then((_) {
          _checkIfSongIsAccessible();
        });
      }
    });
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final newComment = Comment(userId: "CurrentUser_ID", text: text, timestamp: DateTime.now());
    if (mounted) {
      setState(() {
        _songComments.insert(0, newComment);
        _commentController.clear();
      });
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment submitted (locally)')));
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
    final screenHeight = MediaQuery.of(context).size.height;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    Widget mainActionButton;
    String mainActionButtonText = "";
    VoidCallback? mainActionButtonOnPressed;
    Color mainActionButtonColor = colorScheme.primary; // رنگ پیش‌فرض
    bool isMainButtonEnabled = true;


    if (_isSongDownloaded) {
      mainActionButtonText = "Play Full Song (Downloaded)";
      mainActionButtonOnPressed = () {
        final songToPlay = widget.shopSong.copyWith(isDownloaded: true, isLocal: false);
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => local_player.SongDetailScreen(
                    initialSong: songToPlay,
                    songList: [songToPlay],
                    initialIndex: 0)));
      };
      mainActionButtonColor = Colors.greenAccent[700]!;
    } else if (_isSongAccessible) { // اگر قابل دسترس است (رایگان، با اشتراک معتبر) ولی هنوز دانلود نشده
      mainActionButtonText = "Download";
      mainActionButtonOnPressed = _downloadSong;
      mainActionButtonColor = Colors.tealAccent[400]!;
    } else { // اگر آهنگ قابل دسترس نیست (نه رایگان، نه با اشتراک فعلی، نه خریداری شده)
      isMainButtonEnabled = false; // دکمه اصلی غیرفعال می‌شود
      mainActionButtonOnPressed = null;
      mainActionButtonColor = colorScheme.surfaceVariant.withOpacity(0.8); // رنگ برای دکمه غیرفعال

      switch (widget.shopSong.requiredAccessTier) {
        case SongAccessTier.standard:
          mainActionButtonText = "Requires Standard Plan";
          break;
        case SongAccessTier.premium:
          mainActionButtonText = "Requires Premium Plan";
          break;
        case SongAccessTier.free:
          mainActionButtonText = "Free (Error?)";
          break;
      }
    }

    mainActionButton = ElevatedButton.icon(
      icon: Icon(
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
        disabledBackgroundColor: colorScheme.surfaceVariant.withOpacity(0.5),
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
                            padding: const EdgeInsets.only(left: 40.0),
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