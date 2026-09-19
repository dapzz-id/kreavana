import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PusherConfig {
  static String get scheme =>
      dotenv.env['PUSHER_SCHEME'] ?? 'ws';

  static String get host =>
      dotenv.env['PUSHER_HOST'] ?? '127.0.0.1';

  static int get port =>
      int.tryParse(dotenv.env['PUSHER_PORT'] ?? '') ?? 8080;

  static String get key =>
      dotenv.env['PUSHER_KEY'] ?? '';

  static PusherChannelsOptions get options =>
      PusherChannelsOptions.fromHost(
        scheme: scheme,
        host: host,
        port: port,
        key: key,
      );
}