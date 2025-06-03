// lib/main_tabs_screen.dart
import 'dart:async';
import 'dart:math'; // برای Random در shuffle
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart'; // برای کاور آهنگ در mini player
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
    final String methodTag = "MainTabsScreen.playNewSongInGlobalPlayer";
    print(
        "$methodTag: Play Request - Song: '${song.title}' (UID: ${song.uniqueIdentifier}), Index: $index, Playlist size: ${playlist.length}, AutoPlay: $autoPlay, URL: ${song.audioUrl}");

    if (playlist.isEmpty || index < 0 || index >= playlist.length) {
      print(
          "$methodTag: Error - Invalid playlist/index. Playlist empty: ${playlist.isEmpty}, index: $index, playlist length: ${playlist.length}. Stopping player.");
      try {
        await globalAudioPlayer.stop();
      } catch (e) {
        print("$methodTag: Error stopping player on invalid playlist: $e");
      }
      nowPlayingNotifier.value = null;
      return;
    }

    if (song.audioUrl.isEmpty) {
      print("$methodTag: Error - audioUrl for '${song.title}' is empty. Playback cannot proceed.");
      final currentModel = nowPlayingNotifier.value;
      if (currentModel != null && currentModel.song.uniqueIdentifier == song.uniqueIdentifier) {
        nowPlayingNotifier.value = currentModel.copyWith(isPlaying: false);
      }
      return;
    }

    try {
      final currentModel = nowPlayingNotifier.value;
      final bool isCurrentlyPlayingThisSong = currentModel != null &&
          currentModel.song.uniqueIdentifier == song.uniqueIdentifier &&
          globalAudioPlayer.playing;

      // اگر آهنگ درخواستی همان آهنگ فعلی در Notifier است و URL هم یکی است
      if (currentModel != null && currentModel.song.uniqueIdentifier == song.uniqueIdentifier) {
        print("$methodTag: Requested song ('${song.title}') is the same as current in notifier.");
        // فقط وضعیت پخش را بر اساس autoPlay تنظیم کن، اگر لازم است
        if (autoPlay && !globalAudioPlayer.playing) {
          await globalAudioPlayer.play();
          print("$methodTag: Played same song (was paused).");
        } else if (!autoPlay && globalAudioPlayer.playing) {
          await globalAudioPlayer.pause();
          print("$methodTag: Paused same song (autoPlay was false).");
        }
        // اطمینان از اینکه Notifier لیست پخش و ایندکس صحیح را دارد
        nowPlayingNotifier.value = currentModel.copyWith(
            currentPlaylist: playlist,
            currentIndexInPlaylist: index,
            isPlaying: autoPlay ? globalAudioPlayer.playing : false // وضعیت پخش را مجددا از پلیر بگیر یا اگر autoPlay false است، false کن
        );
        print("$methodTag: Notifier updated for same song. isPlaying: ${nowPlayingNotifier.value?.isPlaying}");
        return;
      }

      // آهنگ جدید است یا context (پلی‌لیست/ایندکس) تغییر کرده
      print("$methodTag: New song ('${song.title}') or new context. Stopping previous source if any.");
      await globalAudioPlayer.stop(); // مهم: همیشه قبل از setAudioSource جدید، stop کنید

      print("$methodTag: Setting audio source for '${song.title}' with URL: ${song.audioUrl}");
      await globalAudioPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(song.audioUrl), tag: song.uniqueIdentifier), // از uniqueIdentifier به عنوان tag استفاده شود بهتر است
        initialPosition: Duration.zero,
        // preload: true, // می‌توان فعال کرد اگر باعث بهبود تجربه کاربری شود
      );
      print("$methodTag: Audio source set for '${song.title}'.");

      // آپدیت Notifier با آهنگ جدید و وضعیت پخش بر اساس autoPlay
      nowPlayingNotifier.value = NowPlayingModel(
        song: song,
        audioPlayer: globalAudioPlayer,
        isPlaying: autoPlay, // مقدار اولیه، Listener وضعیت واقعی را بعدا آپدیت می‌کند
        currentPlaylist: playlist,
        currentIndexInPlaylist: index,
      );
      print("$methodTag: Notifier set for new song '${song.title}'. isPlaying (initial): ${nowPlayingNotifier.value?.isPlaying}");

      if (autoPlay) {
        await globalAudioPlayer.play();
        print("$methodTag: Commanded to play new song '${song.title}'. Player.playing: ${globalAudioPlayer.playing}");
      } else {
        // اگر autoPlay false است و notifier به اشتباه isPlaying:true دارد، اصلاحش کن
        if (nowPlayingNotifier.value != null && nowPlayingNotifier.value!.isPlaying) {
          nowPlayingNotifier.value = nowPlayingNotifier.value!.copyWith(isPlaying: false);
        }
        print("$methodTag: AutoPlay is false for '${song.title}', player will not start automatically.");
      }

    } catch (e, s) {
      print("$methodTag: !!! CRITICAL ERROR for '${song.title}': $e\nStack: $s");
      try {
        await globalAudioPlayer.stop();
      } catch (e2) {
        print("$methodTag: Error stopping player in catch block: $e2");
      }
      // سعی کن Notifier را در یک وضعیت پایدار قرار دهی
      if (playlist.isNotEmpty && index >= 0 && index < playlist.length) {
        nowPlayingNotifier.value = NowPlayingModel(
          song: playlist[index], // آهنگ مشکل‌دار
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
  // StreamSubscription<int?>? _currentIndexSubscription; // برای دنبال کردن تغییر ایندکس در sequence

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
        // فقط اگر وضعیت پخش در مدل با وضعیت واقعی پلیر متفاوت است، آپدیت کن
        if (currentModel.isPlaying != playerState.playing) {
          print("MainTabsScreen Listener (PlayerState): Player.playing changed to ${playerState.playing}. Updating notifier for '${currentModel.song.title}'.");
          nowPlayingNotifier.value = currentModel.copyWith(isPlaying: playerState.playing);
        }
        // اگر processingState هم idle شده و پلیر در حال پخش نیست، isPlaying باید false باشد
        if (playerState.processingState == ProcessingState.idle && playerState.playing) {
          print("MainTabsScreen Listener (PlayerState): Player is idle but model says playing. Correcting.");
          nowPlayingNotifier.value = currentModel.copyWith(isPlaying: false);
        }
      }
    });

    _processingStateSubscription = globalAudioPlayer.processingStateStream.listen((processingState) {
      final currentModel = nowPlayingNotifier.value;
      print("MainTabsScreen Listener (ProcessingState): $processingState for song: ${currentModel?.song.title}");

      if (currentModel == null) {
        print("MainTabsScreen Listener (ProcessingState): No current model in notifier.");
        return;
      }

      if (processingState == ProcessingState.completed) {
        print("MainTabsScreen Listener (ProcessingState): Song '${currentModel.song.title}' completed. Loop mode: ${globalAudioPlayer.loopMode}, Shuffle: ${globalAudioPlayer.shuffleModeEnabled}");
        if (globalAudioPlayer.loopMode != LoopMode.one) { // LoopMode.one توسط خود just_audio هندل می‌شود
          _handleSongCompletion();
        } else {
          // در LoopMode.one، آهنگ باید خودکار دوباره شروع شود.
          // فقط اطمینان حاصل می‌کنیم که isPlaying در Notifier درست است.
          if (mounted && !currentModel.isPlaying && globalAudioPlayer.playing) {
            nowPlayingNotifier.value = currentModel.copyWith(isPlaying: true);
          }
        }
      } else if (processingState == ProcessingState.idle && globalAudioPlayer.audioSource != null) {
        // اگر مدل می‌گوید در حال پخش است اما پلیر idle شده، وضعیت را اصلاح کن
        if (currentModel.isPlaying && mounted) {
          print("MainTabsScreen Listener (ProcessingState): Player is idle but model says playing. Correcting to false.");
          nowPlayingNotifier.value = currentModel.copyWith(isPlaying: false);
        }
      }
    });

    // _currentIndexSubscription = globalAudioPlayer.currentIndexStream.listen((index) {
    //   final currentModel = nowPlayingNotifier.value;
    //   if (currentModel != null && index != null && index != currentModel.currentIndexInPlaylist && mounted) {
    //     if (index < currentModel.currentPlaylist.length) {
    //       print("MainTabsScreen Listener (CurrentIndex): Player index changed to $index. Updating notifier.");
    //       // این حالت بیشتر زمانی رخ می‌دهد که از sequence استفاده کنیم.
    //       // با روش فعلی که هر بار setAudioSource می‌کنیم، این stream کمتر کاربرد دارد.
    //       // اما برای اطمینان می‌توان آن را نگه داشت.
    //       final newSong = currentModel.currentPlaylist[index];
    //       nowPlayingNotifier.value = currentModel.copyWith(
    //         song: newSong,
    //         currentIndexInPlaylist: index,
    //         // isPlaying باید از playerStateStream بیاید
    //       );
    //     }
    //   }
    // });

    print("MainTabsScreen: initState finished, global player listeners set up.");
  }

  void _handleSongCompletion() {
    final String methodTag = "MainTabsScreen._handleSongCompletion";
    print("$methodTag: Called. Current song: ${nowPlayingNotifier.value?.song.title}");
    final currentModel = nowPlayingNotifier.value;

    if (currentModel == null) {
      print("$methodTag: Error - currentModel is null.");
      globalAudioPlayer.stop().catchError((e) => print("$methodTag: Error stopping player: $e"));
      return;
    }
    if (currentModel.currentPlaylist.isEmpty) {
      print("$methodTag: Warning - currentPlaylist is empty. Pausing and seeking to zero.");
      globalAudioPlayer.pause();
      globalAudioPlayer.seek(Duration.zero);
      if (mounted) { // فقط اگر mounted است، notifier را آپدیت کن
        nowPlayingNotifier.value = currentModel.copyWith(isPlaying: false);
      }
      return;
    }

    List<Song> playlist = currentModel.currentPlaylist;
    int currentIndex = currentModel.currentIndexInPlaylist;

    if (currentIndex < 0 || currentIndex >= playlist.length) {
      print("$methodTag: Error - Invalid currentIndex ($currentIndex) for playlist length (${playlist.length}). Playing first song or stopping.");
      if (playlist.isNotEmpty) {
        MainTabsScreen.playNewSongInGlobalPlayer(playlist[0], playlist, 0, autoPlay: true);
      } else {
        globalAudioPlayer.stop().catchError((e) => print("$methodTag: Error stopping player: $e"));
        if (mounted) {
          nowPlayingNotifier.value = currentModel.copyWith(isPlaying: false, currentPlaylist: [], currentIndexInPlaylist: 0);
        }
      }
      return;
    }

    int nextIndex;
    if (globalAudioPlayer.shuffleModeEnabled && playlist.length > 1) {
      var availableIndices = List<int>.generate(playlist.length, (i) => i)..remove(currentIndex);
      if (availableIndices.isEmpty) {
        // این حالت زمانی است که فقط یک آهنگ در پلی‌لیست است اما شافل فعال است.
        // یا وقتی به آخرین آهنگ در حالت شافل رسیده‌ایم و لوپ فعال نیست.
        if (globalAudioPlayer.loopMode == LoopMode.all && playlist.isNotEmpty) {
          // اگر لوپ فعال است، یک آهنگ تصادفی دیگر از ابتدا انتخاب کن (می‌تواند خودش هم باشد)
          availableIndices = List<int>.generate(playlist.length, (i) => i);
          availableIndices.shuffle(Random());
          nextIndex = availableIndices.first;
          print("$methodTag: Shuffle & Loop all - playlist exhausted or single song, picking random from start: $nextIndex");
        } else {
          print("$methodTag: Shuffle & No loop - playlist exhausted. Stopping.");
          globalAudioPlayer.pause();
          globalAudioPlayer.seek(Duration.zero);
          if (mounted) {
            nowPlayingNotifier.value = currentModel.copyWith(isPlaying: false);
          }
          return;
        }
      } else {
        availableIndices.shuffle(Random());
        nextIndex = availableIndices.first;
      }
      print("$methodTag: Shuffle next index: $nextIndex for song: '${playlist[nextIndex].title}'");
    } else { // Sequential
      nextIndex = currentIndex + 1;
      print("$methodTag: Sequential next index: $nextIndex");
    }

    if (nextIndex < playlist.length) {
      MainTabsScreen.playNewSongInGlobalPlayer(playlist[nextIndex], playlist, nextIndex, autoPlay: true);
    } else { // Reached end of playlist (sequentially)
      if (globalAudioPlayer.loopMode == LoopMode.all && playlist.isNotEmpty) {
        print("$methodTag: Sequential & Loop all - playing first song from playlist.");
        MainTabsScreen.playNewSongInGlobalPlayer(playlist[0], playlist, 0, autoPlay: true);
      } else {
        print("$methodTag: Sequential & No loop - reached end of playlist. Playback stopped.");
        globalAudioPlayer.pause();
        globalAudioPlayer.seek(Duration.zero);
        if (mounted && nowPlayingNotifier.value != null) {
          nowPlayingNotifier.value = nowPlayingNotifier.value!.copyWith(isPlaying: false);
        }
      }
    }
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _processingStateSubscription?.cancel();
    // _currentIndexSubscription?.cancel();
    // globalAudioPlayer.dispose(); // معمولا در dispose اپلیکیشن انجام می‌شود اگر این آخرین صفحه باشد
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (!mounted) return;
    if (_selectedIndex == index) {
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
    final String methodTag = "MainTabsScreen._miniPlayerPlayPause";
    print("$methodTag: Called. Notifier: ${nowPlayingNotifier.value?.song.title}, Player.isPlaying: ${globalAudioPlayer.playing}, Notifier.isPlaying: ${nowPlayingNotifier.value?.isPlaying}");

    final currentModel = nowPlayingNotifier.value;
    if (currentModel == null) {
      print("$methodTag: No song in notifier to play/pause.");
      // اگر به دلایلی audioSource وجود دارد اما notifier نال است، سعی در پخش نکنید چون اطلاعات آهنگ را نداریم.
      // این حالت باید با مدیریت صحیح playNewSongInGlobalPlayer کمتر رخ دهد.
      return;
    }

    if (globalAudioPlayer.playing) {
      globalAudioPlayer.pause();
    } else {
      if (globalAudioPlayer.processingState == ProcessingState.completed) {
        globalAudioPlayer.seek(Duration.zero).then((_) {
          globalAudioPlayer.play();
        });
      } else if (globalAudioPlayer.audioSource != null) { // فقط اگر منبع صوتی وجود دارد play کن
        globalAudioPlayer.play();
      } else {
        print("$methodTag: Cannot play, no audio source set in player.");
        // اگر منبع صوتی نیست، سعی کن آهنگ فعلی در Notifier را دوباره پلی کنی (اگر URL معتبر دارد)
        if (currentModel.song.audioUrl.isNotEmpty) {
          MainTabsScreen.playNewSongInGlobalPlayer(
              currentModel.song,
              currentModel.currentPlaylist,
              currentModel.currentIndexInPlaylist,
              autoPlay: true
          );
        }
      }
    }
    // Listener مربوط به playerStateStream باید nowPlayingNotifier.value.isPlaying را آپدیت کند
  }

  void _miniPlayerNext() {
    print("MainTabsScreen._miniPlayerNext: Called by user.");
    // به جای فراخوانی مستقیم _handleSongCompletion،
    // از منطق next در SongDetailScreen استفاده می‌کنیم تا شبیه آن باشد
    // یا مطمئن شویم _handleSongCompletion همین کار را می‌کند.
    // فراخوانی _handleSongCompletion در اینجا صحیح است چون منطق next را دارد.
    _handleSongCompletion();
  }

  @override
  Widget build(BuildContext context) {
    // ... (بقیه کد build تقریبا بدون تغییر باقی می‌ماند)
    // فقط در بخش mini player، برای نمایش کاور، از QueryArtworkWidget اگر آهنگ محلی است استفاده کنید:
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
          if (nowPlaying == null || nowPlaying.song.audioUrl.isEmpty) {
            return const SizedBox.shrink();
          }
          final song = nowPlaying.song;
          final isPlaying = nowPlaying.isPlaying; // از مدل بگیر
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          bool canGoNext = false;
          if (nowPlaying.currentPlaylist.isNotEmpty) {
            if (globalAudioPlayer.shuffleModeEnabled && nowPlaying.currentPlaylist.length > 1) {
              // در حالت شافل، اگر بیش از یک آهنگ در لیست باشد، همیشه می‌توان به "بعدی" (تصادفی) رفت
              // مگر اینکه لوپ خاموش باشد و به نحوی تمام آهنگ‌های شافل شده پخش شده باشند (که هندل کردنش پیچیده است)
              // ساده‌تر: اگر شافل است و بیش از یک آهنگ هست، دکمه next فعال باشد.
              canGoNext = true;
            } else { // حالت ترتیبی
              canGoNext = nowPlaying.currentIndexInPlaylist < nowPlaying.currentPlaylist.length - 1 ||
                  (globalAudioPlayer.loopMode == LoopMode.all && nowPlaying.currentPlaylist.isNotEmpty);
            }
          }

          Widget coverArtWidget;
          if (song.isLocal && song.mediaStoreId != null && song.mediaStoreId! > 0) {
            coverArtWidget = QueryArtworkWidget(
              id: song.mediaStoreId!,
              type: ArtworkType.AUDIO,
              artworkWidth: 48, artworkHeight: 48, artworkFit: BoxFit.cover, artworkClipBehavior: Clip.antiAlias,
              nullArtworkWidget: Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: colorScheme.onSurface.withOpacity(0.1)), child: Icon(Icons.music_note, color: colorScheme.onSurface.withOpacity(0.4), size: 24)),
            );
          } else if (song.coverImagePath != null && song.coverImagePath!.isNotEmpty) {
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
                // اطمینان از اینکه context صحیح به SongDetailScreen ارسال می‌شود
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => SongDetailScreen( // استفاده از ctx جدید
                      initialSong: song,
                      songList: nowPlaying.currentPlaylist,
                      initialIndex: nowPlaying.currentIndexInPlaylist,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                height: 65.0, // ارتفاع استاندارد bottom sheet
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
                    const SizedBox(width: 8), // کمی فاصله
                    IconButton(
                      icon: Icon(
                        Icons.skip_next_rounded,
                        size: 32,
                        color: canGoNext ? colorScheme.primary.withOpacity(0.9) : colorScheme.onSurface.withOpacity(0.35), // کم‌رنگ‌تر اگر غیرفعال است
                      ),
                      onPressed: canGoNext ? _miniPlayerNext : null, // غیرفعال کردن اگر نمی‌توان به بعدی رفت
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
        // ... (کد bottomNavigationBar مثل قبل)
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // یا هر نوعی که استفاده می‌کنید
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
    // ... (کد _showSortOptionsDialog مثل قبل)
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
            // می‌توانید گزینه‌های بیشتر امتیازی را اینجا اضافه کنید
          ],
        );
      },
    );
    if (selectedCriteria != null) {
      onSortSelected(selectedCriteria);
    }
  }
}