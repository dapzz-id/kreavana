import 'url_strategy_stub.dart'
    if (dart.library.js_interop) 'url_strategy_web.dart' as impl;

/// Mengaktifkan URL strategy path-based (/login) di Web,
/// dan menjadi no-op di platform native (Windows/Android/iOS/macOS/Linux).
///
/// Wrapper ini menggunakan conditional import agar kode yang memakai
/// `dart:ui_web` hanya dikompilasi untuk target Web.
void configureUrlStrategy() => impl.configureUrlStrategy();

