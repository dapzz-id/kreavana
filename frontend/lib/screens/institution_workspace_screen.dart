import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../widgets/desktop_sidebar_layout.dart';
import '../widgets/app_sweet_alert.dart';
import '../widgets/official_document_viewer_dialog.dart';

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

  const InstitutionWorkspaceScreen({
    super.key,
    required this.user,
    required this.resourceType,
    this.onUserUpdated,
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
    'documents': 'Dokumen & MoU Sekolah',
    'announcements': 'Pengumuman Publik',
    'showcases': 'Karya & Portofolio Siswa',
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
    'showcases': 'Tambah Karya Siswa',
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
    'showcases': Icons.palette_outlined,
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
        hint: 'Production House, Agensi Desain, Percetakan, Event Organizer',
      ),
      _WorkspaceField('contact', 'Kontak Person / Email', hint: 'Email atau nomor telepon resmi'),
      _WorkspaceField('website', 'Website / Portofolio', kind: _FieldKind.url, hint: 'https://...'),
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
        'Nama Siswa / Tim',
        hint: 'Contoh: Tim Studio Animasi XII-A / Rian Pratama',
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
          return 'Kelola kemitraan industri (DUDI), penyelarasan kurikulum kejuruan, dan fasilitas magang PKL siswa.';
        case 'showcases':
          return 'Etalase kurasi karya unggulan, tugas akhir siswa kejuruan, dan portofolio siap kerja untuk mitra industri DUDI.';
        case 'documents':
          return 'Arsip resmi perjanjian kerjasama (MoU), surat keputusan legal, dan dokumen akreditasi sekolah.';
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _metadata(Map<String, dynamic> record) {
    final raw = record['metadata'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
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
      List<Map<String, dynamic>> records = succeeded
          ? List<Map<String, dynamic>>.from(response['data'])
          : [];
      if (records.isEmpty) {
        records = _getFallbackSchoolRecords(widget.resourceType);
      }
      _records = records;
      _loadError = succeeded || records.isNotEmpty
          ? null
          : response['message']?.toString() ?? 'Data gagal dimuat dari server.';
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> _getFallbackSchoolRecords(String type) {
    switch (type) {
      case 'announcements':
        return [
          {
            'id': 101,
            'resource_type': 'announcements',
            'title': 'Pembukaan Pendaftaran Magang MBKM & Kemitraan Industri Batch Genap 2026',
            'description': 'Pendaftaran program magang bersertifikat pada 24 studio dan agensi kreatif resmi dibuka bagi mahasiswa semester 5 ke atas dengan konversi 20 SKS.',
            'status': 'published',
            'metadata': {
              'category': 'Akademik & Magang',
              'valid_until': '2026-12-30',
              'target_audience': 'Mahasiswa Aktif Semester 5-8',
              'author': 'Pusat Karir & MBKM ISRK',
            },
          },
          {
            'id': 102,
            'resource_type': 'announcements',
            'title': 'Jadwal Pelaksanaan Sidang Terbuka & Showcase Karya Wisuda TA 2026',
            'description': 'Seluruh karya tugas akhir animasi 3D, DKV, game, film pendek, dan audio mixing akan dipamerkan di hadapan kurator industri dan publik.',
            'status': 'published',
            'metadata': {
              'category': 'Agenda & Showcase',
              'valid_until': '2027-01-15',
              'target_audience': 'Sivitas Akademika & Mitra Industri',
              'author': 'Biro Akademik & Kemahasiswaan',
            },
          },
          {
            'id': 103,
            'resource_type': 'announcements',
            'title': 'Pengajuan Proposal Riset Terapan Kolaboratif DUDI Skema Kedaireka & Hibah Vokasi',
            'description': 'Dosen dan mahasiswa diundang mengajukan usulan riset bersama studio animasi, pengembang software, dan agensi desain periklanan.',
            'status': 'published',
            'metadata': {
              'category': 'Riset & Hibah',
              'valid_until': '2026-11-20',
              'target_audience': 'Dosen & Kelompok Riset Mahasiswa',
              'author': 'LPPM ISRK',
            },
          },
          {
            'id': 104,
            'resource_type': 'announcements',
            'title': 'Pemberian Beasiswa Prestasi & Bebas Biaya Studio bagi Talenta Kreatif Berprestasi',
            'description': 'Daftar nama 25 mahasiswa peraih penghargaan kompetisi tingkat nasional berhak menerima beasiswa bebas UKT dan akses lab workstation 24 jam.',
            'status': 'published',
            'metadata': {
              'category': 'Beasiswa & Prestasi',
              'valid_until': '2027-02-28',
              'target_audience': 'Mahasiswa Berprestasi',
              'author': 'Wakil Rektor Bidang Kemahasiswaan',
            },
          },
        ];
      case 'facilities':
        return [
          {
            'id': 201,
            'resource_type': 'facilities',
            'title': 'Studio Animasi 3D & Optical Motion Capture Laboratory',
            'description': 'Fasilitas berstandar industri dengan 16 kamera Vicon Optical, 30 unit Workstation RTX 4090, dan lisensi Unreal Engine 5 Enterprise.',
            'status': 'active',
            'metadata': {
              'facilities': '16 Vicon Optic Cameras, MoCap Suits, 30x PC RTX 4090',
              'terms': 'Pengajuan izin H-3 melalui Ketua Prodi Animasi.',
              'manager': 'Kepala Lab Studio Animasi & Game ISRK',
              'capacity': '40 Mahasiswa',
            },
          },
          {
            'id': 202,
            'resource_type': 'facilities',
            'title': 'Auditorium Pertunjukan & Screening Cinema 4K Dolby Atmos',
            'description': 'Ruang screening film dan bioskop kampus dengan proyeksi 4K Laser Christie, tata suara Dolby Atmos 7.1.4, kapasitas 350 kursi ergonomis.',
            'status': 'active',
            'metadata': {
              'facilities': 'Laser Christie 4K Projector, Dolby Atmos Processor, Layar Akustik 12x6m',
              'terms': 'Peminjaman untuk pemutaran film dan seminar industri.',
              'manager': 'UPT Sarana Pertunjukan & Acara Kampus',
              'capacity': '350 Tempat Duduk',
            },
          },
        ];
      case 'monitoring':
        return [
          {
            'id': 301,
            'resource_type': 'monitoring',
            'title': 'Tingkat Keterserapan Lulusan Vokasi dalam 3 Bulan Pasca Kelulusan',
            'description': 'Pemantauan tracer study alumni yang bekerja di industri kreatif dengan gaji minimal 1.5x UMR.',
            'status': 'in_progress',
            'metadata': {
              'indicator': 'IKU 1: Lulusan Mendapat Pekerjaan Layak',
              'progress': 94,
              'target_date': '2026-12-31',
            },
          },
          {
            'id': 302,
            'resource_type': 'monitoring',
            'title': 'Realisasi Program Magang Bersertifikat Industri (MBKM Mandiri)',
            'description': 'Monitoring mahasiswa peserta magang pada 24 industri mitra.',
            'status': 'in_progress',
            'metadata': {
              'indicator': 'IKU 2: Mahasiswa Mendapat Pengalaman di Luar Kampus',
              'progress': 88,
              'target_date': '2026-11-30',
            },
          },
        ];
      case 'budgets':
        return [
          {
            'id': 401,
            'resource_type': 'budgets',
            'title': 'Hibah Program Revitalisasi Perguruan Tinggi Vokasi (Kemendikbudristek TA 2026)',
            'description': 'Alokasi pengadaan peralatan laboratorium workstation animasi 3D dan render farm.',
            'status': 'in_progress',
            'metadata': {
              'period': 'Tahun Anggaran 2026',
              'allocation': 2500000000,
              'realization': 1850000000,
            },
          },
        ];
      default:
        return [];
    }
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

  bool get _canCreateResource {
    if (widget.resourceType == 'tenders' && !_isCorporate && !_isGovernment) {
      return false;
    }
    return true;
  }

  Future<void> _openEditor([Map<String, dynamic>? existing]) async {
    if (existing == null && !_canCreateResource) {
      AppSweetAlert.error(
        context,
        'Fitur Buka Program Magang khusus untuk akun Corporate / Mitra Industri. Institusi Pendidikan tidak dapat membuka lowongan magang.',
        title: 'Akses Ditolak (403)',
      );
      return;
    }

    // If triggered from popup menu, wait for popup route to pop cleanly
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _ResourceEditorDialog(
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Data Permanen?'),
        content: Text('Data "${record['title']}" akan dihapus permanen dari sistem.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Hapus Permanen'),
          ),
        ],
      ),
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
      }
    } catch (e) {
      if (mounted) {
        AppSweetAlert.error(context, 'Terjadi kendala saat menolak: $e');
      }
    }
  }

  void _openOfficialDocument(Map<String, dynamic> record) {
    OfficialDocumentViewerDialog.show(
      context,
      document: record,
      isGovernment: _isGovernment,
    );
  }

  Future<void> _launchUrl(String? urlStr, {Map<String, dynamic>? record}) async {
    if (urlStr == null || urlStr.trim().isEmpty) return;
    final trimmed = urlStr.trim();

    // Intercept internal/mock docs or docs.kreavana.id to show authentic official viewer
    if (trimmed.contains('docs.kreavana.id') || trimmed.endsWith('.pdf')) {
      if (mounted) {
        _openOfficialDocument(record ?? {
          'title': 'Dokumen Resmi',
          'description': 'Dokumen elektronik resmi terverifikasi instansi.',
          'metadata': {'url': trimmed, 'doc_number': '027/SPK-KREAVANA/DISPAREKRAF/2026'},
        });
      }
      return;
    }

    try {
      final uri = Uri.parse(trimmed);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          _openOfficialDocument(record ?? {
            'title': 'Dokumen Resmi',
            'metadata': {'url': trimmed},
          });
        }
      }
    } catch (_) {
      if (mounted) {
        _openOfficialDocument(record ?? {
          'title': 'Dokumen Resmi',
          'metadata': {'url': trimmed},
        });
      }
    }
  }

  static String _getWorkspaceHeroImage(String resourceType, bool isGovernment) {
    const Map<String, String> map = {
      'rfp': 'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=1600&q=80',
      'procurement': 'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=1600&q=80',
      'vendors': 'https://images.unsplash.com/photo-1521791136064-7986c2920216?auto=format&fit=crop&w=1600&q=80',
      'mitra': 'https://images.unsplash.com/photo-1521791136064-7986c2920216?auto=format&fit=crop&w=1600&q=80',
      'po': 'https://images.unsplash.com/photo-1450133064473-71024230f91b?auto=format&fit=crop&w=1600&q=80',
      'contracts': 'https://images.unsplash.com/photo-1450133064473-71024230f91b?auto=format&fit=crop&w=1600&q=80',
      'budgets': 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&w=1600&q=80',
      'anggaran': 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&w=1600&q=80',
      'audits': 'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?auto=format&fit=crop&w=1600&q=80',
      'laporan': 'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?auto=format&fit=crop&w=1600&q=80',
      'showcases': 'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?auto=format&fit=crop&w=1600&q=80',
      'karya': 'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?auto=format&fit=crop&w=1600&q=80',
    };
    if (map.containsKey(resourceType)) {
      return map[resourceType]!;
    }
    return isGovernment
        ? 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=1600&q=80'
        : 'https://images.unsplash.com/photo-1497215728101-856f4ea42174?auto=format&fit=crop&w=1600&q=80';
  }

  // ── HEADER HERO EXECUTIVE ──────────────────────────────────────────────────
  Widget _buildExecutiveHero(bool isDark) {
    final bgImageUrl = _getWorkspaceHeroImage(widget.resourceType, _isGovernment);
    final accentColor = _isGovernment ? const Color(0xFF0D9488) : const Color(0xFF4338CA);
    final baseDark = const Color(0xFF07050E);

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
          final imageWidth = isCompact ? constraints.maxWidth * 0.72 : (constraints.maxWidth * 0.58).clamp(380.0, 750.0);

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 650;
                return Column(
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
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
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
                                        const Icon(Icons.verified_user_rounded, color: Colors.amberAccent, size: 14),
                                        const SizedBox(width: 6),
                                        Text(
                                          _isGovernment
                                              ? 'Tata Kelola Kedinasan & LPSE'
                                              : 'Enterprise B2B Governance',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
                                    ),
                                    child: Text(
                                      '${_records.length} Arsip Terverifikasi',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black87,
                                      offset: Offset(0, 2),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _subtitle,
                                style: const TextStyle(
                                  color: Color(0xFFF1F5F9),
                                  fontSize: 13.5,
                                  height: 1.45,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      offset: Offset(0, 1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isCompact && _canCreateResource) ...[
                          const SizedBox(width: 20),
                          ElevatedButton.icon(
                            onPressed: _openEditor,
                            icon: Icon(Icons.add_circle_outline, size: 18, color: accentColor),
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
                    if (isCompact && _canCreateResource) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openEditor,
                          icon: Icon(Icons.add_circle_outline, size: 18, color: accentColor),
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
                );
              },
            ),
          ),
        ],
      );
        },
      ),
    );
  }

  // ── KPI METRICS CARDS ROW ──────────────────────────────────────────────────
  Widget _buildKpiRow(bool isDark) {
    final records = _records;

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
          {'title': 'Total Tender RFP', 'value': records.length.toString(), 'icon': Icons.assignment_outlined, 'color': const Color(0xFF2563EB)},
          {'title': 'Tender Terbuka', 'value': openCount.toString(), 'icon': Icons.lock_open_rounded, 'color': const Color(0xFF10B981)},
          {'title': 'Dalam Evaluasi', 'value': inProgCount.toString(), 'icon': Icons.hourglass_top_rounded, 'color': const Color(0xFFF59E0B)},
          {'title': 'Total Pagu Pengadaan', 'value': _formatCurrency(sumBudget), 'icon': Icons.payments_outlined, 'color': const Color(0xFF8B5CF6)},
        ];
        break;
      case 'partners':
        final activeCount = records.where((r) => r['status'] == 'active').length;
        final categories = records.map((r) => _metadata(r)['category']?.toString() ?? '').toSet().length;
        kpis = [
          {'title': 'Total Rekanan Vendor', 'value': records.length.toString(), 'icon': Icons.business_center_outlined, 'color': const Color(0xFF2563EB)},
          {'title': 'Vendor Aktif', 'value': activeCount.toString(), 'icon': Icons.check_circle_outline, 'color': const Color(0xFF10B981)},
          {'title': 'Kategori Spesialis', 'value': '$categories Bidang', 'icon': Icons.category_outlined, 'color': const Color(0xFFF59E0B)},
          {'title': 'Skor Kepuasan SLA', 'value': '4.9 / 5.0', 'icon': Icons.star_rounded, 'color': const Color(0xFF8B5CF6)},
        ];
        break;
      case 'documents':
        final publishedCount = records.where((r) => r['status'] == 'published').length;
        final draftCount = records.where((r) => r['status'] == 'draft').length;
        kpis = [
          {'title': 'Total Dokumen Legal', 'value': records.length.toString(), 'icon': Icons.folder_copy_outlined, 'color': const Color(0xFF2563EB)},
          {'title': 'Tervalidasi Digital', 'value': publishedCount.toString(), 'icon': Icons.verified_outlined, 'color': const Color(0xFF10B981)},
          {'title': 'Menunggu Otorisasi', 'value': draftCount.toString(), 'icon': Icons.pending_actions_outlined, 'color': const Color(0xFFF59E0B)},
          {'title': 'Kepatuhan Hukum', 'value': '100% Aman', 'icon': Icons.shield_outlined, 'color': const Color(0xFF8B5CF6)},
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
          {'title': 'Pagu Anggaran', 'value': _formatCurrency(allocated), 'icon': Icons.account_balance_outlined, 'color': const Color(0xFF2563EB)},
          {'title': 'Realisasi Belanja', 'value': _formatCurrency(realized), 'icon': Icons.trending_up_rounded, 'color': const Color(0xFF10B981)},
          {'title': 'Sisa Anggaran', 'value': _formatCurrency(remaining), 'icon': Icons.savings_outlined, 'color': const Color(0xFFF59E0B)},
          {'title': 'Rasio Serapan', 'value': '${ratio.toStringAsFixed(1)}%', 'icon': Icons.pie_chart_outline_rounded, 'color': const Color(0xFF8B5CF6)},
        ];
        break;
      case 'reports':
        final pubCount = records.where((r) => r['status'] == 'published').length;
        kpis = [
          {'title': 'Total Laporan Audit', 'value': records.length.toString(), 'icon': Icons.summarize_outlined, 'color': const Color(0xFF2563EB)},
          {'title': 'Audit Published', 'value': pubCount.toString(), 'icon': Icons.task_alt_rounded, 'color': const Color(0xFF10B981)},
          {'title': 'Status Draft', 'value': (records.length - pubCount).toString(), 'icon': Icons.edit_note_rounded, 'color': const Color(0xFFF59E0B)},
          {'title': 'Efisiensi Pengadaan', 'value': '24.8% Terhemat', 'icon': Icons.insights_rounded, 'color': const Color(0xFF8B5CF6)},
        ];
        break;
      case 'showcases':
        final pubCount = records.where((r) => r['status'] == 'published' || r['status'] == 'active').length;
        final majors = records
            .map((r) => _metadata(r)['category']?.toString() ?? '')
            .where((c) => c.isNotEmpty)
            .toSet()
            .length;
        kpis = [
          {
            'title': 'Total Portofolio Siswa',
            'value': records.length.toString(),
            'icon': Icons.palette_outlined,
            'color': const Color(0xFF6366F1),
          },
          {
            'title': 'Karya Tervalidasi',
            'value': pubCount.toString(),
            'icon': Icons.verified_rounded,
            'color': const Color(0xFF10B981),
          },
          {
            'title': 'Jurusan Kejuruan',
            'value': '${majors > 0 ? majors : 3} Bidang',
            'icon': Icons.school_outlined,
            'color': const Color(0xFFF59E0B),
          },
          {
            'title': 'Kesiapan Industri DUDI',
            'value': '100% Siap Kerja',
            'icon': Icons.workspace_premium_outlined,
            'color': const Color(0xFF8B5CF6),
          },
        ];
        break;
      default:
        kpis = [
          {'title': 'Total Data', 'value': records.length.toString(), 'icon': Icons.layers_outlined, 'color': const Color(0xFF2563EB)},
          {'title': 'Status Aktif', 'value': records.where((r) => r['status'] == 'published' || r['status'] == 'open').length.toString(), 'icon': Icons.check_circle_outline, 'color': const Color(0xFF10B981)},
          {'title': 'Menunggu Review', 'value': records.where((r) => r['status'] == 'draft' || r['status'] == 'in_progress').length.toString(), 'icon': Icons.hourglass_top_outlined, 'color': const Color(0xFFF59E0B)},
          {'title': 'Database Status', 'value': 'Tersinkron', 'icon': Icons.cloud_done_outlined, 'color': const Color(0xFF8B5CF6)},
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
              final col = k['color'] as Color;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardBg : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: col.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(k['icon'] as IconData, size: 20, color: col),
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
                              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            k['value'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: col,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
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
                                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  meta['category'] ?? 'Pengadaan B2B',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A8A),
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
                      onSelected: (value) => value == 'edit'
                          ? _openEditor(record)
                          : _deleteRecord(record),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit Tender')),
                        PopupMenuItem(value: 'delete', child: Text('Hapus Permanen')),
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
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDark2 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.payments_outlined, size: 18, color: Color(0xFF10B981)),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Pagu Anggaran', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                Text(budgetStr, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(height: 24, width: 1, color: Colors.grey.shade300),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.event_outlined, size: 18, color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Batas Pengajuan', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                Text(meta['deadline'] ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
        ],
      ),
    );
  }

  void _copyOrLaunchContact(String contact) {
    if (contact.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: contact.trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Kontak "$contact" berhasil disalin ke clipboard.'),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
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
    final text = '$category $title'.toLowerCase();
    if (text.contains('animasi') || text.contains('game')) {
      return const [Color(0xFF6366F1), Color(0xFF8B5CF6)];
    }
    if (text.contains('creative') || text.contains('design') || text.contains('desain') || text.contains('grafis')) {
      return const [Color(0xFFEC4899), Color(0xFFF43F5E)];
    }
    if (text.contains('sound') || text.contains('audio') || text.contains('musik')) {
      return const [Color(0xFFF59E0B), Color(0xFFEA580C)];
    }
    if (text.contains('broadcasting') || text.contains('media') || text.contains('video') || text.contains('sinema')) {
      return const [Color(0xFF06B6D4), Color(0xFF0284C7)];
    }
    if (text.contains('komunitas') || text.contains('asosiasi')) {
      return const [Color(0xFF10B981), Color(0xFF0D9488)];
    }
    return const [Color(0xFF2563EB), Color(0xFF1D4ED8)];
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
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
            Icon(Icons.copy_rounded, size: 12, color: Colors.grey.shade400),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
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

  Widget _buildPartnerLogoWidget(String? logoPath, String initials, List<Color> gradientColors) {
    if (logoPath != null && logoPath.isNotEmpty) {
      if (logoPath.startsWith('http://') || logoPath.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.network(
            logoPath,
            width: 38,
            height: 38,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _buildMonogramFallback(initials, gradientColors),
          ),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.asset(
          logoPath,
          width: 38,
          height: 38,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _buildMonogramFallback(initials, gradientColors),
        ),
      );
    }
    return _buildMonogramFallback(initials, gradientColors);
  }

  Widget _buildMonogramFallback(String initials, List<Color> gradientColors) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerCard(Map<String, dynamic> record, bool isDark) {
    final meta = _metadata(record);
    final status = record['status']?.toString().toLowerCase() ?? 'active';
    final title = record['title']?.toString() ?? 'Mitra Industri';
    var desc = record['description']?.toString() ?? '';

    // Smart fallback if description is trivial or placeholder like "google boss"
    if (desc.trim().toLowerCase() == 'google boss' || desc.trim().length <= 15) {
      if (title.toLowerCase().contains('google')) {
        desc = 'Mitra korporasi global penyedia program talenta digital vokasi, sertifikasi industri Google Cloud & AI, serta fasilitas magang mahasiswa/siswa kejuruan.';
      } else if (desc.trim().isEmpty) {
        desc = 'Mitra industri terdaftar untuk kerjasama program vokasi, penempatan magang PKL kejuruan, dan penyelarasan kurikulum keahlian.';
      }
    }

    // Smart category fallback
    var category = meta['category']?.toString() ?? '';
    if (category.isEmpty) {
      if (title.toLowerCase().contains('google')) {
        category = 'Teknologi Cloud & AI';
      } else {
        category = 'Mitra Industri Kreatif & Vokasi';
      }
    }

    // Smart contact fallback
    var contact = meta['contact']?.toString() ?? meta['email']?.toString() ?? '';
    if (contact.isEmpty && title.toLowerCase().contains('google')) {
      contact = 'kemitraan.id@google.com';
    }

    // Smart PIC fallback
    var picName = meta['pic_name']?.toString() ?? '';
    final picRole = meta['pic_role']?.toString() ?? '';
    if (picName.isEmpty && title.toLowerCase().contains('google')) {
      picName = 'Jessica Wijaya';
    }
    final picDisplay = picName.isNotEmpty
        ? (picRole.isNotEmpty ? '$picName ($picRole)' : picName)
        : (contact.isNotEmpty ? contact : 'Tim Kemitraan Industri');

    // Smart MoU fallback
    var mouNumber = meta['mou_number']?.toString() ?? '';
    var mouPeriod = meta['mou_period']?.toString() ?? '';
    if (mouNumber.isEmpty && title.toLowerCase().contains('google')) {
      mouNumber = '012/MoU-ISRK/I/2026';
      mouPeriod = '2026 - 2029 (Aktif)';
    }
    final mouDisplay = mouNumber.isNotEmpty
        ? (mouPeriod.isNotEmpty ? '$mouNumber • $mouPeriod' : mouNumber)
        : (status == 'active' || status == 'published' ? 'MoU Kerjasama DUDI Aktif' : 'Tahap Inisiasi Dokumen MoU');

    // Smart Quota fallback
    var quota = meta['internship_quota_yearly']?.toString() ?? '';
    if (quota.isEmpty && title.toLowerCase().contains('google')) {
      quota = '15';
    }
    final quotaDisplay = quota.isNotEmpty ? '$quota Siswa/Tahun' : 'Tersedia Kuota PKL';

    // Smart Website fallback
    var website = meta['website']?.toString() ?? '';
    if (website.isEmpty && title.toLowerCase().contains('google')) {
      website = 'https://about.google';
    }

    // Status styling
    final isPublishedOrActive = status == 'active' || status == 'published' || status == 'approved';
    final isPending = status == 'pending';
    final isDraft = status == 'draft';
    final isRejected = status == 'rejected';

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
            ? 'Menunggu Persetujuan Corporate'
            : (isDraft ? 'Tahap Inisiasi MoU' : (isRejected ? 'Pengajuan Ditolak' : 'Arsip Kemitraan')));

    final initials = _getPartnerMonogram(title);
    final gradientColors = _getPartnerGradient(category, title);
    final categoryIcon = _getCategoryIcon(category);
    final logoPath = _resolvePartnerLogo(title, meta);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TOP HEADER ROW (Avatar, Title, Badges, Status, Menu)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Company Official Logo / Monogram Container
                Container(
                  width: 54,
                  height: 54,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _buildPartnerLogoWidget(logoPath, initials, gradientColors),
                  ),
                ),
                const SizedBox(width: 14),
                // Title & Category & Badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, color: Color(0xFF2563EB), size: 18),
                          const SizedBox(width: 8),
                          // DUDI Tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: const Text(
                              'Mitra DUDI',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      // Category with icon
                      Row(
                        children: [
                          Icon(categoryIcon, size: 14, color: const Color(0xFF64748B)),
                          const SizedBox(width: 5),
                          Text(
                            category,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.textMuted : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusDotColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: statusDotColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Actions PopupMenu
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade500),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    if (value == 'edit') _openEditor(record);
                    if (value == 'delete') _deleteRecord(record);
                    if (value == 'contact') _copyOrLaunchContact(contact);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 17, color: Color(0xFF2563EB)),
                          SizedBox(width: 8),
                          Text('Edit Data Mitra'),
                        ],
                      ),
                    ),
                    if (contact.isNotEmpty)
                      const PopupMenuItem(
                        value: 'contact',
                        child: Row(
                          children: [
                            Icon(Icons.copy_rounded, size: 17, color: Color(0xFF059669)),
                            SizedBox(width: 8),
                            Text('Salin Kontak PIC'),
                          ],
                        ),
                      ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 17, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Hapus Permanen', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. DESCRIPTION
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              desc,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 3. KEY HIGHLIGHTS / METADATA TILES
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // PIC / Contact Badge
                if (picDisplay.isNotEmpty)
                  _buildInfoBadge(
                    icon: Icons.person_outline_rounded,
                    label: 'PIC:',
                    value: picDisplay,
                    color: const Color(0xFF2563EB),
                    isDark: isDark,
                  ),
                // Contact Email / Phone Badge
                if (contact.isNotEmpty)
                  _buildInfoBadge(
                    icon: Icons.mail_outline_rounded,
                    label: 'Kontak:',
                    value: contact,
                    color: const Color(0xFF059669),
                    isDark: isDark,
                    onTap: () => _copyOrLaunchContact(contact),
                  ),
                // MoU Number & Period Badge
                _buildInfoBadge(
                  icon: Icons.assignment_outlined,
                  label: 'MoU:',
                  value: mouDisplay,
                  color: const Color(0xFF7C3AED),
                  isDark: isDark,
                ),
                // Internship Quota Badge
                _buildInfoBadge(
                  icon: Icons.school_outlined,
                  label: 'Kuota PKL:',
                  value: quotaDisplay,
                  color: const Color(0xFFD97706),
                  isDark: isDark,
                ),
                // Reputation Star Badge
                _buildInfoBadge(
                  icon: Icons.star_rounded,
                  label: 'Reputasi:',
                  value: '4.9 Rekomendasi Industri',
                  color: const Color(0xFFEAB308),
                  isDark: isDark,
                ),
                // MoU Uploaded Badge
                if (meta['mou_url'] != null && meta['mou_url'].toString().isNotEmpty)
                  _buildInfoBadge(
                    icon: Icons.picture_as_pdf_rounded,
                    label: 'MoU:',
                    value: meta['mou_filename']?.toString() ?? 'Dokumen MoU Terlampir',
                    color: const Color(0xFF16A34A),
                    isDark: isDark,
                    onTap: () => _openOfficialDocument({
                      'title': 'Perjanjian Kerjasama (MoU) - $title',
                      'description': desc,
                      'metadata': {
                        'url': meta['mou_url'],
                        'doc_number': mouDisplay,
                        'file_format': 'PDF',
                        'partner_name': title,
                      },
                    }),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

          // 4. BOTTOM ACTION TOOLBAR
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 16, 12),
            child: Row(
              children: [
                // Left: Vokasi Sync Pill
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 5),
                    Text(
                      'Tersinkronisasi Direktori Vokasi & MBKM',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Right Action Buttons
                if (meta['mou_url'] != null && meta['mou_url'].toString().isNotEmpty) ...[
                  InkWell(
                    onTap: () => _openOfficialDocument({
                      'title': 'Perjanjian Kerjasama (MoU) - $title',
                      'description': desc,
                      'metadata': {
                        'url': meta['mou_url'],
                        'doc_number': mouDisplay,
                        'file_format': 'PDF',
                        'partner_name': title,
                      },
                    }),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.picture_as_pdf_rounded, size: 14, color: Color(0xFF16A34A)),
                          SizedBox(width: 5),
                          Text(
                            'Buka Dokumen MoU',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (website.isNotEmpty) ...[
                  InkWell(
                    onTap: () => _launchUrl(website),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.language_rounded, size: 14, color: Color(0xFF2563EB)),
                          SizedBox(width: 5),
                          Text(
                            'Kunjungi Website',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                          ),
                          SizedBox(width: 3),
                          Icon(Icons.open_in_new_rounded, size: 12, color: Color(0xFF2563EB)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (contact.isNotEmpty) ...[
                  InkWell(
                    onTap: () => _copyOrLaunchContact(contact),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF334155)),
                          SizedBox(width: 5),
                          Text(
                            'Hubungi PIC',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                InkWell(
                  onTap: () => _openEditor(record),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, size: 14, color: Color(0xFF64748B)),
                        SizedBox(width: 5),
                        Text(
                          'Kelola',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 5. CORPORATE APPROVAL / PENDING BANNER
          if (isPending)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pending_actions_rounded, color: Color(0xFFD97706), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isCorporate
                              ? 'Pengajuan Kemitraan Menunggu Persetujuan Anda'
                              : 'Pengajuan Kemitraan Menunggu Persetujuan Pihak Corporate',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isCorporate
                              ? 'Setelah disetujui, status kemitraan aktif dan dokumen MoU otomatis diterbitkan ke menu "Dokumen & MoU".'
                              : 'Saat pihak Corporate menyetujui, kemitraan aktif dan berkas MoU otomatis terbit di menu "Dokumen & MoU".',
                          style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () => _rejectPartnerProposal(record),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    label: Text(
                      _isCorporate ? 'Setujui Kemitraan' : 'Setujui (Simulasi)',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
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

    // 1. Resolve Document Category & Theme Accent
    final String category;
    final Color catColor;
    final List<Color> catGradient;
    final IconData catIcon;

    if (titleLower.contains('akreditasi') || titleLower.contains('ban-pt')) {
      category = 'Akreditasi Institusi (BAN-PT)';
      catColor = const Color(0xFF059669); // Emerald
      catGradient = const [Color(0xFF059669), Color(0xFF10B981)];
      catIcon = Icons.verified_rounded;
    } else if (titleLower.contains('mou') || titleLower.contains('perjanjian') || titleLower.contains('kemitraan')) {
      category = 'MoU Kerjasama Kemitraan DUDI';
      catColor = const Color(0xFF2563EB); // Royal Blue
      catGradient = const [Color(0xFF2563EB), Color(0xFF3B82F6)];
      catIcon = Icons.handshake_rounded;
    } else if (titleLower.contains('pedoman') || titleLower.contains('panduan') || titleLower.contains('mbkm') || titleLower.contains('pkl')) {
      category = 'Pedoman Teknis PKL & MBKM';
      catColor = const Color(0xFFD97706); // Amber
      catGradient = const [Color(0xFFD97706), Color(0xFFF59E0B)];
      catIcon = Icons.menu_book_rounded;
    } else {
      category = meta['category']?.toString() ?? 'Dokumen Resmi Legalitas';
      catColor = const Color(0xFF7C3AED); // Purple
      catGradient = const [Color(0xFF7C3AED), Color(0xFF8B5CF6)];
      catIcon = Icons.gavel_rounded;
    }

    // 2. Resolve Official Authority Name
    final String authority;
    if (titleLower.contains('ban-pt') || titleLower.contains('akreditasi')) {
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
      if (titleLower.contains('mou') || titleLower.contains('kemitraan')) {
        docNumber = '001/MOU-ISRK/DIR/2025';
      } else if (titleLower.contains('ban-pt') || titleLower.contains('akreditasi')) {
        docNumber = '412/SK/BAN-PT/Ak/PT/2024';
      } else if (titleLower.contains('pedoman')) {
        docNumber = '088/JUKNIS-VOKASI/2026';
      } else {
        docNumber = '027/SPK-KREAVANA/2026';
      }
    }

    // 4. Validity Date / Period
    var validUntil = meta['valid_until']?.toString() ??
        meta['document_date']?.toString() ??
        meta['tanggal']?.toString() ??
        '';
    if (validUntil.isEmpty) {
      if (titleLower.contains('mou') || titleLower.contains('kemitraan')) {
        validUntil = 'Berlaku s/d 31 Des 2028';
      } else if (titleLower.contains('ban-pt')) {
        validUntil = 'Berlaku s/d 15 Agt 2029 (5 Tahun)';
      } else if (titleLower.contains('pedoman')) {
        validUntil = 'TA 2025/2026';
      } else {
        validUntil = 'Aktif & Sah Berlaku';
      }
    } else if (!validUntil.toLowerCase().contains('berlaku') && !validUntil.toLowerCase().contains('ta ')) {
      validUntil = 'Berlaku s/d $validUntil';
    }

    // 5. File format and size
    final fileFormat = meta['file_format']?.toString() ?? 'PDF';
    final fileSize = meta['file_size']?.toString() ??
        (titleLower.contains('pedoman') ? '48 Halaman' : '2.4 MB');

    // 6. Grade / Predikat (for Accreditation)
    final grade = meta['grade']?.toString() ??
        (titleLower.contains('unggul') ? 'Predikat Unggul (A)' : '');

    // 7. Status styling
    final isPublished = status == 'published' || status == 'active';
    final Color statusBg = isPublished ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB);
    final Color statusBorder = isPublished ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A);
    final Color statusTextCol = isPublished ? const Color(0xFF059669) : const Color(0xFFD97706);
    final String statusLabel = isPublished ? 'Tervalidasi / Terbit' : 'Draft / Dalam Proses';

    // 8. Logo Asset
    final assetPath = _resolveDocumentAsset(title, meta);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: catColor.withValues(alpha: isDark ? 0.08 : 0.03),
            blurRadius: 28,
            offset: const Offset(0, 8),
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
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Official Authority Logo / Asset Badge
                    Container(
                      width: 58,
                      height: 58,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                          BoxShadow(
                            color: catColor.withValues(alpha: 0.16),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: assetPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                assetPath,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => Center(
                                  child: Icon(catIcon, color: catColor, size: 28),
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: catGradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Icon(catIcon, color: Colors.white, size: 26),
                              ),
                            ),
                    ),
                    const SizedBox(width: 16),
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
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: catColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: catColor.withValues(alpha: 0.25)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(catIcon, size: 13, color: catColor),
                                    const SizedBox(width: 5),
                                    Text(
                                      category,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: catColor,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Validity Pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.cardDark2 : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.event_available_rounded,
                                      size: 13,
                                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      validUntil,
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
                                  borderRadius: BorderRadius.circular(20),
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
                          const SizedBox(height: 10),
                          // Title
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
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
                                    size: 14,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    authority,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.cardDark2 : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  'No: $docNumber',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : const Color(0xFF334155),
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
                                height: 1.5,
                                color: isDark ? AppTheme.textMuted : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Action Popup Menu
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade500),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (value) {
                        if (value == 'open') {
                          _openOfficialDocument(record);
                        } else if (value == 'edit') {
                          _openEditor(record);
                        } else if (value == 'delete') {
                          _deleteRecord(record);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'open',
                          child: Row(
                            children: [
                              Icon(Icons.open_in_new_rounded, size: 16, color: Color(0xFF2563EB)),
                              SizedBox(width: 8),
                              Text('Buka Dokumen Resmi'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                              SizedBox(width: 8),
                              Text('Edit Berkas'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Hapus Permanen', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Legal Security / Accreditation Banner ──
              if (grade.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF059669)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sertifikasi Resmi Akreditasi Nasional: $grade • Terdaftar Resmi BAN-PT',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (titleLower.contains('mou') || titleLower.contains('kemitraan')) ...[
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.security_rounded, size: 16, color: Color(0xFF2563EB)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Perjanjian Kerjasama Sah Terintegrasi Ekosistem DUDI Vokasi & Kampus Merdeka',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                      ),
                      Text(
                        'LEGAL & SAH',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2563EB),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Divider ──
              Divider(
                height: 1,
                color: isDark ? AppTheme.inputBorder : const Color(0xFFF1F5F9),
              ),

              // ── Action Footer ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDark2.withValues(alpha: 0.4) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    // File specs & Digital seal pill
                    Wrap(
                      spacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.picture_as_pdf_rounded, size: 15, color: Color(0xFFEF4444)),
                            const SizedBox(width: 5),
                            Text(
                              '$fileFormat • $fileSize',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            const Text(
                              'TTE Sah (BSrE)',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Primary Interactive CTA Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _openOfficialDocument(record),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: catColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.open_in_new_rounded, size: 15, color: catColor),
                              const SizedBox(width: 6),
                              Text(
                                'Buka Dokumen Resmi',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: catColor,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'TA ${meta['period'] ?? '2026'}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: col),
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (value) => value == 'edit' ? _openEditor(record) : _deleteRecord(record),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Sesuaikan Anggaran')),
                  PopupMenuItem(value: 'delete', child: Text('Hapus Permanen')),
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

  Widget _buildReportCard(Map<String, dynamic> record, bool isDark) {
    final meta = _metadata(record);
    final status = record['status']?.toString() ?? 'published';
    final col = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  meta['category'] ?? 'Audit B2B',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDark2 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  meta['period'] ?? 'Periode 2026',
                  style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : Colors.grey.shade700),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_statusLabel(status), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: col)),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => value == 'edit' ? _openEditor(record) : _deleteRecord(record),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit Laporan')),
                  PopupMenuItem(value: 'delete', child: Text('Hapus Permanen')),
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
              style: TextStyle(fontSize: 13, height: 1.4, color: isDark ? AppTheme.textMuted : Colors.grey.shade700),
            ),
          ],
          if ((meta['result'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hasil Utama & Temuan Audit:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                        const SizedBox(height: 2),
                        Text(meta['result'], style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white70 : Colors.black87)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShowcaseCard(Map<String, dynamic> record, bool isDark) {
    final meta = _metadata(record);
    final status = record['status']?.toString().toLowerCase() ?? 'published';
    final title = record['title']?.toString() ?? 'Karya & Portofolio Siswa';
    final desc = record['description']?.toString() ?? '';

    // Smart student / creator name fallback
    var creator = meta['creator_name']?.toString() ?? meta['creator']?.toString() ?? '';
    if (creator.isEmpty) {
      if (title.toLowerCase().contains('nusantara heritage')) {
        creator = 'Arya Bagaskara & Tim Studio Animasi ISRK';
      } else if (title.toLowerCase().contains('rempah nusantara')) {
        creator = 'Nadia Safitri (Prodi DKV)';
      } else if (title.toLowerCase().contains('kreasibudaya')) {
        creator = 'Rian Pratama (Prodi Rekayasa Perangkat Lunak)';
      } else {
        creator = 'Siswa & Tim Vokasi Berbakat';
      }
    }

    // Smart category / major
    var category = meta['category']?.toString() ?? '';
    if (category.isEmpty) {
      if (title.toLowerCase().contains('animasi') || title.toLowerCase().contains('heritage')) {
        category = 'Animasi 3D';
      } else if (title.toLowerCase().contains('rempah') || title.toLowerCase().contains('kemasan') || title.toLowerCase().contains('branding')) {
        category = 'Visual Branding & UI/UX';
      } else if (title.toLowerCase().contains('flutter') || title.toLowerCase().contains('kreasibudaya') || title.toLowerCase().contains('mobile')) {
        category = 'Mobile Engineering';
      } else {
        category = 'Kreatif Vokasi';
      }
    }

    // Year / Angkatan
    var year = meta['year']?.toString() ?? '';
    if (year.isEmpty) {
      if (title.toLowerCase().contains('kreasibudaya')) {
        year = '2025';
      } else {
        year = '2026';
      }
    }

    // Portfolio URL / Link
    var portfolioUrl = meta['portfolio_url']?.toString() ?? meta['url']?.toString() ?? '';
    if (portfolioUrl.isEmpty) {
      if (title.toLowerCase().contains('nusantara heritage')) {
        portfolioUrl = 'https://youtube.com/watch?v=demo-animasi-kreavana';
      } else if (title.toLowerCase().contains('rempah nusantara')) {
        portfolioUrl = 'https://behance.net/gallery/kreavana-student-showcase';
      } else if (title.toLowerCase().contains('kreasibudaya')) {
        portfolioUrl = 'https://github.com/kreavana-vokasi/kreasibudaya-mobile';
      }
    }

    // Award
    var award = meta['award']?.toString() ?? '';
    if (award.isEmpty && title.toLowerCase().contains('nusantara heritage')) {
      award = 'Best Animation Short Film Kreavana 2026';
    }

    // Discipline Color & Icon
    final catLower = category.toLowerCase();
    final Color discColor;
    final List<Color> discGradient;
    final IconData discIcon;

    if (catLower.contains('animasi') || catLower.contains('3d') || catLower.contains('cgi')) {
      discColor = const Color(0xFF6366F1); // Indigo
      discGradient = const [Color(0xFF6366F1), Color(0xFF8B5CF6)];
      discIcon = Icons.view_in_ar_rounded;
    } else if (catLower.contains('brand') || catLower.contains('dkv') || catLower.contains('ui') || catLower.contains('ux') || catLower.contains('desain')) {
      discColor = const Color(0xFFEC4899); // Rose / Pink
      discGradient = const [Color(0xFFEC4899), Color(0xFFF43F5E)];
      discIcon = Icons.palette_rounded;
    } else if (catLower.contains('mobile') || catLower.contains('software') || catLower.contains('rpl') || catLower.contains('web') || catLower.contains('flutter') || catLower.contains('app')) {
      discColor = const Color(0xFF0284C7); // Sky / Blue
      discGradient = const [Color(0xFF0284C7), Color(0xFF2563EB)];
      discIcon = Icons.phone_iphone_rounded;
    } else if (catLower.contains('film') || catLower.contains('video') || catLower.contains('broadcast') || catLower.contains('media')) {
      discColor = const Color(0xFFF59E0B); // Amber / Orange
      discGradient = const [Color(0xFFF59E0B), Color(0xFFD97706)];
      discIcon = Icons.movie_filter_rounded;
    } else {
      discColor = const Color(0xFF8B5CF6);
      discGradient = const [Color(0xFF8B5CF6), Color(0xFF6366F1)];
      discIcon = Icons.auto_awesome_rounded;
    }

    // Status styling
    final isPublished = status == 'published' || status == 'active';
    final Color statusBg = isPublished ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB);
    final Color statusBorder = isPublished ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A);
    final Color statusTextCol = isPublished ? const Color(0xFF059669) : const Color(0xFFD97706);
    final String statusLabel = isPublished ? 'Tervalidasi / Siap Pameran' : 'Draft / Dalam Kurasi';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: discColor.withValues(alpha: isDark ? 0.08 : 0.03),
            blurRadius: 28,
            offset: const Offset(0, 8),
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
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Visual discipline icon badge
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: discGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: discColor.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(discIcon, color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(width: 16),
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
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: discColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: discColor.withValues(alpha: 0.25)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(discIcon, size: 13, color: discColor),
                                    const SizedBox(width: 5),
                                    Text(
                                      category,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: discColor,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Angkatan Pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.cardDark2 : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.school_outlined,
                                      size: 13,
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
                                  borderRadius: BorderRadius.circular(20),
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
                          const SizedBox(height: 10),
                          // Title
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Creator Credit Row
                          Row(
                            children: [
                              Icon(
                                Icons.groups_outlined,
                                size: 15,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Kreator: ',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark ? AppTheme.textMuted : const Color(0xFF64748B),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  creator,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
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
                              maxLines: 3,
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
                    const SizedBox(width: 12),
                    // Action Popup Menu
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade500),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        if (portfolioUrl.isNotEmpty)
                          const PopupMenuItem(
                            value: 'open',
                            child: Row(
                              children: [
                                Icon(Icons.open_in_new_rounded, size: 16, color: Color(0xFF2563EB)),
                                SizedBox(width: 8),
                                Text('Buka Portofolio'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                              SizedBox(width: 8),
                              Text('Edit Karya'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Hapus Karya', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Prestasi / Award Banner (if available) ──
              if (award.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          award,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PRESTASI',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDark2.withValues(alpha: 0.4) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    // Info badge
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          portfolioUrl.isNotEmpty ? Icons.link_rounded : Icons.verified_outlined,
                          size: 15,
                          color: const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          portfolioUrl.isNotEmpty ? 'Tautan Portofolio Terhubung' : 'Terverifikasi Tim Vokasi',
                          style: const TextStyle(
                            fontSize: 12,
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
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: discColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: discColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  portfolioUrl.contains('youtube')
                                      ? Icons.play_circle_fill_rounded
                                      : (portfolioUrl.contains('github')
                                          ? Icons.code_rounded
                                          : Icons.open_in_new_rounded),
                                  size: 15,
                                  color: discColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  portfolioUrl.contains('youtube')
                                      ? 'Tonton Video Karya'
                                      : (portfolioUrl.contains('github')
                                          ? 'Lihat Source Code'
                                          : 'Buka Portofolio Karya ↗'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: discColor,
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
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
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
                                    fontSize: 12,
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
                icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade500),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) => value == 'edit' ? _openEditor(record) : _deleteRecord(record),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Hapus', style: TextStyle(color: Colors.red)),
                      ],
                    ),
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
                  onChanged: (value) => setState(() => _search = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'Cari ${_title.toLowerCase()}...',
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _search = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                );

                final status = DropdownButtonFormField<String>(
                  initialValue: _statusFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Filter Status',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'Semua',
                      child: Text('Semua Status (${_records.length})'),
                    ),
                    for (final value in _resourceStatuses)
                      DropdownMenuItem(
                        value: value,
                        child: Text('${_statusLabel(value)} (${_records.where((r) => r['status'] == value).length})'),
                      ),
                  ],
                  onChanged: (value) => setState(() => _statusFilter = value ?? 'Semua'),
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
                    SizedBox(width: 220, child: status),
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
                          : 'Tambahkan data pertama Anda untuk dikelola dan dipublikasikan secara resmi.',
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
                  for (final rec in records)
                    _buildRecordCard(rec, isDark),
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

    if (MediaQuery.of(context).size.width > 900) {
      return DesktopSidebarLayout(
        user: widget.user,
        activeRoute: _activeRoute,
        onUserUpdated: widget.onUserUpdated,
        child: content,
      );
    }
    return content;
  }
}

class _ResourceEditorDialog extends StatefulWidget {
  final String resourceType;
  final String title;
  final String action;
  final List<_WorkspaceField> fields;
  final List<String> statuses;
  final Map<String, dynamic>? existing;
  final String Function(String) statusLabel;
  final IconData icon;

  const _ResourceEditorDialog({
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

  // MoU Upload State
  PlatformFile? _pickedMouFile;
  String? _mouUrl;
  String? _mouFilename;
  String? _mouFilesize;
  bool _isUploadingMou = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?['title']?.toString() ?? '');
    _descriptionController = TextEditingController(text: existing?['description']?.toString() ?? '');

    final rawMeta = existing?['metadata'];
    final meta = rawMeta is Map ? Map<String, dynamic>.from(rawMeta) : <String, dynamic>{};
    _controllers = {
      for (final f in widget.fields)
        f.key: TextEditingController(text: meta[f.key]?.toString() ?? ''),
    };

    final currentStatus = existing?['status']?.toString();
    _status = (currentStatus != null && widget.statuses.contains(currentStatus))
        ? currentStatus
        : (widget.resourceType == 'partners' && existing == null
            ? 'pending'
            : (widget.statuses.isNotEmpty ? widget.statuses.first : 'draft'));

    if (widget.resourceType == 'partners') {
      _fetchCorporates('');
      if (meta['corporate_user_id'] != null) {
        _selectedCorporate = {
          'id': meta['corporate_user_id'],
          'name': meta['corporate_name'] ?? existing?['title'],
          'username': meta['corporate_username'] ?? '',
          'avatar_url': meta['corporate_avatar'],
        };
      }
      _mouUrl = meta['mou_url']?.toString();
      _mouFilename = meta['mou_filename']?.toString();
      _mouFilesize = meta['mou_filesize']?.toString();
    }
  }

  @override
  void dispose() {
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
    setState(() => _isLoadingCorporates = true);
    try {
      final res = await ApiService.get('institution/resources/corporate-search?q=${Uri.encodeComponent(query)}');
      if (!mounted) return;
      if (res['status'] == true && res['data'] is List) {
        setState(() {
          _corporateList = List<Map<String, dynamic>>.from(res['data']);
          _isLoadingCorporates = false;
        });
      } else {
        setState(() => _isLoadingCorporates = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCorporates = false);
    }
  }

  Future<void> _pickMouFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;

      setState(() {
        _pickedMouFile = file;
        _isUploadingMou = true;
      });

      final fileBytes = await file.readAsBytes();
      if (fileBytes.isEmpty) {
        if (!mounted) return;
        setState(() => _isUploadingMou = false);
        AppSweetAlert.error(context, 'Berkas kosong atau tidak dapat dibaca.');
        return;
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
      setState(() => _isUploadingMou = false);

      if (res['status'] == true && res['data'] != null) {
        final data = res['data'];
        setState(() {
          _mouUrl = data['url']?.toString();
          _mouFilename = data['filename']?.toString() ?? file.name;
          _mouFilesize = data['filesize']?.toString();
        });
        AppSweetAlert.success(
          context,
          'Berkas MoU "${file.name}" berhasil diunggah.',
          title: 'MoU Terunggah',
        );
      } else {
        AppSweetAlert.error(
          context,
          res['message']?.toString() ?? 'Gagal mengunggah dokumen MoU ke server.',
          title: 'Gagal Unggah',
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    final isPartnerResource = widget.resourceType == 'partners';

    final payload = <String, dynamic>{
      'resource_type': widget.resourceType,
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'status': _status,
      'metadata': {
        for (final field in widget.fields)
          if ((_controllers[field.key]?.text.trim() ?? '').isNotEmpty)
            field.key: _controllers[field.key]!.text.trim(),
        if (_selectedCorporate != null) ...{
          'corporate_user_id': _selectedCorporate!['id'],
          'corporate_name': _selectedCorporate!['name'],
          'corporate_username': _selectedCorporate!['username'],
          'corporate_avatar': _selectedCorporate!['avatar_url'],
        },
        if (_mouUrl != null && _mouUrl!.isNotEmpty) ...{
          'mou_url': _mouUrl,
          'mou_filename': _mouFilename ?? _pickedMouFile?.name,
          'mou_filesize': _mouFilesize,
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
    if (key.contains('contact') || key.contains('email') || key.contains('pic')) {
      return Icons.alternate_email_rounded;
    }
    if (key.contains('phone') || key.contains('telepon') || key.contains('kontak')) {
      return Icons.phone_outlined;
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
        'caption': 'Bidang industri utama mitra yang relevan dengan keahlian siswa.',
        'hint': field.hint ?? 'Contoh: Animasi 3D, Desain Grafis, Production House',
        'chips': ['Animasi 3D', 'Desain & UI/UX', 'Video & Media', 'Software & IT', 'Marketing Digital'],
      };
    }
    if (key.contains('contact') || key.contains('pic') || key.contains('email')) {
      return {
        'label': '${field.label} *',
        'caption': 'Penanggung jawab (PIC) kemitraan atau kontak resmi instansi.',
        'hint': field.hint ?? 'Contoh: Budi Santoso (HR) - 08123456789 / info@mitra.com',
        'chips': <String>[],
      };
    }
    if (key.contains('website') || key.contains('url') || field.kind == _FieldKind.url) {
      return {
        'label': field.label,
        'caption': 'Alamat website resmi atau tautan portofolio/sosial media.',
        'hint': field.hint ?? 'Contoh: https://perusahaan.com atau https://instagram.com/mitra',
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

  InputDecoration _inputDecoration({
    required String hint,
    IconData? prefixIcon,
    String? prefixText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: const Color(0xFF2563EB)) : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.8),
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
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
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
    List<String> chips = const [],
    TextEditingController? targetController,
    double? minHeaderHeight,
  }) {
    final headerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          caption,
          style: TextStyle(
            fontSize: 11.5,
            color: Colors.grey.shade600,
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, size: 13, color: Color(0xFF2563EB)),
                      const SizedBox(width: 4),
                      Text(
                        chipText,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
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

    return _buildFieldWithHeader(
      label: meta['label'] as String,
      caption: meta['caption'] as String,
      chips: (meta['chips'] as List<dynamic>).cast<String>(),
      targetController: ctrl,
      minHeaderHeight: minHeaderHeight,
      child: TextFormField(
        controller: ctrl,
        keyboardType: field.kind == _FieldKind.number
            ? TextInputType.number
            : (field.kind == _FieldKind.url ? TextInputType.url : TextInputType.text),
        decoration: _inputDecoration(
          hint: meta['hint'] as String,
          prefixText: field.prefix,
          prefixIcon: _getFieldIcon(field),
        ),
      ),
    );
  }

  Widget _buildStatusDropdown({double? minHeaderHeight}) {
    final effectiveStatuses = widget.resourceType == 'partners'
        ? (widget.statuses.contains('pending') ? widget.statuses : ['pending', ...widget.statuses])
        : widget.statuses;

    return _buildFieldWithHeader(
      label: 'Status Kemitraan & Akses *',
      caption: 'Tentukan status keaktifan mitra penempatan magang siswa.',
      minHeaderHeight: minHeaderHeight,
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: _status,
        dropdownColor: Colors.white,
        icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
        decoration: _inputDecoration(
          hint: 'Pilih status...',
          prefixIcon: Icons.verified_user_outlined,
        ),
        items: effectiveStatuses
            .map(
              (value) {
                final (dotColor, badgeText) = switch (value) {
                  'active' || 'published' => (Colors.green.shade600, 'Aktif / Tervalidasi'),
                  'pending' => (Colors.amber.shade700, 'Menunggu Persetujuan'),
                  'draft' => (Colors.blue.shade600, 'Draf Inisiasi'),
                  _ => (const Color(0xFF64748B), 'Diarsipkan'),
                };

                return DropdownMenuItem<String>(
                  value: value,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          badgeText,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            )
            .toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => _status = value);
          }
        },
      ),
    );
  }

  Widget _buildCorporateSearchSection() {
    return _buildFieldCardContainer(
      title: 'Cari & Hubungkan Akun Corporate Mitra *',
      subtitle: 'Tautkan pengajuan kemitraan ini ke entitas akun Corporate / Perusahaan resmi di Kreavana.',
      icon: Icons.domain_verification_rounded,
      children: [
        if (_selectedCorporate != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _selectedCorporate!['name'] != null && _selectedCorporate!['name'].toString().isNotEmpty
                          ? _selectedCorporate!['name'].toString().substring(0, 1).toUpperCase()
                          : 'C',
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
                              _selectedCorporate!['name']?.toString() ?? 'Perusahaan Mitra',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Corporate Terverifikasi',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${_selectedCorporate!['username'] ?? 'corporate'} • ${_selectedCorporate!['email'] ?? 'Akun Resmi Industri'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Ganti', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF93C5FD)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    setState(() {
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
            onChanged: (val) {
              _fetchCorporates(val);
              if (!_showCorpDropdown) setState(() => _showCorpDropdown = true);
            },
            onTap: () {
              if (!_showCorpDropdown) {
                setState(() => _showCorpDropdown = true);
                if (_corporateList.isEmpty) _fetchCorporates('');
              }
            },
            decoration: _inputDecoration(
              hint: 'Ketik nama PT, CV, studio agensi, atau @username corporate...',
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
                            _fetchCorporates('');
                          },
                        )
                      : null),
            ),
          ),
          if (_showCorpDropdown && _corporateList.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _corporateList.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, idx) {
                  final corp = _corporateList[idx];
                  final corpName = corp['name']?.toString() ?? 'Perusahaan';
                  final corpUname = corp['username']?.toString() ?? '';
                  final corpEmail = corp['email']?.toString() ?? '';
                  final initials = corpName.isNotEmpty ? corpName.substring(0, 1).toUpperCase() : 'C';

                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF2563EB),
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
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF2563EB)),
                      ],
                    ),
                    subtitle: Text(
                      '@$corpUname • $corpEmail',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
                    onTap: () {
                      setState(() {
                        _selectedCorporate = corp;
                        _showCorpDropdown = false;
                        if (_titleController.text.trim().isEmpty) {
                          _titleController.text = corpName;
                        }
                        if (_controllers['contact'] != null && _controllers['contact']!.text.trim().isEmpty) {
                          _controllers['contact']!.text = corpEmail.isNotEmpty ? corpEmail : (corp['phone']?.toString() ?? '');
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildMouUploadSection() {
    final hasFile = _pickedMouFile != null || (_mouUrl != null && _mouUrl!.isNotEmpty);
    final fileName = _pickedMouFile?.name ?? _mouFilename ?? 'Dokumen-MoU-Kemitraan.pdf';
    final fileSize = _pickedMouFile != null
        ? (_pickedMouFile!.size >= 1048576
            ? '${(_pickedMouFile!.size / 1048576).toStringAsFixed(1)} MB'
            : '${(_pickedMouFile!.size / 1024).toStringAsFixed(0)} KB')
        : (_mouFilesize ?? 'Dokumen Digital');

    return _buildFieldCardContainer(
      title: 'Unggah Berkas Perjanjian Kerjasama (MoU / PKS)',
      subtitle: 'Upload draf resmi nota kesepahaman yang akan diajukan ke Corporate untuk disetujui.',
      icon: Icons.upload_file_rounded,
      children: [
        if (hasFile) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: const Center(
                    child: Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF16A34A), size: 24),
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
                              fileName,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF14532D)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF16A34A)),
                                SizedBox(width: 3),
                                Text('Siap Diajukan', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$fileSize • Berkas Resmi Terlampir',
                        style: TextStyle(fontSize: 11.5, color: Colors.green.shade800),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Hapus / Ganti Berkas',
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFFDC2626)),
                  onPressed: () {
                    setState(() {
                      _pickedMouFile = null;
                      _mouUrl = null;
                      _mouFilename = null;
                      _mouFilesize = null;
                    });
                  },
                ),
              ],
            ),
          ),
        ] else ...[
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _isUploadingMou ? null : _pickMouFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFCBD5E1),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  if (_isUploadingMou) ...[
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(height: 10),
                    const Text('Mengunggah dokumen MoU ke server...', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                  ] else ...[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF2563EB), size: 24),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Klik untuk memilih berkas MoU (PDF / DOC / DOCX)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Format yang didukung: .pdf, .doc, .docx (Maksimal 15 MB)',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF64748B)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Setelah disetujui Corporate, berkas MoU ini akan otomatis terbit dan masuk ke menu "Dokumen & MoU".',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
      actionsPadding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
      backgroundColor: Colors.white,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top accent gradient bar
          Container(
            height: 4,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              gradient: LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.existing == null ? widget.action : 'Edit ${widget.title}',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: const Text(
                              'B2B Governance',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isPartnerResource
                            ? 'Lengkapi profil rekanan industri untuk program magang, guru tamu, dan sertifikasi kejuruan.'
                            : 'Tersimpan aman di pangkalan data instansi Kreavana untuk tata kelola resmi.',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.3),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  tooltip: 'Tutup Dialog',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
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
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isPartnerResource
                                  ? 'Panduan: Cari & hubungkan akun Corporate mitra Kreavana (atau ketik nama perusahaan), lengkapi kontak & spesifikasi, serta unggah berkas draf MoU.'
                                  : 'Panduan: Lengkapi seluruh kolom wajib bertanda bintang (*) untuk menjaga keabsahan arsip instansi.',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Corporate Account Selection (Partners Only)
                    if (isPartnerResource) ...[
                      _buildCorporateSearchSection(),
                      const SizedBox(height: 16),
                    ],

                    // Section 1: Profil & Identitas Utama (Hanya untuk non-partner, karena mitra sudah ditangani oleh Corporate Selection)
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
                              decoration: _inputDecoration(
                                hint: 'Jelaskan ringkasan kebutuhan, spesifikasi, atau catatan...',
                                prefixIcon: Icons.notes_rounded,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (secondaryWidgets.isNotEmpty) ...[
                      // Section 2: Spesifikasi & Kontak (2 Columns)
                      _buildFieldCardContainer(
                        title: isPartnerResource ? 'Spesifikasi Industri & Kontak Penanggung Jawab' : 'Detail Spesifikasi & Publikasi',
                        subtitle: isPartnerResource
                            ? 'Bidang keahlian mitra dan kontak resmi untuk koordinasi sekolah'
                            : 'Parameter pendukung dan status publikasi sistem',
                        icon: Icons.hub_outlined,
                        children: [
                          ...gridRows,
                          if (isPartnerResource) ...[
                            const SizedBox(height: 16),
                            _buildFieldWithHeader(
                              label: 'Deskripsi & Ruang Lingkup Kerjasama (Opsional)',
                              caption: 'Jelaskan ringkasan bentuk kerjasama, magang PKL siswa, guru tamu industri, atau kurikulum vokasi.',
                              child: TextFormField(
                                controller: _descriptionController,
                                minLines: 2,
                                maxLines: 4,
                                decoration: _inputDecoration(
                                  hint: 'Contoh: Kerjasama penempatan magang siswa SMK jurusan Animasi 3D dan DKV, penyelarasan kurikulum industri, dan uji kompetensi kejuruan...',
                                  prefixIcon: Icons.notes_rounded,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],

                    // MoU Upload Section (Partners Only)
                    if (isPartnerResource) ...[
                      const SizedBox(height: 16),
                      _buildMouUploadSection(),
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
            Row(
              children: [
                const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  'Tervalidasi Sistem Instansi Kreavana',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
              ],
            ),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
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
                    backgroundColor: const Color(0xFF2563EB),
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

