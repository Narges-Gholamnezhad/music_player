// lib/music_shop_category_list_screen.dart
import 'package:flutter/material.dart';
import 'song_model.dart';
import 'music_shop_song_detail_screen.dart';
import 'socket_service.dart';
import 'dart:async';

class MusicShopCategoryListScreen extends StatefulWidget {
  final String categoryName;

  const MusicShopCategoryListScreen({super.key, required this.categoryName});

  @override
  State<MusicShopCategoryListScreen> createState() =>
      _MusicShopCategoryListScreenState();
}

class _MusicShopCategoryListScreenState
    extends State<MusicShopCategoryListScreen> {
  List<Song> _categorySongs = []; // لیست اصلی آهنگ‌های این دسته
  List<Song> _filteredCategorySongs = []; // لیست فیلتر شده برای نمایش
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true; // This will control our loading circle

  @override
  void initState() {
    super.initState();
    _loadSongsForCategory();
    // Listener برای TextField جستجو
    _searchController.addListener(
        _filterCategorySongs); // <--- فراخوانی متدی که باید تعریف شود
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterCategorySongs); // حذف listener
    _searchController.dispose();
    super.dispose();
  }

  // This new version talks to your Java server
  Future<void> _loadSongsForCategory() async {
    // Step 1: Show the loading circle
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    // Step 2: Prepare to talk to the server
    final socketService = SocketService();
    await socketService.connect(); // Make sure we are connected

    // Step 3: Create a system to wait for the server's full response
    final completer = Completer<List<Song>>();
    final List<Song> receivedSongs = [];
    StreamSubscription? subscription;

    // Step 4: Listen for messages from the server
    subscription = socketService.responses.listen((response) {
      // A) If the message is a song...
      if (response.startsWith("SONG_DATA::")) {
        final parts = response.split("::");
        // The parts are: [0]SONG_DATA, [1]title, [2]artist, [3]cover, [4]url, [5]price, [6]tier
        if (parts.length >= 7) {
          try {
            // ...create a Song object from the data...
            final song = Song(
              title: parts[1],
              artist: parts[2],
              coverImagePath: parts[3] == 'null' ? null : parts[3],
              audioUrl: parts[4],
              price: double.tryParse(parts[5]) ?? 0.0,
              requiredAccessTier: SongAccessTier.values.firstWhere(
                  (e) => e.name == parts[6],
                  orElse: () => SongAccessTier.free),
            );
            // ...and add it to our list.
            receivedSongs.add(song);
          } catch (e) {
            print("Error parsing song data from server: $e");
          }
        }
      }
      // B) If the message is the "all done" signal...
      else if (response == "SONGS_END") {
        // ...the list is complete!
        if (!completer.isCompleted) {
          subscription?.cancel(); // Stop listening
          completer.complete(receivedSongs); // Mark our waiting as "finished"
        }
      }
    });

    // Step 5: Send the actual command to the server
    socketService.sendCommand("GET_SONGS_BY_CATEGORY::${widget.categoryName}");

    // Step 6: Wait for the process to complete (or time out)
    try {
      // Wait for the completer from Step 4B to be marked as "finished"
      final songsFromServer =
          await completer.future.timeout(const Duration(seconds: 10));

      // Success! Update the screen with the new songs
      if (mounted) {
        setState(() {
          _categorySongs = songsFromServer;
          _filteredCategorySongs = List.from(_categorySongs);
          _isLoading = false; // Hide the loading circle
        });
      }
    } catch (e) {
      print("Failed to get songs from server (timeout or error): $e");
      if (mounted) {
        setState(() {
          _isLoading =
              false; // Hide the loading circle even if there's an error
        });
      }
    } finally {
      subscription?.cancel(); // Final cleanup to prevent memory leaks
    }
  }

  // ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  // تعریف متد _filterCategorySongs
  // ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  void _filterCategorySongs() {
    final query = _searchController.text.toLowerCase().trim();
    if (mounted) {
      setState(() {
        if (query.isEmpty) {
          _filteredCategorySongs = List.from(_categorySongs);
        } else {
          _filteredCategorySongs = _categorySongs.where((song) {
            final titleLower = song.title.toLowerCase();
            final artistLower = song.artist.toLowerCase();
            return titleLower.contains(query) || artistLower.contains(query);
          }).toList();
        }
      });
    }
  }

  // ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search in ${widget.categoryName}...',
                hintStyle: theme.inputDecorationTheme.hintStyle ??
                    TextStyle(color: Colors.grey[600]),
                fillColor: theme.inputDecorationTheme.fillColor ??
                    const Color(0xFF2C2C2E),
                filled: theme.inputDecorationTheme.filled ?? true,
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]!),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            color: Colors.grey[600]!, size: 20),
                        onPressed: () {
                          _searchController
                              .clear(); // این باعث فراخوانی _filterCategorySongs هم می‌شود
                        })
                    : null,
                border: theme.inputDecorationTheme.border ??
                    OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        borderSide: BorderSide.none),
                enabledBorder: theme.inputDecorationTheme.enabledBorder ??
                    OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        borderSide: BorderSide(
                            color: (theme.inputDecorationTheme.fillColor ??
                                    const Color(0xFF2C2C2E))
                                .withOpacity(0.5))),
                focusedBorder: theme.inputDecorationTheme.focusedBorder ??
                    OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        borderSide:
                            BorderSide(color: colorScheme.primary, width: 1.5)),
                contentPadding: theme.inputDecorationTheme.contentPadding ??
                    const EdgeInsets.symmetric(
                        vertical: 14.0, horizontal: 20.0),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCategorySongs.isEmpty
                    ? Center(
                        child: _searchController.text.isNotEmpty
                            ? Text(
                                "No songs found for \"${_searchController.text}\"",
                                style: textTheme.titleMedium)
                            : Text("No songs in this category yet.",
                                style: textTheme.titleMedium),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                        itemCount: _filteredCategorySongs.length,
                        itemBuilder: (context, index) {
                          final song = _filteredCategorySongs[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 6.0),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(4.0),
                              child: (song.coverImagePath != null &&
                                      song.coverImagePath!.isNotEmpty)
                                  ? Image.asset(song.coverImagePath!,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, st) => Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                              color: Colors.grey[850],
                                              borderRadius:
                                                  BorderRadius.circular(4.0)),
                                          child: Icon(Icons.music_note,
                                              color: Colors.grey[700])))
                                  : Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                          color: Colors.grey[850],
                                          borderRadius:
                                              BorderRadius.circular(4.0)),
                                      child: Icon(Icons.music_note,
                                          color: Colors.grey[700])),
                            ),
                            title: Text(song.title,
                                style: textTheme.titleSmall?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            subtitle: Text(song.artist,
                                style: textTheme.bodyMedium?.copyWith(
                                    color:
                                        colorScheme.onSurface.withOpacity(0.7)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (song.requiredAccessTier ==
                                    SongAccessTier.premium)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Icon(
                                        Icons.workspace_premium_outlined,
                                        color: Colors.amber[600],
                                        size: 18),
                                  )
                                else if (song.requiredAccessTier ==
                                    SongAccessTier.standard)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Icon(Icons.verified_user_outlined,
                                        color: Colors.blueAccent[100],
                                        size: 18),
                                  ),
                                if (song.price > 0)
                                  Text("${song.price.toStringAsFixed(0)} C",
                                      style: TextStyle(
                                          color: colorScheme.onSurface
                                              .withOpacity(0.7),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500)),
                                if (song.price == 0 &&
                                    song.requiredAccessTier ==
                                        SongAccessTier.free)
                                  Text("Free",
                                      style: TextStyle(
                                          color: Colors.greenAccent[400],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500)),
                                const SizedBox(width: 8),
                                Icon(Icons.arrow_forward_ios,
                                    color: colorScheme.onSurface
                                        .withOpacity(0.7)
                                        .withOpacity(0.7),
                                    size: 16),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      MusicShopSongDetailScreen(shopSong: song),
                                ),
                              );
                            },
                          );
                        },
                      ),
          )
        ],
      ),
    );
  }
}
