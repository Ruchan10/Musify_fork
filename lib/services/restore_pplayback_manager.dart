import 'dart:convert';

import 'package:musify_fork/models/playback_state_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflinePlaybackStore {
  static const _key = 'offline_playback_state';

  static Future<void> save(OfflinePlaybackState state) async {  
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(state.toJson());
    await prefs.setString(_key, jsonStr);
  }

  static Future<OfflinePlaybackState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) return null;

    final jsonMap = jsonDecode(jsonStr);
    return OfflinePlaybackState.fromJson(jsonMap);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
