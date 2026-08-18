/// Stub untuk platform native.
///
/// `dart:ui_web` (yang dipakai `flutter_web_plugins`) tidak tersedia
/// di native (Windows/Android/iOS/macOS/Linux), jadi kita pakai no-op.
void configureUrlStrategy() {
  // Tidak perlu menerapkan URL strategy di platform non-web.
}
