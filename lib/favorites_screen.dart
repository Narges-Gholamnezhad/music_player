// lib/favorites_screen.dart
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart'; // برای QueryArtworkWidget
import 'package:shared_preferences/shared_preferences.dart';
import 'song_model.dart';
import 'song_detail_screen.dart';
import 'shared_pref_keys.dart';
import 'main_tabs_screen.dart'; // برای دسترسی به _showSortOptionsDialog اگر لازم باشد

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Song> _favoriteSongs = [];
  bool _isLoading = true;
  SharedPreferences? _prefs;
  String _currentSortCriteria = 'date_desc'; // پیش‌فرض: جدیدترین علاقه‌مندی‌ها اول

  @override
  void initState() {
    super.initState();
    print("FavoritesScreen: initState called");
    _initPrefsAndLoadFavorites();
  }

  Future<void> _initPrefsAndLoadFavorites() async {
    _prefs = await SharedPreferences.getInstance();
    if (mounted) {
      await _loadFavoriteSongs(); // این تابع سورت اولیه را هم انجام می‌دهد
    }
  }

  Future<void> _loadFavoriteSongs() async {
    if (!mounted || _prefs == null) {
      if (_prefs == null) print("FavoritesScreen: SharedPreferences not initialized in _loadFavoriteSongs.");
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final List<String> favoriteDataStrings =
          _prefs!.getStringList(SharedPrefKeys.favoriteSongsDataList) ?? [];

      List<Song> loadedSongs = [];
      for (String dataString in favoriteDataStrings) {
        try {
          final song = Song.fromDataString(dataString);
          // dateAdded باید از fromDataString خوانده شده باشد
          await song.loadLyrics(_prefs!);
          loadedSongs.add(song);
        } catch (e) {
          print("FavoritesScreen: Error parsing or loading lyrics for favorite song data: $dataString, Error: $e");
        }
      }
      if (mounted) {
        _favoriteSongs = loadedSongs;
        _sortFavoriteSongsInternal(); // مرتب‌سازی اولیه بر اساس _currentSortCriteria
        setState(() {
          _isLoading = false;
        });
      }
      print("FavoritesScreen: Loaded ${_favoriteSongs.length} favorite songs.");
    } catch (e) {
      print("FavoritesScreen: Error loading favorites: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load favorites.')),
        );
      }
    }
  }

  void _sortFavoriteSongsInternal() {
    if (_favoriteSongs.isEmpty) return;
    // این متد _favoriteSongs را مستقیما مرتب می‌کند
    _favoriteSongs.sort((a, b) {
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
        case 'date_desc': // جدیدترین اول (بر اساس زمان افزودن به علاقه‌مندی‌ها)
          final dateA = a.dateAdded; // در اینجا از dateAdded استفاده می‌کنیم نه effectiveDateAdded
          final dateB = b.dateAdded;
          if (dateA == null && dateB == null) comparisonResult = 0;
          else if (dateA == null) comparisonResult = 1; // null ها آخر
          else if (dateB == null) comparisonResult = -1;
          else comparisonResult = dateB.compareTo(dateA);
          break;
        case 'date_asc': // قدیمی‌ترین اول
          final dateA = a.dateAdded;
          final dateB = b.dateAdded;
          if (dateA == null && dateB == null) comparisonResult = 0;
          else if (dateA == null) comparisonResult = 1;
          else if (dateB == null) comparisonResult = -1;
          else comparisonResult = dateA.compareTo(dateB);
          break;
        default:
          comparisonResult = 0; // یا سورت پیش‌فرض دیگر
      }
      return comparisonResult;
    });
  }

  // متد برای فراخوانی از بیرون یا از دیالوگ سورت
  void sortFavorites(String criteria) {
    if (!mounted || _isLoading) return;
    // if (_currentSortCriteria == criteria && _favoriteSongs.isNotEmpty) return; // اگر معیار یکی است، سورت نکن
    setState(() {
      _currentSortCriteria = criteria;
      _sortFavoriteSongsInternal(); // لیست را با معیار جدید مرتب کن
    });
  }


  Future<void> _removeFromFavorites(Song songToRemove) async {
    if (_prefs == null) return;

    List<String> favoriteDataStrings = _prefs!.getStringList(SharedPrefKeys.favoriteSongsDataList) ?? [];
    List<String> favoriteIdentifiers = _prefs!.getStringList(SharedPrefKeys.favoriteSongIdentifiers) ?? [];

    final String songIdentifierToRemove = songToRemove.uniqueIdentifier;

    bool removedFromIdentifiers = favoriteIdentifiers.remove(songIdentifierToRemove);
    int initialDataLength = favoriteDataStrings.length;
    favoriteDataStrings.removeWhere((dataString) {
      try {
        final song = Song.fromDataString(dataString);
        return song.uniqueIdentifier == songIdentifierToRemove;
      } catch(e) { return false; }
    });
    bool removedFromData = favoriteDataStrings.length < initialDataLength;

    if (removedFromIdentifiers || removedFromData) {
      await _prefs!.setStringList(SharedPrefKeys.favoriteSongsDataList, favoriteDataStrings);
      await _prefs!.setStringList(SharedPrefKeys.favoriteSongIdentifiers, favoriteIdentifiers);
      await _prefs!.remove(SharedPrefKeys.lyricsDataKeyForSong(songIdentifierToRemove));

      if (mounted) {
        setState(() {
          _favoriteSongs.removeWhere((song) => song.uniqueIdentifier == songIdentifierToRemove);
          // نیازی به سورت مجدد نیست چون فقط یک آیتم حذف شده و ترتیب بقیه حفظ می‌شود
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${songToRemove.title}" removed from favorites.')),
        );
      }
    } else {
      print("FavoritesScreen: Song '${songToRemove.title}' not found in favorites to remove.");
    }
  }

  void _navigateToSongDetail(BuildContext context, Song song, int index) async {
    _prefs ??= await SharedPreferences.getInstance();
    await song.loadLyrics(_prefs!);

    final result = await Navigator.push( // نتیجه بازگشتی را می‌گیریم (اگر از صفحه جزئیات چیزی بازگردانده شود)
      context,
      MaterialPageRoute(
        builder: (context) => SongDetailScreen(
          initialSong: song,
          songList: _favoriteSongs, // لیست علاقه‌مندی‌ها به عنوان پلی‌لیست
          initialIndex: index,
        ),
      ),
    );
    // پس از بازگشت از SongDetailScreen، ممکن است وضعیت علاقه‌مندی‌ها تغییر کرده باشد
    // (مثلاً آهنگی از خود SongDetailScreen به علاقه‌مندی‌ها اضافه یا حذف شده باشد)
    // بنابراین لیست را دوباره بارگذاری و مرتب می‌کنیم.
    if (mounted) {
      await _loadFavoriteSongs(); // این تابع شامل سورت هم می‌شود
    }
  }

  // متد برای نمایش دیالوگ سورت (مشابه MainTabsScreen)
  Future<void> _showSortDialogForFavorites() async {
    final String? selectedCriteria = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Sort Favorites by'),
          children: <Widget>[
            SimpleDialogOption(onPressed: () => Navigator.pop(context, 'date_desc'), child: const Text('Date Added (Newest First)')),
            SimpleDialogOption(onPressed: () => Navigator.pop(context, 'date_asc'), child: const Text('Date Added (Oldest First)')),
            SimpleDialogOption(onPressed: () => Navigator.pop(context, 'title_asc'), child: const Text('Title (A-Z)')),
            SimpleDialogOption(onPressed: () => Navigator.pop(context, 'title_desc'), child: const Text('Title (Z-A)')),
            SimpleDialogOption(onPressed: () => Navigator.pop(context, 'artist_asc'), child: const Text('Artist (A-Z)')),
            SimpleDialogOption(onPressed: () => Navigator.pop(context, 'artist_desc'), child: const Text('Artist (Z-A)')),
          ],
        );
      },
    );
    if (selectedCriteria != null && mounted) {
      sortFavorites(selectedCriteria);
    }
  }


  @override
  Widget build(BuildContext context) {
    print("FavoritesScreen: build called, isLoading: $_isLoading, song count: ${_favoriteSongs.length}");
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorite Songs'),
        actions: [
          if (!_isLoading && _favoriteSongs.isNotEmpty) // دکمه سورت فقط وقتی آهنگ وجود دارد
            IconButton(
              icon: const Icon(Icons.sort),
              tooltip: "Sort Favorites",
              onPressed: _showSortDialogForFavorites,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favoriteSongs.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_border_rounded, size: 80, color: Colors.grey[700]),
              const SizedBox(height: 24),
              Text(
                'No Favorite Songs Yet',
                style: textTheme.headlineSmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.8)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Tap the heart icon on songs to add them to your favorites.',
                style: textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        itemCount: _favoriteSongs.length,
        itemBuilder: (context, index) {
          final song = _favoriteSongs[index];
          Widget leadingWidget;

          if (song.isLocal && song.mediaStoreId != null && song.mediaStoreId! > 0) {
            leadingWidget = SizedBox(
              width: 50, height: 50,
              child: QueryArtworkWidget(
                id: song.mediaStoreId!,
                type: ArtworkType.AUDIO,
                artworkFit: BoxFit.cover,
                artworkBorder: BorderRadius.circular(4.0),
                artworkClipBehavior: Clip.antiAlias,
                nullArtworkWidget: Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4.0)),
                    child: Icon(Icons.music_note_rounded,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.6), size: 30)),
                errorBuilder: (_, __, ___) => Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(color: (colorScheme.errorContainer ?? Colors.red).withOpacity(0.3), borderRadius: BorderRadius.circular(4.0)),
                  child: Icon(Icons.broken_image_outlined, color: colorScheme.onErrorContainer?.withOpacity(0.6) ?? Colors.redAccent, size: 30),
                ),
              ),
            );
          } else if (song.coverImagePath != null && song.coverImagePath!.isNotEmpty) {
            leadingWidget = ClipRRect(
                borderRadius: BorderRadius.circular(4.0),
                child: Image.asset(song.coverImagePath!,
                    width: 50, height: 50, fit: BoxFit.cover,
                    errorBuilder: (ctx, err, st) => Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                            color: colorScheme.surfaceVariant.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4.0)),
                        child: Icon(Icons.album_rounded,
                            color: colorScheme.onSurfaceVariant.withOpacity(0.6), size: 30))));
          } else {
            leadingWidget = Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4.0)),
                child: Icon(Icons.music_note_rounded,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.6), size: 30));
          }

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            leading: SizedBox(width: 50, height: 50, child: leadingWidget),
            title: Text(song.title,
                style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            subtitle: Text(song.artist,
                style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: Icon(Icons.favorite_rounded, // در صفحه علاقه‌مندی‌ها، همه آهنگ‌ها مورد علاقه هستند
                  color: colorScheme.primary),
              tooltip: "Remove from favorites",
              onPressed: () => _removeFromFavorites(song),
            ),
            onTap: () {
              _navigateToSongDetail(context, song, index);
            },
          );
        },
      ),
    );
  }
}