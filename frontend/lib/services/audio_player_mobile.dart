import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'audio_player_stub.dart';
export 'audio_player_stub.dart';

class MobileAudioPlayer implements BaseAudioPlayer {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;

  @override
  bool get isPlaying => _player.playing;

  @override
  Future<void> playUrl(
    String url, {
    required Function(Duration duration) onDuration,
    required Function(Duration position) onPosition,
    required Function() onCompleted,
    required Function(String error) onError,
  }) async {
    try {
      await _posSub?.cancel();
      await _stateSub?.cancel();

      await _player.setUrl(url);
      final duration = _player.duration;
      if (duration != null) {
        onDuration(duration);
      }

      _posSub = _player.positionStream.listen((pos) {
        onPosition(pos);
      });

      _stateSub = _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          onCompleted();
        }
      });

      await _player.play();
    } catch (e) {
      onError(e.toString());
    }
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
  }
}

BaseAudioPlayer createAudioPlayer() => MobileAudioPlayer();
