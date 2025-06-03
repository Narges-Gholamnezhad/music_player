// lib/home_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:on_audio_query/on_audio_query.dart'; // اگر از QueryArtworkWidget استفاده می‌کنید
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
  String _currentSortCriteria = 'title_asc';

  final List<Song> _initialSampleUserMusic = [
    Song(
        title: "My Collection Hit 1",
        artist: "Device Artist A",
        coverImagePath: "assets/covers/D.jpg",
        audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-15.mp3",
        isDownloaded: false,
        isLocal: true,
        averageRating: 4.5),
    Song(
        title: "Another Favorite Sample",
        artist: "User Choice B",
        coverImagePath: "assets/covers/OIP.jpg",
        audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-16.mp3",
        isDownloaded: false,
        isLocal: true,
        averageRating: 4.2),
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
    print("HomeScreen: Favorite unique identifiers refreshed: ${_favoriteSongUniqueIdentifiers.length} items.");
  }

  Future<List<Song>> _getDownloadedSongsFromShop() async {
    _prefs ??= await SharedPreferences.getInstance();
    final List<String> downloadedDataStrings = _prefs!.getStringList(SharedPrefKeys.downloadedSongsDataList) ?? [];
    List<Song> parsedSongs = [];
    for (String dataString in downloadedDataStrings) {
      try {
        final song = Song.fromDataString(dataString);
        // await song.loadLyrics(_prefs!); // فقط اگر lyrics در لیست نمایش داده می‌شود
        parsedSongs.add(song.copyWith(isDownloaded: true, isLocal: false));
      } catch (e) {
        print("HomeScreen: Error parsing downloaded song data: $dataString, Error: $e");
      }
    }
    print("HomeScreen: Loaded ${parsedSongs.length} downloaded songs from shop.");
    return parsedSongs;
  }

  Future<void> _loadMyMusicCollectionData({bool forceRefresh = false}) async {
    if (!mounted) return;

    if (!forceRefresh && !_isLoading && _myMusicCollection.isNotEmpty && _loadingError.isEmpty) {
      print("HomeScreen: Data exists, attempting to update downloaded songs and then filter/sort.");
      List<Song> downloadedFromShop = await _getDownloadedSongsFromShop();
      List<Song> newCombinedMusic = List.from(_initialSampleUserMusic);

      for (var shopSong in downloadedFromShop) {
        if (!newCombinedMusic.any((s) => s.uniqueIdentifier == shopSong.uniqueIdentifier)) {
          newCombinedMusic.add(shopSong);
        }
      }
      if (mounted) {
        _myMusicCollection = newCombinedMusic;
        _applyFilterAndSort();
      }
      return;
    }

    print("HomeScreen: Loading My Music collection data. Force refresh: $forceRefresh");
    setState(() {
      _isLoading = true;
      _loadingError = '';
    });

    List<Song> combinedMusic = List.from(_initialSampleUserMusic);

    List<Song> downloadedFromShop = await _getDownloadedSongsFromShop();
    for (var shopSong in downloadedFromShop) {
      if (!combinedMusic.any((s) => s.uniqueIdentifier == shopSong.uniqueIdentifier)) {
        combinedMusic.add(shopSong);
      }
    }

    if (!mounted) return;
    _myMusicCollection = combinedMusic;
    _loadingError = '';
    _applyFilterAndSort();
    setState(() => _isLoading = false);
    print("HomeScreen: My Music collection loaded with ${_myMusicCollection.length} songs.");
  }

  Future<void> _toggleFavoriteStatus(Song song) async {
    _prefs ??= await SharedPreferences.getInstance();
    List<String> currentFavoriteDataStrings = _prefs!.getStringList(SharedPrefKeys.favoriteSongsDataList) ?? [];
    List<String> currentFavoriteIds = _prefs!.getStringList(SharedPrefKeys.favoriteSongIdentifiers) ?? [];

    final uniqueId = song.uniqueIdentifier;
    bool isCurrentlyPersistedAsFavorite = currentFavoriteIds.contains(uniqueId);
    String message;

    // وضعیت UI را بلافاصله تغییر می‌دهیم و سپس در SharedPreferences ذخیره می‌کنیم
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
      if (!currentFavoriteIds.contains(uniqueId)) { // برای جلوگیری از افزودن تکراری اگر همزمان چند جا toggle شود
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
      if (_currentSortCriteria.startsWith('title')) {
        comparisonResult = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      } else if (_currentSortCriteria.startsWith('artist')) {
        comparisonResult = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
      } else {
        comparisonResult = 0;
      }
      return _currentSortCriteria.endsWith('_asc') ? comparisonResult : -comparisonResult;
    });
  }

  void _applyFilterAndSort() {
    _sortMyMusicCollectionInternal();
    _filterMyMusicCollection();
    if (mounted) setState(() {});
  }

  void sortMusic(String criteria) {
    if (!mounted) return;
    if (_currentSortCriteria == criteria && _myMusicCollection.isNotEmpty) return;
    setState(() {
      _currentSortCriteria = criteria;
    });
    _applyFilterAndSort();
  }

  Future<void> refreshDataOnReturn() async { // <--- تبدیل به async
    if (!mounted) return;
    print("HomeScreen (My Music): refreshDataOnReturn called.");
    await _loadFavoriteSongIdentifiers(); // <--- استفاده از await
    if (mounted) {
      await _loadMyMusicCollectionData(forceRefresh: false); // <--- استفاده از await
    }
  }

  Future<void> scrollToTopAndRefresh() async { // <--- تبدیل به async
    if (!mounted) return;
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(0.0, // <--- استفاده از await
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    await _loadFavoriteSongIdentifiers(); // <--- استفاده از await
    if (mounted) {
      await _loadMyMusicCollectionData(forceRefresh: true); // <--- استفاده از await
    }
  }

  Future<void> _navigateToSongDetail(BuildContext context, Song song, int indexInFilteredList) async { // <--- تبدیل به async
    _prefs ??= await SharedPreferences.getInstance();
    await song.loadLyrics(_prefs!);

    print("HomeScreen: Navigating to detail for '${song.title}' UID: ${song.uniqueIdentifier}");
    // Navigator.push(...).then(...) را با await جایگزین می‌کنیم اگر نیازی به نتیجه بازگشتی فوری نیست
    // و refreshDataOnReturn در هر صورت انجام می‌شود.
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
    // این کد پس از بسته شدن SongDetailScreen اجرا می‌شود.
    if (mounted) { // <--- اضافه کردن mounted check
      await refreshDataOnReturn(); // <--- استفاده از await
    }
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
      bodyContent = Center( /* ... */ ); // محتوای قبلی بدون تغییر
    } else if (_myMusicCollection.isEmpty) {
      bodyContent = Center( /* ... */ ); // محتوای قبلی بدون تغییر
    } else if (_filteredMyMusicCollection.isEmpty && _searchController.text.isNotEmpty) {
      bodyContent = Center( /* ... */ ); // محتوای قبلی بدون تغییر
    } else {
      bodyContent = RefreshIndicator(
        onRefresh: scrollToTopAndRefresh, // دیگر نیاز به async جدا نیست
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
                width: 55,
                height: 55,
                child: QueryArtworkWidget(
                  id: song.mediaStoreId!,
                  type: ArtworkType.AUDIO,
                  artworkFit: BoxFit.cover,
                  artworkBorder: BorderRadius.circular(6.0),
                  artworkClipBehavior: Clip.antiAlias,
                  // NO padding parameter for on_audio_query: ^2.9.0
                  nullArtworkWidget: Container(
                      width: 55, height: 55,
                      decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6.0)),
                      child: Icon(Icons.music_note_rounded, color: colorScheme.onSurfaceVariant.withOpacity(0.6), size: 30)),
                  errorBuilder: (ctx, err, st) => Container(
                      width: 55, height: 55,
                      decoration: BoxDecoration(
                          color: (colorScheme.errorContainer ?? Colors.red).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6.0)),
                      child: Icon(Icons.broken_image_outlined, color: colorScheme.onErrorContainer?.withOpacity(0.6) ?? Colors.redAccent, size: 30)),
                ),
              );
            }
            else if (song.coverImagePath != null && song.coverImagePath!.isNotEmpty) {
              leadingWidget = ClipRRect(/* ... */); // محتوای قبلی بدون تغییر
            } else {
              leadingWidget = Container(/* ... */); // محتوای قبلی بدون تغییر
            }
            // برای اختصار، کدهای Image.asset و Container پیش‌فرض را حذف کردم، آنها باید مانند قبل باشند.
            // اطمینان حاصل کنید که کدهای مربوط به leadingWidget که قبلا کار می‌کردند را اینجا قرار دهید.
            // کدی که برای coverImagePath و حالت پیش‌فرض داشتید:
            if (song.coverImagePath != null && song.coverImagePath!.isNotEmpty) {
              leadingWidget = ClipRRect(
                  borderRadius: BorderRadius.circular(6.0),
                  child: Image.asset(song.coverImagePath!,
                      width: 55, height: 55, fit: BoxFit.cover,
                      errorBuilder: (ctx, err, st) => Container(
                          width: 55, height: 55,
                          decoration: BoxDecoration(
                              color: colorScheme.surfaceVariant.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(6.0)),
                          child: Icon(Icons.album_rounded, color: colorScheme.onSurfaceVariant.withOpacity(0.6), size: 30))
                  )
              );
            } else if (!(song.isLocal && song.mediaStoreId != null && song.mediaStoreId! > 0)) { // اگر محلی با آرت‌ورک نیست
              leadingWidget = Container(
                  width: 55, height: 55,
                  decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(6.0)),
                  child: Icon(Icons.music_note_rounded, color: colorScheme.onSurfaceVariant.withOpacity(0.6), size: 30)
              );
            }
            // اگر آهنگ محلی است و mediaStoreId دارد، leadingWidget قبلا مقداردهی شده.

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
                      child: Icon(Icons.get_app_rounded, color: colorScheme.primary.withOpacity(0.7), size: 20),
                    ),
                  IconButton(
                      icon: Icon(
                          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFavorite ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
                          size: 24),
                      tooltip: isFavorite ? "Remove from favorites" : "Add to favorites",
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
                  onPressed: () => _searchController.clear()
              )
                  : null,
            ),
          ),
        ),
        Expanded(child: bodyContent),
      ],
    );
  }
}