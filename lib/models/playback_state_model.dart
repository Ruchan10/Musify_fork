class OfflinePlaybackState {
  OfflinePlaybackState({
    required this.trackPaths,
    required this.currentIndex,
    required this.currentPosition,
  });

  factory OfflinePlaybackState.fromJson(Map<String, dynamic> json) {
    return OfflinePlaybackState(
      trackPaths: List<dynamic>.from(json['trackPaths']),
      currentIndex: json['currentIndex'],
      currentPosition: Duration(milliseconds: json['currentPosition']),
    );
  }
  final List<dynamic> trackPaths;
  final int currentIndex;
  final Duration currentPosition;

  Map<String, dynamic> toJson() => {
    'trackPaths': trackPaths,
    'currentIndex': currentIndex,
    'currentPosition': currentPosition.inMilliseconds,
  };
}
