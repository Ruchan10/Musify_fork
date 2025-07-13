import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:musify_fork/services/user_shared_pref.dart';
import 'package:musify_fork/utilities/flutter_toast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

@pragma('vm:entry-point')
class DownloadHelper {
  static final ReceivePort _port = ReceivePort();
  static final GlobalKey<ScaffoldMessengerState> snackbarKey =
      GlobalKey<ScaffoldMessengerState>();

  static void initialize() {
    IsolateNameServer.registerPortWithName(
      _port.sendPort,
      'downloader_send_port',
    );
    _port.listen((dynamic data) {
      final String id = data[0];
      final status = DownloadTaskStatus.fromInt(data[1]);
      final int progress = data[2];

      if (status == DownloadTaskStatus.complete) {
        showToast(snackbarKey.currentContext!, 'Download Completed');
      }
    });

    FlutterDownloader.registerCallback(downloadCallback);
  }

  /// Callback for download progress
  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final send = IsolateNameServer.lookupPortByName('downloader_send_port');
    send?.send([id, status, progress]);
  }

  // /// Show snackbar when download is complete
  // static void _showDownloadCompleteSnackbar() {
  //   snackbarKey.currentState?.showSnackBar(
  //     const SnackBar(
  //       content: Text(' Download Complete!'),
  //       duration: Duration(seconds: 3),
  //     ),
  //   );
  // }

  static Future<bool> _hasStoragePermission() async {
    var isGranted = false;

    final externalStorageStatus = await Permission.storage.status;
    if (!externalStorageStatus.isGranted) {
      await Permission.storage.request();
    }

    isGranted = externalStorageStatus.isGranted;

    if (Platform.isAndroid && Platform.version.compareTo('30') <= 0) {
      // For Android 11 and above (API 30+), use manageExternalStorage permission
      var status = await Permission.manageExternalStorage.status;

      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }
      isGranted = status.isGranted;
    } else {
      // For Android 10 and below, use storage permission
      var status = await Permission.storage.status;

      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      isGranted = status.isGranted;
    }
    return isGranted;
  }

  static Future<String> _fetchBestAudioUrl(String youtubeId) async {
    final yt = YoutubeExplode();
    final manifest = await yt.videos.streamsClient.getManifest(youtubeId);
    final audioStream = manifest.audioOnly.withHighestBitrate();
    yt.close();
    return audioStream.url.toString();
  }

  /// Download the audio file
  static Future<void> downloadAudio(
    String youtubeId,
    String title,
    String artist,
    BuildContext context,
  ) async {
    try {
      final hasPermission = await _hasStoragePermission();
      if (!hasPermission) {
        showToast(context, 'Storage permission not granted');
        return;
      }

      final audioUrl = await _fetchBestAudioUrl(youtubeId);
      final musicDir = Directory(await UserSharedPrefs.getDownloadDir());
      if (!musicDir.existsSync()) {
        musicDir.createSync(recursive: true);
      }
      await FlutterDownloader.enqueue(
        url: audioUrl,
        savedDir: musicDir.path,
        fileName: '$artist - $title.flac',
      );

      showToast(context, 'Download started');
    } catch (e) {
      debugPrint('❌ Error downloading audio: $e');
    }
  }
}
