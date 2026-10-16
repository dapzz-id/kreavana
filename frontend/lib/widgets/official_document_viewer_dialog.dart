import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String get _category => (_meta['category'] ?? _meta['kategori'] ?? 'Surat Keputusan (SK)').toString();
  String get _docNumber => (_meta['doc_number'] ?? _meta['nomor_dokumen'] ?? '027/SPK-KREAVANA/DISPAREKRAF/2026').toString();
  String get _docDate => (_meta['document_date'] ?? _meta['tanggal'] ?? '16 Oktober 2026').toString();
  String get _author => (_meta['author'] ?? _meta['penandatangan'] ?? 'Pejabat Pembuat Komitmen (PPK)').toString();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;

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
                color: isGovernment ? const Color(0xFF1D4ED8) : const Color(0xFF2563EB),
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
                    child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isGovernment
                              ? 'PRATINJAU DOKUMEN RESMI PEMERINTAH'
                              : 'PRATINJAU DOKUMEN KORPORAT RESMI',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          'Sertifikasi Digital BSrE • Terdaftar & Terotentikasi',
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
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  decoration: BoxDecoration(
                    color: Colors.white, // Always authentic paper white
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kop Surat Resmi Pemerintah
                      _buildOfficialHeader(),
                      const SizedBox(height: 10),
                      _buildOfficialDivider(),
                      const SizedBox(height: 20),

                      // Nomor & Klasifikasi
                      _buildDocumentMetadataSection(),
                      const SizedBox(height: 20),

                      // Judul Dokumen
                      Center(
                        child: Column(
                          children: [
                            Text(
                              _category.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Nomor: $_docNumber',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Klausul & Isi Surat
                      _buildDocumentBody(),
                      const SizedBox(height: 32),

                      // Pengesahan, Tanda Tangan & Cap Kedinasan
                      _buildSignaturesSection(),
                      const SizedBox(height: 28),

                      // Footer Verifikasi Digital BSrE
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
                      Clipboard.setData(ClipboardData(text: 'https://verifikasi.kreavana.id/doc/$_docNumber'));
                      AppSweetAlert.success(
                        context,
                        'Tautan verifikasi resmi berhasil disalin ke papan klip.',
                        title: 'Tautan Disalin',
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Salin Tautan Digital'),
                  ),
                  Wrap(
                    spacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          _showVerificationCertificate(context);
                        },
                        icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                        label: const Text('Cek Sertifikat BSrE'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          AppSweetAlert.success(
                            context,
                            'Berkas PDF resmi $_docNumber berhasil diunduh dan tersimpan di perangkat.',
                            title: 'Unduh Berhasil',
                          );
                        },
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Cetak / Unduh PDF Resmi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isGovernment ? const Color(0xFF1D4ED8) : const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
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

  // ── Kop Surat ─────────────────────────────────────────────────────────────
  Widget _buildOfficialHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Garuda Emblem or Official Seal
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFEF3C7),
            border: Border.all(color: const Color(0xFFD97706), width: 1.5),
          ),
          child: const Center(
            child: Icon(Icons.account_balance_rounded, color: Color(0xFFB45309), size: 34),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              Text(
                'PEMERINTAH REPUBLIK INDONESIA',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'DINAS KEBUDAYAAN, PARIWISATA DAN EKONOMI KREATIF',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Kompleks Perkantoran Graha Praja Gedung B, Nusantara\nPos-el: disbudpar@daerah.go.id • Laman: https://lpse.kreavana.id',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 10,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Garis Ganda Kop Surat ──────────────────────────────────────────────────
  Widget _buildOfficialDivider() {
    return Column(
      children: [
        Container(height: 2.5, color: Colors.black87),
        const SizedBox(height: 1.5),
        Container(height: 1.0, color: Colors.black87),
      ],
    );
  }

  // ── Metadata Dokumen ──────────────────────────────────────────────────────
  Widget _buildDocumentMetadataSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Klasifikasi: DOKUMEN RESMI NEGARA', style: _metaStyle()),
              const SizedBox(height: 2),
              Text('Lampiran: 1 (Satu) Berkas Terverifikasi', style: _metaStyle()),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Tanggal Otorisasi: $_docDate', style: _metaStyle()),
              const SizedBox(height: 2),
              Text('Status: SAH & AKTIF', style: _metaStyle(color: const Color(0xFF10B981))),
            ],
          ),
        ],
      ),
    );
  }

  TextStyle _metaStyle({Color color = Colors.black87}) {
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: color,
    );
  }

  // ── Isi Naskah Kedinasan ──────────────────────────────────────────────────
  Widget _buildDocumentBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Menimbang / Mengingat:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 4),
        Text(
          '1. Undang-Undang Nomor 24 Tahun 2019 tentang Ekonomi Kreatif;\n'
          '2. Peraturan Presiden Nomor 12 Tahun 2021 tentang Perubahan atas Peraturan Presiden Nomor 16 Tahun 2018 tentang Pengadaan Barang/Jasa Pemerintah;\n'
          '3. Dokumen Pelaksanaan Anggaran (DPA/DIPA) Tahun Anggaran 2026.',
          style: TextStyle(fontSize: 11, height: 1.5, color: Colors.grey.shade800),
        ),
        const SizedBox(height: 16),
        const Text(
          'Uraian Pokok & Ketentuan Pelaksanaan:',
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
        const SizedBox(height: 14),
        Text(
          'Segala hak cipta, kepemilikan aset intelektual, dan dokumentasi yang diproduksi berdasarkan pengesahan ini sepenuhnya tunduk pada ketentuan hukum negara serta perjanjian kemitraan terdaftar pada platform Kreavana.',
          style: TextStyle(fontSize: 11, height: 1.5, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  // ── Tanda Tangan & Cap Basah ──────────────────────────────────────────────
  Widget _buildSignaturesSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Pihak Rekanan / Mitra
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Penyedia Rekanan Terdaftar,',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.verified, size: 14, color: Color(0xFF2563EB)),
                  SizedBox(width: 4),
                  Text(
                    'TERVERIFIKASI DIGITAL',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'DIREKTUR / KREATOR REKANAN',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            Text(
              'ID Rekanan: KRV-REK-2026-08',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),

        // Pihak Pemerintah PPK & Cap Stempel
        Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Ditetapkan di: Nusantara',
                  style: TextStyle(fontSize: 10, color: Colors.black87),
                ),
                Text(
                  _author,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.shield_rounded, size: 14, color: Color(0xFF059669)),
                      SizedBox(width: 4),
                      Text(
                        'DITANDATANGANI SECARA ELEKTRONIK',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'DR. H. ARYA WIRATAMA, M.M.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'NIP. 19780512 200312 1 004',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),

            // Cap Stempel Basah Kedinasan (Stempel Ungu Melingkar)
            Positioned(
              left: -20,
              top: 15,
              child: Opacity(
                opacity: 0.85,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF6B21A8), width: 2.0),
                  ),
                  child: Center(
                    child: Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF6B21A8), width: 1.0),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'PEMERINTAH',
                            style: TextStyle(
                              fontSize: 6.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF6B21A8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          Icon(Icons.star, size: 8, color: Color(0xFF6B21A8)),
                          Text(
                            'DISPAR',
                            style: TextStyle(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF6B21A8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Footer Keabsahan BSrE ──────────────────────────────────────────────────
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
            child: const Icon(Icons.qr_code_2_rounded, size: 36, color: Colors.black87),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Keabsahan Dokumen Tersertifikasi Elektronik (BSrE - BSSN)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                SizedBox(height: 2),
                Text(
                  'Dokumen ini telah ditandatangani secara elektronik menggunakan sertifikat elektronik yang diterbitkan oleh Balai Sertifikasi Elektronik (BSrE), BSSN.',
                  style: TextStyle(fontSize: 9.5, height: 1.35, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showVerificationCertificate(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.verified_user_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Sertifikat BSrE BSSN', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _certRow('Status:', 'VALID & AKTIF'),
            _certRow('Nomor Registrasi:', _docNumber),
            _certRow('Penerbit:', 'Balai Sertifikasi Elektronik (BSrE) BSSN'),
            _certRow('Integritas Data:', 'SHA-256 Otentik (Tanpa Perubahan)'),
            _certRow('Otoritas Penandatangan:', _author),
            _certRow('Waktu Tanda Tangan:', _docDate),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _certRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
