import 'dart:async';
import 'dart:html' as html;
import 'audio_player_stub.dart';
export 'audio_player_stub.dart';

class WebAudioPlayer implements BaseAudioPlayer {
  html.AudioElement? _element;
  StreamSubscription? _endedSub;
  StreamSubscription? _timeSub;
  StreamSubscription? _metaSub;
  bool _playing = false;

  @override
  bool get isPlaying => _playing;

  @override
  Future<void> playUrl(
    String url, {
    required Function(Duration duration) onDuration,
    required Function(Duration position) onPosition,
    required Function() onCompleted,
    required Function(String error) onError,
  }) async {
    try {
      _cleanup();

      _element = html.AudioElement(url);
      _element!.autoplay = false;

      _metaSub = _element!.onLoadedMetadata.listen((_) {
        final durationSec = _element?.duration ?? 0;
        if (durationSec > 0 && !durationSec.isNaN) {
          onDuration(Duration(milliseconds: (durationSec * 1000).round()));
        }
      });

      _timeSub = _element!.onTimeUpdate.listen((_) {
        final currentSec = _element?.currentTime ?? 0;
        onPosition(Duration(milliseconds: (currentSec * 1000).round()));
      });

      _endedSub = _element!.onEnded.listen((_) {
        _playing = false;
        onCompleted();
      });

      _element!.onError.listen((e) {
        _playing = false;
        onError('Gagal memutar audio di browser web');
      });

      await _element!.play();
      _playing = true;
    } catch (e) {
      _playing = false;
      onError(e.toString());
    }
  }

  @override
  Future<void> pause() async {
    _element?.pause();
    _playing = false;
  }

  @override
  Future<void> stop() async {
    _element?.pause();
    _element?.currentTime = 0;
    _playing = false;
    _cleanup();
  }

  void _cleanup() {
    _endedSub?.cancel();
    _timeSub?.cancel();
    _metaSub?.cancel();
    _element?.pause();
    _element = null;
  }

  @override
  void dispose() {
    _cleanup();
  }
}

BaseAudioPlayer createAudioPlayer() => WebAudioPlayer();
