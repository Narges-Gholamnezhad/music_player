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
  String _currentSortCriteria = 'date_desc';

  // آهنگ‌های نمونه اولیه با تاریخ افزودن
  final List<Song> _initialSampleUserMusic = [
    Song(
        title: "My Collection Hit 1",
        artist: "Device Artist A",
        coverImagePath: "assets/covers/D.jpg",
        audioUrl:
            "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-15.mp3",
        isDownloaded: false,
        // اینها آهنگ نمونه هستند، نه لزوما دانلود شده از شاپ
        isLocal: true,
        averageRating: 4.5,
        dateAdded: DateTime(2023, 10, 20, 10, 0, 0) // تاریخ افزودن نمونه
        ),
    Song(
        title: "Another Favorite Sample",
        artist: "User Choice B",
        coverImagePath: "assets/covers/OIP.jpg",
        audioUrl:
            "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-16.mp3",
        isDownloaded: false,
        isLocal: true,
        averageRating: 4.2,
        dateAdded: DateTime(2023, 11, 5, 15, 30, 0) // تاریخ افزودن نمونه
        ),
  ];

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    print("HomeScreen (My Music): initState called");
    _initMyMusicScreen();
    _searchController.addListener(
        _applyFilterAndSort); // هر بار جستجو تغییر کرد، فیلتر و سورت کن
  }

  Future<void> _initMyMusicScreen() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _prefs = await SharedPreferences.getInstance();
    await _loadFavoriteSongIdentifiers();
    await _loadMyMusicCollectionData(
        forceRefresh: true); // بار اول، کامل لود کن
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilterAndSort);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFavoriteSongIdentifiers() async {
    _prefs ??= await SharedPreferences.getInstance();
    final List<String> favoriteIds =
        _prefs!.getStringList(SharedPrefKeys.favoriteSongIdentifiers) ?? [];
    if (mounted) {
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
        final Song songWithDate = song.copyWith(dateAdded: DateTime.now());
        currentFavoriteDataStrings.add(songWithDate.toDataString());
      }
    } else {
      currentFavoriteIds.remove(uniqueId);
      currentFavoriteDataStrings.removeWhere((dataStr) {
        try {
          return Song.fromDataString(dataStr).uniqueIdentifier == uniqueId;
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

  Future<List<Song>> _getDownloadedSongsFromShop() async {
    _prefs ??= await SharedPreferences.getInstance();
    final List<String> downloadedDataStrings =
        _prefs!.getStringList(SharedPrefKeys.downloadedSongsDataList) ?? [];
    List<Song> parsedSongs = [];
    for (String dataString in downloadedDataStrings) {
      try {
        final song = Song.fromDataString(dataString);
        // اطمینان از اینکه isDownloaded = true است و dateAdded از SharedPreferences خوانده شده
        parsedSongs.add(song.copyWith(
            isDownloaded: true)); // isLocal باید از خود آهنگ خوانده شود
      } catch (e) {
        print(
            "HomeScreen: Error parsing downloaded song data in _getDownloadedSongsFromShop: $dataString, Error: $e");
      }
    }
    print(
        "HomeScreen: _getDownloadedSongsFromShop loaded ${parsedSongs.length} songs.");
    return parsedSongs;
  }

  Future<void> _loadMyMusicCollectionData({bool forceRefresh = false}) async {
    if (!mounted) return;
    print(
        "HomeScreen: _loadMyMusicCollectionData called with forceRefresh: $forceRefresh, isLoading: $_isLoading");

    // اگر داده وجود دارد، isLoading false است، و forceRefresh نیست، فقط آپدیت سبک انجام بده
    // این حالت زمانی است که از صفحه دیگری برمی‌گردیم و ممکن است آهنگ جدیدی دانلود شده باشد.
    if (!forceRefresh &&
        !_isLoading &&
        _myMusicCollection.isNotEmpty &&
        _loadingError.isEmpty) {
      print("HomeScreen: Performing light update for downloaded songs.");
      List<Song> downloadedFromShop = await _getDownloadedSongsFromShop();
      List<Song> currentMusic = List.from(_myMusicCollection);
      bool collectionChanged = false;

      // اضافه کردن/آپدیت آهنگ‌های دانلود شده
      for (var downloadedSong in downloadedFromShop) {
        final existingIndex = currentMusic.indexWhere(
            (s) => s.uniqueIdentifier == downloadedSong.uniqueIdentifier);
        if (existingIndex == -1) {
          // آهنگ جدید دانلود شده
          currentMusic.add(downloadedSong);
          collectionChanged = true;
        } else {
          // آهنگ قبلا وجود داشته (ممکن است نمونه بوده یا قبلا دانلود شده و اطلاعاتش آپدیت شده)
          // با نسخه جدیدتر (که ممکن است dateAdded یا lyrics متفاوتی داشته باشد) جایگزین کن
          if (currentMusic[existingIndex].isDownloaded ==
                  false || // اگر قبلا isDownloaded نبوده
              currentMusic[existingIndex].dateAdded !=
                  downloadedSong.dateAdded || // یا تاریخش فرق کرده
              currentMusic[existingIndex].audioUrl != downloadedSong.audioUrl) {
            // یا مسیرش (که نباید برای دانلود شده فرق کند)
            currentMusic[existingIndex] = downloadedSong;
            collectionChanged = true;
          }
        }
      }
      // TODO: اگر آهنگی از لیست دانلود شده‌ها حذف شده، باید از _myMusicCollection هم حذف شود (اگر isDownloaded بوده)
      // این منطق در حال حاضر پیاده‌سازی نشده است.

      if (collectionChanged && mounted) {
        _myMusicCollection = currentMusic;
        // چون لیست اصلی تغییر کرده، دوباره سورت و فیلتر می‌کنیم
        _applyFilterAndSort();
      } else if (mounted) {
        // اگر لیست اصلی تغییر نکرده، فقط فیلتر را (اگر لازم است) و UI را رفرش کن
        // این برای زمانی است که مثلا فقط وضعیت favorite یک آهنگ تغییر کرده
        _applyFilterAndSort(); // این setState را هم انجام می‌دهد
      }
      return;
    }

    // بارگذاری کامل داده‌ها (اولین بار یا با forceRefresh)
    print("HomeScreen: Performing full load of My Music collection data.");
    setState(() {
      _isLoading = true;
      _loadingError = '';
    });

    List<Song> combinedMusic = List.from(_initialSampleUserMusic);
    List<Song> downloadedFromShop = await _getDownloadedSongsFromShop();

    for (var shopSong in downloadedFromShop) {
      final existingIndex = combinedMusic
          .indexWhere((s) => s.uniqueIdentifier == shopSong.uniqueIdentifier);
      if (existingIndex != -1) {
        combinedMusic[existingIndex] = shopSong; // نسخه دانلود شده اولویت دارد
      } else {
        combinedMusic.add(shopSong);
      }
    }

    if (!mounted) return;
    _myMusicCollection = combinedMusic;
    _loadingError = '';
    _applyFilterAndSort(); // شامل سورت اولیه و فیلتر
    setState(() => _isLoading = false);
  }

  void _sortMyMusicCollectionInternal() {
    if (_myMusicCollection.isEmpty) return;
    _myMusicCollection.sort((a, b) {
      int comparisonResult;
      switch (_currentSortCriteria) {
        case 'title_asc':
          comparisonResult =
              a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case 'title_desc':
          comparisonResult =
              b.title.toLowerCase().compareTo(a.title.toLowerCase());
          break;
        case 'artist_asc':
          comparisonResult =
              a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
          break;
        case 'artist_desc':
          comparisonResult =
              b.artist.toLowerCase().compareTo(a.artist.toLowerCase());
          break;
        case 'date_desc':
          final dateA = a.effectiveDateAdded; // از getter استفاده می‌کنیم
          final dateB = b.effectiveDateAdded;
          if (dateA == null && dateB == null)
            comparisonResult = 0;
          else if (dateA == null)
            comparisonResult = 1; // null ها آخر
          else if (dateB == null)
            comparisonResult = -1;
          else
            comparisonResult = dateB.compareTo(dateA);
          break;
        case 'date_asc':
          final dateA = a.effectiveDateAdded;
          final dateB = b.effectiveDateAdded;
          if (dateA == null && dateB == null)
            comparisonResult = 0;
          else if (dateA == null)
            comparisonResult = 1;
          else if (dateB == null)
            comparisonResult = -1;
          else
            comparisonResult = dateA.compareTo(dateB);
          break;
        default: // پیش‌فرض سورت بر اساس تاریخ جدیدترین
          final dateA = a.effectiveDateAdded;
          final dateB = b.effectiveDateAdded;
          if (dateA == null && dateB == null) {
            comparisonResult = 0;
          } else if (dateA == null) {
            comparisonResult = 1;
          } else if (dateB == null) {
            comparisonResult = -1;
          } else {
            comparisonResult = dateB.compareTo(dateA);
          }
      }
      return comparisonResult;
    });
  }

  // این متد هم سورت می‌کند و هم فیلتر و در نهایت UI را آپدیت می‌کند
  void _applyFilterAndSort() {
    _sortMyMusicCollectionInternal(); // اول لیست اصلی را سورت کن
    // حالا لیست فیلتر شده را از روی لیست اصلی مرتب شده بساز
    final query = _searchController.text.toLowerCase().trim();
    if (mounted) {
      setState(() {
        // setState باید اینجا باشد تا UI آپدیت شود
        if (query.isEmpty) {
          _filteredMyMusicCollection = List.from(_myMusicCollection);
        } else {
          _filteredMyMusicCollection = _myMusicCollection
              .where((s) =>
                  s.title.toLowerCase().contains(query) ||
                  s.artist.toLowerCase().contains(query))
              .toList();
        }
      });
    }
  }

  void sortMusic(String criteria) {
    if (!mounted) return;
    // اگر معیار سورت تغییر کرده، آن را ست کن و دوباره سورت و فیلتر کن
    if (_currentSortCriteria != criteria) {
      setState(() {
        _currentSortCriteria = criteria;
      });
    }
    _applyFilterAndSort(); // این تابع هم سورت می‌کند و هم فیلتر
  }

  Future<void> refreshDataOnReturn() async {
    if (!mounted) return;
    print(
        "HomeScreen (My Music): refreshDataOnReturn called - forcing full refresh.");
    await _loadFavoriteSongIdentifiers();
    if (mounted) {
      await _loadMyMusicCollectionData(forceRefresh: true);
    }
  }

  Future<void> scrollToTopAndRefresh() async {
    if (!mounted) return;
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(0.0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    await _loadFavoriteSongIdentifiers();
    if (mounted) {
      await _loadMyMusicCollectionData(forceRefresh: true);
    }
  }

  Future<void> _navigateToSongDetail(
      BuildContext context, Song song, int indexInFilteredList) async {
    _prefs ??= await SharedPreferences.getInstance();
    await song
        .loadLyrics(_prefs!); // بارگذاری متن آهنگ قبل از رفتن به صفحه جزئیات
    final result = await Navigator.push(
      // نتیجه بازگشتی را می‌گیریم
      context,
      MaterialPageRoute(
        builder: (context) => SongDetailScreen(
          initialSong: song,
          songList: _filteredMyMusicCollection,
          initialIndex: indexInFilteredList,
        ),
      ),
    );
    if (mounted) {
      // پس از بازگشت، ممکن است وضعیت علاقه‌مندی‌ها یا دانلود تغییر کرده باشد
      await refreshDataOnReturn();
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
      bodyContent = Center(
          child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(_loadingError,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge
                      ?.copyWith(color: colorScheme.error))));
    } else if (_myMusicCollection.isEmpty) {
      // اگر _myMusicCollection (نه _filtered) خالی باشد
      bodyContent = Center(
          child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                  "No music found in 'My Music'.\nDownload songs from the Shop or check your Local Music tab.",
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7)))));
    } else if (_filteredMyMusicCollection.isEmpty &&
        _searchController.text.isNotEmpty) {
      bodyContent = Center(
          child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text("No music found for '${_searchController.text}'.",
                  style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7)))));
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
            // ... (منطق leadingWidget مثل قبل، بدون تغییر)
            if (song.isLocal &&
                song.mediaStoreId != null &&
                song.mediaStoreId! > 0) {
              leadingWidget = SizedBox(
                  width: 55,
                  height: 55,
                  child: QueryArtworkWidget(
                    id: song.mediaStoreId!,
                    type: ArtworkType.AUDIO,
                    artworkFit: BoxFit.cover,
                    artworkBorder: BorderRadius.circular(6.0),
                    artworkClipBehavior: Clip.antiAlias,
                    nullArtworkWidget: Container(
                        width: 55,
                        height: 55,
                        decoration: BoxDecoration(
                            color: colorScheme.surfaceVariant.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(6.0)),
                        child: Icon(Icons.music_note_rounded,
                            color:
                                colorScheme.onSurfaceVariant.withOpacity(0.6),
                            size: 30)),
                    errorBuilder: (_, __, ___) => Container(
                        width: 55,
                        height: 55,
                        decoration: BoxDecoration(
                            color: (colorScheme.errorContainer ?? Colors.red)
                                .withOpacity(0.3),
                            borderRadius: BorderRadius.circular(6.0)),
                        child: Icon(Icons.broken_image_outlined,
                            color: colorScheme.onErrorContainer
                                    ?.withOpacity(0.6) ??
                                Colors.redAccent,
                            size: 30)),
                  ));
            } else if (song.coverImagePath != null &&
                song.coverImagePath!.isNotEmpty) {
              leadingWidget = ClipRRect(
                  borderRadius: BorderRadius.circular(6.0),
                  child: Image.asset(song.coverImagePath!,
                      width: 55,
                      height: 55,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          width: 55,
                          height: 55,
                          decoration: BoxDecoration(
                              color:
                                  colorScheme.surfaceVariant.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(6.0)),
                          child: Icon(Icons.album_rounded,
                              color:
                                  colorScheme.onSurfaceVariant.withOpacity(0.6),
                              size: 30))));
            } else {
              leadingWidget = Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(6.0)),
                  child: Icon(Icons.music_note_rounded,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                      size: 30));
            }

            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              leading: SizedBox(width: 55, height: 55, child: leadingWidget),
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (song.isDownloaded)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Tooltip(
                        // اطمینان از استفاده از Tooltip
                        message: "Downloaded",
                        child: Icon(Icons.get_app_rounded,
                            color: colorScheme.primary.withOpacity(0.7),
                            size: 20),
                      ),
                    ),
                  IconButton(
                      icon: Icon(
                          isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isFavorite
                              ? colorScheme.primary
                              : colorScheme.onSurface.withOpacity(0.6),
                          size: 24),
                      tooltip: isFavorite
                          ? "Remove from favorites"
                          : "Add to favorites",
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
              prefixIcon: Icon(Icons.search_rounded,
                  color: colorScheme.onSurface.withOpacity(0.6)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded,
                          color: colorScheme.onSurface.withOpacity(0.6)),
                      tooltip: "Clear search",
                      onPressed: () => _searchController
                          .clear() // Listener متصل به controller، _applyFilterAndSort را صدا می‌زند
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
