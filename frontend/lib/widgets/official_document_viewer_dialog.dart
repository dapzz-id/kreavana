import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_sweet_alert.dart';

class OfficialDocumentViewerDialog extends StatelessWidget {
  final Map<String, dynamic> document;
  final bool isGovernment;

  const OfficialDocumentViewerDialog({
    super.key,
    required this.document,
    this.isGovernment = true,
  });

  static void show(
    BuildContext context, {
    required Map<String, dynamic> document,
    bool isGovernment = true,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => OfficialDocumentViewerDialog(
        document: document,
        isGovernment: isGovernment,
      ),
    );
  }

  Map<String, dynamic> get _meta {
    final m = document['metadata'];
    if (m is Map<String, dynamic>) return m;
    return <String, dynamic>{};
  }

  String get _title => (document['title'] ?? 'Dokumen Resmi').toString();
  String get _desc => (document['description'] ?? 'Tidak ada uraian keterangan.').toString();

  String get _category {
    final cat = _meta['category'] ?? _meta['kategori'] ?? document['category'];
    if (cat != null && cat.toString().trim().isNotEmpty) {
      return cat.toString().trim();
    }
    final t = _title.toLowerCase();
    if (t.contains('mou') || t.contains('kerjasama') || t.contains('perjanjian') || t.contains('kemitraan')) {
      return 'Perjanjian Kerjasama (MoU)';
    } else if (t.contains('akreditasi') || t.contains('ban-pt')) {
      return 'Sertifikat Akreditasi';
    } else if (t.contains('pedoman') || t.contains('panduan') || t.contains('juknis')) {
      return 'Pedoman Teknis';
    } else if (t.contains('sk') || t.contains('keputusan')) {
      return 'Surat Keputusan (SK)';
    }
    return 'Dokumen Resmi';
  }

  String get _docNumber {
    final num = _meta['document_number'] ??
        _meta['doc_number'] ??
        _meta['sk_number'] ??
        _meta['nomor_dokumen'] ??
        _meta['no_surat'] ??
        document['document_number'];
    if (num != null && num.toString().trim().isNotEmpty) {
      return num.toString().trim();
    }
    final id = document['id'];
    if (id != null) return 'DOC-$id';
    return '-';
  }

  String get _docDate {
    final d = _meta['document_date'] ??
        _meta['tanggal'] ??
        _meta['valid_until'] ??
        document['published_at'] ??
        document['created_at'];
    if (d != null && d.toString().trim().isNotEmpty) {
      return d.toString().trim();
    }
    return '-';
  }

  String get _author {
    final a = _meta['author'] ??
        _meta['penandatangan'] ??
        _meta['partner_name'] ??
        _meta['institution_name'] ??
        document['author'] ??
        document['institution_name'];
    if (a != null && a.toString().trim().isNotEmpty) {
      return a.toString().trim();
    }
    return 'Instansi Terdaftar';
  }

  String get _status => (document['status'] ?? 'published').toString().toLowerCase();

  String? get _fileUrl {
    final u = _meta['url'] ??
        _meta['file_url'] ??
        _meta['mou_url'] ??
        _meta['attachment_url'] ??
        document['url'] ??
        document['file_url'];
    if (u != null && u.toString().trim().isNotEmpty) {
      final s = u.toString().trim();
      if (s.startsWith('http://') || s.startsWith('https://')) {
        return s;
      }
    }
    return null;
  }

  String get _fileFormat => (_meta['file_format'] ?? 'PDF').toString().toUpperCase();

  String get _fileSize {
    if (_meta['file_size'] != null && _meta['file_size'].toString().isNotEmpty) {
      return _meta['file_size'].toString();
    }
    if (_meta['pages'] != null) {
      return '${_meta['pages']} Halaman';
    }
    return '';
  }

  Future<void> _openExternalFile(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          AppSweetAlert.error(context, 'Tidak dapat membuka tautan berkas: $url');
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppSweetAlert.error(context, 'Gagal membuka berkas: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;

    final isPublished = _status == 'published' || _status == 'active';
    final primaryColor = isGovernment ? const Color(0xFF1D4ED8) : const Color(0xFF2563EB);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isWide ? (screenWidth - 760) / 2 : 16,
        vertical: 24,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Window Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.article_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PRATINJAU DOKUMEN RESMI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          'Arsip Dokumen Terdaftar pada Platform Kreavana',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Scrollable Document Sheet
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
                  decoration: BoxDecoration(
                    color: Colors.white, // Authentic document paper white
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Instansi / Dokumen
                      _buildDocumentHeader(primaryColor),
                      const SizedBox(height: 12),
                      _buildDivider(),
                      const SizedBox(height: 18),

                      // Nomor & Status Dokumen
                      _buildMetadataGrid(isPublished),
                      const SizedBox(height: 20),

                      // Judul Dokumen
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                _category.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                              ),
                            ),
                            if (_docNumber != '-') ...[
                              const SizedBox(height: 4),
                              Text(
                                'Nomor Registrasi: $_docNumber',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Isi / Uraian Dokumen (Data Asli)
                      _buildDocumentContentSection(),
                      const SizedBox(height: 20),

                      // Lampiran Dokumen (Jika Ada)
                      _buildAttachmentSection(context),
                      const SizedBox(height: 20),

                      // Validasi Platform Kreavana
                      _buildVerificationFooter(),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Actions Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161426) : Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _docNumber));
                      AppSweetAlert.success(
                        context,
                        'Nomor dokumen "$_docNumber" berhasil disalin.',
                        title: 'Nomor Disalin',
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Salin Nomor Dokumen'),
                  ),
                  Wrap(
                    spacing: 10,
                    children: [
                      if (_fileUrl != null)
                        ElevatedButton.icon(
                          onPressed: () => _openExternalFile(context, _fileUrl!),
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text('Buka Berkas Asli'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Tutup'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header Dokumen ────────────────────────────────────────────────────────
  Widget _buildDocumentHeader(Color accentColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withValues(alpha: 0.25), width: 1.5),
          ),
          child: Center(
            child: Icon(Icons.account_balance_rounded, color: accentColor, size: 28),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _author.toUpperCase(),
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Platform Kemitraan & Manajemen Arsip Digital Kreavana',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Divider ───────────────────────────────────────────────────────────────
  Widget _buildDivider() {
    return Column(
      children: [
        Container(height: 2.0, color: Colors.grey.shade400),
        const SizedBox(height: 1.5),
        Container(height: 1.0, color: Colors.grey.shade300),
      ],
    );
  }

  // ── Metadata Grid ─────────────────────────────────────────────────────────
  Widget _buildMetadataGrid(bool isPublished) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetaItem('Nomor Dokumen', _docNumber),
              _buildStatusPill(isPublished),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetaItem('Tanggal Terbit / Berlaku', _docDate),
              _buildMetaItem('Format Dokumen', '$_fileFormat ${_fileSize.isNotEmpty ? '• $_fileSize' : ''}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildStatusPill(bool isPublished) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPublished ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPublished ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPublished ? Icons.check_circle_rounded : Icons.pending_rounded,
            size: 13,
            color: isPublished ? const Color(0xFF059669) : const Color(0xFFD97706),
          ),
          const SizedBox(width: 5),
          Text(
            isPublished ? 'Tervalidasi / Terbit' : 'Draft / Dalam Proses',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isPublished ? const Color(0xFF059669) : const Color(0xFFD97706),
            ),
          ),
        ],
      ),
    );
  }

  // ── Uraian Isi Dokumen ────────────────────────────────────────────────────
  Widget _buildDocumentContentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Uraian & Ringkasan Dokumen:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(
            _desc,
            style: const TextStyle(
              fontSize: 12,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        ),
        // Additional parameters if present in metadata
        if (_meta.containsKey('sk_number') ||
            _meta.containsKey('grade') ||
            _meta.containsKey('edition') ||
            _meta.containsKey('pages')) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (_meta['sk_number'] != null)
                _buildInfoTag('No. SK: ${_meta['sk_number']}'),
              if (_meta['grade'] != null)
                _buildInfoTag('Predikat: ${_meta['grade']}'),
              if (_meta['edition'] != null)
                _buildInfoTag('Edisi: ${_meta['edition']}'),
              if (_meta['pages'] != null)
                _buildInfoTag('${_meta['pages']} Halaman'),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildInfoTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
      ),
    );
  }

  // ── Lampiran Berkas ───────────────────────────────────────────────────────
  Widget _buildAttachmentSection(BuildContext context) {
    if (_fileUrl == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: const [
            Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF64748B)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Naskah dokumen digital ini tercatat resmi di database sistem Kreavana.',
                style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFDC2626), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Berkas Lampiran Tersedia',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                ),
                Text(
                  _fileUrl!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF3B82F6)),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _openExternalFile(context, _fileUrl!),
            icon: const Icon(Icons.download_rounded, size: 14),
            label: const Text('Buka', style: TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer Keabsahan Platform ─────────────────────────────────────────────
  Widget _buildVerificationFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Icon(Icons.verified_user_rounded, size: 28, color: Color(0xFF10B981)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Keabsahan Dokumen Terdaftar',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 2),
                Text(
                  'Dokumen ini tercatat resmi di database platform Kreavana dan diterbitkan oleh $_author.',
                  style: const TextStyle(fontSize: 10, height: 1.35, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
