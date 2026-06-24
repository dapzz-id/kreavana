import 'pip_handler.dart';
import 'pip_handler_stub.dart'
    if (dart.library.io) 'pip_handler_android.dart';

/// Get the platform-appropriate PiP handler
PipHandler getPipHandler() => PipHandlerImpl();
