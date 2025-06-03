// lib/local_music_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'song_model.dart';
import 'song_detail_screen.dart'; // برای ناوبری و شاید موارد دیگر، اما نه برای کلید prefs
// import 'main_tabs_screen.dart'; // اگر به nowPlayingNotifier و globalAudioPlayer نیاز دارید

class LocalMusicScreen extends StatefulWidget {
  final Key? key;
  const LocalMusicScreen({this.key}) : super(key: key);

  @override
  State<LocalMusicScreen> createState() => LocalMusicScreenState();
}

class LocalMusicScreenState extends State<LocalMusicScreen> {
  List<Song> _localDeviceSongs = [];
  List<Song> _filteredLocalDeviceSongs = [];
  // List<String> _favoriteSongIdentifiersFromPrefs = []; // دیگر به این شکل لازم نیست، مستقیم از داده‌ها چک می‌کنیم

  final TextEditingController _searchController = TextEditingController();
  final OnAudioQuery _audioQuery = OnAudioQuery();
  SharedPreferences? _prefs;
  bool _isLoading = true;
  String _loadingMessage = 'Loading local music...';
  String _errorMessage = '';
  String _currentSortCriteria = 'title_asc';
  final ScrollController _scrollController = ScrollController();

  // ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  // مقدار کلید SharedPreferences برای علاقه‌مندی‌ها را مستقیماً اینجا تعریف کنید
  // این مقدار باید دقیقاً با مقداری که در SongDetailScreen.favoriteSongsDataKeyPlayer
  // تعریف شده است، یکسان باشد.
  static const String _persistentFavoritesKey = 'favorite_songs_data_list_v1';
  // ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  List<String> _favoriteSongDataStringsFromPrefs = []; // برای نگهداری رشته‌های داده آهنگ‌های محبوب


  @override
  void initState() {
    super.initState();
    _initScreen();
    _searchController.addListener(_filterLocalSongs);
  }

  Future<void> _initScreen() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadFavoriteSongDataStrings(); // استفاده از نام جدید متد
    await _requestPermissionAndLoadLocalSongs();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterLocalSongs);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissionAndLoadLocalSongs({bool forceRefresh = false}) async {
    // ... (کد این متد مثل قبل، بدون تغییر)
    if (!mounted) return;
    if (!forceRefresh && !_isLoading && _localDeviceSongs.isNotEmpty && _errorMessage.isEmpty) {
      _applyFilterAndSort();
      return;
    }
    setState(() {
      _isLoading = true;
      _loadingMessage = forceRefresh ? 'Refreshing local music...' : 'Scanning for local music...';
      _errorMessage = '';
      if (forceRefresh) {
        _localDeviceSongs.clear();
        _filteredLocalDeviceSongs.clear();
      }
    });

    bool permissionsGranted = false;
    if (Platform.isAndroid) {
      var audioPermissionStatus = await Permission.audio.status;
      if (!audioPermissionStatus.isGranted) audioPermissionStatus = await Permission.audio.request();
      permissionsGranted = audioPermissionStatus.isGranted;
    } else {
      permissionsGranted = true;
    }

    if (permissionsGranted) {
      try {
        List<SongModel> deviceSongsRaw = await _audioQuery.querySongs(
          sortType: _getSongSortTypeFromCriteria(_currentSortCriteria),
          orderType: _getOrderTypeFromCriteria(_currentSortCriteria),
          uriType: UriType.EXTERNAL, ignoreCase: true,
        );
        if (!mounted) return;
        if (deviceSongsRaw.isEmpty) {
          _errorMessage = "No music files found on your device. Please add some music to your device's music folders.";
        } else {
          _localDeviceSongs = deviceSongsRaw
              .where((s) => (s.isMusic ?? false) && (s.duration ?? 0) > 30000)
              .map((s) => Song(
            title: s.title.isNotEmpty ? s.title : (s.displayNameWOExt.isNotEmpty ? s.displayNameWOExt : "Unknown Title"),
            artist: s.artist ?? "Unknown Artist", audioUrl: s.data,
            isLocal: true, isDownloaded: false, mediaStoreId: s.id,
            // coverImagePath و requiredAccessTier برای آهنگ‌های محلی معمولاً null یا پیش‌فرض هستند
          )).toList();
          if (_localDeviceSongs.isEmpty && deviceSongsRaw.isNotEmpty) {
            _errorMessage = "Audio files were found, but none met the criteria (e.g., marked as music, duration > 30s).";
          } else if (_localDeviceSongs.isEmpty && deviceSongsRaw.isEmpty) {
            _errorMessage = "No music files found. Ensure music is in standard folders like 'Music' or 'Download'.";
          }
        }
      } catch (e, s) {
        if (mounted) _errorMessage = "An error occurred while fetching songs: ${e.toString().split(':').first}. Please try again.";
        print("LocalMusicScreen: EXCEPTION: $e\n$s");
      }
    } else {
      if (mounted) _errorMessage = "Permission to access audio files was denied. Please grant storage/audio permission in app settings and try again.";
      print("LocalMusicScreen: Required permissions were denied by the user.");
    }
    if (!mounted) return;
    _applyFilterAndSort();
    setState(() => _isLoading = false);
  }

  void _applyFilterAndSort() {
    _sortLocalMusicInternal(); // مرتب‌سازی لیست اصلی
    _filterLocalSongs();     // فیلتر کردن بر اساس جستجو
    if (mounted) setState(() {});
  }

  // خواندن رشته‌های داده آهنگ‌های محبوب از SharedPreferences
  Future<void> _loadFavoriteSongDataStrings() async {
    _prefs ??= await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _favoriteSongDataStringsFromPrefs = _prefs!.getStringList(_persistentFavoritesKey) ?? [];
      });
    }
  }

  Future<void> _toggleFavoriteStatus(Song song) async {
    _prefs ??= await SharedPreferences.getInstance();
    List<String> currentFavoriteDataStrings = List.from(_favoriteSongDataStringsFromPrefs);
    final String songDataForStorage = song.toDataString(); // آهنگ فعلی را به رشته تبدیل کن

    int foundIndex = -1;
    for(int i=0; i < currentFavoriteDataStrings.length; i++) {
      try {
        final favSong = Song.fromDataString(currentFavoriteDataStrings[i]);
        // برای آهنگ‌های محلی، مقایسه audioUrl (مسیر فایل) هم مهم است
        if (favSong.title == song.title && favSong.artist == song.artist && favSong.audioUrl == song.audioUrl) {
          foundIndex = i;
          break;
        }
      } catch (e) { /* رشته نامعتبر */ }
    }

    if (mounted) {
      setState(() {
        if (foundIndex != -1) {
          currentFavoriteDataStrings.removeAt(foundIndex);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${song.title}" removed from favorites.')));
        } else {
          currentFavoriteDataStrings.add(songDataForStorage);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${song.title}" added to favorites.')));
        }
        _favoriteSongDataStringsFromPrefs = currentFavoriteDataStrings;
      });
    }
    await _prefs!.setStringList(_persistentFavoritesKey, currentFavoriteDataStrings);
  }

  bool _isSongFavorite(Song song) {
    return _favoriteSongDataStringsFromPrefs.any((dataString) {
      try {
        final favSong = Song.fromDataString(dataString);
        return favSong.title == song.title && favSong.artist == song.artist && favSong.audioUrl == song.audioUrl;
      } catch (e) {
        return false;
      }
    });
  }

  void _filterLocalSongs() {
    final query = _searchController.text.toLowerCase().trim();
    if (mounted) {
      if (query.isEmpty) {
        _filteredLocalDeviceSongs = List.from(_localDeviceSongs);
      } else {
        _filteredLocalDeviceSongs = _localDeviceSongs.where((song) {
          return song.title.toLowerCase().contains(query) ||
              song.artist.toLowerCase().contains(query);
        }).toList();
      }
      // setState در _applyFilterAndSort انجام می‌شود
    }
  }

  SongSortType _getSongSortTypeFromCriteria(String criteria) {
    if (criteria.startsWith('title')) return SongSortType.TITLE;
    if (criteria.startsWith('artist')) return SongSortType.ARTIST;
    if (criteria.startsWith('album')) return SongSortType.ALBUM;
    if (criteria.startsWith('duration')) return SongSortType.DURATION;
    if (criteria.startsWith('date_added')) return SongSortType.DATE_ADDED;
    return SongSortType.TITLE;
  }

  OrderType _getOrderTypeFromCriteria(String criteria) {
    if (criteria.endsWith('_desc')) return OrderType.DESC_OR_GREATER;
    return OrderType.ASC_OR_SMALLER;
  }

  void _sortLocalMusicInternal() {
    // on_audio_query خودش مرتب می‌کند. اگر نیاز به مرتب‌سازی دستی پس از خواندن دارید، اینجا پیاده‌سازی کنید.
    // مثال:
    // if (_localDeviceSongs.isNotEmpty) {
    //   _localDeviceSongs.sort((a, b) {
    //     if (_currentSortCriteria.startsWith('title')) {
    //       int comp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
    //       return _currentSortCriteria.endsWith('_asc') ? comp : -comp;
    //     } else if (_currentSortCriteria.startsWith('artist')) {
    //       int comp = (a.artist ?? "").toLowerCase().compareTo((b.artist ?? "").toLowerCase());
    //       return _currentSortCriteria.endsWith('_asc') ? comp : -comp;
    //     }
    //     return 0;
    //   });
    // }
  }


  void sortMusic(String criteria) {
    if (!mounted || _isLoading) return;
    if (_currentSortCriteria == criteria && _localDeviceSongs.isNotEmpty) return;
    setState(() {
      _currentSortCriteria = criteria;
      _isLoading = true;
    });
    _requestPermissionAndLoadLocalSongs(forceRefresh: true);
  }

  void scrollToTopAndRefresh() {
    if (!mounted) return;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    _requestPermissionAndLoadLocalSongs(forceRefresh: true);
  }

  void refreshFavorites() { // این متد باید از بیرون (مثلا از MainTabsScreen) هم قابل فراخوانی باشد اگر لازم است
    if (!mounted) return;
    _loadFavoriteSongDataStrings().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _navigateToSongDetail(BuildContext context, Song song, int indexInFilteredList) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongDetailScreen(
          initialSong: song,
          songList: _filteredLocalDeviceSongs, // ارسال لیست فیلتر شده فعلی
          initialIndex: indexInFilteredList,   // ایندکس در لیست فیلتر شده
        ),
      ),
    ).then((_) {
      refreshFavorites(); // پس از بازگشت، وضعیت علاقه‌مندی‌ها را رفرش کن
    });
  }

  @override
  Widget build(BuildContext context) {
    // ... (کد UI مثل قبل، با استفاده از _isSongFavorite و _toggleFavoriteStatus)
    // کد کامل UI که قبلاً فرستاده بودید و شامل QueryArtworkWidget بود را اینجا قرار دهید.
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    Widget bodyContent;

    if (_isLoading) {
      bodyContent = Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(), const SizedBox(height: 20), Text(_loadingMessage, style: textTheme.titleMedium)]));
    } else if (_errorMessage.isNotEmpty) {
      bodyContent = Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 60),
        const SizedBox(height: 20),
        Text(_errorMessage, style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text("Try Scan Again"), onPressed: () => _requestPermissionAndLoadLocalSongs(forceRefresh: true), style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary)),
        if (_errorMessage.toLowerCase().contains("permission"))
          TextButton(child: const Text("Open App Settings"), onPressed: () => openAppSettings())
      ])));
    } else if (_localDeviceSongs.isEmpty) {
      bodyContent = Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.music_off_outlined, size: 70, color: colorScheme.onSurface.withOpacity(0.5)),
        const SizedBox(height: 20),
        Text("No Local Music Found", style: textTheme.headlineSmall?.copyWith(color: colorScheme.onSurface), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text("Ensure music files are in your device's standard music folders and the app has permission.", style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text("Scan Again"), onPressed: () => _requestPermissionAndLoadLocalSongs(forceRefresh: true), style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary))
      ])));
    } else if (_filteredLocalDeviceSongs.isEmpty && _searchController.text.isNotEmpty) {
      bodyContent = Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text("No music found for \"${_searchController.text}\"", style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)), textAlign: TextAlign.center)));
    } else {
      bodyContent = RefreshIndicator(
        onRefresh: () => _requestPermissionAndLoadLocalSongs(forceRefresh: true),
        color: colorScheme.primary,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 70.0, top: 8.0),
          itemCount: _filteredLocalDeviceSongs.length,
          itemBuilder: (context, index) {
            final song = _filteredLocalDeviceSongs[index];
            final bool isFavorite = _isSongFavorite(song); // استفاده از متد اصلاح شده
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              leading: QueryArtworkWidget(
                id: song.mediaStoreId ?? 0,
                type: ArtworkType.AUDIO,
                artworkFit: BoxFit.cover, artworkBorder: BorderRadius.circular(6.0), artworkClipBehavior: Clip.antiAlias,
                nullArtworkWidget: Container(width: 50, height: 50, decoration: BoxDecoration(color: colorScheme.surfaceVariant.withOpacity(0.5), borderRadius: BorderRadius.circular(6.0)), child: Icon(Icons.music_note, color: colorScheme.onSurfaceVariant.withOpacity(0.6), size: 30)),
                errorBuilder: (_, __, ___) => Container(width: 50, height: 50, decoration: BoxDecoration(color: colorScheme.errorContainer?.withOpacity(0.3) ?? Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(6.0)), child: Icon(Icons.broken_image_outlined, color: colorScheme.onErrorContainer?.withOpacity(0.6) ?? Colors.redAccent, size: 30)),
              ),
              title: Text(song.title, style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(song.artist, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: Icon(isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isFavorite ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6)),
                iconSize: 22,
                tooltip: isFavorite ? "Remove from favorites" : "Add to favorites",
                onPressed: () => _toggleFavoriteStatus(song), // استفاده از متد اصلاح شده
              ),
              onTap: () => _navigateToSongDetail(context, song, index),
            );
          },
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 10.0),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Search local music...',
              prefixIcon: Icon(Icons.search_rounded, color: colorScheme.onSurface.withOpacity(0.6)),
              suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: Icon(Icons.clear_rounded, color: colorScheme.onSurface.withOpacity(0.6)), onPressed: () => _searchController.clear()) : null,
            ),
          ),
        ),
        Expanded(child: bodyContent),
      ],
    );
  }
}