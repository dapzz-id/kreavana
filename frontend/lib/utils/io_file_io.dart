import 'dart:io';
import 'dart:typed_data';

class PlatformFileHelper {
  static Future<Uint8List?> readAsBytes(dynamic file) async {
    if (file is File) {
      return await file.readAsBytes();
    }
    return null;
  }
}
