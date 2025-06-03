// lib/home_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'song_model.dart';
import 'song_detail_screen.dart';
import 'shared_pref_keys.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<Song> _myMusicCollection = [];
  List<Song> _filteredMyMusicCollection = [];
  Set<String> _favoriteSongUniqueIdentifiers = {};

  final TextEditingController _searchController = TextEditingController();
  SharedPreferences? _prefs;
  bool _isLoading = true;
  String _loadingError = '';
  String _currentSortCriteria = 'date_desc'; // پیش‌فرض: جدیدترین آهنگ‌ها اول

  final List<Song> _initialSampleUserMusic = [
    Song(
        title: "My Collection Hit 1",
        artist: "Device Artist A",
        coverImagePath: "assets/covers/D.jpg",
        audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-15.mp3",
        isDownloaded: false,
        isLocal: true,
        averageRating: 4.5,
        dateAdded: DateTime(2023, 10, 20, 10, 0, 0)),
    Song(
        title: "Another Favorite Sample",
        artist: "User Choice B",
        coverImagePath: "assets/covers/OIP.jpg",
        audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-16.mp3",
        isDownloaded: false,
        isLocal: true,
        averageRating: 4.2,
        dateAdded: DateTime(2023, 11, 5, 15, 30, 0)),
  ];

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    print("HomeScreen (My Music): initState called");
    _initMyMusicScreen();
    _searchController.addListener(_filterMyMusicCollection);
  }

  Future<void> _initMyMusicScreen() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _prefs = await SharedPreferences.getInstance();
    await _loadFavoriteSongIdentifiers();
    await _loadMyMusicCollectionData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterMyMusicCollection);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFavoriteSongIdentifiers() async {
    _prefs ??= await SharedPreferences.getInstance();
    final List<String> favoriteIds = _prefs!.getStringList(SharedPrefKeys.favoriteSongIdentifiers) ?? [];
    if (mounted) {
      setState(() {
        _favoriteSongUniqueIdentifiers = favoriteIds.toSet();
      });
    }
  }

  Future<List<Song>> _getDownloadedSongsFromShop() async {
    _prefs ??= await SharedPreferences.getInstance();
    final List<String> downloadedDataStrings = _prefs!.getStringList(SharedPrefKeys.downloadedSongsDataList) ?? [];
    List<Song> parsedSongs = [];
    for (String dataString in downloadedDataStrings) {
      try {
        final song = Song.fromDataString(dataString);
        parsedSongs.add(song.copyWith(isDownloaded: true, isLocal: song.isLocal));
      } catch (e) {
        print("HomeScreen: Error parsing downloaded song data: $dataString, Error: $e");
      }
    }
    return parsedSongs;
  }

  Future<void> _loadMyMusicCollectionData({bool forceRefresh = false}) async {
    if (!mounted) return;

    if (!forceRefresh && !_isLoading && _myMusicCollection.isNotEmpty && _loadingError.isEmpty) {
      List<Song> downloadedFromShop = await _getDownloadedSongsFromShop();
      List<Song> newCombinedMusic = List.from(_initialSampleUserMusic);
      for (var shopSong in downloadedFromShop) {
        if (!newCombinedMusic.any((s) => s.uniqueIdentifier == shopSong.uniqueIdentifier)) {
          newCombinedMusic.add(shopSong);
        } else {
          final index = newCombinedMusic.indexWhere((s) => s.uniqueIdentifier == shopSong.uniqueIdentifier);
          if (index != -1) newCombinedMusic[index] = shopSong;
        }
      }
      if (mounted) {
        _myMusicCollection = newCombinedMusic;
        _applyFilterAndSort();
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingError = '';
    });

    List<Song> combinedMusic = List.from(_initialSampleUserMusic);
    List<Song> downloadedFromShop = await _getDownloadedSongsFromShop();
    for (var shopSong in downloadedFromShop) {
      if (!combinedMusic.any((s) => s.uniqueIdentifier == shopSong.uniqueIdentifier)) {
        combinedMusic.add(shopSong);
      } else {
        final index = combinedMusic.indexWhere((s) => s.uniqueIdentifier == shopSong.uniqueIdentifier);
        if (index != -1) combinedMusic[index] = shopSong;
      }
    }

    if (!mounted) return;
    _myMusicCollection = combinedMusic;
    _loadingError = '';
    _applyFilterAndSort();
    setState(() => _isLoading = false);
  }

  Future<void> _toggleFavoriteStatus(Song song) async {
    _prefs ??= await SharedPreferences.getInstance();
    List<String> currentFavoriteDataStrings = _prefs!.getStringList(SharedPrefKeys.favoriteSongsDataList) ?? [];
    List<String> currentFavoriteIds = _prefs!.getStringList(SharedPrefKeys.favoriteSongIdentifiers) ?? [];
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      });
    }

    if (!isCurrentlyPersistedAsFavorite) {
      if (!currentFavoriteIds.contains(uniqueId)) {
        currentFavoriteIds.add(uniqueId);
        final Song songWithDate = song.copyWith(dateAdded: DateTime.now());
        currentFavoriteDataStrings.add(songWithDate.toDataString());
      }
    } else {
      currentFavoriteIds.remove(uniqueId);
      currentFavoriteDataStrings.removeWhere((dataStr) {
        try {
          return Song.fromDataString(dataStr).uniqueIdentifier == uniqueId;
        } catch (e) { return false; }
      });
    }
    await _prefs!.setStringList(SharedPrefKeys.favoriteSongIdentifiers, currentFavoriteIds);
    await _prefs!.setStringList(SharedPrefKeys.favoriteSongsDataList, currentFavoriteDataStrings);
  }

  bool _isSongFavorite(Song song) {
    return _favoriteSongUniqueIdentifiers.contains(song.uniqueIdentifier);
  }

  void _filterMyMusicCollection() {
    final query = _searchController.text.toLowerCase().trim();
    if (mounted) {
      setState(() {
        if (query.isEmpty) {
          _filteredMyMusicCollection = List.from(_myMusicCollection);
        } else {
          _filteredMyMusicCollection = _myMusicCollection.where((s) =>
          s.title.toLowerCase().contains(query) ||
              s.artist.toLowerCase().contains(query)
          ).toList();
        }
      });
    }
  }

  void _sortMyMusicCollectionInternal() {
    if (_myMusicCollection.isEmpty) return;
    _myMusicCollection.sort((a, b) {
      int comparisonResult;
      switch (_currentSortCriteria) {
        case 'title_asc':
          comparisonResult = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case 'title_desc':
          comparisonResult = b.title.toLowerCase().compareTo(a.title.toLowerCase());
          break;
        case 'artist_asc':
          comparisonResult = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
          break;
        case 'artist_desc':
          comparisonResult = b.artist.toLowerCase().compareTo(a.artist.toLowerCase());
          break;
        case 'date_desc':
          final dateA = a.effectiveDateAdded;
          final dateB = b.effectiveDateAdded;
          if (dateA == null && dateB == null) comparisonResult = 0;
          else if (dateA == null) comparisonResult = 1;
          else if (dateB == null) comparisonResult = -1;
          else comparisonResult = dateB.compareTo(dateA);
          break;
        case 'date_asc':
          final dateA = a.effectiveDateAdded;
          final dateB = b.effectiveDateAdded;
          if (dateA == null && dateB == null) comparisonResult = 0;
          else if (dateA == null) comparisonResult = 1;
          else if (dateB == null) comparisonResult = -1;
          else comparisonResult = dateA.compareTo(dateB);
          break;
        default:
          comparisonResult = 0;
      }
      return comparisonResult;
    });
  }

  void _applyFilterAndSort() {
    _sortMyMusicCollectionInternal();
    _filterMyMusicCollection();
    if (mounted) setState(() {});
  }

  void sortMusic(String criteria) {
    if (!mounted) return;
    setState(() => _currentSortCriteria = criteria);
    _applyFilterAndSort();
  }

  Future<void> refreshDataOnReturn() async {
    if (!mounted) return;
    await _loadFavoriteSongIdentifiers();
    if (mounted) await _loadMyMusicCollectionData(forceRefresh: true);
  }

  Future<void> scrollToTopAndRefresh() async {
    if (!mounted) return;
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(0.0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    await _loadFavoriteSongIdentifiers();
    if (mounted) await _loadMyMusicCollectionData(forceRefresh: true);
  }

  Future<void> _navigateToSongDetail(BuildContext context, Song song, int indexInFilteredList) async {
    _prefs ??= await SharedPreferences.getInstance();
    await song.loadLyrics(_prefs!);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongDetailScreen(
          initialSong: song,
          songList: _filteredMyMusicCollection,
          initialIndex: indexInFilteredList,
        ),
      ),
    );
    if (mounted) await refreshDataOnReturn();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    Widget bodyContent;
    if (_isLoading) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (_loadingError.isNotEmpty) {
      bodyContent = Center(child: Text(_loadingError, textAlign: TextAlign.center, style: textTheme.bodyLarge?.copyWith(color: colorScheme.error)));
    } else if (_myMusicCollection.isEmpty) {
      bodyContent = Center(child: Text("No music found in 'My Music'.\nDownload songs or check your local files.", textAlign: TextAlign.center, style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7))));
    } else if (_filteredMyMusicCollection.isEmpty && _searchController.text.isNotEmpty) {
      bodyContent = Center(child: Text("No music found for '${_searchController.text}'.", style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7))));
    } else {
      bodyContent = RefreshIndicator(
        onRefresh: scrollToTopAndRefresh,
        color: colorScheme.primary,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 70.0, top: 8.0),
          itemCount: _filteredMyMusicCollection.length,
          itemBuilder: (context, index) {
            final song = _filteredMyMusicCollection[index];
            final bool isFavorite = _isSongFavorite(song);

            Widget leadingWidget;
            if (song.isLocal && song.mediaStoreId != null && song.mediaStoreId! > 0) {
              leadingWidget = SizedBox(
                width: 55, height: 55,
                child: QueryArtworkWidget(
                  id: song.mediaStoreId!,
                  type: ArtworkType.AUDIO,
                  artworkFit: BoxFit.cover,
                  artworkBorder: BorderRadius.circular(6.0),
                  artworkClipBehavior: Clip.antiAlias,
                  nullArtworkWidget: Container(
                      width: 55, height: 55,
                      decoration: BoxDecoration(color: colorScheme.surfaceVariant.withOpacity(0.5), borderRadius: BorderRadius.circular(6.0)),
                      child: Icon(Icons.music_note_rounded, color: colorScheme.onSurfaceVariant.withOpacity(0.6), size: 30)),
                  errorBuilder: (ctx, err, st) => Container(
                      width: 55, height: 55,
                      decoration: BoxDecoration(color: (colorScheme.errorContainer ?? Colors.red).withOpacity(0.3), borderRadius: BorderRadius.circular(6.0)),
                      child: Icon(Icons.broken_image_outlined, color: colorScheme.onErrorContainer?.withOpacity(0.6) ?? Colors.redAccent, size: 30)),
                ),
              );
            } else if (song.coverImagePath != null && song.coverImagePath!.isNotEmpty) {
              leadingWidget = ClipRRect(
                  borderRadius: BorderRadius.circular(6.0),
                  child: Image.asset(song.coverImagePath!,
                      width: 55, height: 55, fit: BoxFit.cover,
                      errorBuilder: (ctx, err, st) => Container(
                          width: 55, height: 55,
                          decoration: BoxDecoration(color: colorScheme.surfaceVariant.withOpacity(0.5), borderRadius: BorderRadius.circular(6.0)),
                          child: Icon(Icons.album_rounded, color: colorScheme.onSurfaceVariant.withOpacity(0.6), size: 30))
                  )
              );
            } else {
              leadingWidget = Container(
                  width: 55, height: 55,
                  decoration: BoxDecoration(color: colorScheme.surfaceVariant.withOpacity(0.5), borderRadius: BorderRadius.circular(6.0)),
                  child: Icon(Icons.music_note_rounded, color: colorScheme.onSurfaceVariant.withOpacity(0.6), size: 30)
              );
            }

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              leading: SizedBox(width: 55, height: 55, child: leadingWidget),
              title: Text(song.title, style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(song.artist, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (song.isDownloaded)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      // **** اصلاح شده ****
                      child: Tooltip(
                        message: "Downloaded",
                        child: Icon(Icons.get_app_rounded, color: colorScheme.primary.withOpacity(0.7), size: 20),
                      ),
                    ),
                  IconButton(
                      icon: Icon(
                          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFavorite ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
                          size: 24),
                      tooltip: isFavorite ? "Remove from favorites" : "Add to favorites", // IconButton از tooltip پشتیبانی می‌کند
                      onPressed: () => _toggleFavoriteStatus(song)),
                ],
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
              hintText: 'Search "My Music"...',
              prefixIcon: Icon(Icons.search_rounded, color: colorScheme.onSurface.withOpacity(0.6)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: colorScheme.onSurface.withOpacity(0.6)),
                  tooltip: "Clear search", // IconButton از tooltip پشتیبانی می‌کند
                  onPressed: () => _searchController.clear())
                  : null,
            ),
          ),
        ),
        Expanded(child: bodyContent),
      ],
    );
  }
}