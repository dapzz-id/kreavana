abstract class BaseAudioPlayer {
  Future<void> playUrl(
    String url, {
    required Function(Duration duration) onDuration,
    required Function(Duration position) onPosition,
    required Function() onCompleted,
    required Function(String error) onError,
  });
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<Duration?> getDuration(String url);
  bool get isPlaying;
  void dispose();
}

BaseAudioPlayer createAudioPlayer() =>
    throw UnsupportedError('Cannot create audio player');
