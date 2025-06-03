// lib/song_detail_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'song_model.dart';
import 'main_tabs_screen.dart'; // برای دسترسی به globalAudioPlayer و nowPlayingNotifier

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

  StreamSubscription<PlayerState>? _playerStateSubscriptionLocal;
  StreamSubscription<LoopMode>? _loopModeSubscriptionLocal;
  StreamSubscription<bool>? _shuffleModeSubscriptionLocal;
  late VoidCallback _nowPlayingListenerCallback;

  static const String favoriteSongsDataKeyPlayer = 'favorite_songs_data_list';

  Stream<_PositionData> get _positionDataStream =>
      Stream.periodic(const Duration(milliseconds: 200), (_) {
        return _PositionData(
          globalAudioPlayer.position,
          globalAudioPlayer.bufferedPosition,
          globalAudioPlayer.duration ?? Duration.zero,
        );
      }).distinct((prev, next) =>
      prev.position == next.position && prev.duration == next.duration);

  @override
  void initState() {
    super.initState();
    _displayedSong = widget.initialSong;
    print(
        "SongDetailScreen: initState for (initial widget) '${widget.initialSong.title}', "
            "InitialIndex: ${widget.initialIndex}, "
            "Playlist size: ${widget.songList.length}, "
            "Passed song audioUrl: ${widget.initialSong.audioUrl}");

    final currentGlobalNowPlaying = nowPlayingNotifier.value;
    final currentGlobalSong = currentGlobalNowPlaying?.song;

    bool shouldPlayNew = true;

    if (currentGlobalSong != null) {
      if (currentGlobalSong.audioUrl == widget.initialSong.audioUrl) {
        if (_arePlaylistsEffectivelyEqual(currentGlobalNowPlaying?.currentPlaylist, widget.songList) &&
            currentGlobalNowPlaying?.currentIndexInPlaylist == widget.initialIndex) {
          print("SongDetailScreen initState: Same song and context already playing/loaded globally.");
          shouldPlayNew = false;
          _displayedSong = currentGlobalSong;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && globalAudioPlayer.playing != (nowPlayingNotifier.value?.isPlaying ?? false)) {
              setState(() {});
            }
          });
        } else {
          print("SongDetailScreen initState: Same song URL but different playlist context. Will replay with new context (autoPlay true).");
        }
      } else {
        print("SongDetailScreen initState: Different song URL globally. Will play new song (autoPlay true).");
      }
    } else {
      print("SongDetailScreen initState: No song playing globally. Will play new song (autoPlay true).");
    }

    if (shouldPlayNew) {
      print("SongDetailScreen initState: Calling playNewSongInGlobalPlayer for '${widget.initialSong.title}' with autoPlay: true");
      MainTabsScreen.playNewSongInGlobalPlayer(
          widget.initialSong, widget.songList, widget.initialIndex, autoPlay: true);
    }

    _checkIfFavoriteForSong(_displayedSong);
    _setupLocalListeners();
  }

  bool _arePlaylistsEffectivelyEqual(List<Song>? p1, List<Song>? p2) {
    if (p1 == null && p2 == null) return true;
    if (p1 == null || p2 == null) return false;
    if (p1.length != p2.length) return false;
    for (int i = 0; i < p1.length; i++) {
      if (p1[i].audioUrl != p2[i].audioUrl) return false;
    }
    return true;
  }

  void _setupLocalListeners() {
    _nowPlayingListenerCallback = _onNowPlayingChanged;
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

  void _onNowPlayingChanged() {
    final newNowPlaying = nowPlayingNotifier.value;
    if (mounted) {
      if (newNowPlaying != null) {
        bool songChanged = _displayedSong.audioUrl != newNowPlaying.song.audioUrl;
        // حتی اگر آهنگ یکی باشد، isPlaying یا لیست پخش ممکن است تغییر کرده باشد
        setState(() {
          _displayedSong = newNowPlaying.song;
        });
        if (songChanged) {
          _checkIfFavoriteForSong(newNowPlaying.song);
        }
      } else {
        print("SongDetailScreen: nowPlayingNotifier is null. Updating UI to reflect no song.");
        // اگر _displayedSong هنوز مقدار دارد، UI با آن رندر می‌شود اما کنترل‌ها غیرفعال می‌شوند
        // یا می‌توانید _displayedSong را به یک آهنگ پیش‌فرض یا null تغییر دهید
        // Navigator.of(context).pop(); // یا صفحه را ببندید
        setState(() {});
      }
    }
  }

  Future<void> _checkIfFavoriteForSong(Song songToCheck) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> favoriteDataStrings = prefs.getStringList(favoriteSongsDataKeyPlayer) ?? [];
    final String songIdentifier = "${songToCheck.title};;${songToCheck.artist}" + (songToCheck.isLocal ? ";;${songToCheck.audioUrl}" : "");

    bool found = favoriteDataStrings.any((dataString) {
      try {
        final favSong = Song.fromDataString(dataString);
        final String favSongIdentifier = "${favSong.title};;${favSong.artist}" + (favSong.isLocal ? ";;${favSong.audioUrl}" : "");
        return favSongIdentifier == songIdentifier;
      } catch (e) { return false; }
    });

    if (mounted && _isFavorite != found) {
      setState(() { _isFavorite = found; });
    }
  }

  Future<void> _toggleFavorite() async {
    final songToFavorite = nowPlayingNotifier.value?.song ?? _displayedSong;

    final prefs = await SharedPreferences.getInstance();
    List<String> favoriteDataStrings = prefs.getStringList(favoriteSongsDataKeyPlayer) ?? [];
    final String songDataForStorage = songToFavorite.toDataString();
    final String songIdentifierToMatch = "${songToFavorite.title};;${songToFavorite.artist}" + (songToFavorite.isLocal ? ";;${songToFavorite.audioUrl}" : "");

    int foundIndex = -1;
    for(int i=0; i < favoriteDataStrings.length; i++) {
      try {
        final favSong = Song.fromDataString(favoriteDataStrings[i]);
        final String currentFavSongIdentifier = "${favSong.title};;${favSong.artist}" + (favSong.isLocal ? ";;${favSong.audioUrl}" : "");
        if (currentFavSongIdentifier == songIdentifierToMatch) {
          foundIndex = i;
          break;
        }
      } catch (e) { /* ignore */ }
    }

    if (mounted) {
      setState(() {
        _isFavorite = !_isFavorite;
        if (_isFavorite) {
          if (foundIndex == -1) favoriteDataStrings.add(songDataForStorage);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${songToFavorite.title}" added to favorites.')));
        } else {
          if (foundIndex != -1) favoriteDataStrings.removeAt(foundIndex);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${songToFavorite.title}" removed from favorites.')));
        }
      });
    }
    await prefs.setStringList(favoriteSongsDataKeyPlayer, favoriteDataStrings);
  }

  void _controlPlayPause() {
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
        if (globalAudioPlayer.loopMode == LoopMode.all) { MainTabsScreen.playNewSongInGlobalPlayer(playlist[currentIndex], playlist, currentIndex, autoPlay: true); }
        return;
      }
      availableIndices.shuffle(Random());
      nextIndex = availableIndices.first;
    } else {
      nextIndex = currentIndex + 1;
      if (nextIndex >= playlist.length) {
        if (globalAudioPlayer.loopMode == LoopMode.all && playlist.isNotEmpty) {
          nextIndex = 0;
        } else {
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Last song in playlist.")));
          if (nowPlayingNotifier.value != null && nowPlayingNotifier.value!.isPlaying) {
            nowPlayingNotifier.value = nowPlayingNotifier.value!.copyWith(isPlaying: false);
            globalAudioPlayer.pause();
          }
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
      if (!globalAudioPlayer.playing && (nowPlayingNotifier.value?.isPlaying ?? false)) {
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
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("First song in playlist.")));
          return;
        }
      }
    }
    MainTabsScreen.playNewSongInGlobalPlayer(playlist[prevIndex], playlist, prevIndex, autoPlay: true);
  }

  void _controlToggleLoopMode() async {
    LoopMode currentLoopMode = globalAudioPlayer.loopMode;
    LoopMode nextLoopMode;
    if (currentLoopMode == LoopMode.off) { nextLoopMode = LoopMode.all; }
    else if (currentLoopMode == LoopMode.all) { nextLoopMode = LoopMode.one; }
    else { nextLoopMode = LoopMode.off; }
    await globalAudioPlayer.setLoopMode(nextLoopMode);
  }

  void _controlToggleShuffleMode() async {
    final newShuffleState = !await globalAudioPlayer.shuffleModeEnabled;
    await globalAudioPlayer.setShuffleModeEnabled(newShuffleState);
  }

  @override
  void dispose() {
    print("SongDetailScreen: dispose for (displayed) '${_displayedSong.title}'");
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

    final songForDisplay = nowPlayingNotifier.value?.song ?? _displayedSong; // همیشه از _displayedSong استفاده کن اگر notifier null است
    final bool isCurrentlyPlaying = nowPlayingNotifier.value?.isPlaying ?? globalAudioPlayer.playing;


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
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) => FadeTransition(opacity: animation, child: child),
                    child: Column(
                      key: ValueKey<String>("${songForDisplay.title}-${songForDisplay.artist}"),
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
                      final positionData = snapshot.data ?? _PositionData(Duration.zero, Duration.zero, Duration.zero);
                      final position = positionData.position;
                      final duration = positionData.duration;
                      return Column(children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(trackHeight: 3.5, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0, elevation: 1.0), overlayShape: const RoundSliderOverlayShape(overlayRadius: 18.0), activeTrackColor: colorScheme.primary, inactiveTrackColor: colorScheme.onSurface.withOpacity(0.25), thumbColor: colorScheme.primary, overlayColor: colorScheme.primary.withAlpha(0x3D)),
                          child: Slider(
                            min: 0, max: duration.inSeconds.toDouble().isFinite && duration.inSeconds.toDouble() > 0 ? duration.inSeconds.toDouble() : 1.0,
                            value: position.inSeconds.toDouble().clamp(0.0, duration.inSeconds.toDouble().isFinite && duration.inSeconds.toDouble() > 0 ? duration.inSeconds.toDouble() : 1.0),
                            onChanged: (value) { if (globalAudioPlayer.audioSource != null) globalAudioPlayer.seek(Duration(seconds: value.toInt())); }, // فقط اگر منبعی هست seek کن
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
                            return IconButton(icon: Icon(Icons.shuffle_rounded, color: isShuffleEnabled ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.7), size: 26), tooltip: isShuffleEnabled ? "Shuffle On" : "Shuffle Off", onPressed: _controlToggleShuffleMode);
                          }),
                      IconButton(
                        icon: Icon(Icons.skip_previous_rounded, color: (nowPlayingNotifier.value?.currentPlaylist.isNotEmpty ?? false) ? colorScheme.onSurface : colorScheme.onSurface.withOpacity(0.3), size: 40),
                        onPressed: (nowPlayingNotifier.value?.currentPlaylist.isNotEmpty ?? false) ? _controlPlayPrevious : null,
                      ),
                      StreamBuilder<PlayerState>(
                        stream: globalAudioPlayer.playerStateStream,
                        builder: (context, snapshot) {
                          final playerState = snapshot.data;
                          final processingState = playerState?.processingState;
                          final playing = isCurrentlyPlaying;
                          return Container(
                            decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle, boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(0.4), blurRadius: 12, spreadRadius: 1, offset: const Offset(0, 2))]),
                            child: (processingState == ProcessingState.loading || processingState == ProcessingState.buffering)
                                ? const SizedBox(width: 60, height: 60, child: Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)))
                                : IconButton(icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: colorScheme.onPrimary, size: 50), padding: const EdgeInsets.all(10), onPressed: (globalAudioPlayer.audioSource == null && nowPlayingNotifier.value == null) ? null : _controlPlayPause),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.skip_next_rounded, color: (nowPlayingNotifier.value?.currentPlaylist.isNotEmpty ?? false) ? colorScheme.onSurface : colorScheme.onSurface.withOpacity(0.3), size: 40),
                        onPressed: (nowPlayingNotifier.value?.currentPlaylist.isNotEmpty ?? false) ? _controlPlayNext : null,
                      ),
                      StreamBuilder<LoopMode>(
                        stream: globalAudioPlayer.loopModeStream,
                        builder: (context, snapshot) {
                          final loopMode = snapshot.data ?? LoopMode.off;
                          IconData loopIcon; String tooltip;
                          if (loopMode == LoopMode.one) { loopIcon = Icons.repeat_one_on_rounded; tooltip = "Repeat One"; }
                          else if (loopMode == LoopMode.all) { loopIcon = Icons.repeat_on_rounded; tooltip = "Repeat All"; }
                          else { loopIcon = Icons.repeat_rounded; tooltip = "Repeat Off"; }
                          return IconButton(icon: Icon(loopIcon, color: loopMode != LoopMode.off ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.7), size: 26), onPressed: _controlToggleLoopMode, tooltip: tooltip);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}