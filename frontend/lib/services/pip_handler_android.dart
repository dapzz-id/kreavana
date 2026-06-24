import 'package:simple_pip_mode/simple_pip.dart';
import 'pip_handler.dart';

/// Native Android PiP handler using simple_pip_mode
class PipHandlerImpl implements PipHandler {
  @override
  Future<bool> get isPipAvailable async {
    try {
      return await SimplePip.isPipAvailable;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> enterPipMode({(int, int) aspectRatio = (16, 9)}) async {
    try {
      final available = await isPipAvailable;
      if (available) {
        await SimplePip().enterPipMode(aspectRatio: aspectRatio);
      }
    } catch (_) {}
  }

  @override
  Future<void> setAutoPipMode({(int, int) aspectRatio = (16, 9), bool autoEnter = true}) async {
    try {
      final available = await isPipAvailable;
      if (available) {
        await SimplePip().setAutoPipMode(aspectRatio: aspectRatio, autoEnter: autoEnter);
      }
    } catch (_) {}
  }
}
