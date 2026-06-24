import 'pip_handler.dart';

/// Stub PiP handler for Web/unsupported platforms — does nothing
class PipHandlerImpl implements PipHandler {
  @override
  Future<bool> get isPipAvailable async => false;

  @override
  Future<void> enterPipMode({(int, int) aspectRatio = (16, 9)}) async {}

  @override
  Future<void> setAutoPipMode({(int, int) aspectRatio = (16, 9), bool autoEnter = true}) async {}
}
