/// PiP handler interface — platform-agnostic
abstract class PipHandler {
  Future<bool> get isPipAvailable;
  Future<void> enterPipMode({(int, int) aspectRatio});
  Future<void> setAutoPipMode({(int, int) aspectRatio, bool autoEnter});
}
