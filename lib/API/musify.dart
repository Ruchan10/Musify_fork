/*
 *     Copyright (C) 2025 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:musify_fork/DB/albums.db.dart';
import 'package:musify_fork/DB/playlists.db.dart';
import 'package:musify_fork/extensions/l10n.dart';
import 'package:musify_fork/main.dart';
import 'package:musify_fork/services/data_manager.dart';
import 'package:musify_fork/services/io_service.dart';
import 'package:musify_fork/services/lyrics_manager.dart';
import 'package:musify_fork/services/settings_manager.dart';
import 'package:musify_fork/utilities/flutter_toast.dart';
import 'package:musify_fork/utilities/formatter.dart';
import 'package:musify_fork/utilities/utils.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final _yt = YoutubeExplode();

List globalSongs = [];

List playlists = [...playlistsDB, ...albumsDB];
final userPlaylists = ValueNotifier<List>(
  Hive.box('user').get('playlists', defaultValue: []),
);
final userCustomPlaylists = ValueNotifier<List>(
  Hive.box('user').get('customPlaylists', defaultValue: []),
);
List userLikedSongsList = Hive.box('user').get('likedSongs', defaultValue: []);
List userLikedPlaylists = Hive.box(
  'user',
).get('likedPlaylists', defaultValue: []);
List userRecentlyPlayed = Hive.box(
  'user',
).get('recentlyPlayedSongs', defaultValue: []);
List userOfflineSongs = Hive.box(
  'userNoBackup',
).get('offlineSongs', defaultValue: []);
List suggestedPlaylists = [];
List onlinePlaylists = [];
Map activePlaylist = {
  'ytid': '',
  'title': 'No Playlist',
  'image': '',
  'source': 'user-created',
  'list': [],
};

dynamic nextRecommendedSong;

final currentLikedSongsLength = ValueNotifier<int>(userLikedSongsList.length);
final currentLikedPlaylistsLength = ValueNotifier<int>(
  userLikedPlaylists.length,
);
final currentOfflineSongsLength = ValueNotifier<int>(userOfflineSongs.length);
final currentRecentlyPlayedLength = ValueNotifier<int>(
  userRecentlyPlayed.length,
);

final lyrics = ValueNotifier<String?>(null);
String? lastFetchedLyrics;

int activeSongId = 0;

Future<List> fetchSongsList(String searchQuery) async {
  try {
    // Try to get data from cache first
    final cacheKey = 'search_$searchQuery';
    final cachedResults = await getData('cache', cacheKey);

    if (cachedResults != null) {
      return cachedResults;
    }

    // If not in cache, perform the search
    final List<Video> searchResults = await _yt.search.search(searchQuery);
    final songsList =
        searchResults.map((video) => returnSongLayout(0, video)).toList();

    // Cache the results
    await addOrUpdateData('cache', cacheKey, songsList);

    return songsList;
  } catch (e, stackTrace) {
    logger.log('Error in fetchSongsList', e, stackTrace);
    return [];
  }
}

Future<List> getRecommendedSongs() async {
  try {
    if (defaultRecommendations.value && userRecentlyPlayed.isNotEmpty) {
      return await _getRecommendationsFromRecentlyPlayed();
    } else {
      return await _getRecommendationsFromMixedSources();
    }
  } catch (e, stackTrace) {
    logger.log('Error in getRecommendedSongs', e, stackTrace);
    return [];
  }
}

Future<List> _getRecommendationsFromRecentlyPlayed() async {
  final recent = userRecentlyPlayed.take(3).toList();

  final futures =
      recent.map((songData) async {
        try {
          final song = await _yt.videos.get(songData['ytid']);
          final relatedSongs = await _yt.videos.getRelatedVideos(song) ?? [];
          return relatedSongs
              .take(3)
              .map((s) => returnSongLayout(0, s))
              .toList();
        } catch (e, stackTrace) {
          logger.log(
            'Error getting related videos for ${songData['ytid']}',
            e,
            stackTrace,
          );
          return <Map>[];
        }
      }).toList();

  final results = await Future.wait(futures);
  final playlistSongs = results.expand((list) => list).toList()..shuffle();
  return playlistSongs;
}

Future<List> _getRecommendationsFromMixedSources() async {
  final playlistSongs = [...userLikedSongsList, ...userRecentlyPlayed];

  if (globalSongs.isEmpty) {
    const playlistId = 'PLgzTt0k8mXzEk586ze4BjvDXR7c-TUSnx';
    globalSongs = await getSongsFromPlaylist(playlistId);
  }
  playlistSongs.addAll(globalSongs.take(10));

  if (userCustomPlaylists.value.isNotEmpty) {
    for (final userPlaylist in userCustomPlaylists.value) {
      final _list = (userPlaylist['list'] as List)..shuffle();
      playlistSongs.addAll(_list.take(5));
    }
  }

  return _deduplicateAndShuffle(playlistSongs);
}

List _deduplicateAndShuffle(List playlistSongs) {
  final seenYtIds = <String>{};
  final uniqueSongs = <Map>[];

  playlistSongs.shuffle();

  for (final song in playlistSongs) {
    if (song['ytid'] != null && seenYtIds.add(song['ytid'])) {
      uniqueSongs.add(song);
      // Early exit when we have enough songs
      if (uniqueSongs.length >= 15) break;
    }
  }

  return uniqueSongs;
}

Future<List<dynamic>> getUserPlaylists() async {
  final playlistsByUser = [];
  for (final playlistID in userPlaylists.value) {
    try {
      final plist = await _yt.playlists.get(playlistID);
      playlistsByUser.add({
        'ytid': plist.id.toString(),
        'title': plist.title,
        'image': null,
        'source': 'user-youtube',
        'list': [],
      });
    } catch (e, stackTrace) {
      playlistsByUser.add({
        'ytid': playlistID.toString(),
        'title': 'Failed playlist',
        'image': null,
        'source': 'user-youtube',
        'list': [],
      });
      logger.log('Error occurred while fetching the playlist:', e, stackTrace);
    }
  }
  return playlistsByUser;
}

Future<String> addUserPlaylist(String input, BuildContext context) async {
  String? playlistId = input;

  if (input.startsWith('http://') || input.startsWith('https://')) {
    playlistId = extractYoutubePlaylistId(input);
  }

  try {
    final _playlist = await _yt.playlists.get(playlistId);

    if (userPlaylists.value.contains(playlistId)) {
      return '${context.l10n!.playlistAlreadyExists}!';
    }

    if (_playlist.title.isEmpty) {
      return '${context.l10n!.invalidYouTubePlaylist}!';
    }

    userPlaylists.value = [...userPlaylists.value, playlistId];
    await addOrUpdateData('user', 'playlists', userPlaylists.value);
    return '${context.l10n!.addedSuccess}!';
  } catch (e, stackTrace) {
    logger.log('Error adding user playlist', e, stackTrace);
    return '${context.l10n!.error}: $e';
  }
}

String createCustomPlaylist(
  String playlistName,
  String? image,
  BuildContext context,
) {
  final customPlaylist = {
    'title': playlistName,
    'source': 'user-created',
    if (image != null) 'image': image,
    'list': [],
  };
  userCustomPlaylists.value = [...userCustomPlaylists.value, customPlaylist];
  addOrUpdateData('user', 'customPlaylists', userCustomPlaylists.value);
  return '${context.l10n!.addedSuccess}!';
}

String addSongInCustomPlaylist(
  BuildContext context,
  String playlistName,
  Map song, {
  int? indexToInsert,
}) {
  final customPlaylist = userCustomPlaylists.value.firstWhere(
    (playlist) => playlist['title'] == playlistName,
    orElse: () => null,
  );

  if (customPlaylist != null) {
    final List<dynamic> playlistSongs = customPlaylist['list'];
    if (playlistSongs.any(
      (playlistElement) => playlistElement['ytid'] == song['ytid'],
    )) {
      return context.l10n!.songAlreadyInPlaylist;
    }
    indexToInsert != null
        ? playlistSongs.insert(indexToInsert, song)
        : playlistSongs.add(song);
    addOrUpdateData('user', 'customPlaylists', userCustomPlaylists.value);
    return context.l10n!.songAdded;
  } else {
    logger.log('Custom playlist not found: $playlistName', null, null);
    return context.l10n!.error;
  }
}

bool removeSongFromPlaylist(
  Map playlist,
  Map songToRemove, {
  int? removeOneAtIndex,
}) {
  try {
    if (playlist['list'] == null) return false;

    final playlistSongs = List<dynamic>.from(playlist['list']);
    if (removeOneAtIndex != null) {
      if (removeOneAtIndex < 0 || removeOneAtIndex >= playlistSongs.length) {
        return false;
      }
      playlistSongs.removeAt(removeOneAtIndex);
    } else {
      final initialLength = playlistSongs.length;
      playlistSongs.removeWhere((song) => song['ytid'] == songToRemove['ytid']);
      if (playlistSongs.length == initialLength) return false;
    }

    playlist['list'] = playlistSongs;

    try {
      if (playlist['source'] == 'user-created') {
        addOrUpdateData('user', 'customPlaylists', userCustomPlaylists.value);
      } else {
        addOrUpdateData('user', 'playlists', userPlaylists.value);
      }
    } catch (e, stackTrace) {
      logger.log('Error saving playlist changes', e, stackTrace);
      return false;
    }

    return true;
  } catch (e, stackTrace) {
    logger.log('Error while removing song from playlist: ', e, stackTrace);
    return false;
  }
}

void removeUserPlaylist(String playlistId) {
  final updatedPlaylists = List.from(userPlaylists.value)..remove(playlistId);
  userPlaylists.value = updatedPlaylists;
  addOrUpdateData('user', 'playlists', userPlaylists.value);
}

void removeUserCustomPlaylist(dynamic playlist) {
  final updatedPlaylists = List.from(userCustomPlaylists.value)
    ..remove(playlist);
  userCustomPlaylists.value = updatedPlaylists;
  addOrUpdateData('user', 'customPlaylists', userCustomPlaylists.value);
}

Future<void> updateSongLikeStatus(dynamic songId, bool add) async {
  try {
    if (add) {
      if (!userLikedSongsList.any((song) => song['ytid'] == songId)) {
        final songDetails = await getSongDetails(
          userLikedSongsList.length,
          songId,
        );
        userLikedSongsList.add(songDetails);
      }
    } else {
      userLikedSongsList.removeWhere((song) => song['ytid'] == songId);
    }

    currentLikedSongsLength.value = userLikedSongsList.length;
    await addOrUpdateData('user', 'likedSongs', userLikedSongsList);
  } catch (e, stackTrace) {
    logger.log('Error updating song like status', e, stackTrace);
  }
}

void moveLikedSong(int oldIndex, int newIndex) {
  final _song = userLikedSongsList[oldIndex];
  userLikedSongsList
    ..removeAt(oldIndex)
    ..insert(newIndex, _song);
  currentLikedSongsLength.value = userLikedSongsList.length;
  addOrUpdateData('user', 'likedSongs', userLikedSongsList);
}

Future<void> updatePlaylistLikeStatus(String playlistId, bool add) async {
  try {
    if (add) {
      if (!userLikedPlaylists.any(
        (playlist) => playlist['ytid'] == playlistId,
      )) {
        final playlist = playlists.firstWhere(
          (playlist) => playlist['ytid'] == playlistId,
          orElse: () => <String, dynamic>{},
        );

        if (playlist.isNotEmpty) {
          userLikedPlaylists.add(playlist);
        } else {
          final playlistInfo = await getPlaylistInfoForWidget(playlistId);
          if (playlistInfo != null) {
            userLikedPlaylists.add(playlistInfo);
          }
        }
      }
    } else {
      userLikedPlaylists.removeWhere(
        (playlist) => playlist['ytid'] == playlistId,
      );
    }

    currentLikedPlaylistsLength.value = userLikedPlaylists.length;
    await addOrUpdateData('user', 'likedPlaylists', userLikedPlaylists);
  } catch (e, stackTrace) {
    logger.log('Error updating playlist like status: ', e, stackTrace);
  }
}

bool isSongAlreadyLiked(songIdToCheck) =>
    userLikedSongsList.any((song) => song['ytid'] == songIdToCheck);

bool isPlaylistAlreadyLiked(playlistIdToCheck) =>
    userLikedPlaylists.any((playlist) => playlist['ytid'] == playlistIdToCheck);

bool isSongAlreadyOffline(songIdToCheck) =>
    userOfflineSongs.any((song) => song['ytid'] == songIdToCheck);

Future<List> getPlaylists({
  String? query,
  int? playlistsNum,
  bool onlyLiked = false,
  String type = 'all',
}) async {
  // Early exit if there are no playlists to process.
  if (playlists.isEmpty ||
      (playlistsNum == null && query == null && suggestedPlaylists.isEmpty)) {
    return [];
  }

  // If only liked playlists should be returned, ignore other parameters.
  if (onlyLiked) {
    if (playlistsNum != null) {
      return userLikedPlaylists.take(playlistsNum).toList();
    }
    return userLikedPlaylists;
  }

  // If a query is provided (without a limit), filter playlists based on the query and type,
  // and augment with online search results.
  if (query != null && playlistsNum == null) {
    final lowercaseQuery = query.toLowerCase();
    final filteredPlaylists =
        playlists.where((playlist) {
          final title = playlist['title'].toLowerCase();
          final matchesQuery = title.contains(lowercaseQuery);
          final matchesType =
              type == 'all' ||
              (type == 'album' && playlist['isAlbum'] == true) ||
              (type == 'playlist' && playlist['isAlbum'] != true);
          return matchesQuery && matchesType;
        }).toList();

    final searchTerm = type == 'album' ? '$query album' : query;
    final searchResults = await _yt.search.searchContent(
      searchTerm,
      filter: TypeFilters.playlist,
    );

    // Avoid duplicate online playlists.
    final existingYtIds =
        onlinePlaylists.map((p) => p['ytid'] as String).toSet();

    final newPlaylists =
        searchResults
            .whereType<SearchPlaylist>()
            .map((playlist) {
              final playlistMap = {
                'ytid': playlist.id.toString(),
                'title': playlist.title,
                'source': 'youtube',
                'list': [],
              };
              if (!existingYtIds.contains(playlistMap['ytid'])) {
                existingYtIds.add(playlistMap['ytid'].toString());
                return playlistMap;
              }
              return null;
            })
            .whereType<Map<String, dynamic>>()
            .toList();
    onlinePlaylists.addAll(newPlaylists);

    // Merge online playlists that match the query.
    filteredPlaylists.addAll(
      onlinePlaylists.where(
        (p) => p['title'].toLowerCase().contains(lowercaseQuery),
      ),
    );
    return filteredPlaylists;
  }

  // If a specific number of playlists is requested (without a query),
  // return a shuffled subset of suggested playlists.
  if (playlistsNum != null && query == null) {
    if (suggestedPlaylists.isEmpty) {
      suggestedPlaylists = List.from(playlists)..shuffle();
    }
    return suggestedPlaylists.take(playlistsNum).toList();
  }

  // If a specific type is requested, filter accordingly.
  if (type != 'all') {
    return playlists.where((playlist) {
      return type == 'album'
          ? playlist['isAlbum'] == true
          : playlist['isAlbum'] != true;
    }).toList();
  }

  // Default to returning all playlists.
  return playlists;
}

Future<List<String>> getSearchSuggestions(String query) async {
  // Custom implementation:

  // const baseUrl = 'https://suggestqueries.google.com/complete/search';
  // final parameters = {
  //   'client': 'firefox',
  //   'ds': 'yt',
  //   'q': query,
  // };

  // final uri = Uri.parse(baseUrl).replace(queryParameters: parameters);

  // try {
  //   final response = await http.get(
  //     uri,
  //     headers: {
  //       'User-Agent':
  //           'Mozilla/5.0 (Windows NT 10.0; rv:96.0) Gecko/20100101 Firefox/96.0',
  //     },
  //   );

  //   if (response.statusCode == 200) {
  //     final suggestions = jsonDecode(response.body)[1] as List<dynamic>;
  //     final suggestionStrings = suggestions.cast<String>().toList();
  //     return suggestionStrings;
  //   }
  // } catch (e, stackTrace) {
  //   logger.log('Error in getSearchSuggestions:$e\n$stackTrace');
  // }

  // Built-in implementation:

  final suggestions = await _yt.search.getQuerySuggestions(query);

  return suggestions;
}

Future<List<Map<String, int>>> getSkipSegments(String id) async {
  try {
    final res = await http.get(
      Uri(
        scheme: 'https',
        host: 'sponsor.ajay.app',
        path: '/api/skipSegments',
        queryParameters: {
          'videoID': id,
          'category': [
            'sponsor',
            'selfpromo',
            'interaction',
            'intro',
            'outro',
            'music_offtopic',
          ],
          'actionType': 'skip',
        },
      ),
    );
    if (res.body != 'Not Found') {
      final data = jsonDecode(res.body);
      final segments =
          data.map((obj) {
            return Map.castFrom<String, dynamic, String, int>({
              'start': obj['segment'].first.toInt(),
              'end': obj['segment'].last.toInt(),
            });
          }).toList();
      return List.castFrom<dynamic, Map<String, int>>(segments);
    } else {
      return [];
    }
  } catch (e, stack) {
    logger.log('Error in getSkipSegments', e, stack);
    return [];
  }
}

void getSimilarSong(String songYtId) async {
  try {
    final song = await _yt.videos.get(songYtId);
    final relatedSongs = await _yt.videos.getRelatedVideos(song) ?? [];

    if (relatedSongs.isNotEmpty) {
      nextRecommendedSong = returnSongLayout(0, relatedSongs[0]);
    }
  } catch (e, stackTrace) {
    logger.log('Error while fetching next similar song:', e, stackTrace);
  }
}

Future<List> getSongsFromPlaylist(
  dynamic playlistId, {
  String? playlistImage,
}) async {
  final songList = await getData('cache', 'playlistSongs$playlistId') ?? [];

  if (songList.isEmpty) {
    await for (final song in _yt.playlists.getVideos(playlistId)) {
      songList.add(
        returnSongLayout(songList.length, song, playlistImage: playlistImage),
      );
    }

    await addOrUpdateData('cache', 'playlistSongs$playlistId', songList);
  }

  return songList;
}

Future updatePlaylistList(BuildContext context, String playlistId) async {
  final index = findPlaylistIndexByYtId(playlistId);
  if (index != -1) {
    final songList = [];
    await for (final song in _yt.playlists.getVideos(playlistId)) {
      songList.add(returnSongLayout(songList.length, song));
    }

    playlists[index]['list'] = songList;
    await addOrUpdateData('cache', 'playlistSongs$playlistId', songList);
    showToast(context, context.l10n!.playlistUpdated);
  }
  return playlists[index];
}

int findPlaylistIndexByYtId(String ytid) {
  for (var i = 0; i < playlists.length; i++) {
    if (playlists[i]['ytid'] == ytid) {
      return i;
    }
  }
  return -1;
}

Future<void> setActivePlaylist(Map info) async {
  activePlaylist = info;
  activeSongId = 0;
  audioHandler.clearQueue();

  await audioHandler.playSong(activePlaylist['list'][activeSongId]);
}

Future<void> setLocalActivePlaylist(Map info, int index) async {
  activePlaylist = info;
  activeSongId = index;

  final songs = List<Map<String, dynamic>>.from(info['list']);

  // Clear and rebuild queue
  audioHandler.clearQueue();
  for (final song in songs) {
    await audioHandler.addToQueue(song);
  }

  // Play from first song
  await audioHandler.skipToSong(index);
}

Future<Map?> getPlaylistInfoForWidget(
  dynamic id, {
  bool isArtist = false,
}) async {
  if (isArtist) {
    try {
      return {'title': id, 'list': await fetchSongsList(id)};
    } catch (e, stackTrace) {
      logger.log('Error fetching artist songs for $id', e, stackTrace);
      return {'title': id, 'list': []};
    }
  }

  Map? playlist;

  try {
    playlist = playlists.firstWhere((p) => p['ytid'] == id, orElse: () => null);

    // Check in user playlists if not found.
    if (playlist == null) {
      final userPl = await getUserPlaylists();
      playlist = userPl.firstWhere((p) => p['ytid'] == id, orElse: () => null);
    }

    // Check in cached online playlists if still not found.
    playlist ??= onlinePlaylists.firstWhere(
      (p) => p['ytid'] == id,
      orElse: () => null,
    );

    // If still not found, attempt to fetch playlist info.
    if (playlist == null) {
      try {
        final ytPlaylist = await _yt.playlists.get(id);
        playlist = {
          'ytid': ytPlaylist.id.toString(),
          'title': ytPlaylist.title,
          'image': null,
          'source': 'user-youtube',
          'list': [],
        };
        onlinePlaylists.add(playlist);
      } catch (e, stackTrace) {
        logger.log('Failed to fetch playlist info for id $id', e, stackTrace);
        return null;
      }
    }

    // If the playlist exists but its song list is empty, fetch and cache the songs.
    if (playlist['list'] == null ||
        (playlist['list'] is List && (playlist['list'] as List).isEmpty)) {
      try {
        final playlistImage =
            playlist['isAlbum'] == true ? playlist['image'] : null;
        playlist['list'] = await getSongsFromPlaylist(
          playlist['ytid'],
          playlistImage: playlistImage,
        );
        if (!playlists.contains(playlist)) {
          playlists.add(playlist);
        }
      } catch (e, stackTrace) {
        logger.log(
          'Error fetching songs for playlist ${playlist['ytid']}',
          e,
          stackTrace,
        );
        playlist['list'] = [];
      }
    }

    return playlist;
  } catch (e, stackTrace) {
    logger.log(
      'Unexpected error in getPlaylistInfoForWidget for id $id',
      e,
      stackTrace,
    );
    return null;
  }
}

Future<AudioOnlyStreamInfo?> getSongManifest(String? songId) async {
  try {
    if (songId == null || songId.isEmpty) {
      logger.log('getSongManifest: songId is null or empty', null, null);
      return null;
    }
    final manifest = await _yt.videos.streams.getManifest(songId);
    final audioStream = manifest.audioOnly;
    if (audioStream.isEmpty) {
      logger.log('getSongManifest: no audio streams for $songId', null, null);
      return null;
    }
    return audioStream.withHighestBitrate();
  } catch (e, stackTrace) {
    logger.log('Error while getting song streaming manifest', e, stackTrace);
    return null;
  }
}

Future<String?> getSong(String songId, bool isLive) async {
  try {
    if (songId.isEmpty) {
      logger.log('getSong: songId is empty', null, null);
      return null;
    }
    if (isLive) {
      final streamInfo = await _yt.videos.streamsClient.getHttpLiveStreamUrl(
        VideoId(songId),
      );
      unawaited(updateRecentlyPlayed(songId));
      return streamInfo;
    }

    const _cacheDuration = Duration(hours: 3);
    final cacheKey = 'song_${songId}_${audioQualitySetting.value}_url';

    // Try to get from cache
    final cachedUrl = await getData(
      'cache',
      cacheKey,
      cachingDuration: _cacheDuration,
    );

    if (cachedUrl != null && cachedUrl is String && cachedUrl.isNotEmpty) {
      // Validate cached URL is still working
      try {
        final response = await http.head(Uri.parse(cachedUrl));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          unawaited(updateRecentlyPlayed(songId));
          return cachedUrl;
        }
        // If validation fails, remove from cache
        await deleteData('cache', cacheKey);
        await deleteData('cache', '${cacheKey}_date');
      } catch (_) {
        // URL validation failed, remove from cache
        await deleteData('cache', cacheKey);
        await deleteData('cache', '${cacheKey}_date');
      }
    }

    // Get fresh URL
    final manifest = await _yt.videos.streamsClient.getManifest(songId);
    final audioStreams = manifest.audioOnly;
    if (audioStreams.isEmpty) {
      logger.log('getSong: no audio streams for $songId', null, null);
      return null;
    }

    final selectedStream = selectAudioQuality(audioStreams.sortByBitrate());
    final url = selectedStream.url.toString();

    await addOrUpdateData('cache', cacheKey, url);

    unawaited(updateRecentlyPlayed(songId));
    return url;
  } catch (e, stackTrace) {
    logger.log('Error in getSong for songId $songId:', e, stackTrace);
    return null;
  }
}

AudioStreamInfo selectAudioQuality(List<AudioStreamInfo> availableSources) {
  final qualitySetting = audioQualitySetting.value;

  if (qualitySetting == 'low') {
    return availableSources.last;
  } else if (qualitySetting == 'medium') {
    return availableSources[availableSources.length ~/ 2];
  }

  return availableSources.withHighestBitrate();
}

Future<Map<String, dynamic>> getSongDetails(
  int songIndex,
  String songId,
) async {
  try {
    final song = await _yt.videos.get(songId);
    return returnSongLayout(songIndex, song);
  } catch (e, stackTrace) {
    logger.log('Error while getting song details', e, stackTrace);
    rethrow;
  }
}

Future<String?> getSongLyrics(String? artist, String title) async {
  if (artist == null) return null;
  if (lastFetchedLyrics != '$artist - $title') {
    lyrics.value = null;
    var _lyrics = await LyricsManager().fetchLyrics(artist, title);
    if (_lyrics != null) {
      _lyrics = _lyrics.replaceAll(RegExp(r'\n{2}'), '\n');
      _lyrics = _lyrics.replaceAll(RegExp(r'\n{4}'), '\n\n');
      lyrics.value = _lyrics;
    } else {
      return null;
    }

    lastFetchedLyrics = '$artist - $title';
    return _lyrics;
  }

  return lyrics.value;
}

Future<bool> makeSongOffline(dynamic song, {bool fromPlaylist = false}) async {
  try {
    final String? ytid = song['ytid'];

    if (ytid == null || ytid.isEmpty) {
      logger.log('makeSongOffline: song["ytid"] is null or empty', null, null);
      return false;
    }

    if (!fromPlaylist && isSongAlreadyOffline(ytid)) {
      return true;
    }

    final audioPath = FilePaths.getAudioPath(ytid);
    final audioFile = File(audioPath);
    final artworkPath = FilePaths.getArtworkPath(ytid);

    await audioFile.parent.create(recursive: true);

    try {
      final audioManifest = await getSongManifest(ytid);
      if (audioManifest == null) {
        logger.log(
          'makeSongOffline: audioManifest is null for $ytid',
          null,
          null,
        );
        return false;
      }
      final stream = _yt.videos.streamsClient.get(audioManifest);
      final fileStream = audioFile.openWrite();
      await stream.pipe(fileStream);
      await fileStream.flush();
      await fileStream.close();
    } catch (e, stackTrace) {
      logger.log('Error downloading audio file', e, stackTrace);
      if (await audioFile.exists()) {
        await audioFile.delete();
      }
      return false;
    }

    try {
      if (song['highResImage'] != null &&
          song['highResImage'].toString().isNotEmpty) {
        final _artworkFile = await _downloadAndSaveArtworkFile(
          song['highResImage'],
          artworkPath,
        );

        if (_artworkFile != null) {
          song['artworkPath'] = artworkPath;
          song['highResImage'] = artworkPath;
          song['lowResImage'] = artworkPath;
        }
      }
    } catch (e, stackTrace) {
      logger.log('Error downloading artwork', e, stackTrace);
    }

    song['audioPath'] = audioFile.path;
    song['isOffline'] = true;
    if (!fromPlaylist) {
      userOfflineSongs.add(song);
      await addOrUpdateData('userNoBackup', 'offlineSongs', userOfflineSongs);
      currentOfflineSongsLength.value = userOfflineSongs.length;
    }

    return true;
  } catch (e, stackTrace) {
    logger.log('Error making song offline', e, stackTrace);
    return false;
  }
}

Future<bool> removeSongFromOffline(
  dynamic songId, {
  bool fromPlaylist = false,
}) async {
  try {
    final audioPath = FilePaths.getAudioPath(songId);
    final audioFile = File(audioPath);
    final artworkPath = FilePaths.getArtworkPath(songId);
    final artworkFile = File(artworkPath);

    try {
      if (await audioFile.exists()) await audioFile.delete(recursive: true);
    } catch (e, stackTrace) {
      logger.log('Error deleting audio file', e, stackTrace);
    }

    try {
      if (await artworkFile.exists()) await artworkFile.delete(recursive: true);
    } catch (e, stackTrace) {
      logger.log('Error deleting artwork file', e, stackTrace);
    }

    if (!fromPlaylist) {
      userOfflineSongs.removeWhere((song) => song['ytid'] == songId);
      currentOfflineSongsLength.value = userOfflineSongs.length;
      await addOrUpdateData('userNoBackup', 'offlineSongs', userOfflineSongs);
    }

    return true;
  } catch (e, stackTrace) {
    logger.log('Error removing song from offline storage', e, stackTrace);
    return false;
  }
}

Future<File?> _downloadAndSaveArtworkFile(String url, String filePath) async {
  try {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } else {
      logger.log(
        'Failed to download file. Status code: ${response.statusCode}',
        null,
        null,
      );
    }
  } catch (e, stackTrace) {
    logger.log('Error downloading and saving file', e, stackTrace);
  }

  return null;
}

const recentlyPlayedSongsLimit = 50;

Future<void> updateRecentlyPlayed(dynamic songId) async {
  try {
    if (userRecentlyPlayed.isNotEmpty &&
        userRecentlyPlayed.length == 1 &&
        userRecentlyPlayed[0]['ytid'] == songId) {
      return;
    }

    if (userRecentlyPlayed.length >= recentlyPlayedSongsLimit) {
      userRecentlyPlayed.removeLast();
    }

    userRecentlyPlayed.removeWhere((song) => song['ytid'] == songId);

    final newSongDetails = await getSongDetails(0, songId);

    userRecentlyPlayed.insert(0, newSongDetails);
    currentRecentlyPlayedLength.value = userRecentlyPlayed.length;
    await addOrUpdateData('user', 'recentlyPlayedSongs', userRecentlyPlayed);
  } catch (e, stackTrace) {
    logger.log('Error updating recently played', e, stackTrace);
  }
}

Future<void> removeFromRecentlyPlayed(dynamic songId) async {
  if (userRecentlyPlayed.any((song) => song['ytid'] == songId)) {
    userRecentlyPlayed.removeWhere((song) => song['ytid'] == songId);
    currentRecentlyPlayedLength.value = userRecentlyPlayed.length;
    await addOrUpdateData('user', 'recentlyPlayedSongs', userRecentlyPlayed);
  }
}
