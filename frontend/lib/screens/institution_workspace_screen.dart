import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/app_router.dart';
import '../widgets/desktop_sidebar_layout.dart';
import '../widgets/app_sweet_alert.dart';
import '../widgets/official_document_viewer_dialog.dart';
import '../widgets/app_pagination_bar.dart';

enum _FieldKind { text, number, date, url }

class _WorkspaceField {
  final String key;
  final String label;
  final _FieldKind kind;
  final String? hint;
  final String? prefix;

  const _WorkspaceField(
    this.key,
    this.label, {
    this.kind = _FieldKind.text,
    this.hint,
    this.prefix,
  });
}

class InstitutionWorkspaceScreen extends StatefulWidget {
  final UserModel user;
  final String resourceType;
  final ValueChanged<UserModel>? onUserUpdated;
  final String? initialAction;
  final String? initialItemId;

  const InstitutionWorkspaceScreen({
    super.key,
    required this.user,
    required this.resourceType,
    this.onUserUpdated,
    this.initialAction,
    this.initialItemId,
  });

  @override
  State<InstitutionWorkspaceScreen> createState() =>
      _InstitutionWorkspaceScreenState();
}

class _InstitutionWorkspaceScreenState
    extends State<InstitutionWorkspaceScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;
  String? _loadError;
  String _search = '';
  String _statusFilter = 'Semua';
  int _currentPage = 1;
  static const int _pageSize = 5;
  bool _didHandleInitialAction = false;
  bool _editorOpen = false;

  String? get _baseRoutePath {
    switch (widget.resourceType) {
      case 'documents':
        return AppRoutes.dokumenInstitusi;
      case 'announcements':
        return AppRoutes.pengumumanInstitusi;
      case 'monitoring':
        return AppRoutes.monitoringEvaluasi;
      case 'reports':
        return AppRoutes.laporanKegiatan;
      case 'showcases':
        return AppRoutes.karyaSiswa;
      case 'partners':
        return AppRoutes.mitraIndustri;
      case 'tenders':
        return AppRoutes.pengadaanVendor;
      case 'budgets':
        return AppRoutes.realisasiAnggaran;
      default:
        return null;
    }
  }

  String get _itemUnitName {
    switch (widget.resourceType) {
      case 'events':
        return 'kegiatan';
      case 'partners':
        return 'mitra';
      case 'showcases':
        return 'karya';
      case 'documents':
        return 'dokumen';
      case 'reports':
        return 'laporan';
      case 'monitoring':
        return 'agenda monev';
      case 'tenders':
        return 'tender';
      case 'facilities':
        return 'fasilitas';
      case 'announcements':
        return 'pengumuman';
      case 'study_programs':
        return 'program studi';
      default:
        return 'data';
    }
  }

  bool get _isCorporate {
    final sub = widget.user.subRole?.toLowerCase() ?? '';
    return ['corporate', 'company', 'business', 'perusahaan', 'bisnis'].contains(sub);
  }

  bool get _isGovernment {
    final sub = widget.user.subRole?.toLowerCase() ?? '';
    return [
      'government',
      'pemerintah',
      'instansi',
      'dinas',
      'bumn',
      'kementerian',
    ].contains(sub);
  }

  bool get _isSchool {
    final sub = widget.user.subRole?.toLowerCase() ?? '';
    return [
      'school',
      'sekolah',
      'universitas',
      'institution',
      'kampus',
      'smk',
      'education',
      'institusi',
    ].contains(sub);
  }

  static const Map<String, String> _titles = {
    'tenders': 'Pengadaan & Tender (RFP)',
    'partners': 'Mitra & Komunitas Industri',
    'facilities': 'Fasilitas & Venue',
    'reports': 'Laporan & Evaluasi Kinerja',
    'budgets': 'Realisasi Anggaran',
    'monitoring': 'Monitoring & Evaluasi',
    'documents': 'Dokumen & MoU Institusi',
    'announcements': 'Pengumuman Publik',
    'showcases': 'Karya & Portofolio Peserta',
    'study_programs': 'Program Studi & Jurusan',
    'events': 'Kegiatan, Event & Lomba',
    'talents': 'Direktori & Penelusuran Talenta',
  };

  static const Map<String, String> _actions = {
    'tenders': 'Buat Tender RFP',
    'partners': 'Tambah Mitra Industri',
    'facilities': 'Tambah Fasilitas',
    'reports': 'Buat Laporan',
    'budgets': 'Tambah Anggaran',
    'monitoring': 'Tambah Program',
    'documents': 'Tambah Dokumen',
    'announcements': 'Buat Pengumuman',
    'showcases': 'Tambah Karya Peserta',
    'study_programs': 'Tambah Program Studi',
    'events': 'Tambah Event / Lomba',
    'talents': 'Daftarkan Talenta',
  };

  static const Map<String, IconData> _icons = {
    'tenders': Icons.handshake_outlined,
    'partners': Icons.groups_outlined,
    'facilities': Icons.storefront_outlined,
    'reports': Icons.summarize_outlined,
    'budgets': Icons.account_balance_wallet_outlined,
    'monitoring': Icons.monitor_heart_outlined,
    'documents': Icons.folder_outlined,
    'announcements': Icons.campaign_outlined,
    'showcases': Icons.collections_bookmark_rounded,
    'study_programs': Icons.school_outlined,
    'events': Icons.event_outlined,
    'talents': Icons.person_search_outlined,
  };

  static const Map<String, List<_WorkspaceField>> _fields = {
    'tenders': [
      _WorkspaceField('category', 'Kategori Pengadaan', hint: 'Contoh: Video Advertising, Rebranding, Broadcast'),
      _WorkspaceField(
        'budget',
        'Pagu Anggaran',
        kind: _FieldKind.number,
        prefix: 'Rp ',
      ),
      _WorkspaceField('deadline', 'Batas Pengajuan', kind: _FieldKind.date),
    ],
    'partners': [
      _WorkspaceField(
        'category',
        'Kategori Spesialisasi',
        hint: 'Production House, Studio Animasi, Agensi Desain, Cloud & AI',
      ),
      _WorkspaceField('contact', 'Kontak Person / Email', hint: 'Email atau kontak korespondensi resmi'),
      _WorkspaceField('pic_name', 'Nama PIC Penanggung Jawab', hint: 'Nama lengkap penanggung jawab (PIC) industri'),
      _WorkspaceField('pic_role', 'Jabatan PIC Industri', hint: 'Contoh: Education Lead, Studio Director, HRD'),
      _WorkspaceField('phone', 'Nomor Telepon / WhatsApp PIC', hint: '+62 8... atau nomor telepon kantor'),
      _WorkspaceField(
        'internship_quota_yearly',
        'Kuota Magang Peserta/Tahun',
        kind: _FieldKind.number,
        hint: 'Contoh: 15 (peserta/tahun)',
      ),
      _WorkspaceField('mou_number', 'Nomor Registrasi MoU / PKS', hint: 'Contoh: 012/MoU-ISRK/I/2026'),
      _WorkspaceField('mou_period', 'Masa Berlaku MoU', hint: 'Contoh: 2026 - 2029 (Aktif)'),
      _WorkspaceField('website', 'Website / Portofolio Resmi', kind: _FieldKind.url, hint: 'https://...'),
    ],
    'facilities': [
      _WorkspaceField('category', 'Kategori Fasilitas & Venue', hint: 'Gedung Pertunjukan, Studio Multimedia, Amphiteater, Galeri'),
      _WorkspaceField('capacity', 'Kapasitas Ruang / Fasilitas', hint: '850 Kursi Penonton / 40 Workstation Editing'),
      _WorkspaceField('location', 'Lokasi & Alamat Aset Daerah', hint: 'Jl. Pemuda No. 12, Kompleks Budaya'),
      _WorkspaceField('facilities', 'Sarana Pendukung', hint: 'Tata Suara Line Array, Lighting Panggung DMX, WiFi'),
      _WorkspaceField('terms', 'Ketentuan Peminjaman Kreator', hint: 'Pengajuan H-14, bebas retribusi kegiatan non-komersial'),
      _WorkspaceField('manager', 'Unit Pengelola Aset', hint: 'UPT Pengelolaan Sarana Kebudayaan'),
    ],
    'reports': [
      _WorkspaceField('period', 'Periode Audit / Laporan', hint: 'Contoh: Triwulan I 2026 / TA 2026'),
      _WorkspaceField('category', 'Kategori Program / Audit', hint: 'Evaluasi Dampak Festival, Rebranding UMKM, Audit Mutu'),
      _WorkspaceField('beneficiaries', 'Penerima Manfaat / Warga', hint: 'Contoh: 14.500 Pengunjung & 92 Sanggar Seni'),
      _WorkspaceField('economic_impact', 'Dampak Ekonomi / Omset', hint: 'Contoh: Rp 1,45 Miliar Perputaran Omset'),
      _WorkspaceField('satisfaction_rate', 'Indeks Kepuasan Publik', hint: 'Contoh: 98.4% Indeks Kepuasan Masyarakat'),
      _WorkspaceField('testimonial_author', 'Nama Tokoh / Mitra Testimoni', hint: 'Contoh: Ki Suryo Sasongko (Ketua Sanggar Swara Mahardika)'),
      _WorkspaceField('testimonial_quote', 'Kutipan Testimoni Mitra', hint: 'Contoh: Kolaborasi lewat Kreavana memotong jalur birokrasi...'),
      _WorkspaceField('result', 'Hasil Utama & Temuan Evaluasi', hint: 'Ringkasan capaian program dan dampak ke ekosistem'),
    ],
    'budgets': [
      _WorkspaceField('period', 'Tahun Anggaran / Periode', hint: 'Contoh: 2026 / Semester I'),
      _WorkspaceField(
        'allocation',
        'Pagu Anggaran Disetujui',
        kind: _FieldKind.number,
        prefix: 'Rp ',
      ),
      _WorkspaceField(
        'realization',
        'Realisasi Belanja Berjalan',
        kind: _FieldKind.number,
        prefix: 'Rp ',
      ),
    ],
    'monitoring': [
      _WorkspaceField('indicator', 'Indikator'),
      _WorkspaceField(
        'progress',
        'Progres (%)',
        kind: _FieldKind.number,
        hint: '0 - 100',
      ),
      _WorkspaceField('target_date', 'Target Selesai', kind: _FieldKind.date),
    ],
    'documents': [
      _WorkspaceField(
        'category',
        'Jenis Dokumen Legal',
        hint: 'Purchase Order (PO), MoU Kemitraan, SPK Kontrak, NDA',
      ),
      _WorkspaceField(
        'document_date',
        'Tanggal Dokumen / Otorisasi',
        kind: _FieldKind.date,
      ),
      _WorkspaceField(
        'url',
        'Tautan Dokumen Cloud / PDF',
        kind: _FieldKind.url,
        hint: 'https://docs.kreavana.id/...',
      ),
    ],
    'announcements': [
      _WorkspaceField(
        'category',
        'Kategori',
        hint: 'Informasi, agenda, layanan',
      ),
      _WorkspaceField('valid_until', 'Berlaku Sampai', kind: _FieldKind.date),
    ],
    'showcases': [
      _WorkspaceField(
        'category',
        'Jurusan / Bidang',
        hint: 'Contoh: Animasi 3D, DKV, Broadcast, RPL',
      ),
      _WorkspaceField(
        'creator_name',
        'Nama Peserta / Tim',
        hint: 'Contoh: Tim Studio Animasi / Rian Pratama',
      ),
      _WorkspaceField(
        'image_url',
        'URL Gambar / Preview Karya',
        kind: _FieldKind.url,
        hint: 'https://... (otomatis dipilih dari internet sesuai kriteria jika kosong)',
      ),
      _WorkspaceField(
        'portfolio_url',
        'Tautan Karya / Portofolio',
        kind: _FieldKind.url,
        hint: 'https://youtube.com/... atau Behance',
      ),
      _WorkspaceField(
        'year',
        'Tahun Angkatan',
        hint: 'Contoh: 2026',
      ),
    ],
  };

  static const Map<String, List<String>> _statuses = {
    'tenders': ['open', 'in_progress', 'completed', 'closed'],
    'partners': ['pending', 'active', 'inactive'],
    'facilities': ['open', 'active', 'closed'],
    'reports': ['published', 'draft'],
    'budgets': ['in_progress', 'completed'],
    'monitoring': ['in_progress', 'completed', 'closed'],
    'documents': ['published', 'draft'],
    'announcements': ['draft', 'published'],
    'showcases': ['published', 'draft'],
  };

  String get _title {
    if (_isGovernment) {
      switch (widget.resourceType) {
        case 'tenders':
          return 'Pengadaan LPSE & Tender Terbuka';
        case 'partners':
          return 'Rekanan Kreator & Sanggar Daerah';
        case 'facilities':
          return 'Fasilitas & Venue Kreatif Daerah';
        case 'documents':
          return 'Dokumen Resmi, SK & BAST';
        case 'budgets':
          return 'Alokasi Pagu & DIPA APBD';
        case 'reports':
          return 'Laporan Dampak Publik & Kisah Sukses';
        case 'monitoring':
          return 'Monitoring & Evaluasi (Monev)';
        case 'announcements':
          return 'Siaran Pers & Pengumuman Publik';
      }
    }
    if (_isCorporate) {
      switch (widget.resourceType) {
        case 'tenders':
          return 'Pengadaan & Tender (RFP)';
        case 'partners':
          return 'Mitra & Vendor B2B';
        case 'documents':
          return 'Otorisasi PO & MoU';
        case 'budgets':
          return 'Alokasi Anggaran & Pajak';
        case 'reports':
          return 'Laporan & Audit B2B';
      }
    }
    return _titles[widget.resourceType] ?? 'Data Instansi';
  }

  String get _action {
    if (_isGovernment) {
      switch (widget.resourceType) {
        case 'tenders':
          return 'Buat Tender LPSE';
        case 'partners':
          return 'Daftarkan Rekanan';
        case 'documents':
          return 'Unggah Berkas SK/BAST';
        case 'budgets':
          return 'Entri Anggaran APBD';
        case 'facilities':
          return 'Daftarkan Sarana / Venue';
        case 'reports':
          return 'Terbitkan Laporan Dampak';
        case 'monitoring':
          return 'Tambah Agenda Monev';
        case 'announcements':
          return 'Publikasi Siaran Pers';
      }
    }
    if (_isCorporate) {
      switch (widget.resourceType) {
        case 'tenders':
          return 'Buat Tender RFP';
        case 'partners':
          return 'Tambah Mitra Vendor';
        case 'facilities':
          return 'Tambah Fasilitas';
        case 'documents':
          return 'Unggah PO / MoU';
        case 'budgets':
          return 'Alokasi Anggaran';
        case 'reports':
          return 'Buat Laporan Audit';
      }
    }
    return _actions[widget.resourceType] ?? 'Tambah Data';
  }

  String get _subtitle {
    if (_isGovernment) {
      switch (widget.resourceType) {
        case 'tenders':
          return 'Portal transparansi pengadaan barang & jasa kreatif pemerintah berbasis LPSE dan sistem seleksi terverifikasi.';
        case 'partners':
          return 'Direktori rekanan komunitas, sanggar seni budaya, dan talenta kreatif daerah terdaftar di dinas.';
        case 'facilities':
          return 'Katalog sarana, gedung pertunjukan, studio, dan aset daerah yang dapat diakses oleh kreator dan komunitas.';
        case 'documents':
          return 'Arsip resmi Surat Perintah Kerja (SPK), Berita Acara Serah Terima (BAST), SK Pejabat Pembuat Komitmen, dan MoU.';
        case 'budgets':
          return 'Transparansi realisasi anggaran DIPA/APBD sektor ekonomi kreatif dan belanja konten publik.';
        case 'reports':
          return 'Publikasi hasil program, evaluasi dampak ekonomi, capaian penerima manfaat, dan kisah keberhasilan mitra daerah.';
        case 'monitoring':
          return 'Pengawasan indikator output dan outcome program sosialisasi dan pemberdayaan kreatif masyarakat.';
        case 'announcements':
          return 'Pusat publikasi warta kedinasan, siaran pers, dan maklumat layanan resmi instansi.';
      }
    }
    if (_isCorporate) {
      switch (widget.resourceType) {
        case 'tenders':
          return 'Pusat pengadaan proyek kreatif korporat, seleksi vendor terverifikasi, dan lelang tender B2B.';
        case 'partners':
          return 'Direktori rekanan vendor, creative house, dan agensi terpercaya dengan jaminan mutu & SLA.';
        case 'documents':
          return 'Brankas otorisasi Purchase Order (PO), nota kesepahaman (MoU), SPK, dan kepatuhan NDA legal.';
        case 'budgets':
          return 'Monitoring serapan belanja kreatif korporat, realisasi anggaran, dan rekapitulasi PPh Pasal 23.';
        case 'reports':
          return 'Audit akuntabilitas berkala, analisis efisiensi pengadaan, dan evaluasi performa mitra kerja.';
      }
    }
    if (_isSchool) {
      switch (widget.resourceType) {
        case 'partners':
          return 'Kelola kemitraan industri (DUDI), penyelarasan kurikulum, dan fasilitas magang peserta.';
        case 'showcases':
          return 'Etalase kurasi karya unggulan, proyek tugas akhir peserta, dan portofolio siap kerja untuk mitra industri.';
        case 'documents':
          return 'Arsip resmi perjanjian kerjasama (MoU), surat keputusan legal, dan dokumen akreditasi institusi.';
      }
    }
    return 'Kelola data dan arsip resmi terintegrasi dengan ekosistem Kreavana.';
  }

  List<_WorkspaceField> get _resourceFields =>
      _fields[widget.resourceType] ?? const [];

  List<String> get _resourceStatuses =>
      _statuses[widget.resourceType] ?? const ['draft', 'published'];

  List<Map<String, dynamic>> get _filteredRecords {
    final query = _search.trim().toLowerCase();
    return _records.where((record) {
      final metadata = _metadata(record);
      final status = record['status']?.toString() ?? 'draft';
      final matchesStatus = _statusFilter == 'Semua' || status == _statusFilter;
      final searchable = [
        record['title'],
        record['description'],
        ...metadata.values,
      ].whereType<Object>().join(' ').toLowerCase();
      return matchesStatus && (query.isEmpty || searchable.contains(query));
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    if (_isSchool && widget.resourceType == 'tenders') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppSweetAlert.error(
          context,
          'Fitur Pengadaan & Vendor hanya tersedia untuk akun Corporate / Perusahaan.',
          title: 'Akses Ditolak (403)',
        );
        Navigator.maybePop(context);
      });
      return;
    }
    _loadRecords();
  }

  @override
  void didUpdateWidget(covariant InstitutionWorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resourceType != widget.resourceType) {
      _didHandleInitialAction = false;
      setState(() {
        _currentPage = 1;
        _search = '';
        _statusFilter = 'Semua';
      });
      _searchController.clear();
      _loadRecords();
      return;
    }
    if (oldWidget.initialAction != widget.initialAction ||
        oldWidget.initialItemId != widget.initialItemId) {
      _didHandleInitialAction = false;
      if (!_isLoading && widget.initialAction != null) {
        _maybeHandleInitialRouteAction();
      }
    }
  }

  void _maybeHandleInitialRouteAction() {
    if (_didHandleInitialAction || _editorOpen || widget.initialAction == null) {
      return;
    }
    _didHandleInitialAction = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialAction == 'create') {
        _openEditor(null, false);
      } else if (widget.initialAction == 'edit' &&
          widget.initialItemId != null &&
          widget.initialItemId!.isNotEmpty) {
        final match = _records.cast<Map<String, dynamic>?>().firstWhere(
              (r) => r?['id']?.toString() == widget.initialItemId,
              orElse: () => null,
            );
        if (match != null) {
          _openEditor(match, false);
        } else {
          final base = _baseRoutePath;
          final router = GoRouter.maybeOf(context);
          if (base != null && router != null) {
            router.go(base);
          }
          AppSweetAlert.warning(
            context,
            'Data dengan ID "${widget.initialItemId}" tidak ditemukan.',
            title: 'Data Tidak Ditemukan',
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _metadata(Map<String, dynamic> record) {
    final raw = record['metadata'] ?? record['meta'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    final response = await ApiService.get(
      'institution/resources',
      queryParams: {'type': widget.resourceType},
    );
    if (!mounted) return;
    setState(() {
      final succeeded = response['status'] == true && response['data'] is List;
      final List<Map<String, dynamic>> records = succeeded
          ? List<Map<String, dynamic>>.from(response['data'])
          : [];
      _records = records;
      _currentPage = 1;
      _loadError = succeeded
          ? null
          : response['message']?.toString() ?? 'Data gagal dimuat dari server.';
      _isLoading = false;
    });
    _maybeHandleInitialRouteAction();
  }



  String _formatCurrency(num value) {
    final s = value.toStringAsFixed(0);
    return 'Rp ${s.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'published':
      case 'open':
      case 'active':
      case 'approved':
        return const Color(0xFF10B981); // Emerald Green
      case 'in_progress':
        return const Color(0xFF2563EB); // Royal Blue
      case 'completed':
        return const Color(0xFF8B5CF6); // Purple
      case 'closed':
      case 'inactive':
        return Colors.grey.shade600;
      case 'rejected':
        return const Color(0xFFEF4444); // Red
      case 'pending':
      case 'draft':
      default:
        return const Color(0xFFF59E0B); // Amber
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'Draft Internal';
      case 'published':
        return 'Tervalidasi / Terbit';
      case 'open':
        return 'Terbuka';
      case 'in_progress':
        return 'Sedang Berjalan';
      case 'completed':
        return 'Selesai';
      case 'closed':
        return 'Ditutup';
      case 'active':
        return 'Aktif';
      case 'approved':
        return 'Disetujui';
      case 'pending':
        return 'Menunggu Persetujuan';
      case 'rejected':
        return 'Ditolak';
      case 'inactive':
        return 'Nonaktif';
      default:
        return status;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'published':
      case 'active':
      case 'approved':
        return Icons.check_circle_outline_rounded;
      case 'open':
        return Icons.lock_open_rounded;
      case 'in_progress':
        return Icons.sync_rounded;
      case 'completed':
        return Icons.task_alt_rounded;
      case 'closed':
      case 'inactive':
        return Icons.archive_outlined;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'pending':
        return Icons.hourglass_top_rounded;
      case 'draft':
      default:
        return Icons.edit_note_rounded;
    }
  }

  PopupMenuEntry<String> _buildPopupActionItem({
    required String value,
    required IconData icon,
    required String label,
    required bool isDark,
    Color color = const Color(0xFF2563EB),
    bool isDestructive = false,
  }) {
    final effectiveColor = isDestructive ? Colors.red : color;
    return PopupMenuItem<String>(
      value: value,
      height: 42,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 15, color: effectiveColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDestructive
                    ? Colors.red
                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuEntry<String> _buildPopupDivider() {
    return const PopupMenuDivider(height: 1);
  }

  bool get _canCreateResource {
    if (widget.resourceType == 'tenders' && !_isCorporate && !_isGovernment) {
      return false;
    }
    if (widget.resourceType == 'documents') {
      return false;
    }
    return true;
  }

  Future<void> _openEditor([
    Map<String, dynamic>? existing,
    bool syncUrl = true,
  ]) async {
    if (_editorOpen) return;

    if (existing != null) {
      final exStatus = existing['status']?.toString().toLowerCase() ?? '';
      final exMeta = _metadata(existing);
      final isLockedApprovedPartner = widget.resourceType == 'partners' &&
          (exStatus == 'active' ||
              exStatus == 'approved' ||
              exMeta['approval_status']?.toString().toLowerCase() == 'approved' ||
              exMeta['locked_after_approval'] == true);
      final isLockedSyncedMou = widget.resourceType == 'documents' &&
          ((exMeta['partner_resource_id']?.toString().trim().isNotEmpty ?? false) ||
              exMeta['locked_after_approval'] == true);
      if (isLockedApprovedPartner || isLockedSyncedMou) {
        AppSweetAlert.warning(
          context,
          'Kemitraan dan berkas MoU yang telah disetujui tidak dapat diubah lagi.',
          title: 'Dokumen Terkunci',
        );
        final base = _baseRoutePath;
        final router = GoRouter.maybeOf(context);
        if (!syncUrl && base != null && router != null) {
          router.go(base);
        }
        return;
      }
    }

    if (existing == null && !_canCreateResource) {
      final base = _baseRoutePath;
      final router = GoRouter.maybeOf(context);
      if (!syncUrl && base != null && router != null) {
        router.go(base);
      }
      if (widget.resourceType == 'documents') {
        AppSweetAlert.info(
          context,
          'Dokumen MoU diterbitkan secara otomatis setelah pengajuan kemitraan disetujui oleh pihak mitra penerima.',
          title: 'Penerbitan Dokumen Otomatis',
        );
        return;
      }
      AppSweetAlert.error(
        context,
        'Fitur Buka Program Magang khusus untuk akun Corporate / Mitra Industri. Institusi Pendidikan tidak dapat membuka lowongan magang.',
        title: 'Akses Ditolak (403)',
      );
      return;
    }

    // Sinkronkan URL browser ke /<resource>/create atau /<resource>/:id/edit
    final basePath = _baseRoutePath;
    final router = GoRouter.maybeOf(context);
    if (syncUrl && basePath != null && router != null) {
      final targetPath = existing == null
          ? AppRoutes.workspaceCreatePath(basePath)
          : (existing['id'] != null
              ? AppRoutes.workspaceEditPath(basePath, existing['id'].toString())
              : null);
      if (targetPath != null) {
        router.go(targetPath);
        return;
      }
    }

    _editorOpen = true;
    // If triggered from popup menu, wait for popup route to pop cleanly
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) {
      _editorOpen = false;
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _ResourceEditorDialog(
        user: widget.user,
        resourceType: widget.resourceType,
        title: _title,
        action: _action,
        fields: _resourceFields,
        statuses: _resourceStatuses,
        existing: existing,
        statusLabel: _statusLabel,
        icon: _icons[widget.resourceType] ?? Icons.business,
      ),
    );
    _editorOpen = false;

    if (mounted && basePath != null && router != null) {
      final currentLoc = GoRouterState.of(context).matchedLocation;
      if (currentLoc != basePath && currentLoc.startsWith('$basePath/')) {
        router.go(basePath);
      }
    }

    if (saved == true && mounted) {
      // Let the dialog exit transition finish completely before refreshing records and showing toast
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      await _loadRecords();
      if (mounted) {
        AppSweetAlert.success(
          context,
          'Data $_title berhasil disimpan.',
          title: 'Berhasil Disimpan',
        );
      }
    }
  }

  Future<void> _deleteRecord(Map<String, dynamic> record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A182A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Hapus Data Permanen?',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: Text(
            'Data "${record['title']}" akan dihapus permanen dari sistem.',
            style: TextStyle(color: isDark ? AppTheme.textMuted : Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Batal',
                style: TextStyle(color: isDark ? AppTheme.textMuted : Colors.grey.shade700),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              child: const Text('Hapus Permanen'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    final response = await ApiService.delete(
      'institution/resources/${record['id']}',
    );
    if (!mounted) return;
    if (response['status'] == true) {
      AppSweetAlert.success(
        context,
        'Data "${record['title']}" berhasil dihapus dari sistem.',
        title: 'Berhasil Dihapus',
      );
      await _loadRecords();
    } else {
      AppSweetAlert.error(
        context,
        response['message']?.toString() ?? 'Data gagal dihapus dari sistem.',
        title: 'Gagal Menghapus',
      );
    }
  }

  Future<void> _approvePartnerProposal(Map<String, dynamic> record) async {
    final meta = (record['metadata'] is Map<String, dynamic>)
        ? record['metadata'] as Map<String, dynamic>
        : <String, dynamic>{};
    final ownerMap = (record['user'] is Map<String, dynamic>)
        ? record['user'] as Map<String, dynamic>
        : (record['owner'] is Map<String, dynamic>
            ? record['owner'] as Map<String, dynamic>
            : <String, dynamic>{});
    final partnerName = (ownerMap['name']?.toString() ??
            meta['corporate_name']?.toString() ??
            record['title']?.toString() ??
            'Mitra')
        .trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Setujui Pengajuan Kemitraan?',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Text(
          'Anda yakin ingin menyetujui pengajuan kemitraan dari "$partnerName"?\n\n'
          'Setelah disetujui, kemitraan akan berstatus aktif dan dokumen MoU resmi otomatis diterbitkan.',
          style: const TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Ya, Setujui Kemitraan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final id = record['id'];
    try {
      final res = await ApiService.post('institution/resources/$id/approve', {});
      if (!mounted) return;
      if (res['status'] == true) {
        AppSweetAlert.success(
          context,
          'Kemitraan berhasil disetujui! Berkas dokumen MoU telah otomatis terbit dan masuk ke menu "Dokumen & MoU".',
          title: 'Kemitraan Disetujui',
        );
        await _loadRecords();
      } else {
        AppSweetAlert.error(context, res['message']?.toString() ?? 'Gagal menyetujui kemitraan.');
      }
    } catch (e) {
      if (mounted) {
        AppSweetAlert.error(context, 'Terjadi kendala saat menyetujui: $e');
      }
    }
  }

  Future<void> _rejectPartnerProposal(Map<String, dynamic> record) async {
    final meta = (record['metadata'] is Map<String, dynamic>)
        ? record['metadata'] as Map<String, dynamic>
        : <String, dynamic>{};
    final ownerMap = (record['user'] is Map<String, dynamic>)
        ? record['user'] as Map<String, dynamic>
        : (record['owner'] is Map<String, dynamic>
            ? record['owner'] as Map<String, dynamic>
            : <String, dynamic>{});
    final partnerName = (ownerMap['name']?.toString() ??
            meta['corporate_name']?.toString() ??
            record['title']?.toString() ??
            'Mitra')
        .trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Tolak Pengajuan Kemitraan?',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Text(
          'Anda yakin ingin menolak pengajuan kemitraan dari "$partnerName"?\n\nTindakan ini tidak dapat dibatalkan.',
          style: const TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Ya, Tolak'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final id = record['id'];
    try {
      final res = await ApiService.post('institution/resources/$id/reject', {});
      if (!mounted) return;
      if (res['status'] == true) {
        AppSweetAlert.info(
          context,
          'Pengajuan kemitraan telah ditolak.',
          title: 'Kemitraan Ditolak',
        );
        await _loadRecords();
      } else {
        AppSweetAlert.error(
          context,
          res['message']?.toString() ?? 'Gagal menolak pengajuan kemitraan.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSweetAlert.error(context, 'Terjadi kendala saat menolak: $e');
      }
    }
  }

  Future<void> _openOfficialDocument(
    Map<String, dynamic> record, {
    Map<String, dynamic>? specificFile,
  }) async {
    final meta = _metadata(record);

    if (specificFile != null) {
      final rawUrl = specificFile['url']?.toString().trim() ?? '';
      if (rawUrl.isNotEmpty) {
        await _launchOriginalFileUrl(rawUrl);
        return;
      }
    }

    final files = _extractMouFiles(meta);
    if (files.length == 1) {
      await _launchOriginalFileUrl(files.first['url']!.toString());
      return;
    }

    if (files.length > 1) {
      if (!mounted) return;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final accent = _resolvedAccentColor;
      final docTitle = record['title']?.toString().trim().isNotEmpty == true
          ? record['title'].toString().trim()
          : 'Berkas Kerjasama Asli';

      await showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A162D) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 16, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          title: Row(
            children: [
              Icon(Icons.folder_open_rounded, color: accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Berkas Kerjasama Asli (${files.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      docTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                icon: const Icon(Icons.close_rounded, size: 20),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < files.length; i++)
                  Container(
                    margin: EdgeInsets.only(bottom: i < files.length - 1 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF231F3A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF383457) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.insert_drive_file_outlined, color: accent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                files[i]['filename']?.toString() ?? 'Berkas ${i + 1}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                '${(files[i]['extension'] ?? 'PDF').toString().toUpperCase()} • ${files[i]['filesize'] ?? 'Dokumen Asli'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(dialogCtx).pop();
                            _launchOriginalFileUrl(files[i]['url'].toString());
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 14),
                          label: const Text('Buka Berkas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    final fallbackUrl = (meta['url'] ??
            meta['file_url'] ??
            meta['mou_url'] ??
            record['url'] ??
            record['file_url'] ??
            '')
        .toString()
        .trim();

    if (fallbackUrl.isNotEmpty) {
      await _launchOriginalFileUrl(fallbackUrl);
      return;
    }

    if (widget.resourceType == 'reports' || widget.resourceType == 'documents') {
      if (!mounted) return;
      OfficialDocumentViewerDialog.show(
        context,
        document: record,
        isGovernment: _isGovernment,
      );
      return;
    }

    if (mounted) {
      AppSweetAlert.warning(
        context,
        'Berkas dokumen asli belum tersedia atau belum diunggah.',
        title: 'Berkas Tidak Tersedia',
      );
    }
  }

  Future<void> _launchOriginalFileUrl(String rawUrl) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return;

    final resolved = ApiService.resolveAssetUrl(trimmed);
    final candidate = resolved.isNotEmpty ? resolved : trimmed;

    try {
      final uri = Uri.parse(candidate);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
      final fallbackUri = Uri.parse(trimmed);
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    if (mounted) {
      AppSweetAlert.error(
        context,
        'Tidak dapat membuka berkas dokumen: $candidate',
        title: 'Gagal Membuka Berkas',
      );
    }
  }

  Future<void> _launchUrl(String? urlStr, {Map<String, dynamic>? record}) async {
    if (urlStr == null || urlStr.trim().isEmpty) return;
    await _launchOriginalFileUrl(urlStr);
  }

  Color get _resolvedAccentColor {
    if (_isGovernment) return const Color(0xFF1E3A8A); // Deep Executive Navy
    if (_isSchool) return const Color(0xFF4338CA); // Deep Academic Indigo
    return const Color(0xFF2563EB); // Corporate Sapphire Blue
  }

  static String _getWorkspaceHeroImage(String resourceType, bool isGovernment) {
    const Map<String, String> map = {
      'tenders': 'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=1600&q=80',
      'rfp': 'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=1600&q=80',
      'procurement': 'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=1600&q=80',
      'partners': 'https://images.unsplash.com/photo-1521791136064-7986c2920216?auto=format&fit=crop&w=1600&q=80',
      'vendors': 'https://images.unsplash.com/photo-1521791136064-7986c2920216?auto=format&fit=crop&w=1600&q=80',
      'mitra': 'https://images.unsplash.com/photo-1521791136064-7986c2920216?auto=format&fit=crop&w=1600&q=80',
      'documents': 'https://images.unsplash.com/photo-1450133064473-71024230f91b?auto=format&fit=crop&w=1600&q=80',
      'po': 'https://images.unsplash.com/photo-1450133064473-71024230f91b?auto=format&fit=crop&w=1600&q=80',
      'contracts': 'https://images.unsplash.com/photo-1450133064473-71024230f91b?auto=format&fit=crop&w=1600&q=80',
      'budgets': 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&w=1600&q=80',
      'anggaran': 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&w=1600&q=80',
      'reports': 'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?auto=format&fit=crop&w=1600&q=80',
      'audits': 'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?auto=format&fit=crop&w=1600&q=80',
      'laporan': 'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?auto=format&fit=crop&w=1600&q=80',
      'showcases': 'https://images.unsplash.com/photo-1513364776144-60967b0f800f?auto=format&fit=crop&w=1600&q=80',
      'karya': 'https://images.unsplash.com/photo-1513364776144-60967b0f800f?auto=format&fit=crop&w=1600&q=80',
      'monitoring': 'https://images.unsplash.com/photo-1460925895917-afdab827c52f?auto=format&fit=crop&w=1600&q=80',
      'facilities': 'https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=1600&q=80',
    };
    if (map.containsKey(resourceType)) {
      return map[resourceType]!;
    }
    return isGovernment
        ? 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=1600&q=80'
        : 'https://images.unsplash.com/photo-1497215728101-856f4ea42174?auto=format&fit=crop&w=1600&q=80';
  }

  String _getHeroAuthorityBadge(String type) {
    switch (type) {
      case 'showcases':
      case 'karya':
        return 'Galeri Talenta & Kurasi Karya Vokasi';
      case 'partners':
      case 'mitra':
        return _isSchool
            ? 'Kemitraan Industri & DUDI Vokasi'
            : 'Enterprise B2B Governance & Mitra';
      case 'documents':
        return 'Legalitas & MoU Kerjasama Resmi';
      case 'reports':
        return 'Akuntabilitas & Audit Mutu Akademik';
      case 'monitoring':
        return 'Sistem Monitoring & Evaluasi Kemitraan';
      case 'tenders':
        return _isGovernment
            ? 'Tata Kelola Kedinasan & LPSE'
            : 'Pengadaan & Tender Terbuka';
      case 'budgets':
        return 'Transparansi Pagu & Anggaran';
      case 'facilities':
        return 'Laboratorium & Fasilitas Produksi';
      default:
        return _isSchool
            ? 'Instansi Pendidikan Vokasi Terakreditasi'
            : 'Enterprise B2B Governance';
    }
  }

  IconData _getHeroAuthorityIcon(String type) {
    switch (type) {
      case 'showcases':
      case 'karya':
        return Icons.auto_awesome_rounded;
      case 'partners':
      case 'mitra':
        return Icons.handshake_outlined;
      case 'documents':
        return Icons.verified_user_outlined;
      case 'reports':
        return Icons.analytics_outlined;
      case 'monitoring':
        return Icons.query_stats_rounded;
      case 'tenders':
        return Icons.gavel_rounded;
      case 'budgets':
        return Icons.account_balance_wallet_outlined;
      case 'facilities':
        return Icons.meeting_room_outlined;
      default:
        return Icons.verified_rounded;
    }
  }

  String _getHeroStatBadge(String type, int count) {
    switch (type) {
      case 'showcases':
      case 'karya':
        return '$count Portofolio Terkurasi';
      case 'partners':
      case 'mitra':
        return '$count Rekanan Terdaftar';
      case 'documents':
        return '$count Dokumen Legal';
      case 'reports':
        return '$count Laporan Kinerja';
      case 'monitoring':
        return '$count Agenda Monev';
      case 'tenders':
        return '$count Tender RFP';
      case 'budgets':
        return '$count Alokasi Pagu';
      case 'facilities':
        return '$count Fasilitas Tersedia';
      default:
        return '$count Terdata';
    }
  }

  // ── HEADER HERO EXECUTIVE (Rich Photographic Panoramic Banner) ───────────────
  Widget _buildExecutiveHero(bool isDark) {
    final bgImageUrl = _getWorkspaceHeroImage(widget.resourceType, _isGovernment);
    final accentColor = _resolvedAccentColor;
    final baseDark = isDark ? const Color(0xFF07050E) : const Color(0xFF0B132B);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: baseDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.20),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.28 : 0.20),
            blurRadius: 36,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 650;
          final imageWidth = isCompact
              ? constraints.maxWidth * 0.72
              : (constraints.maxWidth * 0.58).clamp(380.0, 750.0);

          return Stack(
            children: [
              // ── Layer 1: Contextual High-Resolution Background Photo (Anchored Right) ──
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: imageWidth,
                child: Image.network(
                  bgImageUrl,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0.15, -0.22),
                  errorBuilder: (_, _, _) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accentColor, const Color(0xFF1E1B38)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Layer 2: Seamless Horizontal Dark Gradient (Solid Dark Left, Clear Right) ──
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        baseDark,
                        baseDark,
                        baseDark.withValues(alpha: 0.94),
                        baseDark.withValues(alpha: 0.55),
                        baseDark.withValues(alpha: 0.12),
                        Colors.transparent,
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.35, 0.48, 0.62, 0.74, 0.84, 1.0],
                    ),
                  ),
                ),
              ),

              // ── Layer 3: Vibrant Accent Color Glow on Left ──
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.85, -0.5),
                      radius: 1.15,
                      colors: [
                        accentColor.withValues(alpha: isDark ? 0.35 : 0.45),
                        accentColor.withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),

              // ── Layer 4: Foreground Content ──
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Authority & Count Badges
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.28),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFFDE68A).withValues(alpha: 0.5),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _getHeroAuthorityIcon(widget.resourceType),
                                          color: const Color(0xFFFDE047),
                                          size: 14,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            _getHeroAuthorityBadge(widget.resourceType),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                                    ),
                                    child: Text(
                                      _getHeroStatBadge(widget.resourceType, _records.length),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Module Title with Icon
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _icons[widget.resourceType] ?? Icons.business_outlined,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      _title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black87,
                                            offset: Offset(0, 2),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Subtitle
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: isCompact ? double.infinity : constraints.maxWidth * 0.62,
                                ),
                                child: Text(
                                  _subtitle,
                                  style: const TextStyle(
                                    color: Color(0xFFF1F5F9),
                                    fontSize: 13,
                                    height: 1.45,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black87,
                                        offset: Offset(0, 1),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Desktop Action Button
                        if (!isCompact && _canCreateResource) ...[
                          const SizedBox(width: 20),
                          ElevatedButton.icon(
                            onPressed: _openEditor,
                            icon: Icon(Icons.add_rounded, size: 18, color: accentColor),
                            label: Text(
                              _action,
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: accentColor,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 6,
                              shadowColor: Colors.black.withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Mobile Action Button
                    if (isCompact && _canCreateResource) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openEditor,
                          icon: Icon(Icons.add_rounded, size: 18, color: accentColor),
                          label: Text(
                            _action,
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: accentColor,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── KPI METRICS CARDS ROW (Unified Executive Theme) ────────────────────────
  Widget _buildKpiRow(bool isDark) {
    final records = _records;
    final accentColor = _resolvedAccentColor;

    List<Map<String, dynamic>> kpis = [];

    switch (widget.resourceType) {
      case 'tenders':
        final openCount = records.where((r) => r['status'] == 'open').length;
        final inProgCount = records.where((r) => r['status'] == 'in_progress').length;
        double sumBudget = 0;
        for (final r in records) {
          final m = _metadata(r);
          sumBudget += double.tryParse(m['budget']?.toString() ?? '') ?? 0;
        }
        kpis = [
          {'title': 'Total Pengadaan', 'value': records.length.toString(), 'icon': Icons.assignment_outlined},
          {'title': 'Tender Terbuka', 'value': openCount.toString(), 'icon': Icons.lock_open_rounded},
          {'title': 'Dalam Evaluasi', 'value': inProgCount.toString(), 'icon': Icons.hourglass_top_rounded},
          {'title': 'Total Pagu', 'value': _formatCurrency(sumBudget), 'icon': Icons.payments_outlined},
        ];
        break;
      case 'partners':
        final activeCount = records.where((r) => r['status'] == 'active').length;
        final categories = records
            .map((r) => (_metadata(r)['category']?.toString() ?? '').trim())
            .where((c) => c.isNotEmpty)
            .toSet()
            .length;
        final activePartnerPct =
            records.isEmpty ? 0 : ((activeCount / records.length) * 100).round();
        kpis = [
          {'title': 'Total Rekanan', 'value': records.length.toString(), 'icon': Icons.business_center_outlined},
          {'title': 'Mitra Aktif', 'value': activeCount.toString(), 'icon': Icons.check_circle_outline},
          {'title': 'Sektor Bidang', 'value': '$categories Bidang', 'icon': Icons.category_outlined},
          {'title': 'Rasio Kemitraan Aktif', 'value': '$activePartnerPct%', 'icon': Icons.verified_user_outlined},
        ];
        break;
      case 'documents':
        final publishedCount = records.where((r) => r['status'] == 'published').length;
        final draftCount = records.where((r) => r['status'] == 'draft').length;
        final validatedPct =
            records.isEmpty ? 0 : ((publishedCount / records.length) * 100).round();
        kpis = [
          {'title': 'Total Dokumen', 'value': records.length.toString(), 'icon': Icons.folder_copy_outlined},
          {'title': 'Tervalidasi Digital', 'value': publishedCount.toString(), 'icon': Icons.verified_outlined},
          {'title': 'Menunggu Otorisasi', 'value': draftCount.toString(), 'icon': Icons.pending_actions_outlined},
          {'title': 'Rasio Tervalidasi', 'value': '$validatedPct%', 'icon': Icons.shield_outlined},
        ];
        break;
      case 'budgets':
        double allocated = 0;
        double realized = 0;
        for (final r in records) {
          final m = _metadata(r);
          allocated += double.tryParse(m['allocation']?.toString() ?? '') ?? 0;
          realized += double.tryParse(m['realization']?.toString() ?? '') ?? 0;
        }
        final double remaining = allocated - realized;
        final double ratio = allocated > 0 ? (realized / allocated * 100).clamp(0, 100) : 0;
        kpis = [
          {'title': 'Pagu Anggaran', 'value': _formatCurrency(allocated), 'icon': Icons.account_balance_outlined},
          {'title': 'Realisasi Belanja', 'value': _formatCurrency(realized), 'icon': Icons.trending_up_rounded},
          {'title': 'Sisa Pagu', 'value': _formatCurrency(remaining), 'icon': Icons.savings_outlined},
          {'title': 'Rasio Serapan', 'value': '${ratio.toStringAsFixed(1)}%', 'icon': Icons.pie_chart_outline_rounded},
        ];
        break;
      case 'reports':
        final pubCount = records.where((r) => r['status'] == 'published' || r['status'] == 'active').length;
        final pubPct =
            records.isEmpty ? 0 : ((pubCount / records.length) * 100).round();
        kpis = [
          {'title': 'Total Laporan', 'value': records.length.toString(), 'icon': Icons.summarize_outlined},
          {'title': 'Laporan Terbit', 'value': pubCount.toString(), 'icon': Icons.task_alt_rounded},
          {'title': 'Draf Evaluasi', 'value': (records.length - pubCount).toString(), 'icon': Icons.edit_note_rounded},
          {'title': 'Rasio Laporan Terbit', 'value': '$pubPct%', 'icon': Icons.insights_rounded},
        ];
        break;
      case 'monitoring':
        final compCount = records.where((r) => r['status'] == 'completed').length;
        final inProgCount = records.where((r) => r['status'] == 'in_progress').length;
        double sumProgress = 0;
        int countWithProgress = 0;
        for (final r in records) {
          final m = _metadata(r);
          final p = double.tryParse(m['progress']?.toString() ?? '');
          if (p != null) {
            sumProgress += p;
            countWithProgress++;
          }
        }
        final avgProgress = countWithProgress > 0 ? (sumProgress / countWithProgress) : 0;
        kpis = [
          {'title': 'Total Agenda Monev', 'value': records.length.toString(), 'icon': Icons.track_changes_rounded},
          {'title': 'Rata-rata Capaian', 'value': '${avgProgress.toStringAsFixed(0)}%', 'icon': Icons.trending_up_rounded},
          {'title': 'Sedang Berjalan', 'value': inProgCount.toString(), 'icon': Icons.speed_rounded},
          {'title': 'Target Tuntas', 'value': '$compCount Agenda', 'icon': Icons.task_alt_rounded},
        ];
        break;
      case 'showcases':
        final pubCount = records.where((r) => r['status'] == 'published' || r['status'] == 'active').length;
        final majors = records
            .map((r) => (_metadata(r)['category']?.toString() ?? '').trim())
            .where((c) => c.isNotEmpty)
            .toSet()
            .length;
        final verifiedPct =
            records.isEmpty ? 0 : ((pubCount / records.length) * 100).round();
        kpis = [
          {'title': 'Total Karya Peserta', 'value': records.length.toString(), 'icon': Icons.palette_outlined},
          {'title': 'Karya Tervalidasi', 'value': pubCount.toString(), 'icon': Icons.verified_rounded},
          {'title': 'Bidang Keahlian', 'value': '$majors Bidang', 'icon': Icons.school_outlined},
          {'title': 'Rasio Tervalidasi', 'value': '$verifiedPct%', 'icon': Icons.workspace_premium_outlined},
        ];
        break;
      default:
        kpis = [
          {'title': 'Total Data', 'value': records.length.toString(), 'icon': Icons.layers_outlined},
          {'title': 'Status Aktif', 'value': records.where((r) => r['status'] == 'published' || r['status'] == 'open').length.toString(), 'icon': Icons.check_circle_outline},
          {'title': 'Menunggu Review', 'value': records.where((r) => r['status'] == 'draft' || r['status'] == 'in_progress').length.toString(), 'icon': Icons.hourglass_top_outlined},
          {'title': 'Sinkronisasi', 'value': 'Tersinkron', 'icon': Icons.cloud_done_outlined},
        ];
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kpis.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWide ? 4 : 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: isWide ? 2.5 : 2.0,
            ),
            itemBuilder: (context, i) {
              final k = kpis[i];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardBg : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.1 : 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(k['icon'] as IconData, size: 18, color: accentColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            k['title'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.textMuted : const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            k['value'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── SPECIALIZED CARDS PER MODULE ───────────────────────────────────────────

  Widget _buildTenderCard(Map<String, dynamic> record, bool isDark) {
    final meta = _metadata(record);
    final status = record['status']?.toString() ?? 'open';
    final col = _statusColor(status);
    final rawBudget = meta['budget'];
    String budgetStr = 'Rp 0';
    if (rawBudget != null) {
      final bVal = double.tryParse(rawBudget.toString()) ?? 0;
      budgetStr = _formatCurrency(bVal);
    }
    final accentColor = _resolvedAccentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              meta['category'] ?? 'Pengadaan B2B',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: col.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(radius: 3, backgroundColor: col),
                                const SizedBox(width: 5),
                                Text(
                                  _statusLabel(status),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: col,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        record['title']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500),
                  color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF2D2A42) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  onSelected: (value) => value == 'edit'
                      ? _openEditor(record)
                      : _deleteRecord(record),
                  itemBuilder: (_) => [
                    _buildPopupActionItem(
                      value: 'edit',
                      icon: Icons.edit_outlined,
                      label: 'Edit Tender',
                      isDark: isDark,
                      color: const Color(0xFF2563EB),
                    ),
                    _buildPopupDivider(),
                    _buildPopupActionItem(
                      value: 'delete',
                      icon: Icons.delete_outline_rounded,
                      label: 'Hapus Permanen',
                      isDark: isDark,
                      isDestructive: true,
                    ),
                  ],
                ),
              ],
            ),
            if ((record['description']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                record['description'].toString(),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: isDark ? AppTheme.textMuted : const Color(0xFF64748B),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark2 : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.payments_outlined, size: 18, color: accentColor),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pagu Anggaran',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              budgetStr,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(height: 24, width: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.event_outlined, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Batas Pengajuan',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              meta['deadline'] ?? '-',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyOrLaunchContact(String contact) {
    final clean = contact.trim();
    if (clean.isEmpty) return;
    Clipboard.setData(ClipboardData(text: clean));
    AppSweetAlert.success(
      context,
      'Kontak "$clean" berhasil disalin ke clipboard.',
      title: 'Kontak Disalin',
    );
  }

  String _getPartnerMonogram(String title) {
    final clean = title
        .replaceAll(RegExp(r'^(PT|CV|UD|Yayasan|Studio|Komunitas|Asosiasi)\s+', caseSensitive: false), '')
        .trim();
    final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'MI';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  List<Color> _getPartnerGradient(String category, String title) {
    final accentColor = _resolvedAccentColor;
    return [accentColor, accentColor];
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('animasi') || cat.contains('game')) return Icons.sports_esports_outlined;
    if (cat.contains('creative') || cat.contains('design') || cat.contains('grafis')) return Icons.palette_outlined;
    if (cat.contains('sound') || cat.contains('audio')) return Icons.headphones_outlined;
    if (cat.contains('broadcasting') || cat.contains('media') || cat.contains('video')) return Icons.videocam_outlined;
    if (cat.contains('komunitas') || cat.contains('asosiasi')) return Icons.groups_outlined;
    return Icons.business_outlined;
  }

  Widget _buildInfoBadge({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark2 : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.copy_rounded, size: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: badge,
      );
    }
    return badge;
  }

  String? _resolvePartnerLogo(String title, Map<String, dynamic> meta) {
    if ((meta['logo_asset'] ?? '').toString().isNotEmpty) {
      return meta['logo_asset'].toString();
    }
    if ((meta['logo_url'] ?? '').toString().isNotEmpty) {
      return meta['logo_url'].toString();
    }
    final t = title.toLowerCase();
    if (t.contains('google')) return 'assets/partners/google.png';
    if (t.contains('animasi') || t.contains('animation')) return 'assets/partners/animasi_nusantara.png';
    if (t.contains('pixel') || t.contains('creative') || t.contains('desain grafis')) return 'assets/partners/pixel_creative.png';
    if (t.contains('svara') || t.contains('audio') || t.contains('sound') || t.contains('musik')) return 'assets/partners/svara_audio.png';
    if (t.contains('cakrawala') || t.contains('media') || t.contains('siber') || t.contains('broadcast')) return 'assets/partners/cakrawala_media.png';
    if (t.contains('adgi') || t.contains('desainer grafis indonesia')) return 'assets/partners/adgi.png';
    if (t.contains('game') || t.contains('guild') || t.contains('developer')) return 'assets/partners/game_guild.png';
    return null;
  }

  String? _resolvePartnerNetworkLogo(String title, Map<String, dynamic> meta) {
    if ((meta['logo_url'] ?? '').toString().isNotEmpty) {
      return meta['logo_url'].toString();
    }
    final t = title.toLowerCase();
    if (t.contains('google')) {
      return 'https://www.gstatic.com/images/branding/googleg/1x/googleg_standard_color_128dp.png';
    }
    return null;
  }

  Widget _buildPartnerLogoWidget({
    required String? logoPath,
    required String? networkFallbackUrl,
    required String initials,
    required List<Color> gradientColors,
    required String title,
    required String category,
  }) {
    final t = title.toLowerCase();

    // 1. Dedicated authentic Google "G" emblem
    if (t.contains('google')) {
      return _buildGoogleLogoWidget();
    }

    // 2. Local Asset Loader
    if (logoPath != null && logoPath.isNotEmpty && !logoPath.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          logoPath,
          width: 40,
          height: 40,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) {
            if (networkFallbackUrl != null && networkFallbackUrl.isNotEmpty) {
              return Image.network(
                networkFallbackUrl,
                width: 40,
                height: 40,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _buildCorporateEmblemWidget(title, category, gradientColors),
              );
            }
            return _buildCorporateEmblemWidget(title, category, gradientColors);
          },
        ),
      );
    }

    // 3. Network URL Loader
    final url = (logoPath != null && logoPath.startsWith('http')) ? logoPath : networkFallbackUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          width: 40,
          height: 40,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _buildCorporateEmblemWidget(title, category, gradientColors),
        ),
      );
    }

    // 4. Elegant Corporate Emblem Fallback (No ugly raw monogram letters)
    return _buildCorporateEmblemWidget(title, category, gradientColors);
  }

  Widget _buildGoogleLogoWidget() {
    return SizedBox(
      width: 38,
      height: 38,
      child: Image.asset(
        'assets/partners/google.png',
        width: 38,
        height: 38,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) {
          return Image.network(
            'https://www.gstatic.com/images/branding/googleg/1x/googleg_standard_color_128dp.png',
            width: 38,
            height: 38,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => CustomPaint(
              size: const Size(38, 38),
              painter: _GoogleGLogoPainter(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCorporateEmblemWidget(String title, String category, List<Color> gradientColors) {
    final t = title.toLowerCase();
    final IconData emblemIcon;
    if (t.contains('animasi') || t.contains('animation')) {
      emblemIcon = Icons.movie_creation_rounded;
    } else if (t.contains('pixel') || t.contains('creative') || t.contains('desain')) {
      emblemIcon = Icons.auto_awesome_rounded;
    } else if (t.contains('svara') || t.contains('audio') || t.contains('sound') || t.contains('musik')) {
      emblemIcon = Icons.graphic_eq_rounded;
    } else if (t.contains('cakrawala') || t.contains('media') || t.contains('siber') || t.contains('broadcast')) {
      emblemIcon = Icons.podcasts_rounded;
    } else if (t.contains('adgi') || t.contains('desainer')) {
      emblemIcon = Icons.draw_rounded;
    } else if (t.contains('game') || t.contains('guild')) {
      emblemIcon = Icons.sports_esports_rounded;
    } else {
      emblemIcon = Icons.apartment_rounded;
    }

    final accentColor = _resolvedAccentColor;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      ),
      child: Center(
        child: Icon(
          emblemIcon,
          color: accentColor,
          size: 20,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _extractMouFiles(Map<String, dynamic> meta) {
    final files = <Map<String, dynamic>>[];
    final rawList = meta['mou_files'];
    if (rawList is List) {
      for (int i = 0; i < rawList.length; i++) {
        final item = rawList[i];
        if (item is Map && (item['url']?.toString().trim().isNotEmpty ?? false)) {
          files.add({
            'url': item['url'].toString().trim(),
            'filename': (item['filename'] ?? item['file_name'] ?? 'Berkas Kerjasama ${i + 1}')
                .toString()
                .trim(),
            'filesize': (item['filesize'] ?? item['file_size'] ?? 'Dokumen Digital')
                .toString()
                .trim(),
            'extension': (item['extension'] ?? 'pdf').toString().trim(),
          });
        }
      }
    }
    if (files.isEmpty && meta['mou_url'] != null && meta['mou_url'].toString().trim().isNotEmpty) {
      files.add({
        'url': meta['mou_url'].toString().trim(),
        'filename': meta['mou_filename']?.toString().trim().isNotEmpty == true
            ? meta['mou_filename'].toString().trim()
            : 'Dokumen MoU Terlampir',
        'filesize': meta['mou_filesize']?.toString().trim().isNotEmpty == true
            ? meta['mou_filesize'].toString().trim()
            : 'Dokumen Digital',
        'extension': meta['mou_extension']?.toString().trim().isNotEmpty == true
            ? meta['mou_extension'].toString().trim()
            : 'pdf',
      });
    }
    return files;
  }

  static bool _isCorporateRoleValue(String? role) {
    final normalized = (role ?? '').trim().toLowerCase();
    return ['corporate', 'company', 'business', 'perusahaan', 'bisnis', 'enterprise', 'b2b'].contains(normalized);
  }

  static bool _isInstitutionRoleValue(String? role) {
    final normalized = (role ?? '').trim().toLowerCase();
    return ['institution', 'school', 'sekolah', 'kampus', 'education', 'institusi', 'smk', 'universitas'].contains(normalized);
  }

  static String _firstNonEmpty(List<dynamic> candidates) {
    for (final item in candidates) {
      final value = (item ?? '').toString().trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return '';
  }

  Widget _buildPartnerCard(Map<String, dynamic> record, bool isDark) {
    final meta = _metadata(record);
    final status = record['status']?.toString().toLowerCase() ?? 'active';
    final title = record['title']?.toString() ?? 'Mitra Industri';
    var desc = record['description']?.toString() ?? '';
    final accentColor = _resolvedAccentColor;

    final ownerMap = record['owner'] is Map
        ? Map<String, dynamic>.from(record['owner'] as Map)
        : <String, dynamic>{};
    final recipientMap = record['recipient'] is Map
        ? Map<String, dynamic>.from(record['recipient'] as Map)
        : <String, dynamic>{};

    final myId = widget.user.id.toString().trim();
    final myUsername = widget.user.username.trim().toLowerCase();
    final senderId = _firstNonEmpty([meta['sender_user_id'], record['user_id']]);
    final targetId = _firstNonEmpty([meta['target_user_id']]);
    final senderUsername = _firstNonEmpty([meta['sender_username'], ownerMap['username']]).toLowerCase();
    final targetUsername = _firstNonEmpty([meta['target_username'], recipientMap['username']]).toLowerCase();
    final senderRole = _firstNonEmpty([meta['sender_role'], ownerMap['sub_role']]);
    final targetRole = _firstNonEmpty([meta['target_role'], recipientMap['sub_role']]);

    final bool isIncomingProposal;
    if (record.containsKey('viewer_is_recipient')) {
      isIncomingProposal = record['viewer_is_recipient'] == true;
    } else if (targetId.isNotEmpty || targetUsername.isNotEmpty) {
      final matchesTarget = (targetId.isNotEmpty && targetId == myId) ||
          (myUsername.isNotEmpty && targetUsername == myUsername);
      final matchesSender = (senderId.isNotEmpty && senderId == myId) ||
          (myUsername.isNotEmpty && senderUsername == myUsername);
      if (matchesTarget && !matchesSender) {
        isIncomingProposal = true;
      } else if (matchesSender) {
        isIncomingProposal = false;
      } else {
        isIncomingProposal = (_isCorporate && _isInstitutionRoleValue(senderRole)) ||
            (_isSchool && _isCorporateRoleValue(senderRole));
      }
    } else {
      final instNameLegacy = _firstNonEmpty([meta['institution_name'], ownerMap['name']]);
      final corpNameLegacy = _firstNonEmpty([meta['corporate_name'], ownerMap['name']]);
      isIncomingProposal = (record['user_id']?.toString() != myId) &&
          ((_isCorporate && instNameLegacy.isNotEmpty) || (_isSchool && corpNameLegacy.isNotEmpty));
    }

    final canReviewProposal = record.containsKey('viewer_can_review')
        ? record['viewer_can_review'] == true
        : isIncomingProposal;

    final senderIsCorporate = _isCorporateRoleValue(senderRole) ||
        (_isSchool && isIncomingProposal && !_isInstitutionRoleValue(senderRole));
    final targetIsInstitution = _isInstitutionRoleValue(targetRole) ||
        (_isCorporate && !isIncomingProposal && (meta['institution_user_id'] != null && meta['institution_user_id'].toString() != myId));

    final counterpartyName = isIncomingProposal
        ? _firstNonEmpty([
            meta['sender_name'],
            ownerMap['name'],
            senderIsCorporate ? meta['corporate_name'] : meta['institution_name'],
            title,
          ])
        : _firstNonEmpty([
            meta['target_name'],
            recipientMap['name'],
            title,
          ]);

    final counterpartyUsername = isIncomingProposal
        ? _firstNonEmpty([
            meta['sender_username'],
            ownerMap['username'],
            senderIsCorporate ? meta['corporate_username'] : meta['institution_username'],
          ])
        : _firstNonEmpty([
            meta['target_username'],
            recipientMap['username'],
            targetIsInstitution ? meta['institution_username'] : meta['corporate_username'],
          ]);

    final phone = isIncomingProposal
        ? _firstNonEmpty([
            meta['sender_phone'],
            ownerMap['phone'],
            senderIsCorporate ? meta['corporate_phone'] : meta['institution_phone'],
            meta['phone'],
            meta['telepon'],
          ])
        : _firstNonEmpty([
            meta['target_phone'],
            recipientMap['phone'],
            targetIsInstitution ? meta['institution_phone'] : meta['corporate_phone'],
            meta['phone'],
            meta['telepon'],
          ]);

    final contact = isIncomingProposal
        ? _firstNonEmpty([
            meta['sender_email'],
            ownerMap['email'],
            senderIsCorporate ? meta['corporate_email'] : meta['institution_email'],
            meta['contact'],
            meta['email'],
          ])
        : _firstNonEmpty([
            meta['target_email'],
            recipientMap['email'],
            targetIsInstitution ? meta['institution_email'] : meta['corporate_email'],
            meta['contact'],
            meta['email'],
          ]);

    final primaryContact = phone.isNotEmpty ? phone : contact;
    final displayTitle = counterpartyName.isNotEmpty ? counterpartyName : title;
    final mouFiles = _extractMouFiles(meta);

    if (desc.trim().isEmpty) {
      desc = '-';
    }

    final category =
        (meta['category']?.toString() ?? meta['bidang']?.toString() ?? '')
            .trim();

    final picName =
        (meta['pic_name']?.toString() ?? meta['pic']?.toString() ?? '').trim();
    final picRole =
        (meta['pic_role']?.toString() ?? meta['jabatan']?.toString() ?? '')
            .trim();
    final picDisplay = picName.isNotEmpty
        ? (picRole.isNotEmpty ? '$picName ($picRole)' : picName)
        : '';

    final mouNumber =
        (meta['mou_number']?.toString() ?? meta['nomor_mou']?.toString() ?? '')
            .trim();
    final mouPeriod = (meta['mou_period']?.toString() ??
            meta['masa_berlaku']?.toString() ??
            '')
        .trim();
    final mouDisplay = mouNumber.isNotEmpty
        ? (mouPeriod.isNotEmpty ? '$mouNumber • $mouPeriod' : mouNumber)
        : mouPeriod;

    final quota = (meta['internship_quota_yearly']?.toString() ??
            meta['quota']?.toString() ??
            '')
        .trim();
    final quotaDisplay = quota.isNotEmpty ? '$quota Peserta/Tahun' : '';

    final website =
        (meta['website']?.toString() ?? meta['url']?.toString() ?? '').trim();

    final subtitleLabel = isIncomingProposal
        ? (counterpartyUsername.isNotEmpty
            ? '@$counterpartyUsername • ${senderIsCorporate ? 'Pengajuan Kemitraan Corporate' : 'Pengajuan Kemitraan Institusi'}'
            : (senderIsCorporate ? 'Pengajuan Kemitraan Corporate' : 'Pengajuan Kemitraan Institusi'))
        : (category.isNotEmpty
            ? category
            : (counterpartyUsername.isNotEmpty ? '@$counterpartyUsername' : ''));

    final normalizedRecord = Map<String, dynamic>.from(record);
    final normalizedMeta = Map<String, dynamic>.from(meta);
    if (category.isNotEmpty) normalizedMeta['category'] = category;
    if (contact.isNotEmpty) normalizedMeta['contact'] = contact;
    if (picName.isNotEmpty) normalizedMeta['pic_name'] = picName;
    if (picRole.isNotEmpty) normalizedMeta['pic_role'] = picRole;
    if (phone.isNotEmpty) normalizedMeta['phone'] = phone;
    if (mouNumber.isNotEmpty) normalizedMeta['mou_number'] = mouNumber;
    if (mouPeriod.isNotEmpty) normalizedMeta['mou_period'] = mouPeriod;
    if (quota.isNotEmpty) normalizedMeta['internship_quota_yearly'] = quota;
    if (website.isNotEmpty) normalizedMeta['website'] = website;
    normalizedRecord['description'] = desc;
    normalizedRecord['metadata'] = normalizedMeta;

    // Status styling
    final isPublishedOrActive = status == 'active' ||
        status == 'published' ||
        status == 'approved' ||
        meta['approval_status']?.toString().toLowerCase() == 'approved';
    final isPending = status == 'pending' && !isPublishedOrActive;
    final isDraft = status == 'draft';
    final isRejected = status == 'rejected';
    final canEditPartner = !isIncomingProposal && !isPublishedOrActive;

    final Color statusBg = isPublishedOrActive
        ? const Color(0xFFECFDF5)
        : (isPending || isDraft
            ? const Color(0xFFFFFBEB)
            : (isRejected ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9)));
    final Color statusBorder = isPublishedOrActive
        ? const Color(0xFFA7F3D0)
        : (isPending || isDraft
            ? const Color(0xFFFDE68A)
            : (isRejected ? const Color(0xFFFECACA) : const Color(0xFFCBD5E1)));
    final Color statusDotColor = isPublishedOrActive
        ? const Color(0xFF059669)
        : (isPending || isDraft
            ? const Color(0xFFD97706)
            : (isRejected ? const Color(0xFFDC2626) : const Color(0xFF64748B)));
    final String statusText = isPublishedOrActive
        ? 'MoU Aktif / Siap Kerjasama'
        : (isPending
            ? (isIncomingProposal
                ? 'Menunggu Persetujuan Anda'
                : 'Menunggu Persetujuan Mitra')
            : (isDraft ? 'Tahap Inisiasi MoU' : (isRejected ? 'Pengajuan Ditolak' : 'Arsip Kemitraan')));

    final counterpartyIsInstitutionSide = isIncomingProposal
        ? !senderIsCorporate
        : targetIsInstitution;
    final initials = _getPartnerMonogram(displayTitle);
    final gradientColors = _getPartnerGradient(category, displayTitle);
    final categoryIcon = counterpartyIsInstitutionSide ? Icons.school_outlined : _getCategoryIcon(category);
    final counterpartyAvatar = isIncomingProposal
        ? ownerMap['avatar_url']?.toString().trim()
        : recipientMap['avatar_url']?.toString().trim();
    final logoPath = isIncomingProposal ? null : _resolvePartnerLogo(displayTitle, meta);
    final networkUrl = (counterpartyAvatar != null && counterpartyAvatar.isNotEmpty)
        ? ApiService.resolveAssetUrl(counterpartyAvatar)
        : (isIncomingProposal ? null : _resolvePartnerNetworkLogo(displayTitle, meta));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TOP HEADER ROW (Avatar, Title, Badges, Status, Menu)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Company / Institution Logo Container
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDark2 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0)),
                  ),
                  child: Center(
                    child: _buildPartnerLogoWidget(
                      logoPath: logoPath,
                      networkFallbackUrl: networkUrl,
                      initials: initials,
                      gradientColors: gradientColors,
                      title: displayTitle,
                      category: category,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Title & Category/Username & Badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayTitle,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.verified_rounded, color: accentColor, size: 16),
                          const SizedBox(width: 8),
                          // Role/DUDI Tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              counterpartyIsInstitutionSide ? 'Institusi Mitra' : (isIncomingProposal ? 'Corporate Mitra' : 'Mitra DUDI'),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (subtitleLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(categoryIcon, size: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                subtitleLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppTheme.textMuted : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusDotColor,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusDotColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Actions PopupMenu (for creator/sender; edit locked after approval)
                if (!isIncomingProposal)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500),
                    color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF2D2A42) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    onSelected: (value) {
                      if (value == 'edit') _openEditor(normalizedRecord);
                      if (value == 'delete') _deleteRecord(record);
                      if (value == 'contact') _copyOrLaunchContact(primaryContact);
                    },
                    itemBuilder: (_) {
                      final items = <PopupMenuEntry<String>>[];
                      if (canEditPartner) {
                        items.add(
                          _buildPopupActionItem(
                            value: 'edit',
                            icon: Icons.edit_outlined,
                            label: 'Edit Data Mitra',
                            isDark: isDark,
                            color: accentColor,
                          ),
                        );
                      }
                      if (primaryContact.isNotEmpty) {
                        if (items.isNotEmpty) items.add(_buildPopupDivider());
                        items.add(
                          _buildPopupActionItem(
                            value: 'contact',
                            icon: Icons.copy_rounded,
                            label: 'Salin Kontak Mitra',
                            isDark: isDark,
                            color: const Color(0xFF059669),
                          ),
                        );
                      }
                      if (!isPublishedOrActive) {
                        if (items.isNotEmpty) items.add(_buildPopupDivider());
                        items.add(
                          _buildPopupActionItem(
                            value: 'delete',
                            icon: Icons.delete_outline_rounded,
                            label: 'Hapus Permanen',
                            isDark: isDark,
                            isDestructive: true,
                          ),
                        );
                      }
                      return items;
                    },
                  ),
              ],
            ),
          ),

          // 2. DESCRIPTION
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              desc,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              ),
            ),
          ),

          // 3. KEY HIGHLIGHTS / METADATA TILES (Clean & Restrained, no blank '-' clutter)
          if (picDisplay.isNotEmpty ||
              phone.isNotEmpty ||
              contact.isNotEmpty ||
              mouDisplay.isNotEmpty ||
              quotaDisplay.isNotEmpty ||
              mouFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (picDisplay.isNotEmpty)
                    _buildInfoBadge(
                      icon: Icons.person_outline_rounded,
                      label: 'PIC:',
                      value: picDisplay,
                      color: const Color(0xFF475569),
                      isDark: isDark,
                    ),
                  if (phone.isNotEmpty)
                    _buildInfoBadge(
                      icon: Icons.phone_outlined,
                      label: 'Telepon:',
                      value: phone,
                      color: const Color(0xFF059669),
                      isDark: isDark,
                      onTap: () => _copyOrLaunchContact(phone),
                    ),
                  if (contact.isNotEmpty && contact != phone)
                    _buildInfoBadge(
                      icon: Icons.mail_outline_rounded,
                      label: 'Kontak:',
                      value: contact,
                      color: const Color(0xFF475569),
                      isDark: isDark,
                      onTap: () => _copyOrLaunchContact(contact),
                    ),
                  if (mouDisplay.isNotEmpty)
                    _buildInfoBadge(
                      icon: Icons.assignment_outlined,
                      label: 'MoU:',
                      value: mouDisplay,
                      color: const Color(0xFF475569),
                      isDark: isDark,
                    ),
                  if (quotaDisplay.isNotEmpty)
                    _buildInfoBadge(
                      icon: Icons.school_outlined,
                      label: 'Kuota PKL:',
                      value: quotaDisplay,
                      color: const Color(0xFF475569),
                      isDark: isDark,
                    ),
                  for (int i = 0; i < mouFiles.length; i++)
                    _buildInfoBadge(
                      icon: Icons.description_outlined,
                      label: mouFiles.length > 1 ? 'Berkas ${i + 1}:' : 'Berkas MoU:',
                      value: mouFiles[i]['filename']?.toString() ?? 'Dokumen MoU Terlampir',
                      color: accentColor,
                      isDark: isDark,
                      onTap: () => _openOfficialDocument(
                        normalizedRecord,
                        specificFile: mouFiles[i],
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF292543) : const Color(0xFFF1F5F9)),

          // 4. BOTTOM ACTION TOOLBAR (Clean, Unified Outline Buttons)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 14, 12),
            child: Row(
              children: [
                // Left: Vokasi Sync Label
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          isIncomingProposal
                              ? 'Pengajuan Resmi Mitra Kreavana'
                              : (isPublishedOrActive
                                  ? 'MoU Disetujui & Terkunci Permanen'
                                  : 'Terverifikasi Direktori Vokasi & DUDI'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Right Action Buttons
                Flexible(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    children: [
                      if (mouFiles.isNotEmpty)
                        InkWell(
                          onTap: () => _openOfficialDocument(normalizedRecord),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.description_outlined, size: 13, color: accentColor),
                                const SizedBox(width: 5),
                                Text(
                                  mouFiles.length > 1
                                      ? 'Dokumen MoU (${mouFiles.length} Berkas)'
                                      : 'Dokumen MoU',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: accentColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (website.isNotEmpty)
                        InkWell(
                          onTap: () => _launchUrl(website),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.language_rounded, size: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                                const SizedBox(width: 5),
                                Text(
                                  'Website',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(Icons.open_in_new_rounded, size: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ],
                            ),
                          ),
                        ),
                      if (primaryContact.isNotEmpty)
                        InkWell(
                          onTap: () => _copyOrLaunchContact(primaryContact),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  phone.isNotEmpty ? Icons.phone_outlined : Icons.chat_bubble_outline_rounded,
                                  size: 13,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Kontak',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (canEditPartner)
                        InkWell(
                          onTap: () => _openEditor(normalizedRecord),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_outlined, size: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                const SizedBox(width: 5),
                                Text(
                                  'Kelola',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 5. PENDING PROPOSAL REVIEW / STATUS BANNER
          if (isPending)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pending_actions_rounded, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isIncomingProposal
                              ? 'Pengajuan Kemitraan Menunggu Persetujuan Anda'
                              : 'Pengajuan Kemitraan Menunggu Persetujuan Mitra',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isIncomingProposal
                              ? 'Tinjau deskripsi dan berkas asli dari pengirim. Setelah disetujui, status kemitraan aktif dan berkas MoU otomatis diterbitkan.'
                              : 'Saat pihak mitra penerima menyetujui, kemitraan aktif dan berkas MoU otomatis terbit di menu "Dokumen & MoU".',
                          style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                        ),
                      ],
                    ),
                  ),
                  if (isIncomingProposal && canReviewProposal) ...[
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => _rejectPartnerProposal(record),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Tolak', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 15),
                      onPressed: () => _approvePartnerProposal(record),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      label: const Text(
                        'Setujui Kemitraan',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  String? _resolveDocumentAsset(String title, Map<String, dynamic> meta) {
    if ((meta['logo_asset'] ?? '').toString().isNotEmpty) {
      return meta['logo_asset'].toString();
    }
    final t = title.toLowerCase();
    final cat = (meta['category'] ?? '').toString().toLowerCase();

    // 1. BAN-PT & Akreditasi
    if (t.contains('ban-pt') || t.contains('akreditasi') || cat.contains('akreditasi') || t.contains('unggul')) {
      return 'assets/ban_pt.png';
    }

    // 2. Kampus Merdeka & MoU Kemitraan Kampus DUDI
    if (t.contains('kampus') || t.contains('dudi') || t.contains('mbkm') || t.contains('kemitraan kampus') || cat.contains('dudi') || t.contains('mou induk')) {
      return 'assets/kampus_merdeka.png';
    }

    // 3. Partner specific MoU
    if (t.contains('google')) return 'assets/partners/google.png';
    if (t.contains('adgi')) return 'assets/partners/adgi.png';
    if (t.contains('animasi')) return 'assets/partners/animasi_nusantara.png';
    if (t.contains('pixel')) return 'assets/partners/pixel_creative.png';
    if (t.contains('cakrawala')) return 'assets/partners/cakrawala_media.png';
    if (t.contains('game')) return 'assets/partners/game_guild.png';
    if (t.contains('svara')) return 'assets/partners/svara_audio.png';

    // 4. Kemendikbud & Pedoman Teknis PKL
    if (t.contains('kemendikbud') || t.contains('pedoman') || t.contains('sk ') || t.contains('panduan') || t.contains('kurikulum')) {
      return 'assets/kemendikbud.png';
    }

    return null;
  }

  Widget _buildDocumentCard(Map<String, dynamic> record, bool isDark) {
    final meta = _metadata(record);
    final status = record['status']?.toString().toLowerCase() ?? 'published';
    final title = record['title']?.toString() ?? 'Dokumen Resmi Legalitas';
    final desc = record['description']?.toString() ?? '';
    final titleLower = title.toLowerCase();
    final accentColor = _resolvedAccentColor;

    // 1. Resolve Document Category & Icon (prefer explicit metadata from synced partner/project docs)
    final explicitCategory = (meta['category'] ?? '').toString().trim();
    final sourceType = (meta['source_type'] ?? '').toString().trim();
    final isLinkedProject = record['is_linked_project_document'] == true ||
        sourceType.startsWith('project_');
    final partnerResourceId = (meta['partner_resource_id'] ?? '').toString().trim();
    final isLinkedPartner = partnerResourceId.isNotEmpty;
    final linkedOppId = (meta['opportunity_id'] ?? '').toString().trim();

    final String category;
    final IconData catIcon;

    if (explicitCategory.isNotEmpty) {
      category = explicitCategory;
      final catLower = explicitCategory.toLowerCase();
      if (catLower.contains('akreditasi')) {
        catIcon = Icons.verified_outlined;
      } else if (catLower.contains('mou') || catLower.contains('kemitraan')) {
        catIcon = Icons.handshake_outlined;
      } else if (catLower.contains('kontrak') || catLower.contains('spk')) {
        catIcon = Icons.assignment_turned_in_outlined;
      } else if (catLower.contains('surat')) {
        catIcon = Icons.mark_email_read_outlined;
      } else if (catLower.contains('proyek') || catLower.contains('hasil')) {
        catIcon = Icons.work_outline_rounded;
      } else {
        catIcon = Icons.gavel_outlined;
      }
    } else if (titleLower.contains('akreditasi') || titleLower.contains('ban-pt')) {
      category = 'Akreditasi Institusi (BAN-PT)';
      catIcon = Icons.verified_outlined;
    } else if (titleLower.contains('mou') || titleLower.contains('perjanjian') || titleLower.contains('kemitraan')) {
      category = 'MoU Kerjasama Kemitraan DUDI';
      catIcon = Icons.handshake_outlined;
    } else if (titleLower.contains('pedoman') || titleLower.contains('panduan') || titleLower.contains('mbkm') || titleLower.contains('pkl')) {
      category = 'Pedoman Teknis PKL & MBKM';
      catIcon = Icons.menu_book_outlined;
    } else {
      category = 'Dokumen Resmi Legalitas';
      catIcon = Icons.gavel_outlined;
    }

    // 2. Resolve Official Authority Name (prefer explicit metadata before title heuristics)
    final explicitAuthority = [
      meta['authority'],
      meta['partner_name'],
      meta['corporate_name'],
      meta['author'],
    ].map((e) => (e ?? '').toString().trim()).firstWhere((e) => e.isNotEmpty, orElse: () => '');

    final String authority;
    if (explicitAuthority.isNotEmpty) {
      authority = explicitAuthority;
    } else if (titleLower.contains('ban-pt') || titleLower.contains('akreditasi')) {
      authority = 'Badan Akreditasi Nasional Perguruan Tinggi (BAN-PT)';
    } else if (titleLower.contains('kampus merdeka') || titleLower.contains('dudi') || titleLower.contains('mou')) {
      authority = 'Kementerian Pendidikan, Kebudayaan, Riset, & Teknologi (DUDI)';
    } else if (titleLower.contains('pedoman') || titleLower.contains('mbkm')) {
      authority = 'Direktorat Jenderal Pendidikan Vokasi & MBKM';
    } else {
      authority = 'Sekretariat Instansi Resmi Kreavana';
    }

    // 3. Document Registration Number
    var docNumber = meta['document_number']?.toString() ??
        meta['sk_number']?.toString() ??
        meta['doc_number']?.toString() ??
        meta['nomor_dokumen']?.toString() ??
        '';
    if (docNumber.isEmpty) {
      final recId = record['id'];
      docNumber = recId != null ? 'DOC-$recId' : '-';
    }

    // 4. Validity Date / Period
    var validUntil = meta['valid_until']?.toString() ??
        meta['document_date']?.toString() ??
        meta['tanggal']?.toString() ??
        '';
    if (validUntil.isEmpty) {
      validUntil = '-';
    } else if (!validUntil.toLowerCase().contains('berlaku') && !validUntil.toLowerCase().contains('ta ')) {
      validUntil = 'Berlaku s/d $validUntil';
    }

    // 5. File format and size
    final fileFormat = meta['file_format']?.toString() ?? 'PDF';
    final fileSize = meta['file_size']?.toString() ?? '-';

    // 6. Grade / Predikat (for Accreditation)
    final grade = meta['grade']?.toString() ?? '';

    // 7. Status styling
    final isPublished = status == 'published' || status == 'active';
    final Color statusBg = isPublished ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB);
    final Color statusBorder = isPublished ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A);
    final Color statusTextCol = isPublished ? const Color(0xFF059669) : const Color(0xFFD97706);
    final String statusLabel = isPublished ? 'Tervalidasi / Terbit' : 'Draft / Dalam Proses';

    // 8. Logo Asset
    final assetPath = _resolveDocumentAsset(title, meta);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openOfficialDocument(record),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header & Core Information ──
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Official Authority Logo / Asset Badge
                    Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.cardDark2 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: assetPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                assetPath,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => Center(
                                  child: Icon(catIcon, color: accentColor, size: 22),
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Icon(catIcon, color: accentColor, size: 22),
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    // Core Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badges Row (Category, Validity, Status)
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Category Pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(catIcon, size: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                    const SizedBox(width: 5),
                                    Text(
                                      category,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Validity Pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.event_available_rounded,
                                      size: 12,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      validUntil,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: statusBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: statusTextCol,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      statusLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: statusTextCol,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isLinkedProject || isLinkedPartner)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isLinkedProject
                                        ? const Color(0xFFEFF6FF)
                                        : const Color(0xFFF5F3FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isLinkedProject
                                          ? const Color(0xFFBFDBFE)
                                          : const Color(0xFFDDD6FE),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isLinkedProject
                                            ? Icons.work_outline_rounded
                                            : Icons.handshake_outlined,
                                        size: 11.5,
                                        color: isLinkedProject
                                            ? const Color(0xFF1D4ED8)
                                            : const Color(0xFF6D28D9),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isLinkedProject ? 'Proyek Saya' : 'Mitra Industri',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isLinkedProject
                                              ? const Color(0xFF1D4ED8)
                                              : const Color(0xFF6D28D9),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Title
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.2,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 5),
                          // Authority & Doc Number Row
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.account_balance_outlined,
                                    size: 13,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    authority,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  'No: $docNumber',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              desc,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: isDark ? AppTheme.textMuted : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Action Popup Menu (lock edit for approved synced MoUs and incoming records)
                    Builder(builder: (_) {
                      final isLockedMou = isLinkedProject ||
                          isLinkedPartner ||
                          meta['locked_after_approval'] == true;
                      final myDocUserId = widget.user.id.toString();
                      final docTargetId = meta['target_user_id']?.toString() ?? '';
                      final isIncomingDoc = record['user_id']?.toString() != myDocUserId &&
                          (docTargetId == myDocUserId ||
                              (_isCorporate && meta['corporate_user_id']?.toString() == myDocUserId) ||
                              (_isSchool && meta['institution_user_id']?.toString() == myDocUserId));
                      final canEditDoc = !isLockedMou && !isIncomingDoc;
                      final canDeleteDoc = !isIncomingDoc && !isLockedMou;

                      return PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500),
                        color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF2D2A42) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        onSelected: (value) {
                          if (value == 'open') {
                            _openOfficialDocument(record);
                          } else if (value == 'go_project') {
                            if (linkedOppId.isNotEmpty) {
                              context.go('/proyek/$linkedOppId');
                            } else {
                              context.go(AppRoutes.proyek);
                            }
                          } else if (value == 'go_partner') {
                            context.go(AppRoutes.mitraIndustri);
                          } else if (value == 'edit') {
                            _openEditor(record);
                          } else if (value == 'delete') {
                            _deleteRecord(record);
                          }
                        },
                        itemBuilder: (_) {
                          final items = <PopupMenuEntry<String>>[
                            _buildPopupActionItem(
                              value: 'open',
                              icon: Icons.open_in_new_rounded,
                              label: 'Buka Dokumen Resmi',
                              isDark: isDark,
                              color: accentColor,
                            ),
                          ];
                          if (isLinkedProject) {
                            items.add(_buildPopupDivider());
                            items.add(
                              _buildPopupActionItem(
                                value: 'go_project',
                                icon: Icons.work_outline_rounded,
                                label: linkedOppId.isNotEmpty ? 'Buka Proyek Terkait' : 'Lihat di Proyek Saya',
                                isDark: isDark,
                                color: const Color(0xFF2563EB),
                              ),
                            );
                          }
                          if (isLinkedPartner) {
                            items.add(_buildPopupDivider());
                            items.add(
                              _buildPopupActionItem(
                                value: 'go_partner',
                                icon: Icons.handshake_outlined,
                                label: 'Lihat Mitra Industri',
                                isDark: isDark,
                                color: const Color(0xFF7C3AED),
                              ),
                            );
                          }
                          if (canEditDoc) {
                            items.add(_buildPopupDivider());
                            items.add(
                              _buildPopupActionItem(
                                value: 'edit',
                                icon: Icons.edit_outlined,
                                label: 'Edit Berkas',
                                isDark: isDark,
                                color: accentColor,
                              ),
                            );
                          }
                          if (canDeleteDoc) {
                            items.add(_buildPopupDivider());
                            items.add(
                              _buildPopupActionItem(
                                value: 'delete',
                                icon: Icons.delete_outline_rounded,
                                label: 'Hapus Permanen',
                                isDark: isDark,
                                isDestructive: true,
                              ),
                            );
                          }
                          return items;
                        },
                      );
                    }),
                  ],
                ),
              ),

              // ── Legal Security / Accreditation Banner ──
              if (grade.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_outlined, size: 15, color: Color(0xFF059669)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sertifikasi Akreditasi: $grade • Terdaftar Resmi BAN-PT',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'TERAKREDITASI',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (titleLower.contains('mou') || titleLower.contains('kemitraan')) ...[
                Container(
                  margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 15, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Perjanjian Kerjasama Sah Terintegrasi Ekosistem DUDI Vokasi & MBKM',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      Text(
                        'LEGAL & SAH',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Divider ──
              Divider(
                height: 1,
                color: isDark ? const Color(0xFF292543) : const Color(0xFFF1F5F9),
              ),

              // ── Action Footer ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDark2.withValues(alpha: 0.4) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                ),
                child: Row(
                  children: [
                    // File specs & Digital seal pill
                    Expanded(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.description_outlined, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              const SizedBox(width: 5),
                              Text(
                                '$fileFormat • $fileSize',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_outlined, size: 13, color: Color(0xFF059669)),
                              const SizedBox(width: 4),
                              const Text(
                                'Terverifikasi Instansi',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Primary Interactive CTA Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _openOfficialDocument(record),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.open_in_new_rounded, size: 14, color: accentColor),
                              const SizedBox(width: 6),
                              Text(
                                'Buka Dokumen Resmi',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetCard(Map<String, dynamic> record, bool isDark) {
    final meta = _metadata(record);
    final status = record['status']?.toString() ?? 'in_progress';
    final col = _statusColor(status);
    final alloc = double.tryParse(meta['allocation']?.toString() ?? '') ?? 0;
    final real = double.tryParse(meta['realization']?.toString() ?? '') ?? 0;
    final remain = alloc - real;
    final ratio = alloc > 0 ? (real / alloc).clamp(0.0, 1.0) : 0.0;
    final accentColor = _resolvedAccentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'TA ${meta['period'] ?? '2026'}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: col),
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500),
                color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isDark ? const Color(0xFF2D2A42) : const Color(0xFFE2E8F0),
                  ),
                ),
                onSelected: (value) => value == 'edit' ? _openEditor(record) : _deleteRecord(record),
                itemBuilder: (_) => [
                  _buildPopupActionItem(
                    value: 'edit',
                    icon: Icons.tune_rounded,
                    label: 'Sesuaikan Anggaran',
                    isDark: isDark,
                    color: accentColor,
                  ),
                  _buildPopupDivider(),
                  _buildPopupActionItem(
                    value: 'delete',
                    icon: Icons.delete_outline_rounded,
                    label: 'Hapus Permanen',
                    isDark: isDark,
                    isDestructive: true,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            record['title']?.toString() ?? '',
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
          ),
          if ((record['description']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              record['description'].toString(),
              style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.textMuted : Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tingkat Serapan Anggaran', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              Text('${(ratio * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: isDark ? AppTheme.cardDark2 : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                ratio >= 0.9 ? const Color(0xFFEF4444) : (ratio >= 0.7 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark2 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pagu Disetujui', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                      Text(_formatCurrency(alloc), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Realisasi Belanja', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                      Text(_formatCurrency(real), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sisa Pagu', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                      Text(_formatCurrency(remain), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: remain < 0 ? Colors.red : Colors.grey.shade800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (IconData, String?) _resolveReportTheme(String title, Map<String, dynamic> meta) {
    final t = title.toLowerCase();
    final cat = (meta['category'] ?? '').toString().toLowerCase();

    if (t.contains('akreditasi') || t.contains('ban-pt') || cat.contains('akreditasi')) {
      return (Icons.verified_rounded, 'assets/ban_pt.png');
    }
    if (t.contains('mbkm') || t.contains('magang') || cat.contains('mbkm') || cat.contains('magang')) {
      return (Icons.school_rounded, 'assets/kampus_merdeka.png');
    }
    if (t.contains('survei') || t.contains('kepuasan') || cat.contains('survei') || cat.contains('kepuasan')) {
      return (Icons.rate_review_rounded, null);
    }
    if (t.contains('anggaran') || t.contains('keuangan') || t.contains('ekonomi') || cat.contains('keuangan')) {
      return (Icons.account_balance_wallet_rounded, null);
    }
    return (Icons.summarize_rounded, 'assets/kemendikbud.png');
  }

  Widget _buildReportMetricPill({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B32) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2F2B4A) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: iconColor ?? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> record, bool isDark) {
    final meta = _metadata(record);
    final status = record['status']?.toString().toLowerCase() ?? 'published';
    final title = record['title']?.toString() ?? 'Laporan Akuntabilitas & Kinerja';
    final desc = record['description']?.toString() ?? '';
    final category = meta['category']?.toString() ?? 'Laporan Kinerja & Evaluasi';
    final period = meta['period']?.toString() ?? 'TA 2025/2026';
    final signatory = meta['signatory']?.toString() ??
        meta['author']?.toString() ??
        'Biro Penjaminan Mutu & Kerjasama';

    final (catIcon, assetPath) = _resolveReportTheme(title, meta);
    final accentColor = _resolvedAccentColor;
    final isPublished = status == 'published' || status == 'active';
    final statusBg = isPublished
        ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5))
        : (isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFFFBEB));
    final statusBorder = isPublished ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A);
    final statusTextCol = isPublished ? const Color(0xFF059669) : const Color(0xFFD97706);
    final statusLabel = isPublished ? 'Tervalidasi / Terbit' : 'Draf Inisiasi';

    // Key metrics chips list
    final metricBadges = <Widget>[];

    if (meta['total_interns'] != null || meta['beneficiaries'] != null) {
      final val = meta['total_interns'] ?? meta['beneficiaries'];
      metricBadges.add(
        _buildReportMetricPill(
          icon: Icons.groups_rounded,
          label: 'Peserta Magang',
          value: '$val Peserta',
          isDark: isDark,
        ),
      );
    }

    if (meta['completion_rate'] != null) {
      metricBadges.add(
        _buildReportMetricPill(
          icon: Icons.task_alt_rounded,
          iconColor: const Color(0xFF059669),
          label: 'Kelulusan',
          value: meta['completion_rate'].toString(),
          isDark: isDark,
        ),
      );
    }

    if (meta['partner_satisfaction'] != null || meta['satisfaction_score'] != null || meta['satisfaction_rate'] != null) {
      final val = meta['partner_satisfaction']?.toString() ??
          (meta['satisfaction_score'] != null ? '${meta['satisfaction_score']}%' : meta['satisfaction_rate']?.toString() ?? '');
      metricBadges.add(
        _buildReportMetricPill(
          icon: Icons.star_rounded,
          label: 'Skor Kepuasan Mitra',
          value: val,
          isDark: isDark,
        ),
      );
    }

    if (meta['employment_offer_rate'] != null) {
      metricBadges.add(
        _buildReportMetricPill(
          icon: Icons.handshake_rounded,
          label: 'Tawaran Kerja Langsung',
          value: meta['employment_offer_rate'].toString(),
          isDark: isDark,
        ),
      );
    } else if (meta['economic_impact'] != null) {
      metricBadges.add(
        _buildReportMetricPill(
          icon: Icons.trending_up_rounded,
          label: 'Dampak Ekonomi',
          value: meta['economic_impact'].toString(),
          isDark: isDark,
        ),
      );
    }

    if (meta['criteria_met'] != null) {
      metricBadges.add(
        _buildReportMetricPill(
          icon: Icons.fact_check_rounded,
          iconColor: const Color(0xFF059669),
          label: 'Standar Mutu',
          value: meta['criteria_met'].toString(),
          isDark: isDark,
        ),
      );
    }

    if (meta['status_accreditation'] != null) {
      metricBadges.add(
        _buildReportMetricPill(
          icon: Icons.military_tech_rounded,
          label: 'Predikat BAN-PT',
          value: meta['status_accreditation'].toString(),
          isDark: isDark,
        ),
      );
    }

    if (meta['key_strengths'] != null) {
      metricBadges.add(
        _buildReportMetricPill(
          icon: Icons.bolt_rounded,
          label: 'Keunggulan Utama',
          value: meta['key_strengths'].toString(),
          isDark: isDark,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161426) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2B2844) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Logo/Avatar + Category, Period, Status + Actions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Official Emblem / Logo / Icon Box
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1B32) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF383457) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Center(
                        child: assetPath != null
                            ? Padding(
                                padding: const EdgeInsets.all(7),
                                child: Image.asset(
                                  assetPath,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(child: Icon(catIcon, color: accentColor, size: 18)),
                                  ),
                                ),
                              )
                            : Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(child: Icon(catIcon, color: accentColor, size: 18)),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Title, Category & Period Pills
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Category Pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(catIcon, size: 12, color: accentColor),
                                    const SizedBox(width: 5),
                                    Text(
                                      category,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: accentColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Period Pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF201D35) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF383457) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 11.5,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      period,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: statusBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: statusTextCol,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      statusLabel,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: statusTextCol,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Action Menu
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500),
                      color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF2D2A42) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      onSelected: (value) {
                        if (value == 'open') {
                          _openOfficialDocument(record);
                        } else if (value == 'edit') {
                          _openEditor(record);
                        } else if (value == 'delete') {
                          _deleteRecord(record);
                        }
                      },
                      itemBuilder: (_) => [
                        _buildPopupActionItem(
                          value: 'open',
                          icon: Icons.open_in_new_rounded,
                          label: 'Buka Laporan Lengkap',
                          isDark: isDark,
                          color: accentColor,
                        ),
                        _buildPopupDivider(),
                        _buildPopupActionItem(
                          value: 'edit',
                          icon: Icons.edit_rounded,
                          label: 'Edit Data Laporan',
                          isDark: isDark,
                          color: accentColor,
                        ),
                        _buildPopupDivider(),
                        _buildPopupActionItem(
                          value: 'delete',
                          icon: Icons.delete_outline_rounded,
                          label: 'Hapus Permanen',
                          isDark: isDark,
                          isDestructive: true,
                        ),
                      ],
                    ),
                  ],
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: isDark ? AppTheme.textMuted : const Color(0xFF475569),
                    ),
                  ),
                ],
                // Key Metrics Highlight Strip
                if (metricBadges.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1B32) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2F2B4D) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.insights_rounded, size: 14, color: accentColor),
                            const SizedBox(width: 6),
                            Text(
                              'Indikator Capaian & Ringkasan Evaluasi:',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: metricBadges,
                        ),
                      ],
                    ),
                  ),
                ],
                if ((meta['result'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.verified_outlined, size: 17, color: Color(0xFF059669)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Hasil Utama & Temuan Evaluasi:',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                meta['result'],
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Footer Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark2.withValues(alpha: 0.4) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              border: Border(
                top: BorderSide(color: isDark ? const Color(0xFF2B2844) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 14,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Otorisasi: $signatory',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openOfficialDocument(record),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_new_rounded, size: 14, color: accentColor),
                          const SizedBox(width: 6),
                          Text(
                            'Buka Laporan Lengkap',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isTargetNear(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return false;
    try {
      final dt = DateTime.tryParse(dateStr.trim());
      if (dt == null) return false;
      final now = DateTime.now();
      final diff = dt.difference(DateTime(now.year, now.month, now.day)).inDays;
      return diff >= 0 && diff <= 30;
    } catch (_) {
      return false;
    }
  }

  String _formatDateIndo(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '-';
    try {
      final parsed = DateTime.tryParse(dateStr.trim());
      if (parsed == null) return dateStr;
      const months = [
        '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      final m = parsed.month >= 1 && parsed.month <= 12 ? months[parsed.month] : '${parsed.month}';
      return '${parsed.day} $m ${parsed.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDeadlineCountdown(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return 'Belum Diatur';
    try {
      final dt = DateTime.tryParse(dateStr.trim());
      if (dt == null) return dateStr;
      final now = DateTime.now();
      final diff = dt.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (diff > 0) {
        return 'Sisa $diff Hari';
      } else if (diff == 0) {
        return 'Hari Ini';
      } else {
        return 'Lewat ${-diff} Hari';
      }
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildMonitoringCard(Map<String, dynamic> record, bool isDark) {
    final meta = _metadata(record);
    final title = record['title']?.toString() ?? 'Program Monitoring & Evaluasi';
    final desc = record['description']?.toString() ?? '';
    final status = record['status']?.toString().toLowerCase() ?? 'in_progress';
    final indicator = meta['indicator']?.toString() ?? 'Indikator Capaian Kinerja (IKU)';
    final category = meta['category']?.toString() ?? '';
    final targetDate = meta['target_date']?.toString() ?? '';
    final auditCycle = meta['audit_cycle']?.toString() ?? 'SPMI Siklus Ganjil 2026/2027';
    final rawProgress = meta['progress'];
    final double progress = (rawProgress is num)
        ? rawProgress.toDouble().clamp(0, 100)
        : (double.tryParse(rawProgress?.toString() ?? '') ?? 0).clamp(0, 100);

    final bool isCompleted = progress >= 100 || status == 'completed';
    final bool isNearDeadline = targetDate.isNotEmpty && _isTargetNear(targetDate);
    final accentColor = _resolvedAccentColor;
    final Color progressColor = isCompleted ? const Color(0xFF059669) : accentColor;

    // ── PROGRAM IDENTITY & AUTHENTIC EMBLEM RESOLUTION ─────────────────────
    final lowerTitle = title.toLowerCase();
    final lowerIndicator = indicator.toLowerCase();
    final lowerCategory = category.toLowerCase();
    final combined = '$lowerTitle $lowerIndicator $lowerCategory';

    final String assetPath;
    final String agencyLabel;
    final String ikuCode;

    if (combined.contains('magang') || combined.contains('mbkm') || combined.contains('merdeka')) {
      assetPath = 'assets/kampus_merdeka.png';
      agencyLabel = 'KEMENDIKBUDRISTEK • MBKM MANDIRI';
      ikuCode = 'IKU 2';
    } else if (combined.contains('bnsp') || combined.contains('lsp') || combined.contains('sertifikasi')) {
      assetPath = 'assets/bnsp.png';
      agencyLabel = 'BNSP • STANDARISASI PROFESI NASIONAL';
      ikuCode = 'IKU 4';
    } else if (combined.contains('akreditasi') || combined.contains('ban-pt') || combined.contains('ban_pt')) {
      assetPath = 'assets/ban_pt.png';
      agencyLabel = 'BAN-PT • AKREDITASI PERGURUAN TINGGI';
      ikuCode = 'IKU 8';
    } else if (combined.contains('kurikulum') || combined.contains('dudi') || combined.contains('kolaboratif') || combined.contains('pbl')) {
      assetPath = 'assets/kemendikbud.png';
      agencyLabel = 'DIREKTORAT KEMITRAAN DUDI • VOKASI';
      ikuCode = 'IKU 7';
    } else {
      assetPath = 'assets/kemendikbud.png';
      agencyLabel = 'TRACER STUDY • VOKASI KEMENDIKBUD';
      ikuCode = 'IKU 1';
    }

    // Baseline minimum target
    final double targetMin = (meta['target_min'] is num)
        ? (meta['target_min'] as num).toDouble()
        : (combined.contains('magang')
            ? 75.0
            : (combined.contains('bnsp')
                ? 70.0
                : (combined.contains('kurikulum') ? 100.0 : 80.0)));

    final double surplus = progress - targetMin;
    final bool isSurplus = surplus >= 0;

    // Rich quantitative field metrics
    final String metricAchieved;
    final String metricTarget;
    final String metricUnit;

    if (meta['achieved_count'] != null && meta['target_count'] != null) {
      metricAchieved = meta['achieved_count'].toString();
      metricTarget = meta['target_count'].toString();
      metricUnit = meta['unit']?.toString() ?? 'Peserta Terdata';
    } else if (combined.contains('magang')) {
      final val = (150 * (progress / 100)).round();
      metricAchieved = '$val';
      metricTarget = '150';
      metricUnit = 'Peserta Magang Industri';
    } else if (combined.contains('bnsp')) {
      final val = (200 * (progress / 100)).round();
      metricAchieved = '$val';
      metricTarget = '200';
      metricUnit = 'Peserta Lulus Uji BNSP';
    } else if (combined.contains('kurikulum')) {
      final val = (18 * (progress / 100)).round();
      metricAchieved = '$val';
      metricTarget = '18';
      metricUnit = 'Modul DUDI Diselaraskan';
    } else {
      final val = (400 * (progress / 100)).round();
      metricAchieved = '$val';
      metricTarget = '400';
      metricUnit = 'Lulusan Bekerja / Wirausaha';
    }

    final statusBg = isCompleted
        ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5))
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9));
    final statusBorder = isCompleted
        ? const Color(0xFFA7F3D0)
        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
    final statusTextCol = isCompleted
        ? const Color(0xFF059669)
        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569));
    final statusLabel = isCompleted
        ? 'Target Tercapai (100%)'
        : (isSurplus ? 'Melampaui Standar' : 'Sedang Berjalan');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161426) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2B2844) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Authentic Program Emblem + Identity Header + Actions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Official Institutional Emblem Frame
                    _buildMonitoringEmblem(
                      assetPath: assetPath,
                      ikuCode: ikuCode,
                      accentColor: accentColor,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 14),
                    // Header Details: Authority Chip + Title + Indicator Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Authority Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_rounded, size: 12, color: accentColor),
                                    const SizedBox(width: 5),
                                    Text(
                                      agencyLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                        color: accentColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: statusBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: statusTextCol,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      statusLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: statusTextCol,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.track_changes_rounded,
                                size: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  indicator,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Action Popup Menu
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500),
                      color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF2D2A42) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _openEditor(record);
                        } else if (value == 'delete') {
                          _deleteRecord(record);
                        }
                      },
                      itemBuilder: (_) => [
                        _buildPopupActionItem(
                          value: 'edit',
                          icon: Icons.edit_note_rounded,
                          label: 'Update Progres & Target',
                          isDark: isDark,
                          color: accentColor,
                        ),
                        _buildPopupDivider(),
                        _buildPopupActionItem(
                          value: 'delete',
                          icon: Icons.delete_outline_rounded,
                          label: 'Hapus Agenda Monev',
                          isDark: isDark,
                          isDestructive: true,
                        ),
                      ],
                    ),
                  ],
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: isDark ? AppTheme.textMuted : const Color(0xFF475569),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // ── QUANTITATIVE EXECUTIVE SCORECARD & BENCHMARK TRACKER ─────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1B182E) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2D294D) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. The 3 Quantitative Scorecard Metrics
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 580;
                          final tiles = [
                            _buildScorecardTile(
                              label: 'Realisasi Capaian',
                              value: '${progress.toStringAsFixed(0)}%',
                              badge: isCompleted
                                  ? 'Target Tercapai'
                                  : (isSurplus
                                      ? '+${surplus.toStringAsFixed(0)}% Surplus'
                                      : '-${surplus.abs().toStringAsFixed(0)}% Gap'),
                              valueColor: progressColor,
                              isDark: isDark,
                              icon: Icons.query_stats_rounded,
                            ),
                            _buildScorecardTile(
                              label: 'Standar Minimum',
                              value: '${targetMin.toStringAsFixed(0)}%',
                              badge: 'Ambang Batas SPMI',
                              valueColor: isDark ? Colors.white : const Color(0xFF0F172A),
                              isDark: isDark,
                              icon: Icons.tune_rounded,
                            ),
                            _buildScorecardTile(
                              label: 'Data Riil Terverifikasi',
                              value: '$metricAchieved / $metricTarget',
                              badge: metricUnit,
                              valueColor: isDark ? Colors.white : const Color(0xFF0F172A),
                              isDark: isDark,
                              icon: Icons.people_outline_rounded,
                            ),
                          ];

                          if (isNarrow) {
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: tiles[0]),
                                    const SizedBox(width: 8),
                                    Expanded(child: tiles[1]),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                tiles[2],
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: tiles[0]),
                              const SizedBox(width: 10),
                              Expanded(child: tiles[1]),
                              const SizedBox(width: 10),
                              Expanded(child: tiles[2]),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // 2. Segmented Benchmark Progress Bar with Target Pin Marker
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Progres Kumulatif Realisasi vs Standar Mutu',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isCompleted ? const Color(0xFF059669) : (isSurplus ? accentColor : const Color(0xFFD97706)))
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isCompleted
                                      ? 'Capaian Tuntas (100%)'
                                      : (isSurplus
                                          ? 'Melampaui Standar (+${surplus.toStringAsFixed(0)}%)'
                                          : 'Perlu Akselerasi (-${surplus.abs().toStringAsFixed(0)}%)'),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: isCompleted ? const Color(0xFF059669) : (isSurplus ? accentColor : const Color(0xFFD97706)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Dual Track Bar with Target Pin
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Background Track
                              Container(
                                height: 10,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF292543) : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              // Active Progress Fill
                              FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: (progress / 100).clamp(0.02, 1.0),
                                child: Container(
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: progressColor,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                              // Target Minimum Marker (The Benchmark Line at targetMin%)
                              if (targetMin > 0 && targetMin < 100)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: -3,
                                  bottom: -3,
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: (targetMin / 100).clamp(0.05, 0.95),
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        width: 2.5,
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '0% Awal',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              if (targetMin > 0 && targetMin < 100)
                                Text(
                                  '▲ Ambang Batas SPMI: ${targetMin.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                  ),
                                ),
                              Text(
                                '100% Target',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // 3. Milestone, Deadline & Audit Details
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (targetDate.isNotEmpty) ...[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.event_available_rounded,
                                  size: 14,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Target: ${_formatDateIndo(targetDate)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (isCompleted ? const Color(0xFF059669) : (isNearDeadline ? const Color(0xFFD97706) : accentColor))
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: (isCompleted ? const Color(0xFF059669) : (isNearDeadline ? const Color(0xFFD97706) : accentColor))
                                      .withValues(alpha: 0.25),
                                ),
                              ),
                              child: Text(
                                isCompleted ? 'Target Tercapai' : _formatDeadlineCountdown(targetDate),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isCompleted ? const Color(0xFF059669) : (isNearDeadline ? const Color(0xFFD97706) : accentColor),
                                ),
                              ),
                            ),
                          ],
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.hub_outlined,
                                size: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                auditCycle,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Footer Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark2.withValues(alpha: 0.4) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              border: Border(
                top: BorderSide(color: isDark ? const Color(0xFF2B2844) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 14,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Sistem Pengendalian Mutu & Akreditasi Vokasi Terintegrasi PDDikti',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openEditor(record),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_note_rounded, size: 15, color: accentColor),
                          const SizedBox(width: 6),
                          Text(
                            'Update Progres & Capaian',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonitoringEmblem({
    required String assetPath,
    required String ikuCode,
    Color? emblemColor,
    Color? accentColor,
    required bool isDark,
  }) {
    final effColor = accentColor ?? emblemColor ?? _resolvedAccentColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 50,
          height: 50,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1B32) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF383457)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Center(
              child: Icon(
                Icons.verified_rounded,
                color: effColor,
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: effColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: effColor.withValues(alpha: 0.2),
              width: 0.8,
            ),
          ),
          child: Text(
            ikuCode,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: effColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScorecardTile({
    required String label,
    required String value,
    required String badge,
    Color? color,
    Color? valueColor,
    required bool isDark,
    IconData? icon,
  }) {
    final effColor = valueColor ?? color ?? (isDark ? Colors.white : const Color(0xFF0F172A));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF221E38) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF332E52) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: effColor,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2846) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _resolveShowcaseInternetImage(String title, String category, Map<String, dynamic> meta) {
    // 1. Explicit direct HTTP(S) URL in metadata
    final rawUrl = (meta['image_url'] ?? '').toString().trim();
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      return rawUrl;
    }
    final rawThumb = (meta['thumbnail'] ?? '').toString().trim();
    if (rawThumb.startsWith('http://') || rawThumb.startsWith('https://')) {
      return rawThumb;
    }

    final text = '${title.toLowerCase()} ${category.toLowerCase()}';

    // 2. Curated criteria-based internet image matches (High-res Unsplash CDN with CORS)
    // 3D Animation, CGI & Visual Effects
    if (text.contains('animasi') ||
        text.contains('3d') ||
        text.contains('cgi') ||
        text.contains('blender') ||
        text.contains('maya') ||
        text.contains('vfx') ||
        text.contains('render') ||
        text.contains('heritage')) {
      return 'https://images.unsplash.com/photo-1634017839464-5c339ebe3cb4?auto=format&fit=crop&w=600&q=80';
    }

    // Branding, Packaging, DKV, Graphic Design, UMKM
    if (text.contains('kemasan') ||
        text.contains('packaging') ||
        text.contains('rempah') ||
        text.contains('brand') ||
        text.contains('branding') ||
        text.contains('dkv') ||
        text.contains('desain grafis') ||
        text.contains('label') ||
        text.contains('umkm')) {
      return 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?auto=format&fit=crop&w=600&q=80';
    }

    // Mobile App, Software, Flutter, RPL, UI/UX
    if (text.contains('mobile') ||
        text.contains('flutter') ||
        text.contains('aplikasi') ||
        text.contains('app') ||
        text.contains('software') ||
        text.contains('rpl') ||
        text.contains('kreasibudaya') ||
        text.contains('coding') ||
        text.contains('ui') ||
        text.contains('ux')) {
      return 'https://images.unsplash.com/photo-1551650975-87deedd944c3?auto=format&fit=crop&w=600&q=80';
    }

    // Tenun Tradisional, Kriya, Tekstil, Kerajinan, Busana
    if (text.contains('tenun') ||
        text.contains('ikat') ||
        text.contains('kriya') ||
        text.contains('tekstil') ||
        text.contains('batik') ||
        text.contains('kerajinan') ||
        text.contains('busana') ||
        text.contains('fashion')) {
      return 'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?auto=format&fit=crop&w=600&q=80';
    }

    // AR, VR, Game Dev, Aksara Kuno, Metaverse
    if (text.contains('game') ||
        text.contains('ar') ||
        text.contains('vr') ||
        text.contains('augmented') ||
        text.contains('virtual') ||
        text.contains('metaverse') ||
        text.contains('aksara') ||
        text.contains('unity') ||
        text.contains('unreal')) {
      return 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&w=600&q=80';
    }

    // Broadcasting, Film, Video, Dokumenter, Sinematografi
    if (text.contains('film') ||
        text.contains('video') ||
        text.contains('sinematografi') ||
        text.contains('dokumenter') ||
        text.contains('broadcast') ||
        text.contains('movie')) {
      return 'https://images.unsplash.com/photo-1485846234645-a62644f84728?auto=format&fit=crop&w=600&q=80';
    }

    // Audio, Musik, Soundscape, Gamelan, Recording
    if (text.contains('musik') ||
        text.contains('audio') ||
        text.contains('sound') ||
        text.contains('soundscape') ||
        text.contains('rekaman') ||
        text.contains('khatulistiwa') ||
        text.contains('lagu')) {
      return 'https://images.unsplash.com/photo-1598488035139-bdbb2231ce04?auto=format&fit=crop&w=600&q=80';
    }

    // Kampanye Sosial & Lingkungan, Laut Bersih, Alam Lestari
    if (text.contains('laut') ||
        text.contains('lingkungan') ||
        text.contains('lestari') ||
        text.contains('sampah') ||
        text.contains('sosial') ||
        text.contains('kampanye') ||
        text.contains('pesisir')) {
      return 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?auto=format&fit=crop&w=600&q=80';
    }

    // Fotografi, Studio Foto, Jurnalistik Visual
    if (text.contains('foto') ||
        text.contains('fotografi') ||
        text.contains('photo') ||
        text.contains('kamera') ||
        text.contains('lens')) {
      return 'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?auto=format&fit=crop&w=600&q=80';
    }

    // Fallback: Elegant modern creative portfolio canvas
    return 'https://images.unsplash.com/photo-1579546929518-9e396f3cc809?auto=format&fit=crop&w=600&q=80';
  }

  Widget _buildShowcaseMediaThumbnail({
    required Map<String, dynamic> record,
    required String title,
    required String category,
    Color? discColor,
    IconData? discIcon,
    required bool isDark,
  }) {
    final meta = _metadata(record);
    final accentColor = discColor ?? _resolvedAccentColor;
    final icon = discIcon ?? Icons.auto_awesome_rounded;
    final internetImageUrl = _resolveShowcaseInternetImage(title, category, meta);

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B32) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              internetImageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: isDark ? const Color(0xFF1E1B32) : const Color(0xFFF1F5F9),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                (loadingProgress.expectedTotalBytes ?? 1)
                            : null,
                        color: accentColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                );
              },
              errorBuilder: (_, _, _) => _buildDisciplineHeroFallback(icon, accentColor, isDark),
            ),

            // Subtle gradient scrim at bottom to ensure discipline badge stands out cleanly
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 28,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.35),
                    ],
                  ),
                ),
              ),
            ),

            // Discipline badge on bottom-right
            Positioned(
              right: 5,
              bottom: 5,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A).withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(icon, color: accentColor, size: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisciplineHeroFallback(IconData icon, Color accentColor, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1E1B32) : const Color(0xFFF8FAFC),
      child: Center(
        child: Icon(icon, color: accentColor, size: 24),
      ),
    );
  }

  Widget _buildShowcaseCard(Map<String, dynamic> record, bool isDark) {
    final meta = _metadata(record);
    final status = record['status']?.toString().toLowerCase() ?? 'published';
    final title = record['title']?.toString() ?? 'Karya & Portofolio Peserta';
    final desc = record['description']?.toString() ?? '';
    final creator = meta['creator_name']?.toString() ?? meta['creator']?.toString() ?? '-';
    final category = meta['category']?.toString() ?? 'Karya Peserta';
    final year = meta['year']?.toString() ?? '';
    final portfolioUrl = meta['portfolio_url']?.toString() ?? meta['url']?.toString() ?? '';
    final award = meta['award']?.toString() ?? '';

    final catLower = category.toLowerCase();
    final IconData discIcon;

    if (catLower.contains('animasi') || catLower.contains('3d') || catLower.contains('cgi')) {
      discIcon = Icons.movie_creation_outlined;
    } else if (catLower.contains('brand') ||
        catLower.contains('dkv') ||
        catLower.contains('ui') ||
        catLower.contains('ux') ||
        catLower.contains('desain') ||
        catLower.contains('kemasan')) {
      discIcon = Icons.design_services_outlined;
    } else if (catLower.contains('mobile') ||
        catLower.contains('software') ||
        catLower.contains('rpl') ||
        catLower.contains('web') ||
        catLower.contains('flutter') ||
        catLower.contains('app')) {
      discIcon = Icons.code_rounded;
    } else if (catLower.contains('film') ||
        catLower.contains('video') ||
        catLower.contains('broadcast') ||
        catLower.contains('media') ||
        catLower.contains('sinematografi')) {
      discIcon = Icons.video_camera_back_outlined;
    } else if (catLower.contains('tenun') ||
        catLower.contains('kriya') ||
        catLower.contains('tekstil') ||
        catLower.contains('batik')) {
      discIcon = Icons.dry_cleaning_outlined;
    } else if (catLower.contains('game') || catLower.contains('ar') || catLower.contains('vr')) {
      discIcon = Icons.sports_esports_outlined;
    } else if (catLower.contains('musik') || catLower.contains('audio') || catLower.contains('sound')) {
      discIcon = Icons.headphones_outlined;
    } else {
      discIcon = Icons.auto_awesome_outlined;
    }

    final accentColor = _resolvedAccentColor;

    // Status styling
    final isPublished = status == 'published' || status == 'active';
    final Color statusBg = isPublished
        ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5))
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9));
    final Color statusBorder = isPublished ? const Color(0xFFA7F3D0) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
    final Color statusTextCol = isPublished ? const Color(0xFF059669) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569));
    final String statusLabel = isPublished ? 'Tervalidasi / Siap Pameran' : 'Draft / Dalam Kurasi';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (portfolioUrl.isNotEmpty) {
              _launchUrl(portfolioUrl, record: record);
            } else {
              _openEditor(record);
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Header & Main Info ──
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShowcaseMediaThumbnail(
                      record: record,
                      title: title,
                      category: category,
                      discColor: accentColor,
                      discIcon: discIcon,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 14),
                    // Core Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tags Row (Discipline, Angkatan, Status)
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Discipline Pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(discIcon, size: 12, color: accentColor),
                                    const SizedBox(width: 5),
                                    Text(
                                      category,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: accentColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Angkatan Pill
                              if (year.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.cardDark2 : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.school_outlined,
                                        size: 12,
                                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Angkatan $year',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: statusBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: statusTextCol,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      statusLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: statusTextCol,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Title
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.2,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Creator Credit Row
                          Row(
                            children: [
                              Icon(
                                Icons.groups_outlined,
                                size: 14,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Kreator: ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppTheme.textMuted : const Color(0xFF64748B),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  creator,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              desc,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: isDark ? AppTheme.textMuted : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Action Popup Menu
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500),
                      color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF2D2A42) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _openEditor(record);
                        } else if (value == 'delete') {
                          _deleteRecord(record);
                        } else if (value == 'open' && portfolioUrl.isNotEmpty) {
                          _launchUrl(portfolioUrl, record: record);
                        }
                      },
                      itemBuilder: (_) => [
                        if (portfolioUrl.isNotEmpty) ...[
                          _buildPopupActionItem(
                            value: 'open',
                            icon: Icons.open_in_new_rounded,
                            label: 'Buka Portofolio',
                            isDark: isDark,
                            color: accentColor,
                          ),
                          _buildPopupDivider(),
                        ],
                        _buildPopupActionItem(
                          value: 'edit',
                          icon: Icons.edit_outlined,
                          label: 'Edit Karya',
                          isDark: isDark,
                          color: accentColor,
                        ),
                        _buildPopupDivider(),
                        _buildPopupActionItem(
                          value: 'delete',
                          icon: Icons.delete_outline_rounded,
                          label: 'Hapus Karya',
                          isDark: isDark,
                          isDestructive: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Prestasi / Award Banner (if available) ──
              if (award.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF451A03).withValues(alpha: 0.3) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events_outlined, size: 16, color: Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          award,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PRESTASI',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Divider ──
              Divider(
                height: 1,
                color: isDark ? AppTheme.inputBorder : const Color(0xFFF1F5F9),
              ),

              // ── Action Footer ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDark2.withValues(alpha: 0.4) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                ),
                child: Row(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          portfolioUrl.isNotEmpty ? Icons.link_rounded : Icons.verified_outlined,
                          size: 14,
                          color: const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          portfolioUrl.isNotEmpty ? 'Tautan Portofolio Terhubung' : 'Terverifikasi Tim Vokasi',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Primary Interactive CTA Button
                    if (portfolioUrl.isNotEmpty) ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _launchUrl(portfolioUrl, record: record),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  portfolioUrl.contains('youtube')
                                      ? Icons.play_circle_outline_rounded
                                      : (portfolioUrl.contains('github')
                                          ? Icons.code_rounded
                                          : Icons.open_in_new_rounded),
                                  size: 14,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  portfolioUrl.contains('youtube')
                                      ? 'Tonton Video'
                                      : (portfolioUrl.contains('github')
                                          ? 'Source Code'
                                          : 'Buka Portofolio'),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openEditor(record),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_outlined, size: 14, color: Color(0xFF475569)),
                                SizedBox(width: 5),
                                Text(
                                  'Kelola Karya',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record, bool isDark) {
    switch (widget.resourceType) {
      case 'tenders':
        return _buildTenderCard(record, isDark);
      case 'partners':
        return _buildPartnerCard(record, isDark);
      case 'documents':
        return _buildDocumentCard(record, isDark);
      case 'budgets':
        return _buildBudgetCard(record, isDark);
      case 'reports':
        return _buildReportCard(record, isDark);
      case 'showcases':
        return _buildShowcaseCard(record, isDark);
      case 'monitoring':
        return _buildMonitoringCard(record, isDark);
    }

    // Default card for non-corporate or other types
    final metadata = _metadata(record);
    final status = record['status']?.toString() ?? 'draft';
    final color = _statusColor(status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icons[widget.resourceType] ?? Icons.folder_outlined, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record['title']?.toString() ?? '',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    if ((record['description']?.toString() ?? '').isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        record['description'].toString(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: isDark ? AppTheme.textMuted : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500),
                color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isDark ? const Color(0xFF2D2A42) : const Color(0xFFE2E8F0),
                  ),
                ),
                onSelected: (value) => value == 'edit' ? _openEditor(record) : _deleteRecord(record),
                itemBuilder: (_) => [
                  _buildPopupActionItem(
                    value: 'edit',
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    isDark: isDark,
                    color: const Color(0xFF2563EB),
                  ),
                  _buildPopupDivider(),
                  _buildPopupActionItem(
                    value: 'delete',
                    icon: Icons.delete_outline_rounded,
                    label: 'Hapus',
                    isDark: isDark,
                    isDestructive: true,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: color),
                    const SizedBox(width: 5),
                    Text(
                      _statusLabel(status),
                      style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              for (final field in _resourceFields)
                if (metadata[field.key] != null && metadata[field.key].toString().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cardDark2 : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      '${field.label}: ${metadata[field.key]}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  // ── BODY BUILDER ───────────────────────────────────────────────────────────
  Widget _buildBody(bool isDark) {
    final records = _filteredRecords;
    final totalItems = records.length;
    final totalPages = totalItems > 0 ? (totalItems / _pageSize).ceil() : 1;
    final safePage = _currentPage.clamp(1, totalPages);
    final startIndex = (safePage - 1) * _pageSize;
    final endIndex = math.min(startIndex + _pageSize, totalItems);
    final pagedRecords = totalItems > 0 && startIndex < totalItems
        ? records.sublist(startIndex, endIndex)
        : <Map<String, dynamic>>[];

    return RefreshIndicator(
      onRefresh: _loadRecords,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          _buildExecutiveHero(isDark),
          _buildKpiRow(isDark),
          // Filter & Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final search = TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() {
                    _search = value;
                    _currentPage = 1;
                  }),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'Cari ${_title.toLowerCase()}...',
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _search = '';
                                _currentPage = 1;
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                );

                final statusList = [
                  ('Semua', 'Semua Status', _records.length, Icons.layers_outlined, const Color(0xFF6366F1)),
                  for (final value in _resourceStatuses)
                    (
                      value,
                      _statusLabel(value),
                      _records.where((r) => r['status'] == value).length,
                      _statusIcon(value),
                      _statusColor(value),
                    ),
                ];

                final status = DropdownButtonFormField<String>(
                  initialValue: _statusFilter,
                  isExpanded: true,
                  dropdownColor: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  elevation: 6,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Filter Status',
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    prefixIcon: Icon(
                      Icons.filter_list_rounded,
                      size: 18,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  selectedItemBuilder: (BuildContext context) {
                    return statusList.map((item) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: item.$5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${item.$2} (${item.$3})',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList();
                  },
                  items: [
                    for (int i = 0; i < statusList.length; i++)
                      DropdownMenuItem<String>(
                        value: statusList[i].$1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            border: i < statusList.length - 1
                                ? Border(
                                    bottom: BorderSide(
                                      color: isDark
                                          ? const Color(0xFF2D2A42)
                                          : const Color(0xFFF1F5F9),
                                      width: 1,
                                    ),
                                  )
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: statusList[i].$5.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Icon(
                                  statusList[i].$4,
                                  size: 15,
                                  color: statusList[i].$5,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  statusList[i].$2,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusList[i].$5.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: statusList[i].$5.withValues(alpha: 0.25),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  '${statusList[i].$3}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: statusList[i].$5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _statusFilter = value ?? 'Semua';
                    _currentPage = 1;
                  }),
                );

                final refresh = IconButton(
                  tooltip: 'Segarkan Data',
                  onPressed: _loadRecords,
                  icon: const Icon(Icons.refresh),
                );

                if (constraints.maxWidth < 600) {
                  return Column(
                    children: [
                      search,
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: status),
                          refresh,
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 12),
                    SizedBox(width: 250, child: status),
                    const SizedBox(width: 4),
                    refresh,
                  ],
                );
              },
            ),
          ),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_loadError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadRecords,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            )
          else if (records.isEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardBg : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_icons[widget.resourceType] ?? Icons.folder_open_rounded, size: 32, color: const Color(0xFF1E3A8A)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _search.isNotEmpty || _statusFilter != 'Semua'
                          ? 'Tidak Ada Hasil yang Cocok'
                          : 'Belum Ada Data $_title Terdaftar',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _search.isNotEmpty || _statusFilter != 'Semua'
                          ? 'Coba sesuaikan kata kunci pencarian atau ubah filter status.'
                          : (widget.resourceType == 'documents'
                              ? 'Berkas dokumen dan MoU akan tampil otomatis dari kemitraan di menu "Mitra Industri" yang disetujui maupun dari kontrak, MoU, dan berkas pada "Proyek Saya".'
                              : 'Tambahkan data pertama Anda untuk dikelola dan dipublikasikan secara resmi.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    if (_canCreateResource) ...[
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: _openEditor,
                        icon: const Icon(Icons.add, size: 18, color: Colors.white),
                        label: Text(_action, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (final rec in pagedRecords)
                    _buildRecordCard(rec, isDark),
                  AppPaginationBar(
                    currentPage: safePage,
                    totalItems: totalItems,
                    pageSize: _pageSize,
                    itemLabel: _itemUnitName,
                    onPageChanged: (newPage) {
                      setState(() => _currentPage = newPage);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String get _activeRoute {
    switch (widget.resourceType) {
      case 'tenders':
        return 'tender_kolaborasi';
      case 'partners':
        return 'mitra_komunitas';
      case 'showcases':
        return 'karya_siswa';
      case 'reports':
        return 'laporan';
      case 'monitoring':
        return 'monitoring_evaluasi';
      case 'documents':
        return 'dokumen_instansi';
      case 'announcements':
        return 'pengumuman_publik';
      case 'budgets':
        return 'realisasi_anggaran';
      default:
        return widget.resourceType;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSchool && widget.resourceType == 'tenders') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Akses Ditolak'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Fitur Pengadaan & Vendor khusus untuk akun Corporate / Perusahaan.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.maybePop(context),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Scaffold(
      appBar: AppBar(
        title: Text(
          _title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        automaticallyImplyLeading: MediaQuery.of(context).size.width <= 900,
        actions: [
          if (_canCreateResource) ...[
            IconButton(
              tooltip: _action,
              onPressed: _openEditor,
              icon: const Icon(Icons.add_circle_outline),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: _buildBody(isDark),
    );

    return DesktopSidebarLayout(
      user: widget.user,
      activeRoute: _activeRoute,
      onUserUpdated: widget.onUserUpdated,
      child: content,
    );
  }
}

class _ResourceEditorDialog extends StatefulWidget {
  final UserModel? user;
  final String resourceType;
  final String title;
  final String action;
  final List<_WorkspaceField> fields;
  final List<String> statuses;
  final Map<String, dynamic>? existing;
  final String Function(String) statusLabel;
  final IconData icon;

  const _ResourceEditorDialog({
    this.user,
    required this.resourceType,
    required this.title,
    required this.action,
    required this.fields,
    required this.statuses,
    this.existing,
    required this.statusLabel,
    required this.icon,
  });

  @override
  State<_ResourceEditorDialog> createState() => _ResourceEditorDialogState();
}

class _ResourceEditorDialogState extends State<_ResourceEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final Map<String, TextEditingController> _controllers;
  late String _status;
  bool _isSaving = false;

  // Corporate Search State
  Map<String, dynamic>? _selectedCorporate;
  List<Map<String, dynamic>> _corporateList = [];
  bool _isLoadingCorporates = false;
  final _corpSearchController = TextEditingController();
  bool _showCorpDropdown = false;
  Timer? _corpSearchDebounce;
  int _corpSearchRequestSeq = 0;

  // MoU Upload State (Mandatory for partnership submissions, max 3 files)
  static const int _maxMouFiles = 3;
  final List<Map<String, dynamic>> _mouFiles = [];
  bool _isUploadingMou = false;
  String? _mouUploadError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?['title']?.toString() ?? '');
    _descriptionController = TextEditingController(text: existing?['description']?.toString() ?? '');

    final rawMeta = existing?['metadata'] ?? existing?['meta'];
    Map<String, dynamic> meta = {};
    if (rawMeta is Map) {
      meta = Map<String, dynamic>.from(rawMeta);
    } else if (rawMeta is String && rawMeta.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(rawMeta);
        if (decoded is Map) meta = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }

    if (widget.resourceType == 'partners' && existing != null) {
      final cat = meta['category']?.toString() ??
          existing['category']?.toString() ??
          meta['bidang']?.toString() ??
          meta['spesialisasi']?.toString() ??
          '';
      if (cat.isNotEmpty) meta['category'] = cat;

      final cnt = meta['contact']?.toString() ??
          meta['email']?.toString() ??
          existing['contact']?.toString() ??
          existing['email']?.toString() ??
          '';
      if (cnt.isNotEmpty) meta['contact'] = cnt;

      final pic = meta['pic_name']?.toString() ??
          meta['pic']?.toString() ??
          existing['pic_name']?.toString() ??
          existing['pic']?.toString() ??
          '';
      if (pic.isNotEmpty) meta['pic_name'] = pic;

      final role = meta['pic_role']?.toString() ??
          meta['jabatan']?.toString() ??
          existing['pic_role']?.toString() ??
          existing['jabatan']?.toString() ??
          '';
      if (role.isNotEmpty) meta['pic_role'] = role;

      final ph = meta['phone']?.toString() ??
          meta['telepon']?.toString() ??
          meta['whatsapp']?.toString() ??
          existing['phone']?.toString() ??
          '';
      if (ph.isNotEmpty) meta['phone'] = ph;

      final mouN = meta['mou_number']?.toString() ??
          meta['nomor_mou']?.toString() ??
          existing['mou_number']?.toString() ??
          '';
      if (mouN.isNotEmpty) meta['mou_number'] = mouN;

      final mouP = meta['mou_period']?.toString() ??
          meta['masa_berlaku']?.toString() ??
          existing['mou_period']?.toString() ??
          '';
      if (mouP.isNotEmpty) meta['mou_period'] = mouP;

      final q = meta['internship_quota_yearly']?.toString() ??
          meta['quota']?.toString() ??
          meta['kuota']?.toString() ??
          existing['internship_quota_yearly']?.toString() ??
          '';
      if (q.isNotEmpty) meta['internship_quota_yearly'] = q;

      final web = meta['website']?.toString() ??
          meta['web']?.toString() ??
          meta['url']?.toString() ??
          existing['website']?.toString() ??
          '';
      if (web.isNotEmpty) meta['website'] = web;
    }

    _controllers = {
      for (final f in widget.fields)
        f.key: TextEditingController(
          text: (meta[f.key] ??
                 existing?[f.key] ??
                 (f.key == 'contact' ? (meta['email'] ?? existing?['email']) : null) ??
                 '').toString(),
        ),
    };

    final currentStatus = existing?['status']?.toString();
    _status = (currentStatus != null && widget.statuses.contains(currentStatus))
        ? currentStatus
        : (widget.resourceType == 'partners' && existing == null
            ? 'pending'
            : (widget.statuses.isNotEmpty ? widget.statuses.first : 'draft'));

    if (widget.resourceType == 'partners') {
      _fetchCorporates('');
      final targetUserId = meta['target_user_id'] ??
          (_isCorporateCaller ? meta['institution_user_id'] : meta['corporate_user_id']);
      if (targetUserId != null) {
        _selectedCorporate = {
          'id': targetUserId,
          'name': meta['target_name'] ??
              (_isCorporateCaller ? meta['institution_name'] : meta['corporate_name']) ??
              existing?['title'],
          'username': meta['target_username'] ??
              (_isCorporateCaller ? meta['institution_username'] : meta['corporate_username']) ??
              '',
          'email': meta['target_email'] ??
              (_isCorporateCaller ? meta['institution_email'] : meta['corporate_email']) ??
              '',
          'phone': meta['target_phone'] ??
              (_isCorporateCaller ? meta['institution_phone'] : meta['corporate_phone']) ??
              meta['phone'] ??
              '',
          'avatar_url': _isCorporateCaller ? meta['institution_avatar'] : meta['corporate_avatar'],
          'selected_sub_role': meta['target_role'] ?? (_isCorporateCaller ? 'institution' : 'corporate'),
        };
      }
      final rawMouFiles = meta['mou_files'];
      if (rawMouFiles is List) {
        for (final item in rawMouFiles) {
          if (item is Map && (item['url']?.toString().trim().isNotEmpty ?? false)) {
            _mouFiles.add({
              'url': item['url'].toString().trim(),
              'filename': (item['filename'] ?? 'Dokumen-Kerjasama.pdf').toString().trim(),
              'filesize': (item['filesize'] ?? 'Dokumen Digital').toString().trim(),
              'extension': (item['extension'] ?? 'pdf').toString().trim(),
            });
            if (_mouFiles.length >= _maxMouFiles) break;
          }
        }
      }
      if (_mouFiles.isEmpty && meta['mou_url'] != null && meta['mou_url'].toString().trim().isNotEmpty) {
        _mouFiles.add({
          'url': meta['mou_url'].toString().trim(),
          'filename': meta['mou_filename']?.toString().trim().isNotEmpty == true
              ? meta['mou_filename'].toString().trim()
              : 'Dokumen-MoU-Kemitraan.pdf',
          'filesize': meta['mou_filesize']?.toString().trim().isNotEmpty == true
              ? meta['mou_filesize'].toString().trim()
              : 'Dokumen Digital',
          'extension': meta['mou_extension']?.toString().trim().isNotEmpty == true
              ? meta['mou_extension'].toString().trim()
              : 'pdf',
        });
      }
    }
  }

  @override
  void dispose() {
    _corpSearchDebounce?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _corpSearchController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchCorporates([String query = '']) async {
    if (!mounted) return;
    final cleanQuery = query.trim().replaceFirst(RegExp(r'^@+'), '');
    final seq = ++_corpSearchRequestSeq;
    setState(() => _isLoadingCorporates = true);
    try {
      final res = await ApiService.get(
        'institution/resources/corporate-search?q=${Uri.encodeComponent(cleanQuery)}',
      );
      if (!mounted || seq != _corpSearchRequestSeq) return;
      if (res['status'] == true && res['data'] is List) {
        setState(() {
          _corporateList = List<Map<String, dynamic>>.from(res['data']);
          _isLoadingCorporates = false;
        });
      } else {
        setState(() => _isLoadingCorporates = false);
      }
    } catch (_) {
      if (mounted && seq == _corpSearchRequestSeq) {
        setState(() => _isLoadingCorporates = false);
      }
    }
  }

  Future<void> _pickMouFiles() async {
    final remainingSlots = _maxMouFiles - _mouFiles.length;
    if (remainingSlots <= 0) {
      AppSweetAlert.warning(
        context,
        'Maksimal $_maxMouFiles berkas kerjasama yang dapat diunggah.',
        title: 'Batas Berkas Tercapai',
      );
      return;
    }

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result == null || result.files.isEmpty) return;

      var selectedFiles = result.files;
      if (selectedFiles.length > remainingSlots) {
        selectedFiles = selectedFiles.take(remainingSlots).toList();
        if (mounted) {
          AppSweetAlert.warning(
            context,
            'Maksimal $_maxMouFiles berkas kerjasama. Hanya $remainingSlots berkas pertama yang diproses.',
            title: 'Batas Maksimal 3 Berkas',
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _isUploadingMou = true;
        _mouUploadError = null;
      });

      int uploadedCount = 0;
      String? lastError;

      for (final file in selectedFiles) {
        if (_mouFiles.length >= _maxMouFiles) break;
        final fileBytes = await file.readAsBytes();
        if (fileBytes.isEmpty) {
          lastError = 'Berkas "${file.name}" kosong atau tidak dapat dibaca.';
          continue;
        }

        final formData = FormData();
        formData.files.add(
          MapEntry(
            'mou_file',
            MultipartFile.fromBytes(fileBytes, filename: file.name),
          ),
        );

        final res = await ApiService.postFormData('institution/resources/upload-mou', formData);
        if (!mounted) return;

        if (res['status'] == true && res['data'] is Map) {
          final data = Map<String, dynamic>.from(res['data'] as Map);
          final uploadedUrl = data['url']?.toString().trim() ?? '';
          if (uploadedUrl.isNotEmpty) {
            final ext = (data['extension'] ??
                    (file.extension?.isNotEmpty == true ? file.extension : 'pdf'))
                .toString()
                .toLowerCase();
            setState(() {
              _mouFiles.add({
                'url': uploadedUrl,
                'filename': data['filename']?.toString() ?? file.name,
                'filesize': data['filesize']?.toString() ?? 'Dokumen Digital',
                'extension': ext,
              });
              _mouUploadError = null;
            });
            uploadedCount++;
          } else {
            lastError = 'URL berkas untuk "${file.name}" tidak valid.';
          }
        } else {
          lastError = res['message']?.toString() ?? 'Gagal mengunggah "${file.name}".';
        }
      }

      if (!mounted) return;
      setState(() => _isUploadingMou = false);

      if (uploadedCount > 0 && lastError == null) {
        AppSweetAlert.success(
          context,
          uploadedCount == 1
              ? '1 berkas kerjasama berhasil diunggah (${_mouFiles.length}/$_maxMouFiles).'
              : '$uploadedCount berkas kerjasama berhasil diunggah (${_mouFiles.length}/$_maxMouFiles).',
          title: 'Berkas Terunggah',
        );
      } else if (lastError != null) {
        AppSweetAlert.error(
          context,
          lastError,
          title: 'Kendala Unggah Berkas',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingMou = false);
        AppSweetAlert.error(
          context,
          'Terjadi kendala saat memilih berkas: $e',
          title: 'Gagal Membaca Berkas',
        );
      }
    }
  }

  void _removeMouFile(int index) {
    if (index < 0 || index >= _mouFiles.length) return;
    setState(() {
      _mouFiles.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final isPartnerResource = widget.resourceType == 'partners';

    if (_isUploadingMou) {
      AppSweetAlert.warning(
        context,
        'Mohon tunggu proses unggah berkas kerjasama selesai terlebih dahulu.',
        title: 'Sedang Mengunggah',
      );
      return;
    }

    final formValid = _formKey.currentState!.validate();
    if (isPartnerResource && _mouFiles.isEmpty) {
      setState(() {
        _mouUploadError = 'Minimal 1 berkas kerjasama wajib diunggah (maksimal 3 berkas).';
      });
    }

    if (!formValid || _isSaving) return;
    if (isPartnerResource && _mouFiles.isEmpty) {
      AppSweetAlert.error(
        context,
        'Silakan unggah minimal 1 berkas kerjasama sebelum mengajukan kemitraan.',
        title: 'Berkas Kerjasama Wajib Diunggah',
      );
      return;
    }

    final baseMeta = <String, dynamic>{};
    if (widget.existing != null) {
      final oldRaw = widget.existing!['metadata'] ?? widget.existing!['meta'];
      if (oldRaw is Map) {
        baseMeta.addAll(Map<String, dynamic>.from(oldRaw));
      } else if (oldRaw is String && oldRaw.trim().startsWith('{')) {
        try {
          final decoded = jsonDecode(oldRaw);
          if (decoded is Map) baseMeta.addAll(Map<String, dynamic>.from(decoded));
        } catch (_) {}
      }
    }

    final payload = <String, dynamic>{
      'resource_type': widget.resourceType,
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'status': (isPartnerResource && widget.existing == null) ? 'pending' : _status,
      'metadata': {
        ...baseMeta,
        if (!isPartnerResource)
          for (final field in widget.fields)
            if ((_controllers[field.key]?.text.trim() ?? '').isNotEmpty)
              field.key: _controllers[field.key]!.text.trim(),
        if (_selectedCorporate != null) ...{
          'target_user_id': _selectedCorporate!['id'],
          'target_name': _selectedCorporate!['name'],
          'target_username': _selectedCorporate!['username'],
          if ((_selectedCorporate!['email'] ?? '').toString().trim().isNotEmpty)
            'target_email': _selectedCorporate!['email'],
          if ((_selectedCorporate!['phone'] ?? '').toString().trim().isNotEmpty)
            'target_phone': _selectedCorporate!['phone'],
          if ((_selectedCorporate!['selected_sub_role'] ?? '').toString().trim().isNotEmpty)
            'target_role': _selectedCorporate!['selected_sub_role'],
          if (_isCorporateCaller) ...{
            'institution_user_id': _selectedCorporate!['id'],
            'institution_name': _selectedCorporate!['name'],
            'institution_username': _selectedCorporate!['username'],
            if ((_selectedCorporate!['email'] ?? '').toString().trim().isNotEmpty)
              'institution_email': _selectedCorporate!['email'],
            if ((_selectedCorporate!['phone'] ?? '').toString().trim().isNotEmpty)
              'institution_phone': _selectedCorporate!['phone'],
            'institution_avatar': _selectedCorporate!['avatar_url'],
          } else ...{
            'corporate_user_id': _selectedCorporate!['id'],
            'corporate_name': _selectedCorporate!['name'],
            'corporate_username': _selectedCorporate!['username'],
            if ((_selectedCorporate!['email'] ?? '').toString().trim().isNotEmpty)
              'corporate_email': _selectedCorporate!['email'],
            if ((_selectedCorporate!['phone'] ?? '').toString().trim().isNotEmpty)
              'corporate_phone': _selectedCorporate!['phone'],
            'corporate_avatar': _selectedCorporate!['avatar_url'],
          },
          if ((_selectedCorporate!['phone'] ?? '').toString().trim().isNotEmpty)
            'phone': _selectedCorporate!['phone'],
        },
        if (isPartnerResource) ...{
          'mou_files': _mouFiles,
          'mou_url': _mouFiles.isNotEmpty ? _mouFiles.first['url'] : null,
          'mou_filename': _mouFiles.isNotEmpty ? _mouFiles.first['filename'] : null,
          'mou_filesize': _mouFiles.isNotEmpty ? _mouFiles.first['filesize'] : null,
          'mou_extension': _mouFiles.isNotEmpty ? _mouFiles.first['extension'] : null,
        },
        if (isPartnerResource && widget.existing == null) ...{
          'submission_date': DateTime.now().toIso8601String().split('T').first,
          'approval_status': 'pending',
        },
      },
    };

    setState(() => _isSaving = true);

    try {
      final response = widget.existing == null
          ? await ApiService.post('institution/resources', payload)
          : await ApiService.put('institution/resources/${widget.existing!['id']}', payload);

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (response['status'] == true) {
        Navigator.of(context).pop(true);
      } else {
        AppSweetAlert.error(
          context,
          response['message']?.toString() ?? 'Data gagal disimpan ke sistem.',
          title: 'Gagal Menyimpan',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppSweetAlert.error(
        context,
        'Terjadi kendala saat menyimpan data: $e',
        title: 'Gagal Menyimpan',
      );
    }
  }

  IconData _getFieldIcon(_WorkspaceField field) {
    final key = field.key.toLowerCase();
    if (key == 'pic_name' || key.contains('pic_name')) {
      return Icons.person_outline_rounded;
    }
    if (key == 'pic_role' || key.contains('pic_role')) {
      return Icons.badge_outlined;
    }
    if (key.contains('mou_number') || key.contains('nomor_mou')) {
      return Icons.assignment_outlined;
    }
    if (key.contains('mou_period') || key.contains('masa_berlaku')) {
      return Icons.date_range_outlined;
    }
    if (key.contains('quota') || key.contains('magang')) {
      return Icons.school_outlined;
    }
    if (key.contains('phone') || key.contains('telepon')) {
      return Icons.phone_outlined;
    }
    if (key.contains('contact') || key.contains('email')) {
      return Icons.alternate_email_rounded;
    }
    if (key.contains('website') || key.contains('url') || key.contains('link') || field.kind == _FieldKind.url) {
      return Icons.language_rounded;
    }
    if (key.contains('category') || key.contains('kategori') || key.contains('spesialisasi')) {
      return Icons.category_outlined;
    }
    if (key.contains('location') || key.contains('alamat') || key.contains('city') || key.contains('kota')) {
      return Icons.location_on_outlined;
    }
    if (key.contains('date') || key.contains('deadline') || key.contains('period') || field.kind == _FieldKind.date) {
      return Icons.calendar_today_outlined;
    }
    if (key.contains('budget') || key.contains('amount') || key.contains('price') || key.contains('omset') || field.kind == _FieldKind.number) {
      return Icons.payments_outlined;
    }
    if (key.contains('capacity') || key.contains('student') || key.contains('beneficiaries')) {
      return Icons.people_alt_outlined;
    }
    if (key.contains('facilities') || key.contains('sarana')) {
      return Icons.construction_outlined;
    }
    if (key.contains('terms') || key.contains('ketentuan') || key.contains('permit')) {
      return Icons.gavel_outlined;
    }
    if (key.contains('headmaster') || key.contains('manager') || key.contains('nip')) {
      return Icons.badge_outlined;
    }
    if (key.contains('npsn') || key.contains('number')) {
      return Icons.numbers_rounded;
    }
    return Icons.edit_note_rounded;
  }

  Map<String, dynamic> _getFieldMeta(_WorkspaceField field) {
    final key = field.key.toLowerCase();
    if (key.contains('category') || key.contains('spesialisasi')) {
      return {
        'label': '${field.label} *',
        'caption': 'Bidang keahlian atau spesialisasi industri mitra.',
        'hint': field.hint ?? 'Contoh: Teknologi Cloud & AI, Studio Animasi, Agensi Desain',
        'chips': <String>[
          'Teknologi Cloud & AI',
          'Studio Animasi & Game',
          'Production House & Video',
          'Branding & Desain Grafis',
          'Software & Web Dev',
        ],
      };
    }
    if (key == 'pic_name' || key.contains('pic_name')) {
      return {
        'label': '${field.label} *',
        'caption': 'Nama lengkap penanggung jawab (PIC) kemitraan industri.',
        'hint': field.hint ?? 'Contoh: Jessica Wijaya, S.Kom.',
        'chips': <String>[],
      };
    }
    if (key == 'pic_role' || key.contains('pic_role')) {
      return {
        'label': field.label,
        'caption': 'Jabatan / divisi PIC dalam struktur perusahaan mitra.',
        'hint': field.hint ?? 'Contoh: Education Lead, Studio Director, HRD',
        'chips': <String>[],
      };
    }
    if (key.contains('phone') || key.contains('telepon')) {
      return {
        'label': field.label,
        'caption': 'Nomor telepon kantor atau WhatsApp aktif PIC.',
        'hint': field.hint ?? 'Contoh: +62 812-3456-7890 / +62 21-5085-8000',
        'chips': <String>[],
      };
    }
    if (key.contains('quota') || key.contains('magang')) {
      return {
        'label': field.label,
        'caption': 'Alokasi kuota penerimaan peserta magang / PKL per tahun.',
        'hint': field.hint ?? 'Contoh: 15 (peserta/tahun)',
        'chips': <String>[],
      };
    }
    if (key.contains('mou_number') || key.contains('nomor_mou')) {
      return {
        'label': field.label,
        'caption': 'Nomor registrasi nota kesepahaman (MoU / PKS) kemitraan.',
        'hint': field.hint ?? 'Contoh: 012/MoU-ISRK/I/2026',
        'chips': <String>[],
      };
    }
    if (key.contains('mou_period') || key.contains('masa_berlaku')) {
      return {
        'label': field.label,
        'caption': 'Durasi masa aktif perjanjian kerjasama kemitraan.',
        'hint': field.hint ?? 'Contoh: 2026 - 2029 (Aktif)',
        'chips': <String>[],
      };
    }
    if (key.contains('contact') || key.contains('email')) {
      return {
        'label': '${field.label} *',
        'caption': 'Alamat email korespondensi resmi atau narahubung kemitraan.',
        'hint': field.hint ?? 'Contoh: kemitraan@perusahaan.com',
        'chips': <String>[],
      };
    }
    if (key.contains('website') || key.contains('url') || field.kind == _FieldKind.url) {
      return {
        'label': field.label,
        'caption': 'Alamat website resmi atau tautan profil perusahaan.',
        'hint': field.hint ?? 'Contoh: https://perusahaan.com',
        'chips': <String>[],
      };
    }
    return {
      'label': field.label,
      'caption': 'Pastikan data yang diisi sesuai dengan dokumen kerjasama resmi.',
      'hint': field.hint ?? 'Masukkan ${field.label.toLowerCase()}...',
      'chips': <String>[],
    };
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  bool get _isCorporateCaller {
    final subRole = widget.user?.subRole?.toLowerCase() ?? '';
    return ['corporate', 'company', 'business', 'perusahaan', 'bisnis'].contains(subRole);
  }

  bool get _isInstitution {
    final subRole = widget.user?.subRole?.toLowerCase() ?? '';
    if (['corporate', 'company', 'business', 'perusahaan', 'bisnis'].contains(subRole)) {
      return false;
    }
    if (['government', 'pemerintah', 'dinas', 'bumn', 'kementerian'].contains(subRole)) {
      return false;
    }
    final role = widget.user?.role.toLowerCase() ?? '';
    if (role == 'institution' || role == 'school') return true;
    const schoolSubroles = [
      'school',
      'sekolah',
      'universitas',
      'institution',
      'kampus',
      'smk',
      'education',
      'institusi',
      'lembaga',
      'yayasan',
    ];
    if (schoolSubroles.contains(subRole)) return true;
    final username = widget.user?.username.toLowerCase() ?? '';
    final email = widget.user?.email.toLowerCase() ?? '';
    if (username.contains('institution') || username.contains('sekolah') || email.contains('institution')) {
      return true;
    }
    return true;
  }

  Color get _accentPrimary => _isInstitution ? const Color(0xFF7C3AED) : const Color(0xFF2563EB);
  Color get _accentDarker => _isInstitution ? const Color(0xFF6D28D9) : const Color(0xFF1D4ED8);
  Color get _accentBright => _isInstitution ? const Color(0xFF8B5CF6) : const Color(0xFF3B82F6);
  Color get _accentLightText => _isInstitution ? const Color(0xFFA78BFA) : const Color(0xFF60A5FA);
  Color get _accentPaleText => _isInstitution ? const Color(0xFFDDD6FE) : const Color(0xFF93C5FD);
  Color get _accentDeepText => _isInstitution ? const Color(0xFF5B21B6) : const Color(0xFF1E40AF);
  Color get _accentBorderLight => _isInstitution ? const Color(0xFFDDD6FE) : const Color(0xFFBFDBFE);
  Color get _accentBgLight => _isInstitution ? const Color(0xFFF5F3FF) : const Color(0xFFEFF6FF);
  Color get _accentBgDark => _isInstitution ? const Color(0xFF2E1065) : const Color(0xFF1E283D);

  InputDecoration _inputDecoration({
    required String hint,
    IconData? prefixIcon,
    String? prefixText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      prefixIcon: prefixIcon != null
          ? Icon(
              prefixIcon,
              size: 20,
              color: _isDark ? _accentLightText : _accentPrimary,
            )
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _isDark ? const Color(0xFF141224) : Colors.white,
      hintStyle: TextStyle(
        fontSize: 13,
        color: _isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: _isDark ? const Color(0xFF2D2A45) : Colors.grey.shade300,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: _isDark ? const Color(0xFF2D2A45) : const Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: _isDark ? _accentBright : _accentPrimary,
          width: 1.8,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
    );
  }

  Widget _buildFieldCardContainer({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF161426) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDark ? const Color(0xFF2B2844) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isDark
                      ? _accentPrimary.withValues(alpha: 0.2)
                      : _accentBgLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isDark
                        ? _accentPrimary.withValues(alpha: 0.4)
                        : _accentBorderLight,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: _isDark ? _accentLightText : _accentPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: _isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            thickness: 1,
            color: _isDark ? const Color(0xFF28253E) : const Color(0xFFE2E8F0),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFieldWithHeader({
    required String label,
    required String caption,
    required Widget child,
    double? minHeaderHeight,
    List<String> chips = const [],
    TextEditingController? targetController,
  }) {
    final headerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          caption,
          style: TextStyle(
            fontSize: 11.5,
            color: _isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
            height: 1.3,
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (minHeaderHeight != null)
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeaderHeight),
            child: headerContent,
          )
        else
          headerContent,
        const SizedBox(height: 8),
        child,
        if (chips.isNotEmpty && targetController != null) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: chips.map((chipText) {
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() {
                    targetController.text = chipText;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isDark ? const Color(0xFF201D35) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isDark ? const Color(0xFF383457) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 13,
                        color: _isDark ? _accentLightText : _accentPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        chipText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildFieldWidget(_WorkspaceField field, {double? minHeaderHeight}) {
    final meta = _getFieldMeta(field);
    final ctrl = _controllers[field.key]!;
    final chips = (meta['chips'] as List<dynamic>?)?.cast<String>() ?? const <String>[];

    return _buildFieldWithHeader(
      label: meta['label'] as String,
      caption: meta['caption'] as String,
      minHeaderHeight: minHeaderHeight,
      chips: chips,
      targetController: ctrl,
      child: TextFormField(
        controller: ctrl,
        style: TextStyle(
          fontSize: 13.5,
          color: _isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        keyboardType: field.kind == _FieldKind.number
            ? TextInputType.number
            : (field.kind == _FieldKind.url ? TextInputType.url : TextInputType.text),
        decoration: _inputDecoration(
          hint: meta['hint'] as String,
          prefixText: field.prefix,
          prefixIcon: _getFieldIcon(field),
        ),
        validator: (meta['label'] as String).contains('*')
            ? (val) => val == null || val.trim().isEmpty
                ? '${(meta['label'] as String).replaceAll('*', '').trim()} wajib diisi'
                : null
            : null,
      ),
    );
  }

  Widget _buildStatusDropdown({double? minHeaderHeight}) {
    final effectiveStatuses = widget.resourceType == 'partners'
        ? (widget.statuses.contains('pending') ? widget.statuses : ['pending', ...widget.statuses])
        : widget.statuses;

    return _buildFieldWithHeader(
      label: 'Status Kemitraan & Akses *',
      caption: 'Tentukan status keaktifan mitra untuk penempatan magang peserta.',
      minHeaderHeight: minHeaderHeight,
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        isDense: true,
        initialValue: _status,
        dropdownColor: _isDark ? const Color(0xFF1E1B32) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 6,
        style: TextStyle(
          fontSize: 13,
          color: _isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        icon: Icon(Icons.arrow_drop_down_rounded, color: _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        decoration: _inputDecoration(
          hint: 'Pilih status...',
          prefixIcon: Icons.verified_user_outlined,
        ),
        selectedItemBuilder: (context) {
          return effectiveStatuses.map((value) {
            final (dotColor, badgeText) = switch (value) {
              'active' || 'published' => (Colors.green.shade600, 'Aktif / Tervalidasi'),
              'pending' => (Colors.amber.shade700, 'Menunggu Persetujuan'),
              'draft' => (Colors.blue.shade600, 'Draf Inisiasi'),
              _ => (const Color(0xFF64748B), 'Diarsipkan'),
            };
            return Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList();
        },
        items: effectiveStatuses.asMap().entries.map((entry) {
          final index = entry.key;
          final value = entry.value;
          final isLast = index == effectiveStatuses.length - 1;
          final (dotColor, badgeText) = switch (value) {
            'active' || 'published' => (Colors.green.shade600, 'Aktif / Tervalidasi'),
            'pending' => (Colors.amber.shade700, 'Menunggu Persetujuan'),
            'draft' => (Colors.blue.shade600, 'Draf Inisiasi'),
            _ => (const Color(0xFF64748B), 'Diarsipkan'),
          };

          return DropdownMenuItem<String>(
            value: value,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                border: !isLast
                    ? Border(
                        bottom: BorderSide(
                          color: _isDark
                              ? const Color(0xFF2D2A42)
                              : const Color(0xFFF1F5F9),
                          width: 1,
                        ),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: dotColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => _status = value);
          }
        },
      ),
    );
  }

  Widget _buildCorporateSearchSection() {
    final isCorpCaller = _isCorporateCaller;
    final selectedRole = (_selectedCorporate?['selected_sub_role'] ?? '').toString().toLowerCase();
    final selectedIsInstitution = selectedRole.isNotEmpty
        ? ['institution', 'school', 'sekolah', 'kampus', 'education', 'institusi', 'smk', 'universitas'].contains(selectedRole)
        : isCorpCaller;
    final selectedPhone = (_selectedCorporate?['phone'] ?? '').toString().trim();
    final selectedEmail = (_selectedCorporate?['email'] ?? '').toString().trim();

    return _buildFieldCardContainer(
      title: isCorpCaller
          ? '1. Cari Institusi / Sekolah / Kampus Mitra'
          : '1. Cari PT / Akun Corporate Mitra',
      subtitle: isCorpCaller
          ? 'Cari institusi pendidikan berdasarkan nama atau username (contoh: @smk_telesandi).'
          : 'Cari perusahaan berdasarkan nama PT atau username (contoh: @corporate_demo).',
      icon: isCorpCaller ? Icons.school_rounded : Icons.business_rounded,
      children: [
        if (_selectedCorporate != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _isDark ? _accentBgDark.withValues(alpha: 0.45) : _accentBgLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isDark ? _accentPrimary.withValues(alpha: 0.45) : _accentBorderLight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _accentPrimary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      _selectedCorporate!['name'] != null && _selectedCorporate!['name'].toString().isNotEmpty
                          ? _selectedCorporate!['name'].toString().substring(0, 1).toUpperCase()
                          : (isCorpCaller ? 'I' : 'C'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _selectedCorporate!['name']?.toString() ??
                                  (selectedIsInstitution ? 'Institusi Mitra' : 'Perusahaan Mitra'),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: _isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _isDark ? _accentBgDark : _accentBgLight,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _isDark ? _accentPrimary.withValues(alpha: 0.5) : _accentBorderLight,
                              ),
                            ),
                            child: Text(
                              selectedIsInstitution ? 'Institusi Terverifikasi' : 'Corporate Terverifikasi',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _isDark ? _accentLightText : _accentDarker,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${_selectedCorporate!['username'] ?? (selectedIsInstitution ? 'institution' : 'corporate')}'
                        '${selectedEmail.isNotEmpty ? ' • $selectedEmail' : ''}'
                        '${selectedPhone.isNotEmpty ? ' • $selectedPhone' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Ganti', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isDark ? _accentLightText : _accentPrimary,
                    side: BorderSide(
                      color: _isDark ? _accentPrimary.withValues(alpha: 0.5) : _accentBorderLight,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    setState(() {
                      final previousSelectedName = _selectedCorporate?['name']?.toString().trim() ?? '';
                      if (_titleController.text.trim() == previousSelectedName) {
                        _titleController.clear();
                      }
                      _selectedCorporate = null;
                      _corpSearchController.clear();
                      _showCorpDropdown = true;
                    });
                    _fetchCorporates('');
                  },
                ),
              ],
            ),
          ),
        ] else ...[
          TextField(
            controller: _corpSearchController,
            style: TextStyle(
              fontSize: 13.5,
              color: _isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            onChanged: (val) {
              if (!_showCorpDropdown) setState(() => _showCorpDropdown = true);
              _corpSearchDebounce?.cancel();
              _corpSearchDebounce = Timer(const Duration(milliseconds: 220), () {
                _fetchCorporates(val);
              });
            },
            onTap: () {
              setState(() => _showCorpDropdown = true);
              if (_corporateList.isEmpty && !_isLoadingCorporates) {
                _fetchCorporates(_corpSearchController.text);
              }
            },
            decoration: _inputDecoration(
              hint: isCorpCaller
                  ? 'Ketik nama Institusi/Sekolah atau @username (contoh: @smk_telesandi)...'
                  : 'Ketik nama PT/Perusahaan atau @username (contoh: @corporate_demo)...',
              prefixIcon: Icons.search_rounded,
              suffixIcon: _isLoadingCorporates
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : (_corpSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _corpSearchController.clear();
                            setState(() => _showCorpDropdown = true);
                            _fetchCorporates('');
                          },
                        )
                      : null),
            ),
          ),
          if (_showCorpDropdown) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isDark ? const Color(0xFF383457) : const Color(0xFFCBD5E1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _isDark ? 0.25 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: _isDark ? const Color(0xFF1E1B2E) : Colors.white,
                borderRadius: BorderRadius.circular(11.5),
                clipBehavior: Clip.antiAlias,
                child: _isLoadingCorporates && _corporateList.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 10),
                            Text(
                              isCorpCaller ? 'Mencari akun Institusi...' : 'Mencari akun Corporate...',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : (_corporateList.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 18,
                                  color: _isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isCorpCaller
                                        ? 'Tidak ditemukan akun Institusi yang cocok. Anda tetap dapat mengetik nama resmi institusi di bawah.'
                                        : 'Tidak ditemukan akun PT/Corporate yang cocok. Anda tetap dapat mengetik nama resmi PT di bawah.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: _corporateList.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              color: _isDark ? const Color(0xFF2D2A42) : const Color(0xFFF1F5F9),
                            ),
                            itemBuilder: (context, idx) {
                              final corp = _corporateList[idx];
                              final corpName = corp['name']?.toString() ?? (isCorpCaller ? 'Institusi' : 'Perusahaan');
                              final corpUname = corp['username']?.toString() ?? '';
                              final corpEmail = corp['email']?.toString() ?? '';
                              final corpPhone = corp['phone']?.toString().trim() ?? '';
                              final initials = corpName.isNotEmpty ? corpName.substring(0, 1).toUpperCase() : (isCorpCaller ? 'I' : 'C');

                              return ListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: _accentPrimary,
                                  child: Text(
                                    initials,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        corpName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: _isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(Icons.verified_rounded, size: 14, color: _accentPrimary),
                                  ],
                                ),
                                subtitle: Text(
                                  '@$corpUname${corpEmail.isNotEmpty ? ' • $corpEmail' : ''}${corpPhone.isNotEmpty ? ' • $corpPhone' : ''}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
                                onTap: () {
                                  setState(() {
                                    _selectedCorporate = corp;
                                    _showCorpDropdown = false;
                                    _titleController.text = corpName;
                                  });
                                },
                              );
                            },
                          )),
              ),
            ),
          ],
        ],
        const SizedBox(height: 14),
        _buildFieldWithHeader(
          label: isCorpCaller
              ? 'Nama Resmi Institusi / Mitra *'
              : 'Nama Resmi Perusahaan / Mitra Industri *',
          caption: 'Nama identitas resmi rekanan (terisi otomatis jika memilih akun di atas).',
          child: TextFormField(
            controller: _titleController,
            style: TextStyle(
              fontSize: 13.5,
              color: _isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            decoration: _inputDecoration(
              hint: isCorpCaller
                  ? 'Contoh: SMK Telekomunikasi Telesandi, Universitas Indonesia...'
                  : 'Contoh: PT Studio Animasi Nusantara, Google, Inc...',
              prefixIcon: isCorpCaller ? Icons.school_rounded : Icons.domain_rounded,
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty
                    ? 'Nama / Judul mitra industri wajib diisi'
                    : null,
          ),
        ),
      ],
    );
  }

  Widget _buildMouUploadSection() {
    final hasFiles = _mouFiles.isNotEmpty;
    final canAddMore = _mouFiles.length < _maxMouFiles;
    final hasError = _mouUploadError != null && _mouFiles.isEmpty;

    return _buildFieldCardContainer(
      title: '3. Upload Berkas Kerjasama *',
      subtitle: 'Wajib mengunggah minimal 1 berkas kerjasama (MoU / PKS / Proposal). Maksimal $_maxMouFiles berkas.',
      icon: Icons.upload_file_rounded,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              hasFiles ? 'Daftar Berkas Terlampir' : 'Belum ada berkas terunggah',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: hasFiles
                    ? const Color(0xFFECFDF5)
                    : (hasError ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasFiles
                      ? const Color(0xFFA7F3D0)
                      : (hasError ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A)),
                ),
              ),
              child: Text(
                '${_mouFiles.length}/$_maxMouFiles Berkas • Wajib',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: hasFiles
                      ? const Color(0xFF059669)
                      : (hasError ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (hasFiles) ...[
          for (int i = 0; i < _mouFiles.length; i++) ...[
            Container(
              margin: EdgeInsets.only(bottom: i < _mouFiles.length - 1 || canAddMore ? 10 : 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isDark ? const Color(0xFF052E16).withValues(alpha: 0.45) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isDark ? const Color(0xFF16A34A) : const Color(0xFF86EFAC),
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF16A34A), size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _mouFiles[i]['filename']?.toString() ?? 'Berkas-Kerjasama-${i + 1}.pdf',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: _isDark ? const Color(0xFFDCFCE7) : const Color(0xFF14532D),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF16A34A)),
                                  SizedBox(width: 3),
                                  Text(
                                    'Siap Diajukan',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_mouFiles[i]['filesize'] ?? 'Dokumen Digital'} • Berkas ${i + 1} dari $_maxMouFiles',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: _isDark ? const Color(0xFF86EFAC) : Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hapus Berkas Ini',
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFFDC2626)),
                    onPressed: _isUploadingMou ? null : () => _removeMouFile(i),
                  ),
                ],
              ),
            ),
          ],
        ],
        if (canAddMore)
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _isUploadingMou ? null : _pickMouFiles,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              decoration: BoxDecoration(
                color: _isDark ? const Color(0xFF19172B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasError
                      ? const Color(0xFFDC2626)
                      : (_isDark ? const Color(0xFF383457) : const Color(0xFFCBD5E1)),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  if (_isUploadingMou) ...[
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: _accentPrimary),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Mengunggah berkas kerjasama ke server...',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _accentPrimary),
                    ),
                  ] else ...[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: hasError ? const Color(0xFFFEF2F2) : _accentBgLight,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: hasError ? const Color(0xFFFCA5A5) : _accentBorderLight,
                        ),
                      ),
                      child: Icon(
                        Icons.cloud_upload_outlined,
                        color: hasError ? const Color(0xFFDC2626) : _accentPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hasFiles
                          ? 'Tambah berkas kerjasama (${_maxMouFiles - _mouFiles.length} slot tersisa)'
                          : 'Klik untuk memilih berkas kerjasama (Wajib, Maks. $_maxMouFiles Berkas)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Format: .pdf, .doc, .docx • Maksimal 15 MB per berkas',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF059669)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Maksimal $_maxMouFiles berkas kerjasama telah terunggah. Hapus salah satu jika ingin mengganti.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: _isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (hasError) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, size: 15, color: Color(0xFFDC2626)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _mouUploadError!,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF64748B)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Setelah disetujui Corporate, seluruh berkas kerjasama ini otomatis diterbitkan ke menu "Dokumen & MoU".',
                style: TextStyle(
                  fontSize: 11.5,
                  color: _isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPartnerResource = widget.resourceType == 'partners';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      backgroundColor: _isDark ? const Color(0xFF1A182A) : Colors.white,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isDark ? _accentPrimary.withValues(alpha: 0.15) : _accentPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isDark ? _accentPrimary.withValues(alpha: 0.3) : _accentPrimary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Center(
                    child: Icon(widget.icon, color: _accentPrimary, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.existing == null ? widget.action : 'Edit ',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: _isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: _isDark ? const Color(0xFF221E38) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _isDark ? const Color(0xFF332E52) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              isPartnerResource ? 'Mitra Industri' : 'Data Resmi',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: _isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isPartnerResource
                            ? 'Lengkapi profil rekanan industri untuk program magang, praktisi mengajar, dan sertifikasi kompetensi.'
                            : 'Tersimpan aman di pangkalan data instansi Kreavana untuk tata kelola resmi.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  tooltip: 'Tutup Dialog',
                  style: IconButton.styleFrom(
                    backgroundColor: _isDark ? const Color(0xFF27243C) : const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: _isDark ? const Color(0xFF2D2A42) : const Color(0xFFE2E8F0),
          ),
        ],
      ),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 540;

                final secondaryWidgets = <Widget>[
                  for (final field in widget.fields)
                    _buildFieldWidget(field, minHeaderHeight: isWide ? 42.0 : null),
                  _buildStatusDropdown(minHeaderHeight: isWide ? 42.0 : null),
                ];

                final gridRows = <Widget>[];
                if (isWide) {
                  for (int i = 0; i < secondaryWidgets.length; i += 2) {
                    if (i + 1 < secondaryWidgets.length) {
                      gridRows.add(
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: secondaryWidgets[i]),
                            const SizedBox(width: 16),
                            Expanded(child: secondaryWidgets[i + 1]),
                          ],
                        ),
                      );
                    } else {
                      gridRows.add(secondaryWidgets[i]);
                    }
                    if (i + 2 < secondaryWidgets.length) {
                      gridRows.add(const SizedBox(height: 16));
                    }
                  }
                } else {
                  for (int i = 0; i < secondaryWidgets.length; i++) {
                    gridRows.add(secondaryWidgets[i]);
                    if (i + 1 < secondaryWidgets.length) {
                      gridRows.add(const SizedBox(height: 16));
                    }
                  }
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Guidance banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _isDark
                            ? _accentBgDark.withValues(alpha: 0.7)
                            : _accentBgLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isDark
                              ? _accentPrimary.withValues(alpha: 0.45)
                              : _accentBorderLight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: _isDark ? _accentLightText : _accentPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isPartnerResource
                                  ? 'Panduan: Lengkapi 3 bagian pengajuan mitra berikut: (1) Cari PT berdasarkan nama atau username, (2) Isi deskripsi kerjasama, dan (3) Unggah berkas kerjasama (wajib, maks. 3 berkas).'
                                  : 'Panduan: Lengkapi seluruh kolom wajib bertanda bintang (*) untuk menjaga keabsahan arsip instansi.',
                              style: TextStyle(
                                fontSize: 12,
                                color: _isDark ? _accentPaleText : _accentDeepText,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1. Cari PT / Hubungkan Akun Corporate Mitra (Partners Only)
                    if (isPartnerResource) ...[
                      _buildCorporateSearchSection(),
                      const SizedBox(height: 16),
                      _buildFieldCardContainer(
                        title: '2. Deskripsi & Ruang Lingkup Kerjasama',
                        subtitle: 'Jelaskan tujuan kerjasama agar pihak institusi maupun mitra memahami rencana kolaborasi.',
                        icon: Icons.notes_rounded,
                        children: [
                          _buildFieldWithHeader(
                            label: 'Deskripsi Kerjasama *',
                            caption: 'Tuliskan bentuk kerjasama seperti magang peserta, praktisi mengajar industri, penyelarasan kurikulum, atau proyek bersama.',
                            child: TextFormField(
                              controller: _descriptionController,
                              minLines: 3,
                              maxLines: 5,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: _isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              decoration: _inputDecoration(
                                hint: 'Contoh: Pengajuan kerjasama penempatan magang peserta bidang DKV & Animasi 3D, program praktisi mengajar industri, dan uji kompetensi...',
                                prefixIcon: Icons.notes_rounded,
                              ),
                              validator: (value) => value == null || value.trim().isEmpty
                                  ? 'Deskripsi kerjasama wajib diisi'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildMouUploadSection(),
                    ],

                    // Non-partner sections remain intact
                    if (!isPartnerResource) ...[
                      _buildFieldCardContainer(
                        title: 'Informasi Utama & Pokok',
                        subtitle: 'Judul dan penjelasan umum mengenai arsip',
                        icon: Icons.business_rounded,
                        children: [
                          _buildFieldWithHeader(
                            label: 'Nama / Judul Resmi *',
                            caption: 'Nama identitas resmi dokumen atau aset.',
                            child: TextFormField(
                              controller: _titleController,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: _isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              decoration: _inputDecoration(
                                hint: 'Masukkan nama atau judul resmi...',
                                prefixIcon: Icons.domain_rounded,
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                      ? 'Nama / Judul wajib diisi'
                                      : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildFieldWithHeader(
                              label: 'Deskripsi / Ruang Lingkup',
                              caption: 'Jelaskan ringkasan kebutuhan, spesifikasi, atau catatan penting.',
                              child: TextFormField(
                                controller: _descriptionController,
                                minLines: 3,
                                maxLines: 4,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: _isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                decoration: _inputDecoration(
                                  hint: 'Jelaskan ringkasan kebutuhan, spesifikasi, atau catatan...',
                                  prefixIcon: Icons.notes_rounded,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      if (secondaryWidgets.isNotEmpty)
                        _buildFieldCardContainer(
                          title: 'Detail Spesifikasi & Publikasi',
                          subtitle: 'Parameter pendukung dan status publikasi sistem',
                          icon: Icons.hub_outlined,
                          children: [
                            ...gridRows,
                          ],
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tervalidasi Sistem Instansi Kreavana',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isDark ? const Color(0xFFE2E8F0) : const Color(0xFF64748B),
                    side: BorderSide(
                      color: _isDark ? const Color(0xFF383457) : const Color(0xFFCBD5E1),
                    ),
                    backgroundColor: _isDark ? const Color(0xFF221F3A) : Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : (isPartnerResource && widget.existing == null
                          ? const Icon(Icons.send_rounded, size: 17)
                          : const Icon(Icons.check_circle_outline_rounded, size: 18)),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accentPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSaving ? null : _submit,
                  label: Text(
                    _isSaving
                        ? 'Memproses...'
                        : (isPartnerResource
                            ? (widget.existing == null ? 'Ajukan Kemitraan' : 'Simpan Perubahan')
                            : 'Simpan Data'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _GoogleGLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.22;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    const degToRad = 3.141592653589793 / 180.0;

    // 1. Red (top arc)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -155 * degToRad, 110 * degToRad, false, paint);

    // 2. Yellow (bottom-left arc)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -225 * degToRad, 70 * degToRad, false, paint);

    // 3. Green (bottom-right arc)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 45 * degToRad, 90 * degToRad, false, paint);

    // 4. Blue (right arc)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -45 * degToRad, 90 * degToRad, false, paint);

    // 5. Blue horizontal crossbar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final barHeight = strokeWidth;
    final barRect = Rect.fromLTWH(
      center.dx - 2,
      center.dy - barHeight / 2,
      radius + strokeWidth / 2 + 2,
      barHeight,
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
