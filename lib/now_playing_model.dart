// lib/now_playing_model.dart
import 'package:just_audio/just_audio.dart';
import 'song_model.dart'; // مطمئن شوید مسیر SongModel صحیح است

class NowPlayingModel {
  final Song song;
  final AudioPlayer audioPlayer; // خود audio player instance
  final bool isPlaying;
  final List<Song> currentPlaylist; // لیست آهنگ‌های فعلی برای next/previous
  final int currentIndexInPlaylist; // ایندکس آهنگ فعلی در لیست

  NowPlayingModel({
    required this.song,
    required this.audioPlayer,
    required this.isPlaying,
    required this.currentPlaylist,
    required this.currentIndexInPlaylist,
  });

  NowPlayingModel copyWith({
    Song? song,
    AudioPlayer? audioPlayer,
    bool? isPlaying,
    List<Song>? currentPlaylist,
    int? currentIndexInPlaylist,
  }) {
    return NowPlayingModel(
      song: song ?? this.song,
      audioPlayer: audioPlayer ?? this.audioPlayer,
      isPlaying: isPlaying ?? this.isPlaying,
      currentPlaylist: currentPlaylist ?? this.currentPlaylist,
      currentIndexInPlaylist: currentIndexInPlaylist ?? this.currentIndexInPlaylist,
    );
  }
}