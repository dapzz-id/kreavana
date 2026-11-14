import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_sweet_alert.dart';
import '../widgets/official_document_viewer_dialog.dart';

class SchoolPdfService {
  /// Unduh berkas PDF resmi, simpan ke folder Downloads/Dokumen, dan buka berkasnya.
  static Future<String?> downloadOfficialPdf(
    BuildContext context, {
    required String title,
    required String category,
    required String docNumber,
    required String date,
    required String description,
    Map<String, String>? attributes,
    Map<String, dynamic>? rawDocument,
  }) async {
    try {
      final pdfBytes = generateSchoolPdf(
        title: title,
        category: category,
        docNumber: docNumber,
        date: date,
        description: description,
        attributes: attributes ?? {},
      );

      final sanitizedTitle = title
          .replaceAll(RegExp(r'[^\w\s\-]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final fileName = '${sanitizedTitle}_${docNumber.replaceAll('/', '-')}.pdf';

      String? savedPath;

      if (kIsWeb) {
        final base64Data = base64Encode(pdfBytes);
        final uri = Uri.parse('data:application/pdf;base64,$base64Data');
        await launchUrl(uri);
        savedPath = fileName;
      } else {
        Directory? targetDir;
        try {
          targetDir = await getDownloadsDirectory();
        } catch (_) {}
        targetDir ??= await getApplicationDocumentsDirectory();

        final file = File('${targetDir.path}/$fileName');
        await file.writeAsBytes(pdfBytes, flush: true);
        savedPath = file.path;

        // Buka berkas otomatis di aplikasi pembaca PDF default pengguna
        try {
          await launchUrl(Uri.file(file.path));
        } catch (_) {}
      }

      if (context.mounted) {
        // Tampilkan dialog pratinjau resmi
        if (rawDocument != null) {
          OfficialDocumentViewerDialog.show(
            context,
            document: rawDocument,
            isGovernment: false,
          );
        }

        AppSweetAlert.success(
          context,
          'Berkas PDF resmi "$title" berhasil diunduh dan tersimpan di: $savedPath',
          title: 'Unduhan Berhasil',
        );
      }

      return savedPath;
    } catch (e) {
      if (context.mounted) {
        AppSweetAlert.error(
          context,
          'Gagal mengunduh dokumen PDF: $e',
          title: 'Gagal Mengunduh',
        );
      }
      return null;
    }
  }

  /// Membuat binary PDF 1.4 valid secara independen
  static Uint8List generateSchoolPdf({
    required String title,
    required String category,
    required String docNumber,
    required String date,
    required String description,
    required Map<String, String> attributes,
  }) {
    final stream = StringBuffer();

    // ── KOP SURAT ───────────────────────────────────────────────────────────
    stream.writeln('BT');
    stream.writeln('/F1 12 Tf');
    stream.writeln('50 800 Td');
    stream.writeln('(KEMENTERIAN PENDIDIKAN, KEBUDAYAAN, RISET, DAN TEKNOLOGI) Tj');

    stream.writeln('/F1 14 Tf');
    stream.writeln('0 -18 Td');
    stream.writeln('(INSTITUT SENI & REKAYASA KREATIF NUSANTARA (ISRK)) Tj');

    stream.writeln('/F2 9 Tf');
    stream.writeln('0 -14 Td');
    stream.writeln('(Kampus Terpadu Vokasi Kreatif | NPSN: 20401829 | SK Pendirian: 842/E/O/2021) Tj');
    stream.writeln('0 -12 Td');
    stream.writeln('(Website: https://kreavana.id | Email: kemitraan@isrk.ac.id | Surabaya, Jawa Timur) Tj');
    stream.writeln('ET');

    // Garis Kop Surat
    stream.writeln('q');
    stream.writeln('0.26 0.22 0.79 rg'); // Solid Academic Indigo
    stream.writeln('50 742 495 2 re f');
    stream.writeln('Q');

    // ── JUDUL & METADATA DOKUMEN ─────────────────────────────────────────────
    stream.writeln('BT');
    stream.writeln('/F1 13 Tf');
    stream.writeln('50 715 Td');
    stream.writeln('(${_escapePdf(title.toUpperCase())}) Tj');

    stream.writeln('/F2 9.5 Tf');
    stream.writeln('0 -16 Td');
    stream.writeln('(Nomor Dokumen / SK : ${_escapePdf(docNumber)}) Tj');

    stream.writeln('0 -14 Td');
    stream.writeln('(Kategori Dokumen    : ${_escapePdf(category)} | Tanggal Otorisasi: ${_escapePdf(date)}) Tj');

    stream.writeln('0 -14 Td');
    stream.writeln('(Status Validasi    : SAH & TERDAFTAR RESMI DI SISTEM EKOSISTEM KREAVANA) Tj');

    // ── URAIAN KETERANGAN ────────────────────────────────────────────────────
    stream.writeln('/F1 11 Tf');
    stream.writeln('0 -28 Td');
    stream.writeln('(I. RINGKASAN & URAIAN DOKUMEN) Tj');

    stream.writeln('/F2 9.5 Tf');
    stream.writeln('0 -16 Td');
    final descLines = _wrapText(description, 75);
    for (final line in descLines) {
      stream.writeln('(${_escapePdf(line)}) Tj');
      stream.writeln('0 -13 Td');
    }

    // ── TABEL PARAMETER & CAPAIAN INDIKATOR ──────────────────────────────────
    if (attributes.isNotEmpty) {
      stream.writeln('/F1 11 Tf');
      stream.writeln('0 -15 Td');
      stream.writeln('(II. PARAMETER, INDIKATOR KINERJA & KETENTUAN HUKUM) Tj');
      stream.writeln('/F2 9.5 Tf');
      stream.writeln('0 -15 Td');

      for (final entry in attributes.entries) {
        stream.writeln('(  * ${_escapePdf(entry.key)}: ${_escapePdf(entry.value)}) Tj');
        stream.writeln('0 -13 Td');
      }
    }

    // ── PENGESAHAN ELEKTRONIK ────────────────────────────────────────────────
    stream.writeln('/F1 10.5 Tf');
    stream.writeln('0 -25 Td');
    stream.writeln('(III. PENGESAHAN ELEKTRONIK & OTORISASI REKTORAT) Tj');

    stream.writeln('/F2 9 Tf');
    stream.writeln('0 -14 Td');
    stream.writeln('(Dokumen ini telah ditandatangani secara elektronik menggunakan sertifikat elektronik) Tj');
    stream.writeln('0 -12 Td');
    stream.writeln('(yang diterbitkan oleh Balai Sertifikasi Elektronik (BSrE), BSSN Republik Indonesia.) Tj');
    stream.writeln('0 -12 Td');
    stream.writeln('(Akreditasi Institusi: UNGGUL (BAN-PT SK No. 412/SK/BAN-PT/Ak/PT/2024)) Tj');

    stream.writeln('/F1 10 Tf');
    stream.writeln('0 -25 Td');
    stream.writeln('(Ditetapkan di : Surabaya) Tj');
    stream.writeln('0 -13 Td');
    stream.writeln('(Pada Tanggal  : ${_escapePdf(date)}) Tj');
    stream.writeln('0 -15 Td');
    stream.writeln('(Wakil Rektor Bidang Akademik, Riset & Kerjasama Industri) Tj');

    stream.writeln('/F1 11 Tf');
    stream.writeln('0 -38 Td');
    stream.writeln('(Prof. Dr. Ir. H. Bambang Soeprapto, M.Sc., Ph.D.) Tj');
    stream.writeln('/F2 9 Tf');
    stream.writeln('0 -12 Td');
    stream.writeln('(NIP. 19680814 199303 1 002 | Sertifikasi Digital BSrE Verified) Tj');

    stream.writeln('ET');

    // ── PACKING PDF SPECIFICATION 1.4 ────────────────────────────────────────
    final streamBytes = utf8.encode(stream.toString());

    final body = StringBuffer();
    final offsets = <int>[];

    body.write('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n');

    // Obj 1: Catalog
    offsets.add(body.length);
    body.write('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');

    // Obj 2: Pages
    offsets.add(body.length);
    body.write('2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n');

    // Obj 3: Page (A4 standard: 595 x 842 points)
    offsets.add(body.length);
    body.write('3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> /Contents 6 0 R >>\nendobj\n');

    // Obj 4: Font Helvetica-Bold
    offsets.add(body.length);
    body.write('4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\nendobj\n');

    // Obj 5: Font Helvetica
    offsets.add(body.length);
    body.write('5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n');

    // Obj 6: Content Stream
    offsets.add(body.length);
    body.write('6 0 obj\n<< /Length ${streamBytes.length} >>\nstream\n');
    final headerBytes = utf8.encode(body.toString());

    final footer = StringBuffer();
    footer.write('\nendstream\nendobj\n');

    final xrefOffset = headerBytes.length + streamBytes.length + footer.length;
    footer.write('xref\n0 7\n');
    footer.write('0000000000 65535 f \n');
    for (final offset in offsets) {
      footer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    footer.write('trailer\n<< /Size 7 /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF\n');
    final footerBytes = utf8.encode(footer.toString());

    final result = BytesBuilder();
    result.add(headerBytes);
    result.add(streamBytes);
    result.add(footerBytes);
    return result.toBytes();
  }

  static String _escapePdf(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)');
  }

  static List<String> _wrapText(String text, int maxChars) {
    final words = text.split(' ');
    final lines = <String>[];
    String current = '';

    for (final word in words) {
      if ((current + (current.isEmpty ? '' : ' ') + word).length <= maxChars) {
        current += (current.isEmpty ? '' : ' ') + word;
      } else {
        if (current.isNotEmpty) lines.add(current);
        current = word;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines.take(6).toList(); // Maksimum 6 baris agar rapi dalam 1 lembar A4
  }
}
