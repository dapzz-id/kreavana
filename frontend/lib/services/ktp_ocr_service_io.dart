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

    String cleanText = text
        .replaceAll('L', '1')
        .replaceAll('l', '1')
        .replaceAll('O', '0')
        .replaceAll('o', '0')
        .replaceAll('I', '1')
        .replaceAll('i', '1')
        .replaceAll('S', '5')
        .replaceAll('s', '5')
        .replaceAll('Z', '2')
        .replaceAll('z', '2')
        .replaceAll('B', '8')
        .replaceAll('b', '8');

    final nikMatch = RegExp(r'\b(\d{16})\b').firstMatch(cleanText);
    if (nikMatch != null) {
      nik = nikMatch.group(1);
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].toUpperCase();

      if (line.contains('NIK') && nik == null && i + 1 < lines.length) {
        final next = RegExp(r'(\d{16})').firstMatch(lines[i + 1]);
        if (next != null) nik = next.group(1);
      }

      if (line == 'NAMA' || line.startsWith('NAMA ') || line.contains('NAMA')) {
        if (i + 1 < lines.length) {
          fullName = lines[i + 1];
        }
      }

      if (line.contains('LAHIR') ||
          line.contains('Tempat') ||
          line.contains('TEMPAT')) {
        final birthMatch = RegExp(
          r':?\s*([A-Za-z\s\.]+),?\s*(\d{2}[-/]?\d{2}[-/]?\d{4})',
        ).firstMatch(lines[i]);
        if (birthMatch != null) {
          birthPlace = birthMatch.group(1)?.trim();
          birthDate = birthMatch.group(2)?.replaceAll('/', '-');
        } else if (i + 1 < lines.length) {
          final nextMatch = RegExp(
            r':?\s*([A-Za-z\s\.]+),?\s*(\d{2}[-/]?\d{2}[-/]?\d{4})',
          ).firstMatch(lines[i + 1]);
          if (nextMatch != null) {
            birthPlace = nextMatch.group(1)?.trim();
            birthDate = nextMatch.group(2)?.replaceAll('/', '-');
          }
        }
      }

      if (line.contains('ALAMAT') || line == 'Alamat') {
        var addressLines = <String>[];
        var j = i + 1;
        while (j < lines.length && j < i + 8) {
          final nextLine = lines[j].toUpperCase();
          if (nextLine.contains('RT/R') ||
              nextLine.contains('RT/RW') ||
              nextLine.contains('KEL/DESA') ||
              nextLine.contains('KEL') ||
              nextLine.contains('KECAMATAN') ||
              nextLine.contains('PROVINSI') ||
              nextLine.contains('KABUPATEN') ||
              nextLine.contains('AGAMA') ||
              nextLine.contains('JENIS') ||
              nextLine.contains('STATUS') ||
              nextLine.contains('NIK') ||
              nextLine.contains('NAMA') ||
              nextLine.contains('TEMPAT') ||
              nextLine.contains('LAHIR')) {
            j++;
            continue;
          }
          if (nextLine.contains('PEKERJAAN') ||
              nextLine.contains('KEWARGANEGARAAN') ||
              nextLine.contains('BERLAKU') ||
              nextLine.contains('GOL')) {
            break;
          }
          final candidate = lines[j];
          if (candidate.isNotEmpty &&
              !RegExp(r'^\d').hasMatch(candidate) &&
              !RegExp(r'\d{4}[A-Za-z]\d').hasMatch(candidate) &&
              !RegExp(r'\d{2}[-/]\d{2}[-/]\d{4}').hasMatch(candidate) &&
              candidate.length > 5 &&
              !RegExp(r'^[A-Z]{3,}$').hasMatch(candidate)) {
            addressLines.add(candidate);
            break;
          }
          j++;
        }
        if (addressLines.isNotEmpty) {
          address = addressLines.join(', ');
        }
      }
    }

    if (birthPlace == null || birthDate == null) {
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final dateMatch = RegExp(
          r'^([A-Z\s]{3,}),?\s*(\d{2}[-/]?\d{2}[-/]?\d{4})$',
        ).firstMatch(line);
        if (dateMatch != null) {
          final place = dateMatch.group(1)?.trim();
          final date = dateMatch.group(2)?.replaceAll('/', '-');
          if (place != null &&
              place.length > 2 &&
              !RegExp(r'\d').hasMatch(place)) {
            birthPlace = place;
            birthDate = date;
            if (birthDate != null &&
                birthDate.length == 9 &&
                birthDate.contains('-')) {
              final parts = birthDate.split('-');
              if (parts.length == 2 && parts[0].length == 4) {
                birthDate =
                    '${parts[0].substring(0, 2)}-${parts[0].substring(2, 4)}-${parts[1]}';
              }
            }
            break;
          }
        }
      }
    }

    if (fullName == null) {
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.length > 5 &&
            !line.contains('NIK') &&
            !line.contains('NAMA') &&
            !line.contains('TEMPAT') &&
            !line.contains('LAHIR') &&
            !line.contains('ALAMAT') &&
            !line.contains('RT/RW') &&
            !line.contains('KEL') &&
            !line.contains('KECAMATAN') &&
            !line.contains('PROVINSI') &&
            !line.contains('KABUPATEN') &&
            !line.contains('AGAMA') &&
            !RegExp(r'^\d').hasMatch(line) &&
            RegExp(r'^[A-Z\s\-]+$').hasMatch(line)) {
          fullName = line;
          break;
        }
      }
    }

    if (nik == null) {
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        String cleanLine = line
            .replaceAll('L', '1')
            .replaceAll('l', '1')
            .replaceAll('O', '0')
            .replaceAll('o', '0')
            .replaceAll('I', '1')
            .replaceAll('i', '1')
            .replaceAll('S', '5')
            .replaceAll('s', '5')
            .replaceAll('Z', '2')
            .replaceAll('z', '2')
            .replaceAll('B', '8')
            .replaceAll('b', '8');

        final nikMatch = RegExp(r'(\d{16})').firstMatch(cleanLine);
        if (nikMatch != null) {
          nik = nikMatch.group(1);
          break;
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
