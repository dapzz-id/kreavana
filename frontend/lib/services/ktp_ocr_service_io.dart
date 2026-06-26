import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class KtpOcrResult {
  final String? nik;
  final String? fullName;
  final String? birthPlace;
  final String? birthDate;
  final String? address;
  final String rawText;

  KtpOcrResult({
    this.nik,
    this.fullName,
    this.birthPlace,
    this.birthDate,
    this.address,
    this.rawText = '',
  });

  bool get hasData => nik != null || fullName != null || address != null;
}

class KtpOcrService {
  static Future<KtpOcrResult> scanFromFile(String filePath) async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      return KtpOcrResult(rawText: '');
    }

    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognizedText = await recognizer.processImage(inputImage);
      await recognizer.close();

      return parseKtpText(recognizedText.text);
    } catch (_) {
      return KtpOcrResult(rawText: '');
    }
  }

  static KtpOcrResult parseKtpText(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String? nik;
    String? fullName;
    String? birthPlace;
    String? birthDate;
    String? address;

    final nikMatch = RegExp(r'\b(\d{16})\b').firstMatch(text);
    if (nikMatch != null) {
      nik = nikMatch.group(1);
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].toUpperCase();

      if (line.contains('NIK') && nik == null && i + 1 < lines.length) {
        final next = RegExp(r'(\d{16})').firstMatch(lines[i + 1]);
        if (next != null) nik = next.group(1);
      }

      if (line == 'NAMA' || line.startsWith('NAMA ')) {
        if (i + 1 < lines.length) {
          fullName = lines[i + 1];
        }
      }

      if (line.contains('LAHIR') || line.contains('Tempat')) {
        final birthMatch = RegExp(
          r'([A-Za-z\s\.]+),?\s*(\d{2}[-/]\d{2}[-/]\d{4})',
        ).firstMatch(lines[i]);
        if (birthMatch != null) {
          birthPlace = birthMatch.group(1)?.trim();
          birthDate = birthMatch.group(2)?.replaceAll('/', '-');
        } else if (i + 1 < lines.length) {
          final nextMatch = RegExp(
            r'([A-Za-z\s\.]+),?\s*(\d{2}[-/]\d{2}[-/]\d{4})',
          ).firstMatch(lines[i + 1]);
          if (nextMatch != null) {
            birthPlace = nextMatch.group(1)?.trim();
            birthDate = nextMatch.group(2)?.replaceAll('/', '-');
          }
        }
      }

      if (line.contains('ALAMAT') || line == 'Alamat') {
        if (i + 1 < lines.length) {
          address = lines[i + 1];
          if (i + 2 < lines.length &&
              !lines[i + 2].toUpperCase().contains('RT') &&
              !lines[i + 2].toUpperCase().contains('KEL')) {
            address = '$address, ${lines[i + 2]}';
          }
        }
      }
    }

    if (fullName == null && nik != null) {
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains(nik!) && i + 1 < lines.length) {
          final candidate = lines[i + 1];
          if (!RegExp(r'^\d').hasMatch(candidate) && candidate.length > 3) {
            fullName = candidate;
            break;
          }
        }
      }
    }

    return KtpOcrResult(
      nik: nik,
      fullName: fullName,
      birthPlace: birthPlace,
      birthDate: birthDate,
      address: address,
      rawText: text,
    );
  }
}
