// lib/favorites_screen.dart
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart'; // برای QueryArtworkWidget
import 'package:shared_preferences/shared_preferences.dart';
import 'song_model.dart';
import 'song_detail_screen.dart';
import 'shared_pref_keys.dart'; // <--- اضافه شد

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Song> _favoriteSongs = [];
  bool _isLoading = true;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    print("FavoritesScreen: initState called");
    _initPrefsAndLoadFavorites();
  }

  Future<void> _initPrefsAndLoadFavorites() async {
    _prefs = await SharedPreferences.getInstance();
    if (mounted) {
      await _loadFavoriteSongs();
    }
  }

  Future<void> _loadFavoriteSongs() async {
    if (!mounted || _prefs == null) {
      if (_prefs == null) print("FavoritesScreen: SharedPreferences not initialized in _loadFavoriteSongs.");
      if (mounted) setState(() => _isLoading = false); // اگر prefs نیست، نمی‌توانیم لود کنیم
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
          await song.loadLyrics(_prefs!); // بارگذاری جداگانه lyrics
          loadedSongs.add(song);
        } catch (e) {
          print("FavoritesScreen: Error parsing or loading lyrics for favorite song data: $dataString, Error: $e");
        }
      }
      if (mounted) {
        setState(() {
          _favoriteSongs = loadedSongs;
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

  Future<void> _removeFromFavorites(Song songToRemove) async {
    if (_prefs == null) return;

    List<String> favoriteDataStrings = _prefs!.getStringList(SharedPrefKeys.favoriteSongsDataList) ?? [];
    List<String> favoriteIdentifiers = _prefs!.getStringList(SharedPrefKeys.favoriteSongIdentifiers) ?? [];

    final String songIdentifierToRemove = songToRemove.uniqueIdentifier;

    // حذف از لیست شناسه‌ها
    bool removedFromIdentifiers = favoriteIdentifiers.remove(songIdentifierToRemove);
    // حذف از لیست داده‌های کامل
    int initialDataLength = favoriteDataStrings.length;
    favoriteDataStrings.removeWhere((dataString) {
      try {
        final song = Song.fromDataString(dataString);
        return song.uniqueIdentifier == songIdentifierToRemove;
      } catch(e) { return false; }
    });
    bool removedFromData = favoriteDataStrings.length < initialDataLength;

    if (removedFromIdentifiers || removedFromData) { // اگر حداقل از یکی حذف شده باشد
      await _prefs!.setStringList(SharedPrefKeys.favoriteSongsDataList, favoriteDataStrings);
      await _prefs!.setStringList(SharedPrefKeys.favoriteSongIdentifiers, favoriteIdentifiers);

      // حذف متن آهنگ ذخیره شده برای این آهنگ (اختیاری، اما برای تمیزی خوب است)
      await _prefs!.remove(SharedPrefKeys.lyricsDataKeyForSong(songIdentifierToRemove));

      if (mounted) {
        // به جای بارگذاری مجدد کل لیست، فقط آیتم را از لیست محلی حذف می‌کنیم
        setState(() {
          _favoriteSongs.removeWhere((song) => song.uniqueIdentifier == songIdentifierToRemove);
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
    // اطمینان از اینکه lyrics برای آهنگ انتخاب شده بارگذاری شده است
    // (اگرچه در _loadFavoriteSongs باید انجام شده باشد، اما برای اطمینان)
    if (_prefs == null) _prefs = await SharedPreferences.getInstance();
    await song.loadLyrics(_prefs!);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongDetailScreen(
          initialSong: song,
          songList: _favoriteSongs, // ارسال لیست فعلی علاقه‌مندی‌ها به عنوان پلی‌لیست
          initialIndex: index,
        ),
      ),
    ).then((_) {
      // پس از بازگشت از SongDetailScreen، ممکن است وضعیت علاقه‌مندی‌ها تغییر کرده باشد
      // (مثلاً آهنگی از خود SongDetailScreen به علاقه‌مندی‌ها اضافه یا حذف شده باشد)
      // بنابراین لیست را دوباره بارگذاری می‌کنیم.
      if (mounted) {
        _loadFavoriteSongs();
      }
    });
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

          // منطق نمایش کاور مشابه سایر لیست‌ها
          if (song.isLocal && song.mediaStoreId != null && song.mediaStoreId! > 0) {
            leadingWidget = SizedBox(
              width: 50, height: 50,
              child: QueryArtworkWidget(
                id: song.mediaStoreId!,
                type: ArtworkType.AUDIO,
                artworkFit: BoxFit.cover,
                artworkBorder: BorderRadius.circular(4.0),
                artworkClipBehavior: Clip.antiAlias,
                // NO padding for on_audio_query ^2.9.0
                nullArtworkWidget: Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4.0)),
                    child: Icon(Icons.music_note_rounded,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.6), size: 30)),
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