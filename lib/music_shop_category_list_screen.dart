// lib/music_shop_category_list_screen.dart
import 'package:flutter/material.dart';
import 'song_model.dart';
import 'music_shop_song_detail_screen.dart';

class MusicShopCategoryListScreen extends StatefulWidget {
  final String categoryName;
  const MusicShopCategoryListScreen({super.key, required this.categoryName});

  @override
  State<MusicShopCategoryListScreen> createState() => _MusicShopCategoryListScreenState();
}

class _MusicShopCategoryListScreenState extends State<MusicShopCategoryListScreen> {
  List<Song> _categorySongs = []; // لیست اصلی آهنگ‌های این دسته
  List<Song> _filteredCategorySongs = []; // لیست فیلتر شده برای نمایش
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSongsForCategory();
    // Listener برای TextField جستجو
    _searchController.addListener(_filterCategorySongs); // <--- فراخوانی متدی که باید تعریف شود
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterCategorySongs); // حذف listener
    _searchController.dispose();
    super.dispose();
  }

  void _loadSongsForCategory() {
    List<Song> tempSongs = [];
    // ... (تعریف آهنگ‌ها با coverImagePath مثل قبل)
    if (widget.categoryName.contains('Pop') || widget.categoryName.contains('Latest')) {
      tempSongs = [
        Song(
            title: "Pop Hit Deluxe", artist: "Pop Supernova",
            coverImagePath: "assets/covers/cover1.jpg",
            price: 0, averageRating: 4.6,
            sampleAudioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
            audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
            requiredAccessTier: SongAccessTier.standard),
        Song(
            title: "Pop Sensation (VIP Exclusive)", artist: "Rising PopStar",
            coverImagePath: "assets/covers/cover2.jpg",
            price: 1200, averageRating: 3.9,
            sampleAudioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
            audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
            requiredAccessTier: SongAccessTier.premium),
        Song(
            title: "Free Pop Sample", artist: "Community Artist",
            coverImagePath: "assets/covers/A.jpg",
            price: 0, averageRating: 3.5,
            sampleAudioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3",
            audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3",
            requiredAccessTier: SongAccessTier.free),
      ];
    } else if (widget.categoryName.contains('Rock')) {
      tempSongs = [
        Song(
            title: "Rock Legend Anthem", artist: "The Titans",
            coverImagePath: "assets/covers/cover3.jpg",
            price: 1000, averageRating: 4.1,
            sampleAudioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3",
            audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3",
            requiredAccessTier: SongAccessTier.standard),
        Song(
            title: "Indie Rock Discovery (Free)", artist: "Garage Heroes",
            coverImagePath: "assets/covers/cover4.jpg",
            price: 0, averageRating: 4.3,
            sampleAudioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3",
            audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3",
            requiredAccessTier: SongAccessTier.free),
        Song(
            title: "Heavy Metal VIP", artist: "Metal Gods",
            coverImagePath: "assets/covers/S.jpg",
            price: 0, averageRating: 4.8,
            sampleAudioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-11.mp3",
            audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-11.mp3",
            requiredAccessTier: SongAccessTier.premium),
      ];
    } else {
      tempSongs = [
        Song(
            title: "${widget.categoryName} - Groovy Track (VIP)", artist: "Artist Collective",
            coverImagePath: "assets/covers/cover5.jpg",
            price: 0, averageRating: 4.0,
            sampleAudioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3",
            audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3",
            requiredAccessTier: SongAccessTier.premium),
        Song(
            title: "${widget.categoryName} - Jam Track (Standard)", artist: "Community Sound",
            coverImagePath: "assets/covers/cover6.jpg",
            price: 800, averageRating: 3.7,
            sampleAudioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3",
            audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3",
            requiredAccessTier: SongAccessTier.standard),
        Song(
            title: "${widget.categoryName} - Free Beat", artist: "Producer X",
            coverImagePath: "assets/covers/N.jpg",
            price: 0, averageRating: 3.2,
            sampleAudioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3",
            audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3",
            requiredAccessTier: SongAccessTier.free),
      ];
    }

    if (mounted) {
      setState(() {
        _categorySongs = tempSongs;
        _filteredCategorySongs = List.from(_categorySongs); // مقداردهی اولیه لیست فیلتر شده
      });
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
                hintStyle: theme.inputDecorationTheme.hintStyle ?? TextStyle(color: Colors.grey[600]),
                fillColor: theme.inputDecorationTheme.fillColor ?? const Color(0xFF2C2C2E),
                filled: theme.inputDecorationTheme.filled ?? true,
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]!),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[600]!, size: 20),
                    onPressed: () {
                      _searchController.clear(); // این باعث فراخوانی _filterCategorySongs هم می‌شود
                    }
                )
                    : null,
                border: theme.inputDecorationTheme.border ?? OutlineInputBorder(borderRadius: BorderRadius.circular(30.0), borderSide: BorderSide.none),
                enabledBorder: theme.inputDecorationTheme.enabledBorder ?? OutlineInputBorder(borderRadius: BorderRadius.circular(30.0), borderSide: BorderSide(color: (theme.inputDecorationTheme.fillColor ?? const Color(0xFF2C2C2E)).withOpacity(0.5))),
                focusedBorder: theme.inputDecorationTheme.focusedBorder ?? OutlineInputBorder(borderRadius: BorderRadius.circular(30.0), borderSide: BorderSide(color: colorScheme.primary, width: 1.5)),
                contentPadding: theme.inputDecorationTheme.contentPadding ?? const EdgeInsets.symmetric(vertical: 14.0, horizontal: 20.0),
              ),
            ),
          ),
          Expanded(
            child: _filteredCategorySongs.isEmpty
                ? Center(
              child: _searchController.text.isNotEmpty
                  ? Text("No songs found for \"${_searchController.text}\"", style: textTheme.titleMedium)
                  : Text("No songs in this category yet.", style: textTheme.titleMedium),
            )
                : ListView.builder(
              padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
              itemCount: _filteredCategorySongs.length,
              itemBuilder: (context, index) {
                final song = _filteredCategorySongs[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(4.0),
                    child: (song.coverImagePath != null && song.coverImagePath!.isNotEmpty)
                        ? Image.asset(song.coverImagePath!, width: 50, height: 50, fit: BoxFit.cover,
                        errorBuilder: (ctx, err, st) => Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(4.0)), child: Icon(Icons.music_note, color: Colors.grey[700])))
                        : Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(4.0)), child: Icon(Icons.music_note, color: Colors.grey[700])),
                  ),
                  title: Text(song.title, style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(song.artist, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (song.requiredAccessTier == SongAccessTier.premium)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Icon(Icons.workspace_premium_outlined, color: Colors.amber[600], size: 18),
                        )
                      else if (song.requiredAccessTier == SongAccessTier.standard)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Icon(Icons.verified_user_outlined, color: Colors.blueAccent[100], size: 18),
                        ),
                      if (song.price > 0)
                        Text("${song.price.toStringAsFixed(0)} C", style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w500)),
                      if (song.price == 0 && song.requiredAccessTier == SongAccessTier.free)
                        Text("Free", style: TextStyle(color: Colors.greenAccent[400], fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios, color: colorScheme.onSurface.withOpacity(0.7).withOpacity(0.7), size: 16),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MusicShopSongDetailScreen(shopSong: song),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}