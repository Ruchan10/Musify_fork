import 'dart:io';

import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Future<String> fetchBestAudioUrl(String youtubeId) async {
  final yt = YoutubeExplode();
  final manifest = await yt.videos.streamsClient.getManifest(youtubeId);
  final audioStream = manifest.audioOnly.withHighestBitrate();

  yt.close();

  return audioStream.url.toString();
}

Future<void> downloadAudio(String youtubeId) async {
  try {
    final audioUrl = await fetchBestAudioUrl(youtubeId);

    final musicDir = Directory('/storage/emulated/0/Music/Musify');

    if (!musicDir.existsSync()) {
      musicDir.createSync(recursive: true);
    }

    final filePath = '${musicDir.path}/$youtubeId.flac';

    final client =
        HttpClient()..userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)';

    final request = await client.getUrl(Uri.parse(audioUrl));
    final response = await request.close();

    if (response.statusCode == 200) {
      final file = File(filePath);
      final sink = file.openWrite();

      await response.forEach(sink.add);

      await sink.close();
      debugPrint('Download complete! File saved at: $filePath');
    } else {
      debugPrint(
        'Failed to download audio. Status code: ${response.statusCode}',
      );
    }

    client.close();
  } catch (e) {
    debugPrint('Error downloading audio: $e');
  }
}
