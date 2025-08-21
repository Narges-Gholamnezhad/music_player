// lib/main_tabs_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'song_model.dart';
import 'now_playing_model.dart';
import 'song_detail_screen.dart';
import 'home_screen.dart';
import 'user_profile_screen.dart';
import 'music_shop_screen.dart';
import 'local_music_screen.dart';
import 'favorites_screen.dart';

final GlobalKey<HomeScreenState> homeScreenKey = GlobalKey<HomeScreenState>();
final GlobalKey<LocalMusicScreenState> localMusicScreenKey =
    GlobalKey<LocalMusicScreenState>();

final AudioPlayer globalAudioPlayer = AudioPlayer();
final ValueNotifier<NowPlayingModel?> nowPlayingNotifier = ValueNotifier(null);

class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({super.key});

  static Future<void> playNewSongInGlobalPlayer(
      Song song, List<Song> playlist, int index,
      {bool autoPlay = true}) async {
    final String methodTag = "MainTabsScreen.playNewSongInGlobalPlayer";
    print(
        "$methodTag: Play Request - Song: '${song.title}' (UID: ${song.uniqueIdentifier}), Index: $index, Playlist size: ${playlist.length}, AutoPlay: $autoPlay, URL: ${song.audioUrl}");

    if (playlist.isEmpty || index < 0 || index >= playlist.length) {
      print("$methodTag: Error - Invalid playlist/index. Stopping player.");
      try {
        await globalAudioPlayer.stop();
      } catch (e) {
        print("$methodTag: Error stopping player: $e");
      }
      nowPlayingNotifier.value = null;
      return;
    }
    if (song.audioUrl.isEmpty) {
      print("$methodTag: Error - audioUrl for '${song.title}' is empty.");
      final currentModel = nowPlayingNotifier.value;
      if (currentModel != null &&
          currentModel.song.uniqueIdentifier == song.uniqueIdentifier) {
        nowPlayingNotifier.value = currentModel.copyWith(isPlaying: false);
      }
      return;
    }

    try {
      final currentModel = nowPlayingNotifier.value;
      if (currentModel != null &&
          currentModel.song.uniqueIdentifier == song.uniqueIdentifier) {
        if (autoPlay && !globalAudioPlayer.playing) {
          await globalAudioPlayer.play();
        } else if (!autoPlay && globalAudioPlayer.playing) {
          await globalAudioPlayer.pause();
        }
        nowPlayingNotifier.value = currentModel.copyWith(
            currentPlaylist: playlist,
            currentIndexInPlaylist: index,
            isPlaying: autoPlay ? globalAudioPlayer.playing : false);
        return;
      }

      await globalAudioPlayer.stop();
      await globalAudioPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(song.audioUrl), tag: song.uniqueIdentifier),
        initialPosition: Duration.zero,
      );
      nowPlayingNotifier.value = NowPlayingModel(
        song: song,
        audioPlayer: globalAudioPlayer,
        isPlaying: autoPlay,
        currentPlaylist: playlist,
        currentIndexInPlaylist: index,
      );
      if (autoPlay) {
        await globalAudioPlayer.play();
      } else {
        if (nowPlayingNotifier.value != null &&
            nowPlayingNotifier.value!.isPlaying) {
          nowPlayingNotifier.value =
              nowPlayingNotifier.value!.copyWith(isPlaying: false);
        }
      }
    } catch (e, s) {
      print(
          "$methodTag: !!! CRITICAL ERROR for '${song.title}': $e\nStack: $s");
      try {
        await globalAudioPlayer.stop();
      } catch (_) {}
      if (playlist.isNotEmpty && index >= 0 && index < playlist.length) {
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
    _appBarTitles = <String>[
      'My Music',
      'Music Shop',
      'Account',
      'Local Music'
    ];

    _playerStateSubscription =
        globalAudioPlayer.playerStateStream.listen((playerState) {
      final currentModel = nowPlayingNotifier.value;
      if (currentModel != null && mounted) {
        if (currentModel.isPlaying != playerState.playing) {
          nowPlayingNotifier.value =
              currentModel.copyWith(isPlaying: playerState.playing);
        }
        if (playerState.processingState == ProcessingState.idle &&
            playerState.playing) {
          nowPlayingNotifier.value = currentModel.copyWith(isPlaying: false);
        }
      }
    });

    _processingStateSubscription =
        globalAudioPlayer.processingStateStream.listen((processingState) {
      final currentModel = nowPlayingNotifier.value;
      if (currentModel == null) return;
      if (processingState == ProcessingState.completed) {
        if (globalAudioPlayer.loopMode != LoopMode.one) {
          _handleSongCompletion();
        } else {
          if (mounted && !currentModel.isPlaying && globalAudioPlayer.playing) {
            nowPlayingNotifier.value = currentModel.copyWith(isPlaying: true);
          }
        }
      } else if (processingState == ProcessingState.idle &&
          globalAudioPlayer.audioSource != null) {
        if (currentModel.isPlaying && mounted) {
          nowPlayingNotifier.value = currentModel.copyWith(isPlaying: false);
        }
      }
    });
  }

  void _handleSongCompletion() {
    final currentModel = nowPlayingNotifier.value;
    if (currentModel == null || currentModel.currentPlaylist.isEmpty) {
      globalAudioPlayer.stop().catchError((_) {});
      if (currentModel != null && mounted)
        nowPlayingNotifier.value = currentModel.copyWith(isPlaying: false);
      return;
    }
    List<Song> playlist = currentModel.currentPlaylist;
    int currentIndex = currentModel.currentIndexInPlaylist;
    if (currentIndex < 0 || currentIndex >= playlist.length) {
      if (playlist.isNotEmpty)
        MainTabsScreen.playNewSongInGlobalPlayer(playlist[0], playlist, 0,
            autoPlay: true);
      else {
        globalAudioPlayer.stop().catchError((_) {});
        if (mounted)
          nowPlayingNotifier.value = currentModel.copyWith(
              isPlaying: false, currentPlaylist: [], currentIndexInPlaylist: 0);
      }
      return;
    }
    int nextIndex;
    if (globalAudioPlayer.shuffleModeEnabled && playlist.length > 1) {
      var availableIndices = List<int>.generate(playlist.length, (i) => i)
        ..remove(currentIndex);
      if (availableIndices.isEmpty) {
        if (globalAudioPlayer.loopMode == LoopMode.all && playlist.isNotEmpty) {
          availableIndices = List<int>.generate(playlist.length, (i) => i);
          availableIndices.shuffle(Random());
          nextIndex = availableIndices.first;
        } else {
          globalAudioPlayer.pause();
          globalAudioPlayer.seek(Duration.zero);
          if (mounted)
            nowPlayingNotifier.value = currentModel.copyWith(isPlaying: false);
          return;
        }
      } else {
        availableIndices.shuffle(Random());
        nextIndex = availableIndices.first;
      }
    } else {
      nextIndex = currentIndex + 1;
    }
    if (nextIndex < playlist.length) {
      MainTabsScreen.playNewSongInGlobalPlayer(
          playlist[nextIndex], playlist, nextIndex,
          autoPlay: true);
    } else {
      if (globalAudioPlayer.loopMode == LoopMode.all && playlist.isNotEmpty) {
        MainTabsScreen.playNewSongInGlobalPlayer(playlist[0], playlist, 0,
            autoPlay: true);
      } else {
        globalAudioPlayer.pause();
        globalAudioPlayer.seek(Duration.zero);
        if (mounted && nowPlayingNotifier.value != null) {
          nowPlayingNotifier.value =
              nowPlayingNotifier.value!.copyWith(isPlaying: false);
        }
      }
    }
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _processingStateSubscription?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (!mounted) return;
    if (_selectedIndex == index) {
      if (index == 0 && homeScreenKey.currentState != null)
        homeScreenKey.currentState!.scrollToTopAndRefresh();
      else if (index == 3 && localMusicScreenKey.currentState != null)
        localMusicScreenKey.currentState!.scrollToTopAndRefresh();
    }
    setState(() => _selectedIndex = index);
  }

  void _miniPlayerPlayPause() {
    final currentModel = nowPlayingNotifier.value;
    if (currentModel == null) return;
    if (globalAudioPlayer.playing) {
      globalAudioPlayer.pause();
    } else {
      if (globalAudioPlayer.processingState == ProcessingState.completed) {
        globalAudioPlayer
            .seek(Duration.zero)
            .then((_) => globalAudioPlayer.play());
      } else if (globalAudioPlayer.audioSource != null) {
        globalAudioPlayer.play();
      } else if (currentModel.song.audioUrl.isNotEmpty) {
        MainTabsScreen.playNewSongInGlobalPlayer(currentModel.song,
            currentModel.currentPlaylist, currentModel.currentIndexInPlaylist,
            autoPlay: true);
      }
    }
  }

  void _miniPlayerNext() {
    _handleSongCompletion();
  }

  // متد برای نمایش دیالوگ سورت با گزینه‌های تاریخ
  Future<void> _showSortOptionsDialog(BuildContext context, String tabName,
      Function(String) onSortSelected) async {
    final String? selectedCriteria = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        List<Widget> options = [
          SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'title_asc'),
              child: const Text('Title (A-Z)')),
          SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'title_desc'),
              child: const Text('Title (Z-A)')),
          SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'artist_asc'),
              child: const Text('Artist (A-Z)')),
          SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'artist_desc'),
              child: const Text('Artist (Z-A)')),
        ];
        // گزینه‌های تاریخ فقط برای تب‌های مربوطه
        if (tabName == "My Music" ||
            tabName == "Local Music" ||
            tabName == "Favorites") {
          options.addAll([
            SimpleDialogOption(
                onPressed: () => Navigator.pop(context, 'date_desc'),
                child: const Text('Date Added (Newest First)')),
            SimpleDialogOption(
                onPressed: () => Navigator.pop(context, 'date_asc'),
                child: const Text('Date Added (Oldest First)')),
          ]);
        }
        // برای Music Shop می‌توان گزینه‌های سورت قیمت، امتیاز و ... را اضافه کرد
        if (tabName == "Music Shop Category") {
          // فرض می‌کنیم نام تب برای لیست آهنگ‌های فروشگاه این است
          options.addAll([
            SimpleDialogOption(
                onPressed: () => Navigator.pop(context, 'price_asc'),
                child: const Text('Price (Low to High)')),
            SimpleDialogOption(
                onPressed: () => Navigator.pop(context, 'price_desc'),
                child: const Text('Price (High to Low)')),
            SimpleDialogOption(
                onPressed: () => Navigator.pop(context, 'rating_desc'),
                child: const Text('Rating (Highest First)')),
          ]);
        }

        return SimpleDialog(
          title: Text('Sort $tabName by'),
          children: options,
        );
      },
    );
    if (selectedCriteria != null) {
      onSortSelected(selectedCriteria);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget>? currentActions;
    if (_selectedIndex == 0) {
      // My Music (HomeScreen)
      currentActions = [
        IconButton(
            icon: const Icon(Icons.favorite_border_outlined),
            tooltip: "Favorites",
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const FavoritesScreen())).then(
                  (_) => homeScreenKey.currentState?.refreshDataOnReturn());
            }),
        IconButton(
            icon: const Icon(Icons.sort),
            tooltip: "Sort My Music",
            onPressed: () => _showSortOptionsDialog(context, "My Music",
                (criteria) => homeScreenKey.currentState?.sortMusic(criteria))),
        IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh My Music",
            onPressed: () =>
                homeScreenKey.currentState?.scrollToTopAndRefresh()),
      ];
    } else if (_selectedIndex == 3) {
      // Local Music (LocalMusicScreen)
      currentActions = [
        // برای LocalMusicScreen هم می‌توانید دکمه علاقه‌مندی‌ها را بگذارید اگر لازم است
        IconButton(
            icon: const Icon(Icons.sort),
            tooltip: "Sort Local Music",
            onPressed: () => _showSortOptionsDialog(
                context,
                "Local Music",
                (criteria) =>
                    localMusicScreenKey.currentState?.sortMusic(criteria))),
        IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Local Music",
            onPressed: () =>
                localMusicScreenKey.currentState?.scrollToTopAndRefresh()),
      ];
    }
    // برای سایر تب‌ها (Music Shop, Account) فعلا action خاصی در AppBar تعریف نشده.
    // برای FavoritesScreen، دکمه سورت داخل خود آن صفحه است.

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
          // ... (کد bottomSheet دقیقا مثل قبل، بدون تغییر)
          if (nowPlaying == null || nowPlaying.song.audioUrl.isEmpty) {
            return const SizedBox.shrink();
          }
          final song = nowPlaying.song;
          final isPlaying = nowPlaying.isPlaying;
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          bool canGoNext = false;
          if (nowPlaying.currentPlaylist.isNotEmpty) {
            if (globalAudioPlayer.shuffleModeEnabled &&
                nowPlaying.currentPlaylist.length > 1) {
              canGoNext = true;
            } else {
              canGoNext = nowPlaying.currentIndexInPlaylist <
                      nowPlaying.currentPlaylist.length - 1 ||
                  (globalAudioPlayer.loopMode == LoopMode.all &&
                      nowPlaying.currentPlaylist.isNotEmpty);
            }
          }

          Widget coverArtWidget;
          if (song.isLocal &&
              song.mediaStoreId != null &&
              song.mediaStoreId! > 0) {
            coverArtWidget = QueryArtworkWidget(
              id: song.mediaStoreId!,
              type: ArtworkType.AUDIO,
              artworkWidth: 48,
              artworkHeight: 48,
              artworkFit: BoxFit.cover,
              artworkClipBehavior: Clip.antiAlias,
              nullArtworkWidget: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.onSurface.withOpacity(0.1)),
                  child: Icon(Icons.music_note,
                      color: colorScheme.onSurface.withOpacity(0.4), size: 24)),
            );
          } else if (song.coverImagePath != null &&
              song.coverImagePath!.isNotEmpty) {
            coverArtWidget = Image.asset(
              song.coverImagePath!,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.onSurface.withOpacity(0.1)),
                  child: Icon(Icons.music_note,
                      color: colorScheme.onSurface.withOpacity(0.4), size: 24)),
            );
          } else {
            coverArtWidget = Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.onSurface.withOpacity(0.1)),
                child: Icon(Icons.music_note,
                    color: colorScheme.onSurface.withOpacity(0.4), size: 24));
          }

          return Material(
            elevation: 8.0,
            color: theme.bottomNavigationBarTheme.backgroundColor ??
                colorScheme.surface,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => SongDetailScreen(
                      initialSong: song,
                      songList: nowPlaying.currentPlaylist,
                      initialIndex: nowPlaying.currentIndexInPlaylist,
                    ),
                  ),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
                          Text(song.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(song.artist,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      colorScheme.onSurface.withOpacity(0.7)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 32,
                          color: colorScheme.primary),
                      onPressed: _miniPlayerPlayPause,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.skip_next_rounded,
                        size: 32,
                        color: canGoNext
                            ? colorScheme.primary.withOpacity(0.9)
                            : colorScheme.onSurface.withOpacity(0.35),
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
          BottomNavigationBarItem(
              icon: Icon(Icons.library_music_outlined),
              activeIcon: Icon(Icons.library_music),
              label: 'My Music'),
          BottomNavigationBarItem(
              icon: Icon(Icons.store_outlined),
              activeIcon: Icon(Icons.store),
              label: 'Shop'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_circle_outlined),
              activeIcon: Icon(Icons.account_circle),
              label: 'Account'),
          BottomNavigationBarItem(
              icon: Icon(Icons.folder_special_outlined),
              activeIcon: Icon(Icons.folder_special),
              label: 'Local'),
        ],
      ),
    );
  }
}
