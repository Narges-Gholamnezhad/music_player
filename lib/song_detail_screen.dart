// lib/song_detail_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'song_model.dart';
import 'main_tabs_screen.dart'; // برای دسترسی به globalAudioPlayer و nowPlayingNotifier
import 'shared_pref_keys.dart';
import 'now_playing_model.dart'; // اطمینان از وجود این import

class _PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  _PositionData(this.position, this.bufferedPosition, this.duration);
}

class SongDetailScreen extends StatefulWidget {
  final Song initialSong; // آهنگی که با آن صفحه باز می‌شود
  final List<Song> songList; // لیست پخشی که این آهنگ از آن آمده
  final int initialIndex; // ایندکس آهنگ در لیست پخش

  const SongDetailScreen({
    super.key,
    required this.initialSong,
    required this.songList,
    required this.initialIndex,
  });

  @override
  State<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends State<SongDetailScreen> {
  bool _isFavorite = false;
  late Song _displayedSong; // آهنگی که در UI نمایش داده می‌شود، از Notifier می‌آید
  SharedPreferences? _prefs;

  // Listener های محلی برای UI این صفحه
  StreamSubscription<PlayerState>? _playerStateSubscriptionLocal;
  StreamSubscription<LoopMode>? _loopModeSubscriptionLocal;
  StreamSubscription<bool>? _shuffleModeSubscriptionLocal;
  late VoidCallback _nowPlayingListenerCallback; // Listener برای nowPlayingNotifier

  // Stream برای آپدیت Slider و زمان‌ها
  Stream<_PositionData> get _positionDataStream =>
      Stream.periodic(const Duration(milliseconds: 200), (_) {
        final currentDuration = globalAudioPlayer.duration;
        return _PositionData(
          globalAudioPlayer.position,
          globalAudioPlayer.bufferedPosition,
          currentDuration ?? Duration.zero,
        );
      }).distinct((prev, next) => // برای جلوگیری از آپدیت‌های غیرضروری
      prev.position.inMilliseconds == next.position.inMilliseconds &&
          prev.duration.inMilliseconds == next.duration.inMilliseconds &&
          prev.bufferedPosition.inMilliseconds == next.bufferedPosition.inMilliseconds);


  @override
  void initState() {
    super.initState();
    // _displayedSong در ابتدا با آهنگ فعلی در Notifier مقداردهی می‌شود یا اگر Notifier خالی است، با initialSong
    _displayedSong = nowPlayingNotifier.value?.song ?? widget.initialSong;

    print(
        "SongDetailScreen: initState - DisplayedSong: '${_displayedSong.title}', InitialWidgetSong: '${widget.initialSong.title}', UID: ${widget.initialSong.uniqueIdentifier}, Index: ${widget.initialIndex}, Playlist size: ${widget.songList.length}");

    _initPrefsAndLoadDataForSong(_displayedSong); // بارگذاری اطلاعات برای آهنگ نمایش داده شده

    // بررسی اینکه آیا نیاز به پخش آهنگ جدیدی هست یا آهنگ فعلی در پلیر جهانی با آهنگ این صفحه یکی است
    final currentGlobalNowPlaying = nowPlayingNotifier.value;
    bool playThisSongAnuew = true;

    if (currentGlobalNowPlaying != null && currentGlobalNowPlaying.song.uniqueIdentifier == widget.initialSong.uniqueIdentifier) {
      // اگر آهنگ یکی است، بررسی کن که آیا لیست پخش و ایندکس هم یکی هستند
      // این برای جلوگیری از ریست کردن آهنگ اگر کاربر فقط از مینی‌پلیر به این صفحه آمده
      if (_arePlaylistsEffectivelyEqual(currentGlobalNowPlaying.currentPlaylist, widget.songList) &&
          currentGlobalNowPlaying.currentIndexInPlaylist == widget.initialIndex) {
        print("SongDetailScreen initState: Same song and context already loaded globally. No need to replay.");
        playThisSongAnuew = false;
      } else {
        print("SongDetailScreen initState: Same song UID, but different playlist/index. Will replay with new context.");
      }
    } else {
      print("SongDetailScreen initState: Different song UID or no song globally. Will play new song.");
    }

    if (playThisSongAnuew) {
      print("SongDetailScreen initState: Calling playNewSongInGlobalPlayer for '${widget.initialSong.title}' with autoPlay: true");
      MainTabsScreen.playNewSongInGlobalPlayer(
          widget.initialSong, widget.songList, widget.initialIndex, autoPlay: true);
    }
    // در هر صورت، displayedSong را با آهنگ فعلی Notifier (که ممکن است همین الان توسط playNewSongInGlobalPlayer ست شده باشد) همگام کن
    if (nowPlayingNotifier.value != null) {
      _displayedSong = nowPlayingNotifier.value!.song;
    }


    _setupLocalListeners();
  }

  // برای مقایسه موثر دو لیست پخش
  bool _arePlaylistsEffectivelyEqual(List<Song>? p1, List<Song>? p2) {
    if (p1 == null && p2 == null) return true;
    if (p1 == null || p2 == null) return false;
    if (p1.length != p2.length) return false;
    for (int i = 0; i < p1.length; i++) {
      if (p1[i].uniqueIdentifier != p2[i].uniqueIdentifier) return false;
    }
    return true;
  }


  Future<void> _initPrefsAndLoadDataForSong(Song songToLoadFor) async {
    _prefs ??= await SharedPreferences.getInstance();
    if (!mounted) return;
    await _loadFavoriteStatusAndLyrics(songToLoadFor);
  }

  void _setupLocalListeners() {
    // Listener برای nowPlayingNotifier
    _nowPlayingListenerCallback = () {
      final newNowPlaying = nowPlayingNotifier.value;
      if (mounted) {
        if (newNowPlaying != null) {
          // اگر آهنگ نمایش داده شده با آهنگ جدید در Notifier متفاوت است
          if (_displayedSong.uniqueIdentifier != newNowPlaying.song.uniqueIdentifier) {
            setState(() {
              _displayedSong = newNowPlaying.song; // آپدیت UI با آهنگ جدید
            });
            _loadFavoriteStatusAndLyrics(newNowPlaying.song); // بارگذاری اطلاعات برای آهنگ جدید
            print("SongDetailScreen Listener (NowPlaying): Song changed to '${_displayedSong.title}'. UI updated.");
          } else {
            // حتی اگر آهنگ یکی است، ممکن است isPlaying یا سایر اطلاعات تغییر کرده باشد
            setState(() {}); // رفرش UI برای انعکاس تغییرات isPlaying و ...
            print("SongDetailScreen Listener (NowPlaying): Song is same ('${_displayedSong.title}'), but other properties (e.g., isPlaying=${newNowPlaying.isPlaying}) might have changed. UI refreshed.");
          }
        } else { // اگر nowPlayingNotifier.value نال شد (مثلا پلیر متوقف شد)
          print("SongDetailScreen Listener (NowPlaying): Notifier is null. Player might have stopped.");
          // UI را رفرش کن تا کنترل‌ها وضعیت صحیح را نشان دهند (مثلا غیرفعال شوند)
          setState(() {});
        }
      }
    };
    nowPlayingNotifier.addListener(_nowPlayingListenerCallback);

    // Listener های محلی برای خود پلیر (فقط برای رفرش UI این صفحه)
    _playerStateSubscriptionLocal = globalAudioPlayer.playerStateStream.listen((state) {
      if (mounted) setState(() {});
    });
    _loopModeSubscriptionLocal = globalAudioPlayer.loopModeStream.listen((_) {
      if (mounted) setState(() {});
    });
    _shuffleModeSubscriptionLocal = globalAudioPlayer.shuffleModeEnabledStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadFavoriteStatusAndLyrics(Song songToCheck) async {
    _prefs ??= await SharedPreferences.getInstance();
    if (!mounted) return;

    await songToCheck.loadLyrics(_prefs!); // بارگذاری متن آهنگ

    final List<String> favoriteIdsList = _prefs!.getStringList(SharedPrefKeys.favoriteSongIdentifiers) ?? [];
    if (mounted) { // بررسی مجدد mounted بودن
      setState(() {
        _isFavorite = favoriteIdsList.contains(songToCheck.uniqueIdentifier);
      });
    }
  }

  Future<void> _toggleFavorite() async {
    // ... (کد _toggleFavorite مثل قبل، اما با استفاده از _displayedSong برای اطمینان)
    _prefs ??= await SharedPreferences.getInstance();
    final songToFavorite = _displayedSong; // همیشه از آهنگی که نمایش داده می‌شود استفاده کن

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

  void _controlPlayPause() {
    // ... (کد _controlPlayPause مثل قبل)
    if (globalAudioPlayer.audioSource == null && nowPlayingNotifier.value == null) {
      print("SongDetailScreen: Cannot play/pause, no audio source and no song in notifier.");
      return;
    }
    if (globalAudioPlayer.playing) {
      globalAudioPlayer.pause();
    } else {
      // اگر آهنگ تمام شده بود، از اول شروع کن
      if (globalAudioPlayer.processingState == ProcessingState.completed) {
        globalAudioPlayer.seek(Duration.zero);
      }
      globalAudioPlayer.play();
    }
    // Listener در MainTabsScreen وضعیت isPlaying در nowPlayingNotifier را آپدیت می‌کند
    // و setState در شنونده‌های محلی این صفحه (یا listener خود nowPlayingNotifier) UI را رفرش می‌کند.
  }

  void _controlPlayNext() {
    final String methodTag = "SongDetailScreen._controlPlayNext";
    final currentModel = nowPlayingNotifier.value;
    if (currentModel == null || currentModel.currentPlaylist.isEmpty) {
      print("$methodTag: No current model or empty playlist.");
      return;
    }

    List<Song> playlist = currentModel.currentPlaylist;
    int currentIndex = currentModel.currentIndexInPlaylist;
    int nextIndex;

    print("$methodTag: Current song '${currentModel.song.title}', Index: $currentIndex, Shuffle: ${globalAudioPlayer.shuffleModeEnabled}, Loop: ${globalAudioPlayer.loopMode}");

    if (globalAudioPlayer.shuffleModeEnabled && playlist.length > 1) {
      var availableIndices = List<int>.generate(playlist.length, (i) => i)..remove(currentIndex);
      if (availableIndices.isEmpty) { // فقط یک آهنگ در لیست یا همه پخش شده‌اند
        if (globalAudioPlayer.loopMode == LoopMode.all && playlist.isNotEmpty) {
          // اگر لوپ فعال است، یک آهنگ تصادفی دیگر از ابتدا انتخاب کن
          availableIndices = List<int>.generate(playlist.length, (i) => i);
          availableIndices.shuffle(Random());
          nextIndex = availableIndices.first;
          print("$methodTag: Shuffle & Loop - playlist exhausted, picking random: $nextIndex");
        } else {
          print("$methodTag: Shuffle & No Loop - playlist exhausted. Stopping.");
          if (globalAudioPlayer.playing) globalAudioPlayer.pause();
          globalAudioPlayer.seek(Duration.zero); // برای اینکه دفعه بعد از اول شروع شود
          // nowPlayingNotifier توسط listener در MainTabsScreen آپدیت می‌شود
          return;
        }
      } else {
        availableIndices.shuffle(Random());
        nextIndex = availableIndices.first;
      }
    } else { // Sequential
      nextIndex = currentIndex + 1;
      if (nextIndex >= playlist.length) { // به انتهای لیست رسیده
        if (globalAudioPlayer.loopMode == LoopMode.all && playlist.isNotEmpty) {
          nextIndex = 0; // برو به اولین آهنگ
          print("$methodTag: Sequential & Loop - reached end, going to first.");
        } else {
          print("$methodTag: Sequential & No Loop - reached end. Stopping.");
          if (globalAudioPlayer.playing) globalAudioPlayer.pause();
          globalAudioPlayer.seek(Duration.zero);
          // اگر می‌خواهید دکمه next غیرفعال شود، باید این وضعیت را در build چک کنید.
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("End of playlist.")));
          return;
        }
      }
    }
    print("$methodTag: Playing next song: '${playlist[nextIndex].title}' at index $nextIndex");
    MainTabsScreen.playNewSongInGlobalPlayer(playlist[nextIndex], playlist, nextIndex, autoPlay: true);
  }

  void _controlPlayPrevious() {
    // ... (کد _controlPlayPrevious مثل قبل، با کمی دقت بیشتر در لاگ‌ها و شرایط)
    final String methodTag = "SongDetailScreen._controlPlayPrevious";
    final currentModel = nowPlayingNotifier.value;
    if (currentModel == null || currentModel.currentPlaylist.isEmpty) {
      print("$methodTag: No current model or empty playlist.");
      return;
    }

    // اگر آهنگ بیش از چند ثانیه (مثلا ۳) پخش شده، به ابتدای همان آهنگ برگرد
    if (globalAudioPlayer.position > const Duration(seconds: 3)) {
      print("$methodTag: Position > 3s, seeking to zero for '${currentModel.song.title}'.");
      globalAudioPlayer.seek(Duration.zero);
      // اگر متوقف بود و باید پخش می‌شد (طبق notifier)، دوباره پخشش کن
      if (!globalAudioPlayer.playing && currentModel.isPlaying) {
        globalAudioPlayer.play();
      }
      return;
    }

    List<Song> playlist = currentModel.currentPlaylist;
    int currentIndex = currentModel.currentIndexInPlaylist;
    int prevIndex;

    print("$methodTag: Current song '${currentModel.song.title}', Index: $currentIndex, Shuffle: ${globalAudioPlayer.shuffleModeEnabled}, Loop: ${globalAudioPlayer.loopMode}");


    if (globalAudioPlayer.shuffleModeEnabled && playlist.length > 1) {
      // در حالت شافل، "قبلی" معمولا معنی خاصی ندارد. می‌توان یک آهنگ تصادفی دیگر (غیر از فعلی) انتخاب کرد.
      var availableIndices = List<int>.generate(playlist.length, (i) => i)..remove(currentIndex);
      if (availableIndices.isEmpty) {
        if (playlist.isNotEmpty) MainTabsScreen.playNewSongInGlobalPlayer(playlist[currentIndex], playlist, currentIndex, autoPlay: true); // پخش مجدد همان آهنگ
        return;
      }
      availableIndices.shuffle(Random());
      prevIndex = availableIndices.first;
    } else { // Sequential
      prevIndex = currentIndex - 1;
      if (prevIndex < 0) { // به ابتدای لیست رسیده
        if (globalAudioPlayer.loopMode == LoopMode.all && playlist.isNotEmpty) {
          prevIndex = playlist.length - 1; // برو به آخرین آهنگ
          print("$methodTag: Sequential & Loop - reached start, going to last.");
        } else {
          print("$methodTag: Sequential & No Loop - reached start. Doing nothing.");
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Beginning of playlist.")));
          // اگر می‌خواهید پلیر به اول برگردد و متوقف شود:
          // globalAudioPlayer.seek(Duration.zero);
          // if (globalAudioPlayer.playing) globalAudioPlayer.pause();
          return;
        }
      }
    }
    print("$methodTag: Playing previous song: '${playlist[prevIndex].title}' at index $prevIndex");
    MainTabsScreen.playNewSongInGlobalPlayer(playlist[prevIndex], playlist, prevIndex, autoPlay: true);
  }

  void _controlToggleLoopMode() async {
    // ... (کد _controlToggleLoopMode مثل قبل)
    if (globalAudioPlayer.audioSource == null && nowPlayingNotifier.value == null) return;
    LoopMode currentLoopMode = globalAudioPlayer.loopMode;
    LoopMode nextLoopMode;
    String message;
    if (currentLoopMode == LoopMode.off) { nextLoopMode = LoopMode.all; message = "Repeat All Enabled"; }
    else if (currentLoopMode == LoopMode.all) { nextLoopMode = LoopMode.one; message = "Repeat One Enabled"; }
    else { nextLoopMode = LoopMode.off; message = "Repeat Off"; }
    await globalAudioPlayer.setLoopMode(nextLoopMode);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 1)));
    // setState در listener مربوط به loopModeStream در این کلاس انجام می‌شود
  }

  void _controlToggleShuffleMode() async {
    // ... (کد _controlToggleShuffleMode مثل قبل)
    if (globalAudioPlayer.audioSource == null && nowPlayingNotifier.value == null) return;
    final currentShuffleState = globalAudioPlayer.shuffleModeEnabled;
    await globalAudioPlayer.setShuffleModeEnabled(!currentShuffleState);
    String message = !currentShuffleState ? "Shuffle On" : "Shuffle Off";
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 1)));
    // setState در listener مربوط به shuffleModeEnabledStream در این کلاس انجام می‌شود
  }

  @override
  void dispose() {
    print("SongDetailScreen: dispose for (displayed song) '${_displayedSong.title}'");
    _playerStateSubscriptionLocal?.cancel();
    _loopModeSubscriptionLocal?.cancel();
    _shuffleModeSubscriptionLocal?.cancel();
    nowPlayingNotifier.removeListener(_nowPlayingListenerCallback); // حذف listener
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    // ... (کد _formatDuration مثل قبل)
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return [
      if (hours > 0) twoDigits(hours),
      twoDigits(minutes),
      twoDigits(seconds),
    ].join(':');
  }

  @override
  Widget build(BuildContext context) {
    // ... (بقیه کد build تقریبا بدون تغییر باقی می‌ماند)
    // مهم است که isPlaying و دیگر وضعیت‌ها از nowPlayingNotifier یا globalAudioPlayer خوانده شوند
    // و _displayedSong برای نمایش اطلاعات آهنگ استفاده شود.

    final screenHeight = MediaQuery.of(context).size.height;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    // آهنگ برای نمایش از _displayedSong می‌آید که توسط listener ها آپدیت می‌شود.
    final songForDisplay = _displayedSong;
    // وضعیت پخش را از nowPlayingNotifier (که توسط listener پلیر آپدیت می‌شود) یا مستقیما از پلیر بخوان.
    // اولویت با Notifier است چون ممکن است شامل وضعیت دقیق‌تری باشد (مثلا اگر autoPlay false بوده).
    final bool isCurrentlyPlaying = nowPlayingNotifier.value?.isPlaying ?? globalAudioPlayer.playing;
    final bool canControlPlayback = globalAudioPlayer.audioSource != null || nowPlayingNotifier.value != null;


    Widget coverWidget;
    // ... (کد coverWidget مثل قبل با استفاده از songForDisplay)
    if (songForDisplay.isLocal && songForDisplay.mediaStoreId != null && songForDisplay.mediaStoreId! > 0) {
      coverWidget = QueryArtworkWidget(
        id: songForDisplay.mediaStoreId!, type: ArtworkType.AUDIO, artworkFit: BoxFit.cover, artworkWidth: double.infinity, artworkHeight: screenHeight * 0.45, keepOldArtwork: true, artworkBorder: BorderRadius.zero, artworkClipBehavior: Clip.antiAlias,
        nullArtworkWidget: Container(width: double.infinity, height: screenHeight * 0.45, color: colorScheme.surfaceVariant.withOpacity(0.7), child: Icon(Icons.album_rounded, size: 120, color: colorScheme.onSurfaceVariant.withOpacity(0.5))),
        errorBuilder: (ctx, err, st) => Container(width: double.infinity, height: screenHeight * 0.45, color: colorScheme.surfaceVariant.withOpacity(0.5), child: Icon(Icons.broken_image_outlined, size: 120, color: colorScheme.onSurfaceVariant.withOpacity(0.4))),
      );
    } else if (songForDisplay.coverImagePath != null && songForDisplay.coverImagePath!.isNotEmpty) {
      coverWidget = Image.asset(
        songForDisplay.coverImagePath!, fit: BoxFit.cover, width: double.infinity, height: screenHeight * 0.45,
        errorBuilder: (ctx, err, st) => Container(width: double.infinity, height: screenHeight * 0.45, color: colorScheme.surfaceVariant.withOpacity(0.7), child: Icon(Icons.album_rounded, size: 120, color: colorScheme.onSurfaceVariant.withOpacity(0.5))),
      );
    } else {
      coverWidget = Container(
          width: double.infinity, height: screenHeight * 0.45, color: colorScheme.surfaceVariant.withOpacity(0.7), child: Icon(Icons.album_rounded, size: 120, color: colorScheme.onSurfaceVariant.withOpacity(0.5)));
    }


    Widget lyricsWidget = const SizedBox.shrink();
    // ... (کد lyricsWidget مثل قبل با استفاده از songForDisplay)
    if (songForDisplay.lyrics != null && songForDisplay.lyrics!.isNotEmpty) {
      lyricsWidget = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Lyrics:", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(songForDisplay.lyrics!, style: textTheme.bodyMedium?.copyWith(height: 1.5)),
            const SizedBox(height: 20),
          ],
        ),
      );
    }


    return Scaffold(
      appBar: AppBar(
        // ... (کد AppBar مثل قبل با استفاده از _isFavorite)
        backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          IconButton(
            icon: Icon(_isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: _isFavorite ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.8), size: 28),
            onPressed: _toggleFavorite, tooltip: _isFavorite ? "Remove from favorites" : "Add to favorites",
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          children: [
            SizedBox(height: screenHeight * 0.45, width: double.infinity, child: coverWidget),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // AnimatedSwitcher برای تغییر نرم عنوان و خواننده
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: Column(
                      key: ValueKey<String>(songForDisplay.uniqueIdentifier), // کلید برای تشخیص تغییر
                      children: [
                        Text(songForDisplay.title, textAlign: TextAlign.center, style: textTheme.headlineSmall?.copyWith(color: colorScheme.onBackground, fontWeight: FontWeight.bold) ?? const TextStyle(), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Text(songForDisplay.artist, textAlign: TextAlign.center, style: textTheme.titleMedium?.copyWith(color: colorScheme.onBackground.withOpacity(0.8)) ?? const TextStyle(), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  StreamBuilder<_PositionData>(
                    // ... (StreamBuilder مثل قبل)
                    stream: _positionDataStream,
                    builder: (context, snapshot) {
                      final positionData = snapshot.data ?? _PositionData(Duration.zero, Duration.zero, globalAudioPlayer.duration ?? Duration.zero);
                      final position = positionData.position;
                      final duration = positionData.duration;
                      return Column(children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(trackHeight: 3.5, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0, elevation: 1.0), overlayShape: const RoundSliderOverlayShape(overlayRadius: 18.0), activeTrackColor: colorScheme.primary, inactiveTrackColor: colorScheme.onSurface.withOpacity(0.25), thumbColor: colorScheme.primary, overlayColor: colorScheme.primary.withAlpha(0x3D)),
                          child: Slider(
                            min: 0,
                            max: duration.inSeconds.toDouble().isFinite && duration.inSeconds.toDouble() > 0 ? duration.inSeconds.toDouble() : 1.0,
                            value: position.inSeconds.toDouble().clamp(0.0, duration.inSeconds.toDouble().isFinite && duration.inSeconds.toDouble() > 0 ? duration.inSeconds.toDouble() : 1.0),
                            onChanged: canControlPlayback ? (value) { globalAudioPlayer.seek(Duration(seconds: value.toInt())); } : null,
                          ),
                        ),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_formatDuration(position), style: textTheme.bodySmall?.copyWith(color: colorScheme.onBackground.withOpacity(0.7), letterSpacing: 0.5)), Text(_formatDuration(duration), style: textTheme.bodySmall?.copyWith(color: colorScheme.onBackground.withOpacity(0.7), letterSpacing: 0.5))]))
                      ]);
                    },
                  ),
                  const SizedBox(height: 28),
                  Row(
                    // ... (Row کنترل‌ها مثل قبل، با استفاده از isCurrentlyPlaying و canControlPlayback)
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      StreamBuilder<bool>(
                          stream: globalAudioPlayer.shuffleModeEnabledStream,
                          builder: (context, snapshot) {
                            final isShuffleEnabled = snapshot.data ?? false;
                            return IconButton(icon: Icon(Icons.shuffle_rounded, color: isShuffleEnabled ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.7), size: 26), tooltip: isShuffleEnabled ? "Shuffle On" : "Shuffle Off", onPressed: canControlPlayback ? _controlToggleShuffleMode : null);
                          }),
                      IconButton(
                        icon: Icon(Icons.skip_previous_rounded, color: canControlPlayback ? colorScheme.onSurface : colorScheme.onSurface.withOpacity(0.3), size: 40),
                        onPressed: canControlPlayback ? _controlPlayPrevious : null,
                      ),
                      // دکمه Play/Pause از isCurrentlyPlaying استفاده می‌کند
                      Container(
                        decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle, boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(0.4), blurRadius: 12, spreadRadius: 1, offset: const Offset(0, 2))]),
                        child: StreamBuilder<PlayerState>( // برای نمایش loading/buffering
                            stream: globalAudioPlayer.playerStateStream,
                            builder: (context, snapshot) {
                              final playerState = snapshot.data;
                              final processingState = playerState?.processingState;
                              if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering) {
                                return const SizedBox(width: 60, height: 60, child: Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)));
                              }
                              return IconButton(icon: Icon(isCurrentlyPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: colorScheme.onPrimary, size: 50), padding: const EdgeInsets.all(10), onPressed: canControlPlayback ? _controlPlayPause : null);
                            }
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.skip_next_rounded, color: canControlPlayback ? colorScheme.onSurface : colorScheme.onSurface.withOpacity(0.3), size: 40),
                        onPressed: canControlPlayback ? _controlPlayNext : null,
                      ),
                      StreamBuilder<LoopMode>(
                        stream: globalAudioPlayer.loopModeStream,
                        builder: (context, snapshot) {
                          final loopMode = snapshot.data ?? LoopMode.off;
                          IconData loopIcon; String tooltip;
                          if (loopMode == LoopMode.one) { loopIcon = Icons.repeat_one_on_rounded; tooltip = "Repeat One"; }
                          else if (loopMode == LoopMode.all) { loopIcon = Icons.repeat_on_rounded; tooltip = "Repeat All"; }
                          else { loopIcon = Icons.repeat_rounded; tooltip = "Repeat Off"; }
                          return IconButton(icon: Icon(loopIcon, color: loopMode != LoopMode.off ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.7), size: 26), onPressed: canControlPlayback ? _controlToggleLoopMode : null, tooltip: tooltip);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  lyricsWidget,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}