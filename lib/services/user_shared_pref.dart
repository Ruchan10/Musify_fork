import 'dart:convert';

import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserSharedPrefs {
  Future<void> setAllSongs(bool u) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('allSongs', u);
  }

  Future<bool?> getAllSongs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('allSongs') ?? false;
  }

  Future<void> setDeviceSongs(List<SongModel> songs) async {
    final prefs = await SharedPreferences.getInstance();
    final songStrings = songs.map((song) => jsonEncode(song.getMap)).toList();
    await prefs.setStringList('songs', songStrings);
  }

  Future<List<SongModel>> getDeviceSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final songStrings = prefs.getStringList('songs');
    if (songStrings == null) return [];
    return songStrings.map((song) => SongModel(jsonDecode(song))).toList();
  }

  Future<void> setDownloadDir(String dir) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('downloadPath', dir);
  }

  static Future<void> setPlayingSong(Map song) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('playingSong', jsonEncode(song));
  }

  static Future<String> getDownloadDir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('downloadPath') ??
        '/storage/emulated/0/Music/Musify';
  }

  static Future<Map?> getPlayingSong() async {
    final prefs = await SharedPreferences.getInstance();
    final songString = prefs.getString('playingSong');
    if (songString == null) return null;
    return jsonDecode(songString);
  }
}
