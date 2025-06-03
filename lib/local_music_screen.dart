// lib/local_music_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'song_model.dart';
import 'song_detail_screen.dart';
import 'shared_pref_keys.dart';

class LocalMusicScreen extends StatefulWidget {
  final Key? key;
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
  String _currentSortCriteria = 'title_asc';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initScreen();
    _searchController.addListener(_filterLocalSongs);
  }

  Future<void> _initScreen() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadFavoriteSongIdentifiers();
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
          _errorMessage = "No music files found on your device.";
        } else {
          _localDeviceSongs = deviceSongsRaw
              .where((s) => (s.isMusic ?? false) && (s.duration ?? 0) > 30000)
              .map((s) => Song(
            title: s.title.isNotEmpty ? s.title : (s.displayNameWOExt.isNotEmpty ? s.displayNameWOExt : "Unknown Title"),
            artist: s.artist ?? "Unknown Artist",
            audioUrl: s.data,
            isLocal: true,
            mediaStoreId: s.id,
          )).toList();

          if (_localDeviceSongs.isEmpty && deviceSongsRaw.isNotEmpty) {
            _errorMessage = "Audio files were found, but none met the criteria (e.g., marked as music, duration > 30s).";
          } else if (_localDeviceSongs.isEmpty && deviceSongsRaw.isEmpty) {
            _errorMessage = "No music files found. Ensure music is in standard folders like 'Music' or 'Download'.";
          }
        }
      } catch (e, stack) {
        if (mounted) _errorMessage = "An error occurred while fetching songs: ${e.toString().split(':').first}.";
        print("LocalMusicScreen: EXCEPTION fetching songs: $e\n$stack");
      }
    } else {
      if (mounted) _errorMessage = "Permission to access audio files was denied. Please grant storage/audio permission in app settings.";
    }
    if (!mounted) return;
    _applyFilterAndSort();
    setState(() => _isLoading = false);
  }

  void _applyFilterAndSort() {
    _filterLocalSongs(); // مرتب‌سازی توسط on_audio_query انجام شده
    if (mounted) setState(() {});
  }

  Future<void> _loadFavoriteSongIdentifiers() async {
    _prefs ??= await SharedPreferences.getInstance();
    if (mounted) {
      final List<String> favoriteIds = _prefs!.getStringList(SharedPrefKeys.favoriteSongIdentifiers) ?? [];
      setState(() {
        _favoriteSongUniqueIdentifiers = favoriteIds.toSet();
      });
    }
  }

  Future<void> _toggleFavoriteStatus(Song song) async {
    _prefs ??= await SharedPreferences.getInstance();
    List<String> currentFavoriteDataStrings = _prefs!.getStringList(SharedPrefKeys.favoriteSongsDataList) ?? [];
    List<String> currentFavoriteIds = _prefs!.getStringList(SharedPrefKeys.favoriteSongIdentifiers) ?? [];

    final uniqueId = song.uniqueIdentifier;
    bool isCurrentlyPersistedAsFavorite = currentFavoriteIds.contains(uniqueId);
    String message;

    // وضعیت UI را بلافاصله تغییر می‌دهیم
    if (mounted) {
      setState(() {
        if (!isCurrentlyPersistedAsFavorite) {
          _favoriteSongUniqueIdentifiers.add(uniqueId);
          message = '"${song.title}" added to favorites.';
        } else {
          _favoriteSongUniqueIdentifiers.remove(uniqueId);
          message = '"${song.title}" removed from favorites.';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      });
    }

    // حالا SharedPreferences را آپدیت کن
    if (!isCurrentlyPersistedAsFavorite) {
      if (!currentFavoriteIds.contains(uniqueId)) {
        currentFavoriteIds.add(uniqueId);
        currentFavoriteDataStrings.add(song.toDataString());
      }
    } else {
      currentFavoriteIds.remove(uniqueId);
      currentFavoriteDataStrings.removeWhere((dataStr) {
        try {
          final songFromData = Song.fromDataString(dataStr);
          return songFromData.uniqueIdentifier == uniqueId;
        } catch (e) { return false; }
      });
    }
    await _prefs!.setStringList(SharedPrefKeys.favoriteSongIdentifiers, currentFavoriteIds);
    await _prefs!.setStringList(SharedPrefKeys.favoriteSongsDataList, currentFavoriteDataStrings);
  }

  bool _isSongFavorite(Song song) {
    return _favoriteSongUniqueIdentifiers.contains(song.uniqueIdentifier);
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
    // ... سایر معیارها
    return SongSortType.TITLE;
  }

  OrderType _getOrderTypeFromCriteria(String criteria) {
    if (criteria.endsWith('_desc')) return OrderType.DESC_OR_GREATER;
    return OrderType.ASC_OR_SMALLER;
  }

  Future<void> sortMusic(String criteria) async { // <--- تبدیل به async
    if (!mounted || _isLoading) return;
    if (_currentSortCriteria == criteria && _localDeviceSongs.isNotEmpty) return;
    setState(() {
      _currentSortCriteria = criteria;
    });
    await _requestPermissionAndLoadLocalSongs(forceRefresh: true); // <--- استفاده از await
  }

  Future<void> scrollToTopAndRefresh() async { // <--- تبدیل به async
    if (!mounted) return;
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    await _loadFavoriteSongIdentifiers(); // <--- استفاده از await
    if (mounted) {
      await _requestPermissionAndLoadLocalSongs(forceRefresh: true); // <--- استفاده از await
    }
  }

  Future<void> refreshFavorites() async { // <--- تبدیل به async
    if (!mounted) return;
    await _loadFavoriteSongIdentifiers(); // <--- استفاده از await
    if (mounted) setState(() {});
  }

  Future<void> _navigateToSongDetail(BuildContext context, Song song, int indexInFilteredList) async { // <--- تبدیل به async
    _prefs ??= await SharedPreferences.getInstance();
    await song.loadLyrics(_prefs!);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongDetailScreen(
          initialSong: song,
          songList: _filteredLocalDeviceSongs,
          initialIndex: indexInFilteredList,
        ),
      ),
    );
    if (mounted) { // <--- اضافه کردن mounted check
      await refreshFavorites(); // <--- استفاده از await
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    Widget bodyContent;

    if (_isLoading) {
      bodyContent = Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(), const SizedBox(height: 20), Text(_loadingMessage, style: textTheme.titleMedium)]));
    } else if (_errorMessage.isNotEmpty) {
      bodyContent = Center( /* ... */ ); // محتوای قبلی بدون تغییر
    } else if (_localDeviceSongs.isEmpty) {
      bodyContent = Center( /* ... */ ); // محتوای قبلی بدون تغییر
    } else if (_filteredLocalDeviceSongs.isEmpty && _searchController.text.isNotEmpty) {
      bodyContent = Center( /* ... */ ); // محتوای قبلی بدون تغییر
    } else {
      bodyContent = RefreshIndicator(
        onRefresh: scrollToTopAndRefresh, // دیگر نیاز به async جدا نیست
        color: colorScheme.primary,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 70.0, top: 8.0),
          itemCount: _filteredLocalDeviceSongs.length,
          itemBuilder: (context, index) {
            final song = _filteredLocalDeviceSongs[index];
            final bool isFavorite = _isSongFavorite(song);
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              leading: SizedBox(
                width: 50,
                height: 50,
                child: QueryArtworkWidget(
                  id: song.mediaStoreId ?? 0,
                  type: ArtworkType.AUDIO,
                  artworkFit: BoxFit.cover,
                  artworkBorder: BorderRadius.circular(6.0),
                  artworkClipBehavior: Clip.antiAlias,
                  // NO padding parameter
                  nullArtworkWidget: Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(color: colorScheme.surfaceVariant.withOpacity(0.5), borderRadius: BorderRadius.circular(6.0)),
                    child: Icon(Icons.music_note, color: colorScheme.onSurfaceVariant.withOpacity(0.6), size: 30),
                  ),
                  errorBuilder: (_, __, ___) => Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(color: (colorScheme.errorContainer ?? Colors.red).withOpacity(0.3), borderRadius: BorderRadius.circular(6.0)),
                    child: Icon(Icons.broken_image_outlined, color: colorScheme.onErrorContainer?.withOpacity(0.6) ?? Colors.redAccent, size: 30),
                  ),
                ),
              ),
              title: Text(song.title, style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(song.artist, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: Icon(isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isFavorite ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6)),
                iconSize: 22,
                tooltip: isFavorite ? "Remove from favorites" : "Add to favorites",
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