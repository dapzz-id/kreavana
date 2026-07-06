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
      print('OCR: Platform not supported');
      return KtpOcrResult(rawText: '');
    }

    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognizedText = await recognizer.processImage(inputImage);
      await recognizer.close();

      print('OCR: Raw text extracted: ${recognizedText.text}');
      final result = parseKtpText(recognizedText.text);
      print(
        'OCR: Parsed result - nik=${result.nik}, name=${result.fullName}, birthPlace=${result.birthPlace}, birthDate=${result.birthDate}, address=${result.address}',
      );
      return result;
    } catch (e) {
      print('OCR: Error during scan - $e');
      return KtpOcrResult(rawText: '');
    }
  }

  static KtpOcrResult parseKtpText(String text) {
    print('OCR: Starting to parse text, length: ${text.length}');
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    print('OCR: Number of lines: ${lines.length}');
    print('OCR: Lines: $lines');

    String? nik;
    String? fullName;
    String? birthPlace;
    String? birthDate;
    String? address;

    // NIK is always 16 digits (no letters). Handle OCR errors by converting common misreads
    // Common OCR errors: L->1, O->0, I->1, S->5, Z->2, B->8
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
      print('OCR: Found NIK via 16-digit regex: $nik');
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].toUpperCase();
      print('OCR: Processing line $i: $line');

      if (line.contains('NIK') && nik == null && i + 1 < lines.length) {
        final next = RegExp(r'(\d{16})').firstMatch(lines[i + 1]);
        if (next != null) nik = next.group(1);
        print('OCR: Found NIK after NIK label: $nik');
      }

      // More flexible name detection
      if (line == 'NAMA' || line.startsWith('NAMA ') || line.contains('NAMA')) {
        if (i + 1 < lines.length) {
          fullName = lines[i + 1];
          print('OCR: Found Name: $fullName');
        }
      }

      // More flexible birth date detection
      if (line.contains('LAHIR') ||
          line.contains('Tempat') ||
          line.contains('TEMPAT')) {
        final birthMatch = RegExp(
          r':?\s*([A-Za-z\s\.]+),?\s*(\d{2}[-/]?\d{2}[-/]?\d{4})',
        ).firstMatch(lines[i]);
        if (birthMatch != null) {
          birthPlace = birthMatch.group(1)?.trim();
          birthDate = birthMatch.group(2)?.replaceAll('/', '-');
          print('OCR: Found birth info: $birthPlace, $birthDate');
        } else if (i + 1 < lines.length) {
          final nextMatch = RegExp(
            r':?\s*([A-Za-z\s\.]+),?\s*(\d{2}[-/]?\d{2}[-/]?\d{4})',
          ).firstMatch(lines[i + 1]);
          if (nextMatch != null) {
            birthPlace = nextMatch.group(1)?.trim();
            birthDate = nextMatch.group(2)?.replaceAll('/', '-');
            print(
              'OCR: Found birth info in next line: $birthPlace, $birthDate',
            );
          }
        }
      }

      // Better address detection
      if (line.contains('ALAMAT') || line == 'Alamat') {
        // Skip labels and find actual address (usually street name)
        var addressLines = <String>[];
        var j = i + 1;
        while (j < lines.length && j < i + 8) {
          final nextLine = lines[j].toUpperCase();
          // Skip labels
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
          // Stop if we hit other major sections
          if (nextLine.contains('PEKERJAAN') ||
              nextLine.contains('KEWARGANEGARAAN') ||
              nextLine.contains('BERLAKU') ||
              nextLine.contains('GOL')) {
            break;
          }
          // Only add if it looks like a street/address (not NIK, not name, not date)
          final candidate = lines[j];
          if (candidate.isNotEmpty &&
              !RegExp(
                r'^\d',
              ).hasMatch(candidate) && // Doesn't start with number
              !RegExp(r'\d{4}[A-Za-z]\d').hasMatch(candidate) && // Not NIK-like
              !RegExp(
                r'\d{2}[-/]\d{2}[-/]\d{4}',
              ).hasMatch(candidate) && // Not date
              candidate.length > 5 &&
              !RegExp(r'^[A-Z]{3,}$').hasMatch(candidate)) {
            // Not just uppercase word (like city names)
            addressLines.add(candidate);
            // Only take first valid address line to avoid mixing data
            break;
          }
          j++;
        }
        if (addressLines.isNotEmpty) {
          address = addressLines.join(', ');
          print('OCR: Found Address: $address');
        }
      }
    }

    // Try to find birth date if still not found
    if (birthPlace == null || birthDate == null) {
      print('OCR: Trying to find birth date via pattern');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Look for patterns like "BEKASI, 10-10-2008" or "BEKASI, 1010-2008"
        // More specific pattern to avoid false positives from NIK-like strings
        final dateMatch = RegExp(
          r'^([A-Z\s]{3,}),?\s*(\d{2}[-/]?\d{2}[-/]?\d{4})$',
        ).firstMatch(line);
        if (dateMatch != null) {
          final place = dateMatch.group(1)?.trim();
          final date = dateMatch.group(2)?.replaceAll('/', '-');
          // Validate the place is a city name (not single letter, not numbers)
          if (place != null &&
              place.length > 2 &&
              !RegExp(r'\d').hasMatch(place)) {
            birthPlace = place;
            birthDate = date;
            // Handle case like 1010-2008 -> 10-10-2008 (DDMM-YYYY format)
            if (birthDate != null &&
                birthDate.length == 9 &&
                birthDate.contains('-')) {
              final parts = birthDate.split('-');
              if (parts.length == 2 && parts[0].length == 4) {
                birthDate =
                    '${parts[0].substring(0, 2)}-${parts[0].substring(2, 4)}-${parts[1]}';
              }
            }
            print('OCR: Found birth date via pattern: $birthPlace, $birthDate');
            break;
          }
        }
      }
    }

    // Try to find name if still not found (look for uppercase text that looks like a name)
    if (fullName == null) {
      print('OCR: Trying to find name via pattern');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Skip if it's a label or contains mostly numbers
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
          print('OCR: Found Name via pattern: $fullName');
          break;
        }
      }
    }

    // Try to find NIK near name if still not found
    if (nik == null) {
      print('OCR: Trying to find NIK via pattern');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Clean OCR errors
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
          print('OCR: Found NIK via pattern: $nik');
          break;
        }
      }
    }

    print(
      'OCR: Final parsing result - nik=$nik, name=$fullName, birthPlace=$birthPlace, birthDate=$birthDate, address=$address',
    );
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
