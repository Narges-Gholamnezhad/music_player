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
import 'now_playing_model.dart';

class _PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  _PositionData(this.position, this.bufferedPosition, this.duration);
}

class SongDetailScreen extends StatefulWidget {
  final Song initialSong;
  final List<Song> songList;
  final int initialIndex;

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
  late Song _displayedSong;
  SharedPreferences? _prefs;

  StreamSubscription<PlayerState>? _playerStateSubscriptionLocal;
  StreamSubscription<LoopMode>? _loopModeSubscriptionLocal;
  StreamSubscription<bool>? _shuffleModeSubscriptionLocal;
  late VoidCallback _nowPlayingListenerCallback;

  Stream<_PositionData> get _positionDataStream =>
      Stream.periodic(const Duration(milliseconds: 200), (_) {
        final currentDuration = globalAudioPlayer.duration;
        return _PositionData(
          globalAudioPlayer.position,
          globalAudioPlayer.bufferedPosition,
          currentDuration ?? Duration.zero,
        );
      }).distinct((prev, next) =>
      prev.position.inMilliseconds == next.position.inMilliseconds &&
          prev.duration.inMilliseconds == next.duration.inMilliseconds &&
          prev.bufferedPosition.inMilliseconds == next.bufferedPosition.inMilliseconds);


  @override
  void initState() {
    super.initState();
    _displayedSong = nowPlayingNotifier.value?.song ?? widget.initialSong;
    print(
        "SongDetailScreen: initState - DisplayedSong: '${_displayedSong.title}', InitialWidgetSong: '${widget.initialSong.title}', UID: ${widget.initialSong.uniqueIdentifier}, Index: ${widget.initialIndex}, Playlist size: ${widget.songList.length}");

    _initPrefsAndLoadDataForSong(_displayedSong);

    final currentGlobalNowPlaying = nowPlayingNotifier.value;
    bool playThisSongAnuew = true;

    if (currentGlobalNowPlaying != null && currentGlobalNowPlaying.song.uniqueIdentifier == widget.initialSong.uniqueIdentifier) {
      if (_arePlaylistsEffectivelyEqual(currentGlobalNowPlaying.currentPlaylist, widget.songList) &&
          currentGlobalNowPlaying.currentIndexInPlaylist == widget.initialIndex) {
        playThisSongAnuew = false;
      }
    }

    if (playThisSongAnuew) {
      MainTabsScreen.playNewSongInGlobalPlayer(
          widget.initialSong, widget.songList, widget.initialIndex, autoPlay: true);
    }
    // مقداردهی اولیه displayedSong پس از اطمینان از اینکه Notifier آپدیت شده
    if (nowPlayingNotifier.value != null) {
      _displayedSong = nowPlayingNotifier.value!.song;
    }

    _setupLocalListeners();
  }

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
    _nowPlayingListenerCallback = () {
      final newNowPlaying = nowPlayingNotifier.value;
      if (mounted) {
        if (newNowPlaying != null) {
          if (_displayedSong.uniqueIdentifier != newNowPlaying.song.uniqueIdentifier) {
            setState(() => _displayedSong = newNowPlaying.song);
            _loadFavoriteStatusAndLyrics(newNowPlaying.song);
          } else {
            setState(() {});
          }
        } else {
          setState(() {});
        }
      }
    };
    nowPlayingNotifier.addListener(_nowPlayingListenerCallback);

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

    await songToCheck.loadLyrics(_prefs!);

    final List<String> favoriteIdsList = _prefs!.getStringList(SharedPrefKeys.favoriteSongIdentifiers) ?? [];
    if (mounted) {
      setState(() {
        _isFavorite = favoriteIdsList.contains(songToCheck.uniqueIdentifier);
      });
    }
  }

  Future<void> _toggleFavorite() async {
    _prefs ??= await SharedPreferences.getInstance();
    // از _displayedSong استفاده می‌کنیم چون همیشه آهنگ فعلی نمایش داده شده در UI است
    final songToFavorite = _displayedSong;

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
      // اگر بخواهیم HomeScreen هم بلافاصله آپدیت شود (مثلا آیکون قلب در لیست)
      // homeScreenKey.currentState?.refreshDataOnReturn(); // این نیاز به بررسی دارد که آیا لازم است
    }
  }

  void _controlPlayPause() {
    if (globalAudioPlayer.audioSource == null && nowPlayingNotifier.value == null) return;
    if (globalAudioPlayer.playing) {
      globalAudioPlayer.pause();
    } else {
      if (globalAudioPlayer.processingState == ProcessingState.completed) {
        globalAudioPlayer.seek(Duration.zero);
      }
      globalAudioPlayer.play();
    }
  }

  void _controlPlayNext() {
    final currentModel = nowPlayingNotifier.value;
    if (currentModel == null || currentModel.currentPlaylist.isEmpty) return;
    List<Song> playlist = currentModel.currentPlaylist;
    int currentIndex = currentModel.currentIndexInPlaylist;
    int nextIndex;

    if (globalAudioPlayer.shuffleModeEnabled && playlist.length > 1) {
      var availableIndices = List<int>.generate(playlist.length, (i) => i)..remove(currentIndex);
      if (availableIndices.isEmpty) {
        if (globalAudioPlayer.loopMode == LoopMode.all && playlist.isNotEmpty) {
          availableIndices = List<int>.generate(playlist.length, (i) => i);
          availableIndices.shuffle(Random());
          nextIndex = availableIndices.first;
        } else {
          if (globalAudioPlayer.playing) globalAudioPlayer.pause();
          globalAudioPlayer.seek(Duration.zero);
          return;
        }
      } else {
        availableIndices.shuffle(Random());
        nextIndex = availableIndices.first;
      }
    } else {
      nextIndex = currentIndex + 1;
      if (nextIndex >= playlist.length) {
        if (globalAudioPlayer.loopMode == LoopMode.all && playlist.isNotEmpty) {
          nextIndex = 0;
        } else {
          if (globalAudioPlayer.playing) globalAudioPlayer.pause();
          globalAudioPlayer.seek(Duration.zero);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("End of playlist.")));
          return;
        }
      }
    }
    MainTabsScreen.playNewSongInGlobalPlayer(playlist[nextIndex], playlist, nextIndex, autoPlay: true);
  }

  void _controlPlayPrevious() {
    final currentModel = nowPlayingNotifier.value;
    if (currentModel == null || currentModel.currentPlaylist.isEmpty) return;
    if (globalAudioPlayer.position > const Duration(seconds: 3)) {
      globalAudioPlayer.seek(Duration.zero);
      if (!globalAudioPlayer.playing && currentModel.isPlaying) {
        globalAudioPlayer.play();
      }
      return;
    }
    List<Song> playlist = currentModel.currentPlaylist;
    int currentIndex = currentModel.currentIndexInPlaylist;
    int prevIndex;

    if (globalAudioPlayer.shuffleModeEnabled && playlist.length > 1) {
      var availableIndices = List<int>.generate(playlist.length, (i) => i)..remove(currentIndex);
      if (availableIndices.isEmpty) {
        if (playlist.isNotEmpty) MainTabsScreen.playNewSongInGlobalPlayer(playlist[currentIndex], playlist, currentIndex, autoPlay: true);
        return;
      }
      availableIndices.shuffle(Random());
      prevIndex = availableIndices.first;
    } else {
      prevIndex = currentIndex - 1;
      if (prevIndex < 0) {
        if (globalAudioPlayer.loopMode == LoopMode.all && playlist.isNotEmpty) {
          prevIndex = playlist.length - 1;
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Beginning of playlist.")));
          return;
        }
      }
    }
    MainTabsScreen.playNewSongInGlobalPlayer(playlist[prevIndex], playlist, prevIndex, autoPlay: true);
  }

  void _controlToggleLoopMode() async {
    if (globalAudioPlayer.audioSource == null && nowPlayingNotifier.value == null) return;
    LoopMode currentLoopMode = globalAudioPlayer.loopMode;
    LoopMode nextLoopMode; String message;
    if (currentLoopMode == LoopMode.off) { nextLoopMode = LoopMode.all; message = "Repeat All Enabled"; }
    else if (currentLoopMode == LoopMode.all) { nextLoopMode = LoopMode.one; message = "Repeat One Enabled"; }
    else { nextLoopMode = LoopMode.off; message = "Repeat Off"; }
    await globalAudioPlayer.setLoopMode(nextLoopMode);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 1)));
  }

  void _controlToggleShuffleMode() async {
    if (globalAudioPlayer.audioSource == null && nowPlayingNotifier.value == null) return;
    final currentShuffleState = globalAudioPlayer.shuffleModeEnabled;
    await globalAudioPlayer.setShuffleModeEnabled(!currentShuffleState);
    String message = !currentShuffleState ? "Shuffle On" : "Shuffle Off";
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 1)));
  }

  @override
  void dispose() {
    print("SongDetailScreen: dispose for (displayed song) '${_displayedSong.title}'");
    _playerStateSubscriptionLocal?.cancel();
    _loopModeSubscriptionLocal?.cancel();
    _shuffleModeSubscriptionLocal?.cancel();
    nowPlayingNotifier.removeListener(_nowPlayingListenerCallback);
    super.dispose();
  }

  String _formatDuration(Duration duration) {
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
    final screenHeight = MediaQuery.of(context).size.height;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final songForDisplay = _displayedSong;
    final bool isCurrentlyPlaying = nowPlayingNotifier.value?.isPlaying ?? globalAudioPlayer.playing;
    final bool canControlPlayback = globalAudioPlayer.audioSource != null || nowPlayingNotifier.value != null;

    Widget coverWidget;
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
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: Column(
                      key: ValueKey<String>(songForDisplay.uniqueIdentifier),
                      children: [
                        Text(songForDisplay.title, textAlign: TextAlign.center, style: textTheme.headlineSmall?.copyWith(color: colorScheme.onBackground, fontWeight: FontWeight.bold) ?? const TextStyle(), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Text(songForDisplay.artist, textAlign: TextAlign.center, style: textTheme.titleMedium?.copyWith(color: colorScheme.onBackground.withOpacity(0.8)) ?? const TextStyle(), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  StreamBuilder<_PositionData>(
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
                      Container(
                        decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle, boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(0.4), blurRadius: 12, spreadRadius: 1, offset: const Offset(0, 2))]),
                        child: StreamBuilder<PlayerState>(
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