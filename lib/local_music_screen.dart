// lib/local_music_screen.dart
import 'dart:io'; // برای Platform.isAndroid
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'song_model.dart';
import 'song_detail_screen.dart';
import 'shared_pref_keys.dart';

class LocalMusicScreen extends StatefulWidget {
  final Key? key; // اجازه می‌دهد کلید از بیرون پاس داده شود
  const LocalMusicScreen({this.key}) : super(key: key);

  @override
  State<LocalMusicScreen> createState() => LocalMusicScreenState();
}

class LocalMusicScreenState extends State<LocalMusicScreen> {
  List<Song> _localDeviceSongs = [];
  List<Song> _filteredLocalDeviceSongs = [];
  Set<String> _favoriteSongUniqueIdentifiers = {};

  final TextEditingController _searchController = TextEditingController();
  final OnAudioQuery _audioQuery = OnAudioQuery();
  SharedPreferences? _prefs;
  bool _isLoading = true;
  String _loadingMessage = 'Loading local music...';
  String _errorMessage = '';
  String _currentSortCriteria =
      'date_desc'; // پیش‌فرض: جدیدترین آهنگ‌ها از MediaStore
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initScreen();
    _searchController.addListener(_applyFilter); // فقط فیلتر، سورت توسط query
  }

  Future<void> _initScreen() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadFavoriteSongIdentifiers();
    await _requestPermissionAndLoadLocalSongs(); // این تابع سورت اولیه را هم انجام می‌دهد
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilter);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissionAndLoadLocalSongs(
      {bool forceRefresh = false}) async {
    if (!mounted) return;

    // اگر داده وجود دارد، isLoading false است، و forceRefresh نیست، فقط فیلتر را اعمال کن
    // چون سورت توسط query اولیه انجام شده و _localDeviceSongs نباید تغییر کند مگر با forceRefresh
    if (!forceRefresh &&
        !_isLoading &&
        _localDeviceSongs.isNotEmpty &&
        _errorMessage.isEmpty) {
      _applyFilter(); // فقط فیلتر
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = forceRefresh
          ? 'Refreshing local music...'
          : 'Scanning for local music...';
      _errorMessage = '';
      if (forceRefresh) {
        // اگر رفرش اجباری است، لیست‌ها را پاک کن
        _localDeviceSongs.clear();
        _filteredLocalDeviceSongs.clear();
      }
    });

    bool permissionsGranted = false;
    if (Platform.isAndroid) {
      var audioPermissionStatus =
          await Permission.audio.status; // یا Permission.storage بسته به SDK
      if (!audioPermissionStatus.isGranted)
        audioPermissionStatus = await Permission.audio.request();
      permissionsGranted = audioPermissionStatus.isGranted;
    } else {
      // برای iOS یا پلتفرم‌های دیگر که نیازی به درخواست صریح مشابه ندارند
      permissionsGranted = true;
    }

    if (permissionsGranted) {
      try {
        print(
            "LocalMusicScreen: Querying songs with sort: $_currentSortCriteria");
        List<SongModel> deviceSongsRaw = await _audioQuery.querySongs(
          sortType: _getSongSortTypeFromCriteria(_currentSortCriteria),
          orderType: _getOrderTypeFromCriteria(_currentSortCriteria),
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );
        if (!mounted) return;

        if (deviceSongsRaw.isEmpty) {
          _errorMessage = "No music files found on your device.";
          _localDeviceSongs.clear(); // اطمینان از خالی بودن لیست
        } else {
          _localDeviceSongs = deviceSongsRaw
              .where((s) =>
                  (s.isMusic ?? false) &&
                  (s.duration ?? 0) > 30000) // حداقل 30 ثانیه
              .map((s) => Song(
                    title: s.title.isNotEmpty
                        ? s.title
                        : (s.displayNameWOExt.isNotEmpty
                            ? s.displayNameWOExt
                            : "Unknown Title"),
                    artist: s.artist ?? "Unknown Artist",
                    audioUrl: s.data,
                    isLocal: true,
                    mediaStoreId: s.id,
                    dateAddedMediaStore:
                        s.dateAdded, // timestamp از on_audio_query (ثانیه)
                    // dateAdded اینجا null است
                  ))
              .toList();

          if (_localDeviceSongs.isEmpty && deviceSongsRaw.isNotEmpty) {
            _errorMessage =
                "Audio files were found, but none met the criteria (e.g., music, duration > 30s).";
          } else if (_localDeviceSongs.isEmpty && deviceSongsRaw.isEmpty) {
            // این حالت با چک اولیه deviceSongsRaw.isEmpty پوشش داده می‌شود
            _errorMessage =
                "No music files found. Ensure music is in standard folders.";
          } else {
            _errorMessage = ''; // پاک کردن ارور قبلی اگر آهنگ پیدا شد
          }
        }
      } catch (e, stack) {
        if (mounted)
          _errorMessage =
              "An error occurred while fetching songs: ${e.toString().split(':').first}.";
        print("LocalMusicScreen: EXCEPTION fetching songs: $e\n$stack");
        _localDeviceSongs.clear();
      }
    } else {
      if (mounted)
        _errorMessage =
            "Permission to access audio files was denied. Please grant storage/audio permission in app settings.";
      _localDeviceSongs.clear();
    }

    if (!mounted) return;
    _applyFilter(); // اعمال فیلتر روی لیست جدید (مرتب شده توسط query)
    setState(() => _isLoading = false);
  }

  // این متد فقط فیلتر می‌کند، چون سورت توسط querySongs انجام شده
  void _applyFilter() {
    final query = _searchController.text.toLowerCase().trim();
    if (mounted) {
      setState(() {
        // باید setState اینجا باشد تا UI آپدیت شود
        if (query.isEmpty) {
          _filteredLocalDeviceSongs = List.from(_localDeviceSongs);
        } else {
          _filteredLocalDeviceSongs = _localDeviceSongs.where((song) {
            return song.title.toLowerCase().contains(query) ||
                song.artist.toLowerCase().contains(query);
          }).toList();
        }
      });
    }
  }

  Future<void> _loadFavoriteSongIdentifiers() async {
    _prefs ??= await SharedPreferences.getInstance();
    if (mounted) {
      final List<String> favoriteIds =
          _prefs!.getStringList(SharedPrefKeys.favoriteSongIdentifiers) ?? [];
      setState(() {
        _favoriteSongUniqueIdentifiers = favoriteIds.toSet();
      });
    }
  }

  Future<void> _toggleFavoriteStatus(Song song) async {
    _prefs ??= await SharedPreferences.getInstance();
    List<String> currentFavoriteDataStrings =
        _prefs!.getStringList(SharedPrefKeys.favoriteSongsDataList) ?? [];
    List<String> currentFavoriteIds =
        _prefs!.getStringList(SharedPrefKeys.favoriteSongIdentifiers) ?? [];

    final uniqueId = song.uniqueIdentifier;
    bool isCurrentlyPersistedAsFavorite = currentFavoriteIds.contains(uniqueId);
    String message;

    if (mounted) {
      setState(() {
        if (!isCurrentlyPersistedAsFavorite) {
          _favoriteSongUniqueIdentifiers.add(uniqueId);
          message = '"${song.title}" added to favorites.';
        } else {
          _favoriteSongUniqueIdentifiers.remove(uniqueId);
          message = '"${song.title}" removed from favorites.';
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      });
    }

    if (!isCurrentlyPersistedAsFavorite) {
      if (!currentFavoriteIds.contains(uniqueId)) {
        currentFavoriteIds.add(uniqueId);
        final Song songForFavorites = song.copyWith(dateAdded: DateTime.now());
        currentFavoriteDataStrings.add(songForFavorites.toDataString());
      }
    } else {
      currentFavoriteIds.remove(uniqueId);
      currentFavoriteDataStrings.removeWhere((dataStr) {
        try {
          final songFromData = Song.fromDataString(dataStr);
          return songFromData.uniqueIdentifier == uniqueId;
        } catch (e) {
          return false;
        }
      });
    }
    await _prefs!.setStringList(
        SharedPrefKeys.favoriteSongIdentifiers, currentFavoriteIds);
    await _prefs!.setStringList(
        SharedPrefKeys.favoriteSongsDataList, currentFavoriteDataStrings);
  }

  bool _isSongFavorite(Song song) {
    return _favoriteSongUniqueIdentifiers.contains(song.uniqueIdentifier);
  }

  SongSortType _getSongSortTypeFromCriteria(String criteria) {
    if (criteria.startsWith('title')) return SongSortType.TITLE;
    if (criteria.startsWith('artist')) return SongSortType.ARTIST;
    if (criteria.startsWith('date')) return SongSortType.DATE_ADDED;
    return SongSortType.DATE_ADDED; // پیش‌فرض جدید
  }

  OrderType _getOrderTypeFromCriteria(String criteria) {
    if (criteria.endsWith('_desc')) return OrderType.DESC_OR_GREATER;
    return OrderType.ASC_OR_SMALLER;
  }

  // این متد وقتی کاربر معیار سورت را تغییر می‌دهد، فراخوانی می‌شود
  Future<void> sortMusic(String criteria) async {
    if (!mounted || _isLoading) return;
    // اگر معیار سورت تغییر کرده، دوباره آهنگ‌ها را با سورت جدید کوئری بزن
    if (_currentSortCriteria != criteria) {
      setState(() {
        _currentSortCriteria = criteria;
      });
      await _requestPermissionAndLoadLocalSongs(forceRefresh: true);
    }
  }

  Future<void> scrollToTopAndRefresh() async {
    if (!mounted) return;
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(0.0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    await _loadFavoriteSongIdentifiers(); // وضعیت علاقه‌مندی‌ها را هم رفرش کن
    if (mounted) {
      // forceRefresh: true تا با سورت فعلی (_currentSortCriteria) دوباره کوئری بزند
      await _requestPermissionAndLoadLocalSongs(forceRefresh: true);
    }
  }

  // وقتی از صفحه جزئیات آهنگ بازمی‌گردیم، فقط وضعیت علاقه‌مندی‌ها را رفرش می‌کنیم
  Future<void> refreshFavoritesOnReturn() async {
    if (!mounted) return;
    await _loadFavoriteSongIdentifiers();
    if (mounted)
      setState(() {}); // فقط برای رفرش UI اگر وضعیت آیکون قلب تغییر کرده
  }

  Future<void> _navigateToSongDetail(
      BuildContext context, Song song, int indexInFilteredList) async {
    _prefs ??= await SharedPreferences.getInstance();
    await song
        .loadLyrics(_prefs!); // بارگذاری متن آهنگ قبل از رفتن به صفحه جزئیات

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongDetailScreen(
          initialSong: song,
          songList: _filteredLocalDeviceSongs,
          // لیست فیلتر شده فعلی را به عنوان پلی‌لیست بفرست
          initialIndex: indexInFilteredList,
        ),
      ),
    );
    if (mounted) {
      await refreshFavoritesOnReturn(); // پس از بازگشت، وضعیت علاقه‌مندی‌ها را رفرش کن
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    Widget bodyContent;

    if (_isLoading) {
      bodyContent = Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 20),
        Text(_loadingMessage, style: textTheme.titleMedium)
      ]));
    } else if (_errorMessage.isNotEmpty) {
      bodyContent = Center(
          child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 60, color: colorScheme.error.withOpacity(0.7)),
                  const SizedBox(height: 16),
                  Text(_errorMessage,
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.8))),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text("Try Again"),
                    onPressed: () =>
                        _requestPermissionAndLoadLocalSongs(forceRefresh: true),
                  )
                ],
              )));
    } else if (_localDeviceSongs.isEmpty) {
      // این حالت با _errorMessage پوشش داده می‌شود اگر خطایی نباشد و لیستی خالی باشد
      bodyContent = Center(
          child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.music_off_outlined,
                        size: 80, color: Colors.grey[700]),
                    const SizedBox(height: 24),
                    Text("No Local Music Found",
                        style: textTheme.headlineSmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.8))),
                    const SizedBox(height: 12),
                    Text("Scan again or check your device's music folders.",
                        style: textTheme.bodyMedium
                            ?.copyWith(color: Colors.grey[600]),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text("Scan for Music"),
                      onPressed: () => _requestPermissionAndLoadLocalSongs(
                          forceRefresh: true),
                    )
                  ])));
    } else if (_filteredLocalDeviceSongs.isEmpty &&
        _searchController.text.isNotEmpty) {
      bodyContent = Center(
          child: Text("No local music found for '${_searchController.text}'.",
              style: textTheme.titleMedium
                  ?.copyWith(color: colorScheme.onSurface.withOpacity(0.7))));
    } else {
      bodyContent = RefreshIndicator(
        onRefresh: scrollToTopAndRefresh,
        color: colorScheme.primary,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 70.0, top: 8.0),
          // جا برای مینی پلیر
          itemCount: _filteredLocalDeviceSongs.length,
          itemBuilder: (context, index) {
            final song = _filteredLocalDeviceSongs[index];
            final bool isFavorite = _isSongFavorite(song);
            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              leading: SizedBox(
                width: 50, // اندازه ثابت برای کاور
                height: 50,
                child: QueryArtworkWidget(
                  id: song.mediaStoreId ?? 0,
                  // mediaStoreId برای آهنگ محلی الزامی است
                  type: ArtworkType.AUDIO,
                  artworkFit: BoxFit.cover,
                  artworkBorder: BorderRadius.circular(6.0),
                  artworkClipBehavior: Clip.antiAlias,
                  nullArtworkWidget: Container(
                    // ویجت جایگزین اگر کاور وجود ندارد
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(6.0)),
                    child: Icon(Icons.music_note,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                        size: 30),
                  ),
                  errorBuilder: (_, __, ___) => Container(
                    // ویجت جایگزین در صورت خطا در لود کاور
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                        color: (colorScheme.errorContainer ?? Colors.red)
                            .withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6.0)),
                    child: Icon(Icons.broken_image_outlined,
                        color: colorScheme.onErrorContainer?.withOpacity(0.6) ??
                            Colors.redAccent,
                        size: 30),
                  ),
                ),
              ),
              title: Text(song.title,
                  style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              subtitle: Text(song.artist,
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: Icon(
                    isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFavorite
                        ? colorScheme.primary
                        : colorScheme.onSurface.withOpacity(0.6)),
                iconSize: 22,
                tooltip:
                    isFavorite ? "Remove from favorites" : "Add to favorites",
                onPressed: () => _toggleFavoriteStatus(song),
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
              prefixIcon: Icon(Icons.search_rounded,
                  color: colorScheme.onSurface.withOpacity(0.6)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded,
                          color: colorScheme.onSurface.withOpacity(0.6)),
                      onPressed: () {
                        _searchController
                            .clear(); // listener _applyFilter را صدا می‌زند
                      })
                  : null,
            ),
          ),
        ),
        Expanded(child: bodyContent),
      ],
    );
  }
}
