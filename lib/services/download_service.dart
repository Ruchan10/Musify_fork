import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> downloadFlac(String flacUrl, String fileName) async {
  try {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        debugPrint('Storage permission denied');
        return;
      }
    }

    // Get the downloads directory
    final dir = await getExternalStorageDirectory();
    final filePath = '${dir?.path}/$fileName.flac';

    final dio = Dio();
    await dio.download(
      flacUrl,
      filePath,
      onReceiveProgress: (count, total) {
        debugPrint('Downloading: ${(count / total * 100).toStringAsFixed(2)}%');
      },
    );

    debugPrint('Download complete: $filePath');
  } catch (e) {
    debugPrint('Error downloading FLAC: $e');
  }
}

void isYtDlpInstalled() async {
  // try {
  //   final result = await Process.run(
  //     '/data/data/com.termux/files/usr/bin/yt-dlp',
  //     ['--version'],
  //     runInShell: true,
  //   );
  //   return result.exitCode == 0;
  // } catch (e) {
  //   debugPrint('$e');
  //   return false;
  // }
  Process.start('/data/data/com.termux/files/usr/bin/yt-dlp', ['--version'])
      .then((process) {
        process.stdout.transform(utf8.decoder).listen(print);
      })
      .catchError((error) {
        print('Error: $error');
      });
}

Future<void> downloadFlac0(String videoUrl, String title) async {
  // if (!isYtDlpInstalled()) {
  //   debugPrint('yt-dlp is not installed. Please install it first.');

  //   await showDialog(
  //     context: NavigationManager().context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             Text(
  //               'Download yt-dlp on your system.',
  //               textAlign: TextAlign.center,
  //               style: TextStyle(
  //                 fontSize: 24,
  //                 fontWeight: FontWeight.bold,
  //                 color: Theme.of(context).colorScheme.onPrimaryContainer,
  //               ),
  //             ),

  //             const SizedBox(height: 10),
  //           ],
  //         ),
  //         actionsAlignment: MainAxisAlignment.center,
  //         actions: <Widget>[
  //           OutlinedButton(
  //             onPressed: () {
  //               Navigator.pop(context);
  //             },
  //             child: Text(context.l10n!.cancel.toUpperCase()),
  //           ),
  //           FilledButton(
  //             onPressed: () async {
  //               const url =
  //                   'https://github.com/yt-dlp/yt-dlp/wiki/Installation#android';
  //               await launchUrl(
  //                 Uri.parse(url),
  //                 mode: LaunchMode.externalApplication,
  //               );
  //             },
  //             child: Text(context.l10n!.download.toUpperCase()),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  isYtDlpInstalled();
  final process = await Process.start('yt-dlp', [
    '-f',
    'bestaudio',
    '--extract-audio',
    '--audio-format',
    'flac',
    '-o',
    '$title.%(ext)s',
    videoUrl,
  ], runInShell: true);

  process.stdout.transform(const SystemEncoding().decoder).listen(debugPrint);
  process.stderr.transform(const SystemEncoding().decoder).listen(debugPrint);

  final exitCode = await process.exitCode;
  if (exitCode == 0) {
    debugPrint('Download successful: $title.flac');
  } else {
    debugPrint('Download failed');
  }
}
