import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musify_fork/main.dart';
import 'package:musify_fork/services/settings_manager.dart';

class LocalMusifyAudioHandler extends BaseAudioHandler {
  LocalMusifyAudioHandler() {
    _setupEventSubscriptions();
    _updatePlaybackState();
    _initialize();
  }

  final AudioPlayer audioPlayer = AudioPlayer();
  final List<Map> _queueList = [];
  final List<Map> _historyList = [];
  int _currentQueueIndex = 0;

  void _setupEventSubscriptions() {
    audioPlayer.playbackEventStream.listen(_handlePlaybackEvent);
    audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _handleSongCompletion();
      }
    });
  }

  Future<void> _initialize() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  void _updatePlaybackState() {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (audioPlayer.playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState:
            const {
              ProcessingState.idle: AudioProcessingState.idle,
              ProcessingState.loading: AudioProcessingState.loading,
              ProcessingState.buffering: AudioProcessingState.buffering,
              ProcessingState.ready: AudioProcessingState.ready,
              ProcessingState.completed: AudioProcessingState.completed,
            }[audioPlayer.processingState]!,
        playing: audioPlayer.playing,
        updatePosition: audioPlayer.position,
        bufferedPosition: audioPlayer.bufferedPosition,
        queueIndex:
            _currentQueueIndex < _queueList.length ? _currentQueueIndex : null,
      ),
    );
  }

  void _handlePlaybackEvent(PlaybackEvent event) {
    _updatePlaybackState();
  }

  Future<void> _handleSongCompletion() async {
    if (_currentQueueIndex < _queueList.length) {
      _addToHistory(_queueList[_currentQueueIndex]);
    }

    if (hasNext) {
      await skipToNext();
    } else if (repeatNotifier.value == AudioServiceRepeatMode.all &&
        _queueList.isNotEmpty) {
      await _playFromQueue(0);
    }
  }

  void _addToHistory(Map song) {
    _historyList
      ..removeWhere((s) => s['filePath'] == song['filePath'])
      ..insert(0, song);
  }

  Future<void> addToQueue(Map song, {bool playNext = false}) async {
    if (!File(song['filePath']).existsSync()) return;

    _queueList.removeWhere((s) => s['filePath'] == song['filePath']);

    if (playNext) {
      _queueList.insert(_currentQueueIndex + 1, song);
    } else {
      _queueList.add(song);
    }

    _updateQueueMediaItems();

    if (!audioPlayer.playing && _queueList.length == 1) {
      await _playFromQueue(0);
    }
  }

  Future<void> addPlaylistToQueue(
    List<Map> songs, {
    bool replace = false,
    int? startIndex,
  }) async {
    if (replace) {
      _queueList.clear();
      _currentQueueIndex = 0;
    }

    for (final song in songs) {
      if (File(song['filePath']).existsSync()) {
        _queueList.add(song);
      }
    }

    _updateQueueMediaItems();

    if (startIndex != null && startIndex < _queueList.length) {
      await _playFromQueue(startIndex);
    }
  }

  Future<void> _playFromQueue(int index) async {
    if (index < 0 || index >= _queueList.length) return;

    _currentQueueIndex = index;
    _updateQueueMediaItems();

    final song = _queueList[index];
    final filePath = song['filePath'];

    try {
      await audioPlayer.setAudioSource(AudioSource.uri(Uri.file(filePath)));
      await audioPlayer.play();
    } catch (e) {
      logger.log('Error playing offline song', e, null);
    }
  }

  void _updateQueueMediaItems() {
    final mediaItems =
        _queueList
            .map(
              (song) => MediaItem(
                id: song['filePath'],
                title: song['title'] ?? 'Unknown',
                artist: song['artist'] ?? 'Unknown',
                album: song['album'] ?? 'Unknown',
                artUri:
                    song['artworkPath'] != null
                        ? Uri.file(song['artworkPath'])
                        : null,
              ),
            )
            .toList();

    queue.add(mediaItems);
    if (_currentQueueIndex < mediaItems.length) {
      mediaItem.add(mediaItems[_currentQueueIndex]);
    }
  }

  // Getters
  List<Map> get currentQueue => List.unmodifiable(_queueList);
  int get currentQueueIndex => _currentQueueIndex;
  bool get hasNext => _currentQueueIndex < _queueList.length - 1;
  bool get hasPrevious => _currentQueueIndex > 0 || _historyList.isNotEmpty;

  @override
  Future<void> play() => audioPlayer.play();

  @override
  Future<void> pause() => audioPlayer.pause();

  @override
  Future<void> stop() => audioPlayer.stop();

  @override
  Future<void> seek(Duration position) => audioPlayer.seek(position);

  @override
  Future<void> skipToNext() async {
    if (hasNext) {
      await _playFromQueue(_currentQueueIndex + 1);
    } else if (repeatNotifier.value == AudioServiceRepeatMode.all &&
        _queueList.isNotEmpty) {
      await _playFromQueue(0);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_currentQueueIndex > 0) {
      await _playFromQueue(_currentQueueIndex - 1);
    } else if (_historyList.isNotEmpty) {
      final previousSong = _historyList.removeAt(0);
      _queueList.insert(0, previousSong);
      await _playFromQueue(0);
    }
  }

  Future<void> playLocalPlaylistSong({
    required Map<String, dynamic> playlist,
    required int songIndex,
  }) async {
    final validSongs =
        (playlist['list'] as List)
            .where((song) => File(song['filePath']).existsSync())
            .toList();

    if (validSongs.isEmpty) return;

    await addPlaylistToQueue(
      List<Map>.from(playlist['list']),
      replace: true,
      startIndex: songIndex,
    );
  }
}
