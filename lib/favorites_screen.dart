// lib/favorites_screen.dart
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'song_model.dart';
import 'song_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Song> _favoriteSongs = [];
  bool _isLoading = true;

  static const String favoriteSongsDataKey = 'favorite_songs_data_list';

  @override
  void initState() {
    super.initState();
    print("FavoritesScreen: initState called");
    _loadFavoriteSongs();
  }

  Future<void> _loadFavoriteSongs() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> favoriteDataStrings =
          prefs.getStringList(favoriteSongsDataKey) ?? [];

      List<Song> loadedSongs = [];
      for (String dataString in favoriteDataStrings) {
        final parts = dataString.split(';;');
        if (parts.length >= 6) {
          try {
            loadedSongs.add(Song(
              title: parts[0],
              artist: parts[1],
              audioUrl: parts[2],
              coverImagePath: parts[3].isNotEmpty ? parts[3] : null,
              isLocal: parts[4] == 'true',
              mediaStoreId: parts[5] != 'null' ? int.tryParse(parts[5]) : null,
            ));
          } catch (e) {
            print(
                "FavoritesScreen: Error parsing favorite song data: $dataString, Error: $e");
          }
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
    final prefs = await SharedPreferences.getInstance();
    List<String> favoriteDataStrings =
        prefs.getStringList(favoriteSongsDataKey) ?? [];

    final String songIdentifierToRemove =
        "${songToRemove.title};;${songToRemove.artist}";

    favoriteDataStrings.removeWhere((dataString) {
      final parts = dataString.split(';;');
      return parts[0] == songToRemove.title && parts[1] == songToRemove.artist;
    });

    await prefs.setStringList(favoriteSongsDataKey, favoriteDataStrings);

    if (mounted) {
      _loadFavoriteSongs();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('"${songToRemove.title}" removed from favorites.')),
      );
    }
  }

  void _navigateToSongDetail(BuildContext context, Song song, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongDetailScreen(
          initialSong: song,
          songList: _favoriteSongs,
          initialIndex: index,
        ),
      ),
    ).then((_) {
      _loadFavoriteSongs();
    });
  }

  @override
  Widget build(BuildContext context) {
    print(
        "FavoritesScreen: build called, isLoading: $_isLoading, song count: ${_favoriteSongs.length}");
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
                        Icon(Icons.favorite_border_rounded,
                            size: 80, color: Colors.grey[700]),
                        const SizedBox(height: 24),
                        Text(
                          'No Favorite Songs Yet',
                          style: textTheme.headlineSmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.8)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tap the heart icon on songs to add them to your favorites.',
                          style: textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
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
                    if (song.isLocal &&
                        song.mediaStoreId != null &&
                        song.mediaStoreId! > 0) {
                      leadingWidget = QueryArtworkWidget(
                        id: song.mediaStoreId!,
                        type: ArtworkType.AUDIO,
                        artworkFit: BoxFit.cover,
                        artworkBorder: BorderRadius.circular(4.0),
                        artworkClipBehavior: Clip.antiAlias,
                        nullArtworkWidget: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                                color:
                                    colorScheme.surfaceVariant.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(4.0)),
                            child: Icon(Icons.music_note_rounded,
                                color: colorScheme.onSurfaceVariant
                                    .withOpacity(0.6),
                                size: 30)),
                      );
                    } else if (song.coverImagePath != null &&
                        song.coverImagePath!.isNotEmpty) {
                      leadingWidget = ClipRRect(
                          borderRadius: BorderRadius.circular(4.0),
                          child: Image.asset(song.coverImagePath!,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, st) => Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                      color: colorScheme.surfaceVariant
                                          .withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(4.0)),
                                  child: Icon(Icons.album_rounded,
                                      color: colorScheme.onSurfaceVariant
                                          .withOpacity(0.6),
                                      size: 30))));
                    } else {
                      leadingWidget = Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                              color:
                                  colorScheme.surfaceVariant.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(4.0)),
                          child: Icon(Icons.music_note_rounded,
                              color:
                                  colorScheme.onSurfaceVariant.withOpacity(0.6),
                              size: 30));
                    }

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      leading:
                          SizedBox(width: 50, height: 50, child: leadingWidget),
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
                        icon: Icon(Icons.favorite_rounded,
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
