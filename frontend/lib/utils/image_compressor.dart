import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageCompressor {
  /// Compresses raw image bytes (resizes to max dimension and encodes to JPEG).
  /// Target max size is typically 80KB - 250KB, ensuring smooth transmission through Nginx/API limits.
  static Uint8List compressBytes(
    Uint8List bytes, {
    int maxDimension = 1280,
    int quality = 80,
  }) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;

      img.Image processed = decoded;
      if (decoded.width > maxDimension || decoded.height > maxDimension) {
        if (decoded.width >= decoded.height) {
          processed = img.copyResize(decoded, width: maxDimension);
        } else {
          processed = img.copyResize(decoded, height: maxDimension);
        }
      }

      final compressed = img.encodeJpg(processed, quality: quality);
      return Uint8List.fromList(compressed);
    } catch (e) {
      debugPrint('ImageCompressor error: $e');
      return bytes;
    }
  }

  /// Converts bytes to compressed base64 data URI (e.g. data:image/jpeg;base64,...).
  static Future<String> compressToBase64(
    Uint8List bytes, {
    int maxDimension = 1280,
    int quality = 80,
  }) async {
    Uint8List compressed;
    if (kIsWeb) {
      compressed = compressBytes(bytes, maxDimension: maxDimension, quality: quality);
    } else {
      try {
        compressed = await compute(_compressBytesWorker, {
          'bytes': bytes,
          'maxDimension': maxDimension,
          'quality': quality,
        });
      } catch (_) {
        compressed = compressBytes(bytes, maxDimension: maxDimension, quality: quality);
      }
    }

    return 'data:image/jpeg;base64,${base64Encode(compressed)}';
  }

  static Uint8List _compressBytesWorker(Map<String, dynamic> params) {
    return compressBytes(
      params['bytes'] as Uint8List,
      maxDimension: params['maxDimension'] as int,
      quality: params['quality'] as int,
    );
  }
}
