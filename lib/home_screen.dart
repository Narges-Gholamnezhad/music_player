// lib/home_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// on_audio_query برای آهنگ‌های محلی اسکن شده از دستگاه استفاده نمی‌شود در این نسخه،
// اما اگر بخواهید آهنگ‌های محلی را هم داشته باشید، باید QueryArtworkWidget و OnAudioQuery را نگه دارید.
// import 'package:on_audio_query/on_audio_query.dart';

import 'song_model.dart';
import 'song_detail_screen.dart';

// کلیدهای SharedPreferences که در MusicShopSongDetailScreen هم استفاده می‌شوند
const String prefFavoriteSongsDataKeyHomeScreen = 'favorite_songs_data_list'; // باید با کلید favorites_screen و music_shop_song_detail_screen یکی باشد
const String prefDownloadedSongsDataKeyHomeScreen = 'downloaded_songs_data_list_v2'; // باید با کلید music_shop_song_detail_screen یکی باشد

class HomeScreen extends StatefulWidget {
  // GlobalKey از main_tabs_screen به اینجا پاس داده می‌شود
  // final Key? key; // کلید می‌تواند از طریق constructor پاس داده شود

  const HomeScreen({super.key}); // کلید به درستی استفاده شده

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<Song> _myMusicCollection = []; // شامل آهنگ‌های نمونه اولیه + آهنگ‌های دانلود شده
  List<Song> _filteredMyMusicCollection = [];

  // برای نگهداری شناسه‌های آهنگ‌های محبوب (مثلا "title;;artist") برای بررسی سریع
  List<String> _favoriteSongLookupIdentifiers = [];

  final TextEditingController _searchController = TextEditingController();
  SharedPreferences? _prefs;
  bool _isLoading = true;
  String _loadingError = '';
  String _currentSortCriteria = 'title_asc'; // پیش‌فرض مرتب‌سازی

  // آهنگ‌های نمونه اولیه که همیشه در "My Music" هستند (مگر اینکه منطق دیگری پیاده کنید)
  // اینها می‌توانند به عنوان آهنگ‌های "پیش‌فرض" یا "همراه برنامه" در نظر گرفته شوند.
  // مطمئن شوید که isDownloaded برای اینها false است مگر اینکه واقعا از جایی دانلود شده باشند.
  final List<Song> _initialSampleUserMusic = [
    Song(
        title: "My Collection Hit 1",
        artist: "Device Artist A", // تغییر نام برای تمایز
        coverImagePath: "assets/covers/D.jpg",
        audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-15.mp3",
        isDownloaded: false, // این آهنگ نمونه است، دانلود نشده از فروشگاه
        isLocal: true, // فرض می‌کنیم این آهنگ‌ها محلی هستند یا بخشی از برنامه
        averageRating: 4.5),
    Song(
        title: "Another Favorite Sample",
        artist: "User Choice B",
        coverImagePath: "assets/covers/OIP.jpg",
        audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-16.mp3",
        isDownloaded: false,
        isLocal: true,
        averageRating: 4.2),
    // می‌توانید آهنگ‌های نمونه بیشتری اضافه کنید
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
    await _loadFavoriteLookupIdentifiers(); // ابتدا لیست محبوب‌ها را لود کن
    await _loadMyMusicCollectionData(); // سپس کل آهنگ‌های My Music
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterMyMusicCollection);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // این متد شناسه‌های آهنگ‌های محبوب را از SharedPreferences می‌خواند
  // فرمت شناسه باید با نحوه ذخیره در _toggleFavoriteStatus هماهنگ باشد
  Future<void> _loadFavoriteLookupIdentifiers() async {
    if (_prefs == null) _prefs = await SharedPreferences.getInstance();
    final List<String> favoriteDataStrings = _prefs!.getStringList(prefFavoriteSongsDataKeyHomeScreen) ?? [];
    List<String> tempIdentifiers = [];
    for (String dataString in favoriteDataStrings) {
      try {
        final song = Song.fromDataString(dataString); // بازیابی آهنگ کامل
        tempIdentifiers.add("${song.title};;${song.artist}"); // ساخت شناسه برای جستجو
      } catch (e) {
        print("HomeScreen: Error parsing favorite song data for lookup: $dataString, Error: $e");
      }
    }
    if (mounted) {
      setState(() {
        _favoriteSongLookupIdentifiers = tempIdentifiers;
      });
    }
    print("HomeScreen: Favorite lookup identifiers refreshed: ${_favoriteSongLookupIdentifiers.length} items.");
  }

  // این متد آهنگ‌های دانلود شده از فروشگاه را از SharedPreferences می‌خواند
  Future<List<Song>> _getDownloadedSongsFromShop() async {
    if (_prefs == null) _prefs = await SharedPreferences.getInstance();
    final List<String> downloadedDataStrings = _prefs!.getStringList(prefDownloadedSongsDataKeyHomeScreen) ?? [];
    List<Song> parsedSongs = [];
    for (String dataString in downloadedDataStrings) {
      try {
        // از متد کارخانه‌ای Song.fromDataString برای تبدیل رشته به شیء Song استفاده می‌کنیم
        final song = Song.fromDataString(dataString);
        // اطمینان حاصل می‌کنیم که isDownloaded واقعا true است (باید در toDataString هم به درستی ست شده باشد)
        parsedSongs.add(song.copyWith(isDownloaded: true, isLocal: false));
      } catch (e) {
        print("HomeScreen: Error parsing downloaded song data: $dataString, Error: $e");
      }
    }
    print("HomeScreen: Loaded ${parsedSongs.length} downloaded songs from shop.");
    return parsedSongs;
  }

  // متد اصلی برای لود کردن و ترکیب آهنگ‌ها
  Future<void> _loadMyMusicCollectionData({bool forceRefresh = false}) async {
    if (!mounted) return;

    // اگر forceRefresh نیست و داده‌ها قبلاً لود شده‌اند، فقط آهنگ‌های دانلود شده را آپدیت کن
    if (!forceRefresh && !_isLoading && _myMusicCollection.isNotEmpty && _loadingError.isEmpty) {
      print("HomeScreen: Data exists, attempting to update downloaded songs and then filter/sort.");
      List<Song> downloadedFromShop = await _getDownloadedSongsFromShop();
      List<Song> newCombinedMusic = List.from(_initialSampleUserMusic); // همیشه با آهنگ‌های نمونه شروع کن

      // اضافه کردن آهنگ‌های دانلود شده (بدون تکرار با آهنگ‌های نمونه بر اساس title و artist)
      for (var shopSong in downloadedFromShop) {
        if (!newCombinedMusic.any((s) => s.title == shopSong.title && s.artist == shopSong.artist)) {
          newCombinedMusic.add(shopSong);
        }
      }
      if (mounted) {
        _myMusicCollection = newCombinedMusic; // آپدیت لیست اصلی
        _applyFilterAndSort(); // اعمال فیلتر و مرتب‌سازی مجدد
        // نیازی به setState برای isLoading نیست چون از قبل false بوده
      }
      return;
    }

    print("HomeScreen: Loading My Music collection data. Force refresh: $forceRefresh");
    setState(() {
      _isLoading = true;
      _loadingError = '';
    });

    List<Song> combinedMusic = [];
    // همیشه آهنگ‌های نمونه اولیه را اضافه کن
    combinedMusic.addAll(List.from(_initialSampleUserMusic));

    // خواندن آهنگ‌های دانلود شده از فروشگاه
    List<Song> downloadedFromShop = await _getDownloadedSongsFromShop();
    for (var shopSong in downloadedFromShop) {
      // جلوگیری از اضافه کردن آهنگ تکراری (بر اساس عنوان و خواننده)
      if (!combinedMusic.any((s) => s.title == shopSong.title && s.artist == shopSong.artist)) {
        combinedMusic.add(shopSong);
      }
    }

    if (!mounted) return;
    _myMusicCollection = combinedMusic;
    _loadingError = ''; // خطا را پاک کن اگر لود موفق بود
    _applyFilterAndSort(); // فیلتر و مرتب‌سازی اولیه
    setState(() => _isLoading = false);
    print("HomeScreen: My Music collection loaded with ${_myMusicCollection.length} songs.");
  }

  // این متد وضعیت محبوب بودن یک آهنگ را تغییر می‌دهد
  Future<void> _toggleFavoriteStatus(Song song) async {
    if (_prefs == null) _prefs = await SharedPreferences.getInstance();
    List<String> currentFavoriteDataStrings = _prefs!.getStringList(prefFavoriteSongsDataKeyHomeScreen) ?? [];
    final String songLookupIdentifier = "${song.title};;${song.artist}";
    final String songDataForStorage = song.toDataString(); // برای ذخیره اطلاعات کامل

    bool isCurrentlyInLookup = _favoriteSongLookupIdentifiers.contains(songLookupIdentifier);

    if (mounted) {
      setState(() {
        if (isCurrentlyInLookup) { // اگر در لیست lookup هست، یعنی محبوب است و باید حذف شود
          currentFavoriteDataStrings.removeWhere((data) {
            // برای حذف، باید با ساختار ذخیره شده در SharedPreferences مقایسه کنیم
            // اگر فقط title;;artist ذخیره می‌کنید، مقایسه باید بر آن اساس باشد
            // اگر Song.toDataString() ذخیره می‌کنید، باید Song.fromDataString(data) استفاده کنید
            try {
              final favSong = Song.fromDataString(data);
              return favSong.title == song.title && favSong.artist == song.artist;
            } catch (e) { return false; }
          });
          _favoriteSongLookupIdentifiers.remove(songLookupIdentifier);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('"${song.title}" removed from favorites.')));
        } else { // اگر در لیست lookup نیست، یعنی محبوب نیست و باید اضافه شود
          // ابتدا بررسی کن که آهنگ با این شناسه قبلا در لیست داده‌ها وجود نداشته باشد
          if (!currentFavoriteDataStrings.any((data) {
            try {
              final favSong = Song.fromDataString(data);
              return favSong.title == song.title && favSong.artist == song.artist;
            } catch (e) { return false; }
          })) {
            currentFavoriteDataStrings.add(songDataForStorage); // ذخیره اطلاعات کامل آهنگ
          }
          _favoriteSongLookupIdentifiers.add(songLookupIdentifier);
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('"${song.title}" added to favorites.')));
        }
      });
    }
    await _prefs!.setStringList(prefFavoriteSongsDataKeyHomeScreen, currentFavoriteDataStrings);
  }

  // این متد چک می‌کند که آیا یک آهنگ محبوب است یا نه
  bool _isSongFavorite(Song song) {
    return _favoriteSongLookupIdentifiers.contains("${song.title};;${song.artist}");
  }

  // فیلتر کردن آهنگ‌ها بر اساس متن جستجو
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

  // مرتب‌سازی داخلی لیست اصلی آهنگ‌ها
  void _sortMyMusicCollectionInternal() {
    if (_myMusicCollection.isEmpty) return;

    // مرتب‌سازی بر اساس عنوان یا خواننده
    _myMusicCollection.sort((a, b) {
      int comparisonResult;
      if (_currentSortCriteria.startsWith('title')) {
        comparisonResult = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      } else if (_currentSortCriteria.startsWith('artist')) {
        comparisonResult = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
      } else {
        comparisonResult = 0; // اگر معیار نامشخص بود
      }
      return _currentSortCriteria.endsWith('_asc') ? comparisonResult : -comparisonResult;
    });
  }

  // اعمال فیلتر و مرتب‌سازی
  void _applyFilterAndSort() {
    _sortMyMusicCollectionInternal(); // ابتدا لیست اصلی را مرتب کن
    _filterMyMusicCollection();     // سپس لیست فیلتر شده را از روی آن بساز
    if (mounted) setState(() {});   // برای به‌روزرسانی UI
  }

  // متد عمومی برای مرتب‌سازی که از بیرون (مثلاً از AppBar) فراخوانی می‌شود
  void sortMusic(String criteria) {
    if (!mounted) return;
    // اگر معیار مرتب‌سازی تغییر نکرده و لیست خالی نیست، کاری نکن
    if (_currentSortCriteria == criteria && _myMusicCollection.isNotEmpty) return;
    setState(() {
      _currentSortCriteria = criteria;
    });
    _applyFilterAndSort(); // پس از تغییر معیار، دوباره مرتب و فیلتر کن
  }

  // این متد زمانی فراخوانی می‌شود که از صفحه دیگری به HomeScreen برمی‌گردیم
  // (مثلاً از FavoritesScreen یا SongDetailScreen)
  void refreshDataOnReturn() {
    if (!mounted) return;
    print("HomeScreen (My Music): refreshDataOnReturn called. Reloading favorites and music data.");
    _loadFavoriteLookupIdentifiers().then((_) {
      _loadMyMusicCollectionData(forceRefresh: false); // forceRefresh را false می‌گذاریم تا سریعتر باشد
      // و فقط آهنگ‌های دانلود شده را بررسی کند.
      // اگر نیاز به اسکن مجدد آهنگ‌های نمونه هم هست، true کنید.
    });
  }

  // برای اسکرول به بالا و رفرش کامل داده‌ها (مثلاً با دکمه رفرش AppBar)
  void scrollToTopAndRefresh() {
    if (!mounted) return;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0.0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    _loadFavoriteLookupIdentifiers().then((_) { // همیشه اول محبوب‌ها را آپدیت کن
      _loadMyMusicCollectionData(forceRefresh: true); // سپس کل داده‌ها را با forceRefresh
    });
  }

  void _navigateToSongDetail(BuildContext context, Song song, int indexInFilteredList) {
    // اطمینان حاصل کنید که _filteredMyMusicCollection لیست درستی است که کاربر می‌بیند
    // و indexInFilteredList ایندکس صحیح در آن لیست است.
    print("HomeScreen: Navigating to detail for '${song.title}' at index $indexInFilteredList in filtered list of size ${_filteredMyMusicCollection.length}");
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongDetailScreen(
          initialSong: song, // آهنگی که کلیک شده
          songList: _filteredMyMusicCollection, // لیست کامل فیلتر شده فعلی
          initialIndex: indexInFilteredList,   // ایندکس آهنگ کلیک شده در لیست فیلتر شده
        ),
      ),
    ).then((_) {
      refreshDataOnReturn();
    });
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
                  style: TextStyle(color: colorScheme.error, fontSize: 16),
                  textAlign: TextAlign.center)));
    } else if (_myMusicCollection.isEmpty) { // اگر کل مجموعه خالی باشد
      bodyContent = Center(
          child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_note_outlined, size: 70, color: colorScheme.onSurface.withOpacity(0.5)),
                  const SizedBox(height: 20),
                  Text(
                      "Your music collection is empty.",
                      style: textTheme.headlineSmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.8)),
                      textAlign: TextAlign.center
                  ),
                  const SizedBox(height: 10),
                  Text(
                      "Download songs from the Shop tab.",
                      style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.6)),
                      textAlign: TextAlign.center
                  ),
                ],
              )
          ));
    } else if (_filteredMyMusicCollection.isEmpty && _searchController.text.isNotEmpty) { // اگر نتیجه جستجو خالی باشد
      bodyContent = Center(
          child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text("No music found for \"${_searchController.text}\"",
                  style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.6)),
                  textAlign: TextAlign.center)));
    } else { // نمایش لیست آهنگ‌ها
      bodyContent = RefreshIndicator(
        onRefresh: () async => scrollToTopAndRefresh(), // استفاده از متد کامل برای رفرش
        color: colorScheme.primary,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 70.0, top: 8.0), // پدینگ برای نوار پایین و بالا
          itemCount: _filteredMyMusicCollection.length,
          itemBuilder: (context, index) {
            final song = _filteredMyMusicCollection[index];
            final bool isFavorite = _isSongFavorite(song);

            Widget leadingWidget;
            // برای آهنگ‌های دانلود شده از فروشگاه یا آهنگ‌های نمونه، از coverImagePath استفاده می‌کنیم
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
            }
            // اگر آهنگ محلی بود و mediaStoreId داشت (و on_audio_query استفاده می‌شد)
            // else if (song.isLocal && song.mediaStoreId != null && song.mediaStoreId! > 0) {
            //   leadingWidget = QueryArtworkWidget(
            //     id: song.mediaStoreId!,
            //     type: ArtworkType.AUDIO,
            //     artworkFit: BoxFit.cover,
            //     artworkBorder: BorderRadius.circular(6.0),
            //     nullArtworkWidget: ... , // مشابه بالا
            //   );
            // }
            else { // حالت پیش‌فرض اگر کاور موجود نباشد
              leadingWidget = Container(
                  width: 55, height: 55,
                  decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(6.0)),
                  child: Icon(Icons.music_note_rounded, color: colorScheme.onSurfaceVariant.withOpacity(0.6), size: 30)
              );
            }

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              leading: SizedBox(width: 55, height: 55, child: leadingWidget),
              title: Text(song.title,
                  style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface, fontWeight: FontWeight.w500),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(song.artist,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // نمایش آیکون دانلود شده اگر آهنگ از فروشگاه دانلود شده باشد
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
                  // دکمه پخش سریع را حذف کردم چون با onTap کل ListTile به صفحه جزئیات می‌رود
                  // اگر نیاز بود، می‌توانید آن را برگردانید.
                ],
              ),
              onTap: () => _navigateToSongDetail(context, song, index), // ارسال ایندکس در لیست فیلتر شده
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
                  onPressed: () => _searchController.clear() // این باعث فراخوانی listener و فیلتر مجدد می‌شود
              )
                  : null,
              // می‌توانید از inputDecorationTheme که در main.dart تعریف کرده‌اید استفاده کنید
              // border: theme.inputDecorationTheme.border,
              // enabledBorder: theme.inputDecorationTheme.enabledBorder,
              // focusedBorder: theme.inputDecorationTheme.focusedBorder,
              // fillColor: theme.inputDecorationTheme.fillColor,
              // filled: theme.inputDecorationTheme.filled,
            ),
          ),
        ),
        Expanded(child: bodyContent),
      ],
    );
  }
}