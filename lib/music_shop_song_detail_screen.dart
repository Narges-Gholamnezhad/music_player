// lib/music_shop_song_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'song_model.dart';
import 'payment_screen.dart';
import 'subscription_screen.dart' as sub_screen;
import 'song_detail_screen.dart' as local_player;
import 'main_tabs_screen.dart';
import 'shared_pref_keys.dart';
import 'user_auth_provider.dart';
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

  @override
  void dispose() {
    _samplePlayer.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _initScreenDetails() async {
    setState(() => _isScreenLoading = true);
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
    final username =
        Provider.of<UserAuthProvider>(context, listen: false).username;
    if (username == null || username.isEmpty) {
      if (mounted) setState(() => _isFavorite = false);
      return;
    }

    _prefs ??= await SharedPreferences.getInstance();
    final ids = _prefs!.getStringList(
            SharedPrefKeys.favoriteSongIdentifiersForUser(username)) ??
        [];
    if (mounted) {
      setState(
          () => _isFavorite = ids.contains(widget.shopSong.uniqueIdentifier));
    }
  }

  Future<void> _toggleFavorite() async {
    final username =
        Provider.of<UserAuthProvider>(context, listen: false).username;
    if (username == null || username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to add favorites.')));
      return;
    }

    _prefs ??= await SharedPreferences.getInstance();
    final songToFavorite = widget.shopSong;

    List<String> favDataStrings = _prefs!.getStringList(
            SharedPrefKeys.favoriteSongsDataListForUser(username)) ??
        [];
    List<String> favIds = _prefs!.getStringList(
            SharedPrefKeys.favoriteSongIdentifiersForUser(username)) ??
        [];

    final uniqueId = songToFavorite.uniqueIdentifier;
    final bool isCurrentlyFavorite = favIds.contains(uniqueId);
    String message;

    if (isCurrentlyFavorite) {
      favIds.remove(uniqueId);
      favDataStrings.removeWhere((dataStr) {
        try {
          return Song.fromDataString(dataStr).uniqueIdentifier == uniqueId;
        } catch (e) {
          return false;
        }
      });
      message = '"${songToFavorite.title}" removed from favorites.';
      if (mounted) setState(() => _isFavorite = false);
    } else {
      favIds.add(uniqueId);
      final songForFavorites =
          songToFavorite.copyWith(dateAdded: DateTime.now());
      favDataStrings.add(songForFavorites.toDataString());
      message = '"${songToFavorite.title}" added to favorites.';
      if (mounted) setState(() => _isFavorite = true);
    }

    await _prefs!.setStringList(
        SharedPrefKeys.favoriteSongIdentifiersForUser(username), favIds);
    await _prefs!.setStringList(
        SharedPrefKeys.favoriteSongsDataListForUser(username), favDataStrings);

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _checkIfSongDownloadedAndUpdateLyrics() async {
    final username =
        Provider.of<UserAuthProvider>(context, listen: false).username;
    if (username == null) {
      if (mounted) setState(() => _isSongDownloaded = false);
      return;
    }

    _prefs ??= await SharedPreferences.getInstance();
    final downloadedStrings = _prefs!.getStringList(
            SharedPrefKeys.downloadedSongsDataListForUser(username)) ??
        [];

    final currentId = widget.shopSong.uniqueIdentifier;
    bool found = false;
    String? lyrics;

    for (String data in downloadedStrings) {
      try {
        final song = Song.fromDataString(data);
        if (song.shopUniqueIdentifierBasis == currentId) {
          if (await File(song.audioUrl).exists()) {
            found = true;
            lyrics = song.lyrics;
            break;
          }
        }
      } catch (e) {
        print("Error in _checkIfSongDownloadedAndUpdateLyrics: $e");
      }
    }

    if (mounted) {
      setState(() {
        _isSongDownloaded = found;
        _displayLyrics = lyrics ?? widget.shopSong.lyrics;
      });
    }
  }

  Future<void> _checkIfSongIsAccessible() async {
    _prefs ??= await SharedPreferences.getInstance();
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
          (_currentUserTier == sub_screen.SubscriptionTier.standard ||
              _currentUserTier == sub_screen.SubscriptionTier.premium)) {
        accessible = true;
      } else if (widget.shopSong.requiredAccessTier == SongAccessTier.premium &&
          _currentUserTier == sub_screen.SubscriptionTier.premium) {
        accessible = true;
      }
    }

    if (!accessible && widget.shopSong.isAvailableForPurchase) {
      final purchased =
          _prefs!.getStringList(SharedPrefKeys.purchasedSongIds) ?? [];
      if (purchased.contains(widget.shopSong.uniqueIdentifier)) {
        accessible = true;
      }
    }
    if (mounted) setState(() => _isSongAccessible = accessible);
  }

  Future<void> _downloadSong() async {
    final username =
        Provider.of<UserAuthProvider>(context, listen: false).username;
    if (username == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to download songs.')));
      return;
    }

    if (!_isSongAccessible) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'This song must be purchased or unlocked via subscription first.')));
      }
      return;
    }
    if (_isDownloading) return;

    var status = await Permission.audio.request();
    if (status.isPermanentlyDenied) {
      if (mounted) openAppSettings();
      return;
    }
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Storage permission is required to download songs.')));
      }
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName =
          "${widget.shopSong.uniqueIdentifier.replaceAll(RegExp(r'[^\w\.-]'), '_')}.mp3";
      final String savePath = "${appDir.path}/$fileName";
      print("Downloading '${widget.shopSong.title}' to: $savePath");

      await Dio().download(
        widget.shopSong.audioUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      if (mounted) {
        _prefs ??= await SharedPreferences.getInstance();
        List<String> downloadedList = _prefs!.getStringList(
                SharedPrefKeys.downloadedSongsDataListForUser(username)) ??
            [];

        final Song downloadedEntry = Song(
          title: widget.shopSong.title,
          artist: widget.shopSong.artist,
          audioUrl: savePath,
          isDownloaded: true,
          isLocal: true,
          dateAdded: DateTime.now(),
          shopUniqueIdentifierBasis: widget.shopSong.uniqueIdentifier,
          coverImagePath: widget.shopSong.coverImagePath,
          price: widget.shopSong.price,
          requiredAccessTier: widget.shopSong.requiredAccessTier,
        );

        downloadedList.add(downloadedEntry.toDataString());
        await _prefs!.setStringList(
            SharedPrefKeys.downloadedSongsDataListForUser(username),
            downloadedList);

        setState(() {
          _isSongDownloaded = true;
          _isDownloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('"${widget.shopSong.title}" downloaded successfully!')));

        homeScreenKey.currentState?.refreshDataOnReturn();
      }
    } catch (e) {
      print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
      print("!!!!!! DOWNLOAD FAILED - THE REAL ERROR IS: !!!!!");
      print(e.toString());
      print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");

      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Download failed. Check the debug console for the error.')));
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

      final userAuthProvider =
          Provider.of<UserAuthProvider>(context, listen: false);
      await userAuthProvider.updateUserCredit(newCredit);

      setState(() {
        _userCredit = newCredit;
        _isSongAccessible = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '"${widget.shopSong.title}" purchased! You can now download it.')));
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

  String _formatTimestamp(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    print("--- BUILDING DETAIL SCREEN ---");
    print("Song Title: ${widget.shopSong.title}");
    print("Sample URL from Song object: '${widget.shopSong.sampleAudioUrl}'");

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
    } else if (_isSongDownloaded) {
      mainActionButtonText = "Play Full Song";
      mainActionButtonIcon = Icons.play_circle_fill_rounded;
      mainActionButtonOnPressed = () async {
        final username =
            Provider.of<UserAuthProvider>(context, listen: false).username;
        if (username == null) return;

        _prefs ??= await SharedPreferences.getInstance();
        Song? songToPlay;
        final list = _prefs!.getStringList(
                SharedPrefKeys.downloadedSongsDataListForUser(username)) ??
            [];
        for (String data in list) {
          try {
            final s = Song.fromDataString(data);
            if (s.shopUniqueIdentifierBasis ==
                widget.shopSong.uniqueIdentifier) {
              songToPlay = s;
              break;
            }
          } catch (_) {}
        }
        if (songToPlay != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => local_player.SongDetailScreen(
                initialSong: songToPlay!,
                songList: [songToPlay!],
                initialIndex: 0,
              ),
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Error: Could not find downloaded song data.")));
        }
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

      if (widget.shopSong.isAvailableForPurchase &&
          _userCredit < widget.shopSong.price) {
        mainActionButtonText =
            "Need ${widget.shopSong.price.toStringAsFixed(0)} Cr.";
        mainActionButtonIcon = Icons.credit_card_off_outlined;
      } else if (widget.shopSong.isAvailableForPurchase) {
        mainActionButtonText =
            "Purchase (${widget.shopSong.price.toStringAsFixed(0)} Cr.)";
        mainActionButtonIcon = Icons.shopping_cart_checkout_rounded;
        mainActionButtonOnPressed = _purchaseSong;
        isMainButtonEnabled = true;
        mainActionButtonColor = colorScheme.secondary;
      } else {
        mainActionButtonText = "Requires Subscription";
        mainActionButtonIcon = Icons.workspace_premium_outlined;
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
                  color: colorScheme.onPrimary),
            )
          : Icon(mainActionButtonIcon,
              color: isMainButtonEnabled
                  ? colorScheme.onPrimary
                  : colorScheme.onSurface.withOpacity(0.7)),
      label: Text(mainActionButtonText,
          style: TextStyle(
              color: isMainButtonEnabled
                  ? colorScheme.onPrimary
                  : colorScheme.onSurface.withOpacity(0.7))),
      style: ElevatedButton.styleFrom(
        backgroundColor: mainActionButtonColor,
        disabledBackgroundColor: Colors.grey[800],
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      ),
      onPressed: mainActionButtonOnPressed,
    );

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
                  tooltip: _isFavorite
                      ? "Remove from favorites"
                      : "Add to favorites")
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
                                  if (_samplePlayer.audioSource == null) {
                                    await _initSampleAudioPlayer(
                                        widget.shopSong.sampleAudioUrl!);
                                  }
                                  if (_isPlayingSample) {
                                    await _samplePlayer.pause();
                                  } else {
                                    if (_samplePlayer.processingState ==
                                        ProcessingState.completed) {
                                      await _samplePlayer.seek(Duration.zero);
                                    }
                                    await _samplePlayer.play();
                                  }
                                },
                                icon: Icon(
                                    _isPlayingSample
                                        ? Icons.pause_circle_filled_outlined
                                        : Icons.play_circle_fill_outlined,
                                    color: colorScheme.onPrimary,
                                    size: 22),
                                label: Text(
                                    _isPlayingSample
                                        ? "Pause Sample"
                                        : "Play Sample",
                                    style: TextStyle(
                                        color: colorScheme.onPrimary,
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
                                  const Text("Rate it:"),
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
                              Padding(
                                padding: const EdgeInsets.only(top: 12.0),
                                child: OutlinedButton.icon(
                                  icon: Icon(Icons.workspace_premium_outlined,
                                      color: Colors.amber[600]),
                                  label: Text(
                                      _currentUserTier ==
                                              sub_screen.SubscriptionTier.none
                                          ? "Get Subscription"
                                          : "Manage Subscription",
                                      style:
                                          TextStyle(color: Colors.amber[600])),
                                  style: OutlinedButton.styleFrom(
                                      side:
                                          BorderSide(color: Colors.amber[600]!),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10.0))),
                                  onPressed: _navigateToSubscriptionPage,
                                ),
                              ),
                            if (_displayLyrics != null &&
                                _displayLyrics!.isNotEmpty)
                              Padding(
                                  padding: const EdgeInsets.only(
                                      top: 24.0, left: 20.0, right: 20.0),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text("Lyrics:",
                                            style: textTheme.titleLarge
                                                ?.copyWith(
                                                    color: colorScheme
                                                        .onBackground,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                        const SizedBox(height: 10),
                                        Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                                color: colorScheme
                                                    .surfaceVariant
                                                    .withOpacity(0.5),
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            child: Text(_displayLyrics!,
                                                style: textTheme.bodyMedium
                                                    ?.copyWith(
                                                        color: colorScheme
                                                            .onSurface,
                                                        height: 1.6))),
                                      ])),
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
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: Text("No comments yet.",
                                        textAlign: TextAlign.center))
                                : ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
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
                                              const CircleAvatar(
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
                                                      icon: const Icon(
                                                          Icons
                                                              .thumb_up_alt_outlined,
                                                          size: 16),
                                                      onPressed: () {}),
                                                  Text(com.likes.toString()),
                                                  const SizedBox(width: 12),
                                                  IconButton(
                                                      icon: const Icon(
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
