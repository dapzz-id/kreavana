import 'audio_player_stub.dart'
    if (dart.library.html) 'audio_player_web.dart'
    if (dart.library.io) 'audio_player_mobile.dart';

export 'audio_player_stub.dart';

BaseAudioPlayer getAudioPlayer() => createAudioPlayer();

