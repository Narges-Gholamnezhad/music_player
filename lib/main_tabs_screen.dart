// lib/main_tabs_screen.dart
import 'dart:async';
import 'dart:math'; // برای Random در shuffle
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'song_model.dart';
import 'now_playing_model.dart';
import 'song_detail_screen.dart';
import 'home_screen.dart';
import 'music_shop_screen.dart';
import 'user_profile_screen.dart';
import 'local_music_screen.dart';
import 'favorites_screen.dart';

// Global Keys
final GlobalKey<HomeScreenState> homeScreenKey = GlobalKey<HomeScreenState>();
final GlobalKey<LocalMusicScreenState> localMusicScreenKey = GlobalKey<LocalMusicScreenState>();

// Global Audio Player and Notifier
final AudioPlayer globalAudioPlayer = AudioPlayer();
final ValueNotifier<NowPlayingModel?> nowPlayingNotifier = ValueNotifier(null);

class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({super.key});

  static Future<void> playNewSongInGlobalPlayer(Song song, List<Song> playlist, int index, {bool autoPlay = true}) async {
    print(
        "MainTabsScreen (static): Play Request - Song: '${song.title}', Index: $index, Playlist size: ${playlist.length}, AutoPlay: $autoPlay, URL: ${song.audioUrl}");

    if (playlist.isEmpty || index < 0 || index >= playlist.length) {
      print(
          "Error in playNewSongInGlobalPlayer: Invalid playlist/index. Playlist empty: ${playlist.isEmpty}, index: $index, playlist length: ${playlist.length}. Stopping player.");
      await globalAudioPlayer.stop().catchError((e) => print("Error stopping player: $e"));
      nowPlayingNotifier.value = null;
      return;
    }

    if (song.audioUrl.isEmpty) {
      print("Error in playNewSongInGlobalPlayer: audioUrl for '${song.title}' is empty. Playback cannot proceed.");
      final currentModel = nowPlayingNotifier.value;
      // اگر آهنگ فعلی همین آهنگ مشکل‌دار بود، آن را به حالت پاوز در بیاور
      if (currentModel != null && currentModel.song.audioUrl == song.audioUrl) {
        nowPlayingNotifier.value = currentModel.copyWith(isPlaying: false);
      }
      // می‌توانید به کاربر پیغام خطا نشان دهید
      return;
    }

    try {
      final currentSourceTag = (globalAudioPlayer.sequenceState?.currentSource?.tag as Uri?)?.toString();
      final currentModel = nowPlayingNotifier.value;
      bool isCurrentlyPlayingGlobal = globalAudioPlayer.playing;

      print("playNewSongInGlobalPlayer: Current source tag: $currentSourceTag, New song URL: ${song.audioUrl}, Player isPlaying: $isCurrentlyPlayingGlobal");

      // اگر URL آهنگ جدید با آهنگ در حال پخش یکی است
      if (currentSourceTag == song.audioUrl) {
        print("playNewSongInGlobalPlayer: Requested song ('${song.title}') is the same as current source.");

        // اگر قرار است پخش شود و در حال پخش نیست، یا اگر قرار نیست پخش شود و در حال پخش است
        if (autoPlay && !isCurrentlyPlayingGlobal) {
          await globalAudioPlayer.play();
          isCurrentlyPlayingGlobal = true; // وضعیت را آپدیت کن
          print("playNewSongInGlobalPlayer: Played same song (was paused).");
        } else if (!autoPlay && isCurrentlyPlayingGlobal) {
          await globalAudioPlayer.pause();
          isCurrentlyPlayingGlobal = false; // وضعیت را آپدیت کن
          print("playNewSongInGlobalPlayer: Paused same song (autoPlay false).");
        } else if (autoPlay && isCurrentlyPlayingGlobal) {
          // اگر در حال پخش است و autoPlay هم true است، ممکن است فقط context عوض شده
          print("playNewSongInGlobalPlayer: Same song, already playing and autoPlay true. Context might have changed.");
        }


        // notifier را آپدیت کن تا لیست پخش و ایندکس جدید را منعکس کند
        nowPlayingNotifier.value = NowPlayingModel(
          song: song,
          audioPlayer: globalAudioPlayer,
          isPlaying: isCurrentlyPlayingGlobal, // وضعیت واقعی پخش
          currentPlaylist: playlist,
          currentIndexInPlaylist: index,
        );
        print("playNewSongInGlobalPlayer: Notifier updated for same song. isPlaying: ${nowPlayingNotifier.value?.isPlaying}");
        return;
      }

      // آهنگ جدید است
      await globalAudioPlayer.stop();
      print("playNewSongInGlobalPlayer: Stopped previous. Setting audio source for '${song.title}'.");
      await globalAudioPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(song.audioUrl), tag: song.audioUrl),
        initialPosition: Duration.zero,
        // preload: true // می‌توانید preload را هم فعال کنید
      );
      print("playNewSongInGlobalPlayer: Audio source set for '${song.title}'.");

      nowPlayingNotifier.value = NowPlayingModel(
        song: song,
        audioPlayer: globalAudioPlayer,
        isPlaying: autoPlay, // مقدار اولیه، listener آن را بعدا با وضعیت واقعی پلیر آپدیت می‌کند
        currentPlaylist: playlist,
        currentIndexInPlaylist: index,
      );
      print("playNewSongInGlobalPlayer: Notifier set for new song '${song.title}'. isPlaying (initial from autoPlay): ${nowPlayingNotifier.value?.isPlaying}");

      if (autoPlay) {
        await globalAudioPlayer.play();
        print("playNewSongInGlobalPlayer: Commanded to play new song '${song.title}'. Actual player.playing: ${globalAudioPlayer.playing}");
      } else {
        // اگر autoPlay false است و notifier به اشتباه isPlaying:true دارد، اصلاحش کن
        if (nowPlayingNotifier.value != null && nowPlayingNotifier.value!.isPlaying) {
          nowPlayingNotifier.value = nowPlayingNotifier.value!.copyWith(isPlaying: false);
        }
        print("playNewSongInGlobalPlayer: AutoPlay is false for '${song.title}', player will not start automatically.");
      }
    } catch (e, s) {
      print("!!! CRITICAL ERROR in playNewSongInGlobalPlayer (static) for '${song.title}': $e\nStack: $s");
      await globalAudioPlayer.stop().catchError((_) {});
      final currentModelError = nowPlayingNotifier.value;
      if (currentModelError != null && currentModelError.song.audioUrl == song.audioUrl) {
        nowPlayingNotifier.value = currentModelError.copyWith(isPlaying: false);
      } else if (playlist.isNotEmpty && index >=0 && index < playlist.length) {
        nowPlayingNotifier.value = NowPlayingModel(
          song: playlist[index],
          audioPlayer: globalAudioPlayer,
          isPlaying: false,
          currentPlaylist: playlist,
          currentIndexInPlaylist: index,
        );
      } else {
        nowPlayingNotifier.value = null;
      }
    }
  }

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _widgetOptions;
  late final List<String> _appBarTitles;

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<ProcessingState>? _processingStateSubscription;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      HomeScreen(key: homeScreenKey),
      const MusicShopScreen(),
      const UserProfileScreen(),
      LocalMusicScreen(key: localMusicScreenKey),
    ];
    _appBarTitles = <String>['My Music', 'Music Shop', 'Account', 'Local Music'];

    _playerStateSubscription = globalAudioPlayer.playerStateStream.listen((playerState) {
      final currentModel = nowPlayingNotifier.value;
      if (currentModel != null && mounted) {
        if (currentModel.isPlaying != playerState.playing) {
          print("MainTabsScreen Listener: Player state changed (playing: ${playerState.playing}). Updating notifier for '${currentModel.song.title}'. Current model isPlaying was ${currentModel.isPlaying}");
          nowPlayingNotifier.value = currentModel.copyWith(isPlaying: playerState.playing);
        }
      }
    });

    _processingStateSubscription = globalAudioPlayer.processingStateStream.listen((processingState) {
      final currentModel = nowPlayingNotifier.value;
      print("MainTabsScreen Listener: Processing state: $processingState for song: ${currentModel?.song.title}");

      if (currentModel == null) {
        print("MainTabsScreen Listener: Processing state changed but no current model in notifier.");
        return;
      }

      if (processingState == ProcessingState.completed) {
        print("Song '${currentModel.song.title}' completed. Loop mode: ${globalAudioPlayer.loopMode}");
        if (globalAudioPlayer.loopMode != LoopMode.one) {
          _handleSongCompletion();
        } else {
          // just_audio باید loop one را خودش هندل کند و دوباره پلی شود.
          // فقط مطمئن شویم isPlaying در notifier درست است.
          if (mounted && !currentModel.isPlaying) { // اگر به دلایلی false شده بود
            nowPlayingNotifier.value = currentModel.copyWith(isPlaying: true);
          }
          // در برخی پیاده‌سازی‌ها، شاید نیاز به seek(0) و play() دستی باشد
          // globalAudioPlayer.seek(Duration.zero).then((_) => globalAudioPlayer.play());
        }
      } else if (processingState == ProcessingState.idle && globalAudioPlayer.audioSource != null) {
        print("Warning: Player is idle but has an audio source. Possible error or stopped state for '${currentModel.song.title}'. Current isPlaying in model: ${currentModel.isPlaying}");
        // اگر مدل می‌گوید در حال پخش است اما پلیر idle شده، وضعیت را اصلاح کن
        if (currentModel.isPlaying && mounted) {
          nowPlayingNotifier.value = currentModel.copyWith(isPlaying: false);
        }
      }
    });
    print("MainTabsScreen: initState finished, global player listeners set up.");
  }

  void _handleSongCompletion() {
    print("_handleSongCompletion called. Current song: ${nowPlayingNotifier.value?.song.title}");
    final currentModel = nowPlayingNotifier.value;

    if (currentModel == null) {
      print("Error in _handleSongCompletion: currentModel is null.");
      globalAudioPlayer.stop().catchError((e) => print("Error stopping player: $e"));
      return;
    }
    if (currentModel.currentPlaylist.isEmpty) {
      print("Warning in _handleSongCompletion: currentPlaylist is empty.");
      globalAudioPlayer.pause(); // یا stop()
      globalAudioPlayer.seek(Duration.zero);
      nowPlayingNotifier.value = currentModel.copyWith(isPlaying: false);
      return;
    }

    List<Song> playlist = currentModel.currentPlaylist;
    int currentIndex = currentModel.currentIndexInPlaylist;

    if (currentIndex < 0 || currentIndex >= playlist.length) {
      print("Error in _handleSongCompletion: Invalid currentIndex ($currentIndex) for playlist length (${playlist.length}). Playing first song or stopping.");
      if (playlist.isNotEmpty) {
        MainTabsScreen.playNewSongInGlobalPlayer(playlist[0], playlist, 0, autoPlay: true);
      } else {
        globalAudioPlayer.stop().catchError((e) => print("Error stopping player: $e"));
        nowPlayingNotifier.value = currentModel.copyWith(isPlaying: false, currentPlaylist: [], currentIndexInPlaylist: 0);
      }
      return;
    }

    int nextIndex;
    if (globalAudioPlayer.shuffleModeEnabled && playlist.length > 1) {
      var availableIndices = List<int>.generate(playlist.length, (i) => i)..remove(currentIndex);
      if (availableIndices.isEmpty) { // این نباید اتفاق بیفتد اگر playlist.length > 1
        if (globalAudioPlayer.loopMode == LoopMode.all) {
          MainTabsScreen.playNewSongInGlobalPlayer(playlist[currentIndex], playlist, currentIndex, autoPlay: true);
        } else { // فقط یک آهنگ بوده و شافل فعال است و لوپ نیست
          globalAudioPlayer.pause();
          globalAudioPlayer.seek(Duration.zero);
          nowPlayingNotifier.value = currentModel.copyWith(isPlaying: false);
        }
        return;
      }
      availableIndices.shuffle(Random());
      nextIndex = availableIndices.first;
      print("_handleSongCompletion: Shuffle next index: $nextIndex for song: '${playlist[nextIndex].title}'");
    } else {
      nextIndex = currentIndex + 1;
      print("_handleSongCompletion: Sequential next index: $nextIndex");
    }

    if (nextIndex < playlist.length) {
      MainTabsScreen.playNewSongInGlobalPlayer(playlist[nextIndex], playlist, nextIndex, autoPlay: true);
    } else {
      if (globalAudioPlayer.loopMode == LoopMode.all && playlist.isNotEmpty) {
        print("_handleSongCompletion: Loop all, playing first song from playlist.");
        MainTabsScreen.playNewSongInGlobalPlayer(playlist[0], playlist, 0, autoPlay: true);
      } else {
        print("_handleSongCompletion: Reached end of playlist and loop all is off. Playback stopped.");
        globalAudioPlayer.pause();
        globalAudioPlayer.seek(Duration.zero);
        if (nowPlayingNotifier.value != null) { // برای جلوگیری از خطا اگر همزمان null شده باشد
          nowPlayingNotifier.value = nowPlayingNotifier.value!.copyWith(isPlaying: false);
        }
      }
    }
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _processingStateSubscription?.cancel();
    // globalAudioPlayer.dispose(); // معمولا در dispose اپلیکیشن انجام می‌شود
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (!mounted) return;
    if (_selectedIndex == index) {
      // اگر روی تب فعلی دوباره کلیک شد، اسکرول به بالا و رفرش
      if (index == 0 && homeScreenKey.currentState != null) {
        homeScreenKey.currentState!.scrollToTopAndRefresh();
      } else if (index == 3 && localMusicScreenKey.currentState != null) {
        localMusicScreenKey.currentState!.scrollToTopAndRefresh();
      }
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  void _miniPlayerPlayPause() {
    print("_miniPlayerPlayPause called. Notifier: ${nowPlayingNotifier.value?.song.title}, Player isPlaying: ${globalAudioPlayer.playing}, Notifier isPlaying: ${nowPlayingNotifier.value?.isPlaying}");

    if (nowPlayingNotifier.value == null && globalAudioPlayer.audioSource != null) {
      // اگر notifier null است اما منبعی در پلیر وجود دارد (مثلا بعد از خطا)
      print("Notifier was null, attempting to play current source if any.");
      globalAudioPlayer.play(); // سعی کن هرچی هست را پلی کنی
      // اینجا باید notifier هم آپدیت شود، اما اطلاعات آهنگ و لیست را نداریم
      // این حالت باید کمتر پیش بیاید با اصلاحات دیگر
      return;
    }
    if (nowPlayingNotifier.value == null) {
      print("No song in notifier to play/pause.");
      return;
    }

    if (globalAudioPlayer.playing) {
      globalAudioPlayer.pause();
    } else {
      // اگر آهنگ تمام شده بود، از اول شروع کن
      if (globalAudioPlayer.processingState == ProcessingState.completed) {
        globalAudioPlayer.seek(Duration.zero).then((_) {
          globalAudioPlayer.play();
        });
      } else {
        globalAudioPlayer.play();
      }
    }
    // Listener مربوط به playerStateStream باید nowPlayingNotifier.value.isPlaying را آپدیت کند
  }

  void _miniPlayerNext() {
    print("_miniPlayerNext called by user.");
    _handleSongCompletion();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget>? currentActions;
    if (_selectedIndex == 0) {
      currentActions = [
        IconButton(icon: const Icon(Icons.favorite_border_outlined), tooltip: "Favorites",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const FavoritesScreen()))
                  .then((_) => homeScreenKey.currentState?.refreshDataOnReturn());
            }),
        IconButton(icon: const Icon(Icons.sort), tooltip: "Sort My Music",
            onPressed: () => _showSortOptionsDialog(context, "My Music", (criteria) => homeScreenKey.currentState?.sortMusic(criteria))),
        IconButton(icon: const Icon(Icons.refresh), tooltip: "Refresh My Music",
            onPressed: () => homeScreenKey.currentState?.scrollToTopAndRefresh()),
      ];
    } else if (_selectedIndex == 3) {
      currentActions = [
        IconButton(icon: const Icon(Icons.sort), tooltip: "Sort Local Music",
            onPressed: () => _showSortOptionsDialog(context, "Local Music", (criteria) => localMusicScreenKey.currentState?.sortMusic(criteria))),
        IconButton(icon: const Icon(Icons.refresh), tooltip: "Refresh Local Music",
            onPressed: () => localMusicScreenKey.currentState?.scrollToTopAndRefresh()),
      ];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitles[_selectedIndex]),
        automaticallyImplyLeading: false,
        actions: currentActions,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomSheet: ValueListenableBuilder<NowPlayingModel?>(
        valueListenable: nowPlayingNotifier,
        builder: (context, nowPlaying, child) {
          if (nowPlaying == null || nowPlaying.song.audioUrl.isEmpty) { // اگر URL خالی بود هم نشان نده
            return const SizedBox.shrink();
          }
          final song = nowPlaying.song;
          final isPlaying = nowPlaying.isPlaying;
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          bool canGoNext = false;
          if (nowPlaying.currentPlaylist.isNotEmpty) {
            if (globalAudioPlayer.shuffleModeEnabled && nowPlaying.currentPlaylist.length > 1) {
              canGoNext = true;
            } else {
              canGoNext = nowPlaying.currentIndexInPlaylist < nowPlaying.currentPlaylist.length - 1 ||
                  (globalAudioPlayer.loopMode == LoopMode.all && nowPlaying.currentPlaylist.isNotEmpty);
            }
          }

          Widget coverArtWidget;
          if (song.coverImagePath != null && song.coverImagePath!.isNotEmpty) {
            coverArtWidget = Image.asset(
              song.coverImagePath!, width: 48, height: 48, fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: colorScheme.onSurface.withOpacity(0.1)), child: Icon(Icons.music_note, color: colorScheme.onSurface.withOpacity(0.4), size: 24)),
            );
          } else {
            coverArtWidget = Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: colorScheme.onSurface.withOpacity(0.1)), child: Icon(Icons.music_note, color: colorScheme.onSurface.withOpacity(0.4), size: 24));
          }

          return Material(
            elevation: 8.0,
            color: theme.bottomNavigationBarTheme.backgroundColor ?? colorScheme.surface,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SongDetailScreen(
                      initialSong: song,
                      songList: nowPlaying.currentPlaylist,
                      initialIndex: nowPlaying.currentIndexInPlaylist,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                height: 65.0,
                child: Row(
                  children: [
                    ClipOval(child: coverArtWidget),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(song.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500, color: colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(song.artist, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 32, color: colorScheme.primary),
                      onPressed: _miniPlayerPlayPause,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.skip_next_rounded,
                        size: 32,
                        color: canGoNext ? colorScheme.primary.withOpacity(0.9) : colorScheme.onSurface.withOpacity(0.5),
                      ),
                      onPressed: canGoNext ? _miniPlayerNext : null,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: "Next",
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.library_music_outlined), activeIcon: Icon(Icons.library_music), label: 'My Music'),
          BottomNavigationBarItem(icon: Icon(Icons.store_outlined), activeIcon: Icon(Icons.store), label: 'Shop'),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle_outlined), activeIcon: Icon(Icons.account_circle), label: 'Account'),
          BottomNavigationBarItem(icon: Icon(Icons.folder_special_outlined), activeIcon: Icon(Icons.folder_special), label: 'Local'),
        ],
      ),
    );
  }

  Future<void> _showSortOptionsDialog(BuildContext context, String tabName, Function(String) onSortSelected) async {
    final String? selectedCriteria = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text('Sort $tabName by'),
          children: <Widget>[
            SimpleDialogOption(onPressed: () => Navigator.pop(context, 'title_asc'), child: const Text('Title (A-Z)')),
            SimpleDialogOption(onPressed: () => Navigator.pop(context, 'title_desc'), child: const Text('Title (Z-A)')),
            SimpleDialogOption(onPressed: () => Navigator.pop(context, 'artist_asc'), child: const Text('Artist (A-Z)')),
            SimpleDialogOption(onPressed: () => Navigator.pop(context, 'artist_desc'), child: const Text('Artist (Z-A)')),
          ],
        );
      },
    );
    if (selectedCriteria != null) {
      onSortSelected(selectedCriteria);
    }
  }
}