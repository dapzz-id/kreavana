import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Data model untuk pencetakan & pengunduhan Kontrak Digital Resmi 3 Pihak (Ukuran A4)
/// dengan Kop Surat CV Transforma Alam Kreasi & Sumber Aplikasi Kreavana.
class OfficialContractDocumentData {
  final String contractNumber;
  final String companyHeader;
  final String platformSource;
  final String projectTitle;
  final String projectDescription;
  final String projectLocation;
  final String projectSchedule;
  final double agreedPrice;
  final String paymentSchemeLabel;
  final List<String> clauses;
  final bool isFinal;
  final String issuedDateText;

  // Pihak Pertama (Penyelenggara / Klien)
  final String clientName;
  final String clientUsername;
  final String clientRoleLabel;
  final String? clientSignature;
  final String? clientSignedAtText;

  // Pihak Kedua (Pekerja / Pelamar Individu — 1 Orang 1 Kontrak)
  final String creatorName;
  final String creatorUsername;
  final String creatorSubRoleLabel;
  final String? creatorSignature;
  final String? creatorSignedAtText;

  // Pihak Ketiga (Otoritas Penjamin Escrow & Platform)
  final String adminCompanyName;
  final String adminTitle;
  final String adminSignedAtText;

  const OfficialContractDocumentData({
    required this.contractNumber,
    this.companyHeader = 'CV TRANSFORMA ALAM KREASI',
    this.platformSource = 'Aplikasi Kreavana — Ekosistem Kreatif & Rekening Bersama (Escrow)',
    required this.projectTitle,
    required this.projectDescription,
    required this.projectLocation,
    required this.projectSchedule,
    required this.agreedPrice,
    required this.paymentSchemeLabel,
    required this.clauses,
    required this.isFinal,
    required this.issuedDateText,
    required this.clientName,
    required this.clientUsername,
    required this.clientRoleLabel,
    this.clientSignature,
    this.clientSignedAtText,
    required this.creatorName,
    required this.creatorUsername,
    required this.creatorSubRoleLabel,
    this.creatorSignature,
    this.creatorSignedAtText,
    this.adminCompanyName = 'CV Transforma Alam Kreasi',
    this.adminTitle = 'Otoritas Penjamin Escrow & Legalitas Platform Aplikasi Kreavana',
    required this.adminSignedAtText,
  });
}

class ContractPdfService {
  static String formatIdr(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  static String formatOfficialDate(DateTime? dt) {
    final target = (dt ?? DateTime.now()).toLocal();
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${target.day.toString().padLeft(2, '0')} ${months[target.month - 1]} ${target.year}';
  }

  static String formatOfficialDateTime(String? isoString) {
    if (isoString == null || isoString.trim().isEmpty) {
      return '-';
    }
    final parsed = DateTime.tryParse(isoString)?.toLocal();
    if (parsed == null) return isoString;
    final datePart = formatOfficialDate(parsed);
    final timePart =
        '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')} WIB';
    return '$datePart, $timePart';
  }

  /// Menghasilkan byte PDF 1.4 standar ukuran A4 (595 x 842 pt) yang valid dan dapat dibuka
  /// di seluruh pembaca PDF tanpa dependensi native tambahan.
  static List<int> buildOfficialContractA4PdfBytes(
    OfficialContractDocumentData data,
  ) {
    final statusBanner = data.isFinal
        ? 'STATUS DOKUMEN: KONTRAK FIX & FINAL (DISETUJUI KEDUA BELAH PIHAK - TERKUNCI)'
        : 'STATUS DOKUMEN: DRAF KONTRAK DIGITAL (MENUNGGU TANDA TANGAN LENGKAP)';

    final List<String> bodyLines = [
      statusBanner,
      'Sumber Resmi: ${data.platformSource}',
      'Tanggal Dokumen: ${data.issuedDateText}',
      '',
      'PARA PIHAK YANG BERSEPAKAT (1 ORANG 1 KONTRAK INDIVIDU - 3 PIHAK):',
      '1. PIHAK PERTAMA (PENYELENGGARA / KLIEN):',
      '   Nama Lengkap / Instansi : ${data.clientName} (@${data.clientUsername})',
      '   Peran pada Proyek       : ${data.clientRoleLabel}',
      '2. PIHAK KEDUA (PEKERJA KREATIF / PELAMAR TERPILIH):',
      '   Nama Lengkap Pekerja    : ${data.creatorName} (@${data.creatorUsername})',
      '   Bidang / Spesialisasi   : ${data.creatorSubRoleLabel}',
      '3. PIHAK KETIGA (PENJAMIN REKENING BERSAMA & OTORITAS PLATFORM):',
      '   Badan Usaha Resmi       : ${data.adminCompanyName}',
      '   Unit Otoritas           : ${data.adminTitle}',
      '',
      'PASAL 1 - OBJEK PEKERJAAN & PELAKSANAAN ACARA',
      'Nama Proyek / Acara : ${data.projectTitle}',
      'Lokasi Pelaksanaan  : ${data.projectLocation}',
      'Jadwal Pelaksanaan  : ${data.projectSchedule}',
      'Lingkup Pekerjaan   : ${data.projectDescription.isEmpty ? "Sesuai deskripsi proyek pada Aplikasi Kreavana." : data.projectDescription}',
      '',
      'PASAL 2 - NILAI HONORARIUM INDIVIDU & JAMINAN ESCROW',
      'Nilai Kontrak Individu Pihak Kedua : ${formatIdr(data.agreedPrice)}',
      'Skema Pencairan Pembayaran         : ${data.paymentSchemeLabel}',
      'Dana honorarium dijamin pada sistem Rekening Bersama (Escrow) Aplikasi Kreavana',
      'yang dikelola oleh CV Transforma Alam Kreasi dan dicairkan sesuai tahapan penyelesaian kerja.',
      '',
      'PASAL 3 - KETENTUAN KHUSUS & KLAUSUL KESEPAKATAN:',
    ];

    for (var i = 0; i < data.clauses.length; i++) {
      bodyLines.add('${i + 1}. ${data.clauses[i]}');
    }

    bodyLines.addAll([
      '',
      'PASAL 4 - PENGESAHAN, FINALITAS KONTRAK FIX, & KEKUATAN HUKUM (UU ITE)',
      'Setelah ditandatangani secara elektronik oleh Pihak Pertama dan Pihak Kedua,',
      'dokumen kontrak ini berstatus KONTRAK FIX (FINAL), mengikat secara hukum sesuai',
      'Pasal 11 UU No. 11 Tahun 2008 tentang ITE, dan tidak dapat diubah lagi oleh pihak manapun.',
    ]);

    return _generateA4ContractPdfBytes(
      companyHeader: data.companyHeader,
      platformSource: data.platformSource,
      contractNumber: data.contractNumber,
      issuedDateText: data.issuedDateText,
      isFinal: data.isFinal,
      lines: bodyLines,
      clientName: data.clientName,
      clientSignature: data.clientSignature,
      clientSignedAt: data.clientSignedAtText,
      creatorName: data.creatorName,
      creatorSignature: data.creatorSignature,
      creatorSignedAt: data.creatorSignedAtText,
      adminCompanyName: data.adminCompanyName,
      adminSignedAt: data.adminSignedAtText,
    );
  }

  static Future<String> downloadOfficialContractPdf({
    required OfficialContractDocumentData data,
  }) async {
    final pdfBytes = buildOfficialContractA4PdfBytes(data);
    final sanitizedNo = data.contractNumber
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final sanitizedCreator = data.creatorUsername
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final filename = 'Kontrak_Resmi_A4_${sanitizedNo}_$sanitizedCreator.pdf';

    if (kIsWeb) {
      final base64Pdf = base64Encode(pdfBytes);
      final dataUri = Uri.parse('data:application/pdf;base64,$base64Pdf');
      await launchUrl(dataUri, mode: LaunchMode.platformDefault);
      return filename;
    }

    Directory targetDir;
    try {
      targetDir =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    } catch (_) {
      targetDir = Directory.systemTemp;
    }

    final filePath =
        '${targetDir.path}${Platform.pathSeparator}$filename';
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes, flush: true);

    final fileUri = Uri.file(file.path);
    try {
      await launchUrl(fileUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Abaikan jika OS tidak memiliki default PDF viewer, path tetap dikembalikan
    }

    return file.path;
  }

  static List<int> _generateA4ContractPdfBytes({
    required String companyHeader,
    required String platformSource,
    required String contractNumber,
    required String issuedDateText,
    required bool isFinal,
    required List<String> lines,
    required String clientName,
    required String? clientSignature,
    required String? clientSignedAt,
    required String creatorName,
    required String? creatorSignature,
    required String? creatorSignedAt,
    required String adminCompanyName,
    required String adminSignedAt,
  }) {
    String esc(String s) {
      return s
          .replaceAll(r'\', r'\\')
          .replaceAll('(', r'\(')
          .replaceAll(')', r'\)')
          .replaceAll(RegExp(r'[^\x20-\x7E]'), ' ');
    }

    final stream = StringBuffer();

    // Bingkai Luar Kertas Resmi A4 (595 x 842 pt)
    stream.writeln('0.85 0.88 0.92 RG');
    stream.writeln('1 w');
    stream.writeln('28 28 539 786 re S');

    // Header Kop Resmi: CV TRANSFORMA ALAM KREASI
    stream.writeln('0.08 0.14 0.28 rg');
    stream.writeln('28 748 539 66 re f');

    stream.writeln('BT');
    stream.writeln('/F2 14 Tf');
    stream.writeln('1 1 1 rg');
    stream.writeln('44 790 Td');
    stream.writeln('(${esc(companyHeader.toUpperCase())}) Tj');
    stream.writeln('ET');

    stream.writeln('BT');
    stream.writeln('/F1 8.5 Tf');
    stream.writeln('0.82 0.88 0.98 rg');
    stream.writeln('44 775 Td');
    stream.writeln(
      '(${esc("SUMBER DOKUMEN RESMI: $platformSource")}) Tj',
    );
    stream.writeln('ET');

    stream.writeln('BT');
    stream.writeln('/F1 8 Tf');
    stream.writeln('0.75 0.84 0.96 rg');
    stream.writeln('44 761 Td');
    stream.writeln(
      '(${esc("Dokumen Kontrak Elektronik 3 Pihak Berstandar A4  |  Tanggal: $issuedDateText")}) Tj',
    );
    stream.writeln('ET');

    // Garis Aksentuasi Emas/Biru di bawah Kop
    stream.writeln('0.18 0.45 0.85 RG');
    stream.writeln('2.2 w');
    stream.writeln('28 746 m 567 746 l S');

    // Judul Dokumen & Nomor Kontrak
    stream.writeln('BT');
    stream.writeln('/F2 11.5 Tf');
    stream.writeln('0.08 0.12 0.20 rg');
    stream.writeln('44 726 Td');
    stream.writeln(
      '(${esc("SURAT PERJANJIAN KERJA KREATIF & JAMINAN ESCROW (3 PIHAK)")}) Tj',
    );
    stream.writeln('ET');

    stream.writeln('BT');
    stream.writeln('/F2 9 Tf');
    stream.writeln('0.20 0.30 0.50 rg');
    stream.writeln('44 712 Td');
    stream.writeln(
      '(${esc("Nomor Kontrak: $contractNumber   |   Status: ${isFinal ? "KONTRAK FIX (FINAL)" : "MENUNGGU TTD"}")}) Tj',
    );
    stream.writeln('ET');

    stream.writeln('0.82 0.85 0.90 RG');
    stream.writeln('0.8 w');
    stream.writeln('44 704 m 551 704 l S');

    // Isi Pasal & Klausul Kontrak
    double y = 690;
    for (final rawLine in lines) {
      if (y < 165) break;
      if (rawLine.trim().isEmpty) {
        y -= 7;
        continue;
      }
      final wrapped = _wrapText(rawLine, 86);
      final isHeading =
          rawLine.startsWith('PASAL ') ||
          rawLine.startsWith('PARA PIHAK') ||
          rawLine.startsWith('STATUS DOKUMEN:');
      for (final part in wrapped) {
        if (y < 165) break;
        stream.writeln('BT');
        stream.writeln('${isHeading ? "/F2 8.5" : "/F1 8.2"} Tf');
        if (rawLine.startsWith('STATUS DOKUMEN:')) {
          stream.writeln(isFinal ? '0.05 0.45 0.25 rg' : '0.65 0.38 0.05 rg');
        } else if (isHeading) {
          stream.writeln('0.08 0.16 0.32 rg');
        } else {
          stream.writeln('0.15 0.18 0.24 rg');
        }
        stream.writeln('44 ${y.toStringAsFixed(1)} Td');
        stream.writeln('(${esc(part)}) Tj');
        stream.writeln('ET');
        y -= 11.2;
      }
    }

    // Kotak Tanda Tangan 3 Pihak di Bagian Bawah Kertas A4
    stream.writeln('0.78 0.82 0.88 RG');
    stream.writeln('0.8 w');
    stream.writeln('44 150 m 551 150 l S');

    stream.writeln('BT');
    stream.writeln('/F2 8.5 Tf');
    stream.writeln('0.08 0.14 0.28 rg');
    stream.writeln('44 136 Td');
    stream.writeln(
      '(${esc("LEMBAR PENGESAHAN TANDA TANGAN ELEKTRONIK 3 PIHAK (1 ORANG 1 KONTRAK):")}) Tj',
    );
    stream.writeln('ET');

    // Kolom 1: Pihak Pertama (Klien)
    _drawSignatureColumn(
      stream: stream,
      esc: esc,
      x: 44,
      partyLabel: 'PIHAK PERTAMA (KLIEN)',
      name: clientName,
      signature: clientSignature,
      signedAt: clientSignedAt,
    );

    // Kolom 2: Pihak Kedua (Pekerja Individu)
    _drawSignatureColumn(
      stream: stream,
      esc: esc,
      x: 218,
      partyLabel: 'PIHAK KEDUA (PEKERJA)',
      name: creatorName,
      signature: creatorSignature,
      signedAt: creatorSignedAt,
    );

    // Kolom 3: Pihak Ketiga (CV Transforma Alam Kreasi / Aplikasi Kreavana)
    _drawSignatureColumn(
      stream: stream,
      esc: esc,
      x: 392,
      partyLabel: 'PIHAK KETIGA (PENJAMIN)',
      name: adminCompanyName,
      signature: 'VERIFIED-ESCROW-TAK-KREAVANA',
      signedAt: adminSignedAt,
    );

    // Footer Resmi A4
    stream.writeln('0.85 0.88 0.92 RG');
    stream.writeln('0.6 w');
    stream.writeln('44 50 m 551 50 l S');

    stream.writeln('BT');
    stream.writeln('/F1 7.2 Tf');
    stream.writeln('0.40 0.45 0.52 rg');
    stream.writeln('44 38 Td');
    stream.writeln(
      '(${esc("Diterbitkan secara resmi oleh $companyHeader melalui $platformSource  |  Ukuran Kertas: A4 Resmi (210 x 297 mm)")}) Tj',
    );
    stream.writeln('ET');

    final contentBytes = ascii.encode(stream.toString());

    final objects = <String>[
      '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
      '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n',
      '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> /Contents 6 0 R >>\nendobj\n',
      '4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n',
      '5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\nendobj\n',
      '6 0 obj\n<< /Length ${contentBytes.length} >>\nstream\n${stream.toString()}endstream\nendobj\n',
    ];

    final pdf = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[0];
    for (final obj in objects) {
      offsets.add(pdf.toString().length);
      pdf.write(obj);
    }

    final xrefOffset = pdf.toString().length;
    pdf.writeln('xref');
    pdf.writeln('0 ${objects.length + 1}');
    pdf.writeln('0000000000 65535 f ');
    for (var i = 1; i <= objects.length; i++) {
      pdf.writeln('${offsets[i].toString().padLeft(10, '0')} 00000 n ');
    }
    pdf.writeln('trailer');
    pdf.writeln('<< /Size ${objects.length + 1} /Root 1 0 R >>');
    pdf.writeln('startxref');
    pdf.writeln('$xrefOffset');
    pdf.write('%%EOF');

    return ascii.encode(pdf.toString());
  }

  static void _drawSignatureColumn({
    required StringBuffer stream,
    required String Function(String) esc,
    required double x,
    required String partyLabel,
    required String name,
    required String? signature,
    required String? signedAt,
  }) {
    final isSigned = signature != null && signature.trim().isNotEmpty;
    stream.writeln('0.82 0.86 0.92 RG');
    stream.writeln('0.7 w');
    stream.writeln('${x.toStringAsFixed(1)} 58 158 72 re S');

    stream.writeln('BT');
    stream.writeln('/F2 7.5 Tf');
    stream.writeln('0.12 0.18 0.30 rg');
    stream.writeln('${(x + 6).toStringAsFixed(1)} 118 Td');
    stream.writeln('(${esc(_truncate(partyLabel, 26))}) Tj');
    stream.writeln('ET');

    stream.writeln('BT');
    stream.writeln('/F2 7.2 Tf');
    stream.writeln(isSigned ? '0.05 0.48 0.25 rg' : '0.65 0.35 0.08 rg');
    stream.writeln('${(x + 6).toStringAsFixed(1)} 98 Td');
    stream.writeln(
      '(${esc(isSigned ? "[SAH] TTD Elektronik Terverifikasi" : "[BELUM TTD] Menunggu Pengesahan")}) Tj',
    );
    stream.writeln('ET');

    if (isSigned) {
      stream.writeln('BT');
      stream.writeln('/F1 6.5 Tf');
      stream.writeln('0.30 0.35 0.42 rg');
      stream.writeln('${(x + 6).toStringAsFixed(1)} 86 Td');
      stream.writeln('(${esc(_truncate("Token: $signature", 30))}) Tj');
      stream.writeln('ET');
    }

    stream.writeln('BT');
    stream.writeln('/F2 7.5 Tf');
    stream.writeln('0.10 0.12 0.18 rg');
    stream.writeln('${(x + 6).toStringAsFixed(1)} 73 Td');
    stream.writeln('(${esc(_truncate(name, 26))}) Tj');
    stream.writeln('ET');

    stream.writeln('BT');
    stream.writeln('/F1 6.5 Tf');
    stream.writeln('0.40 0.45 0.52 rg');
    stream.writeln('${(x + 6).toStringAsFixed(1)} 63 Td');
    stream.writeln(
      '(${esc(_truncate("Waktu: ${signedAt ?? "-"}", 30))}) Tj',
    );
    stream.writeln('ET');
  }

  static String _truncate(String input, int maxLen) {
    if (input.length <= maxLen) return input;
    return '${input.substring(0, maxLen - 3)}...';
  }

  static List<String> _wrapText(String text, int maxChars) {
    final words = text.split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = StringBuffer();

    for (final word in words) {
      if (current.isEmpty) {
        current.write(word);
      } else if (current.length + 1 + word.length <= maxChars) {
        current.write(' $word');
      } else {
        lines.add(current.toString());
        current = StringBuffer(word);
      }
    }
    if (current.isNotEmpty) {
      lines.add(current.toString());
    }
    return lines.isEmpty ? [''] : lines;
  }
}
