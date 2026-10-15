import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../widgets/desktop_sidebar_layout.dart';
import '../widgets/app_sweet_alert.dart';

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
  bool _isSaving = false;
  String? _loadError;
  String _search = '';
  String _statusFilter = 'Semua';

  bool get _isCorporate {
    final sub = widget.user.subRole?.toLowerCase() ?? '';
    return ['corporate', 'company', 'business', 'perusahaan', 'bisnis'].contains(sub);
  }

  static const Map<String, String> _titles = {
    'tenders': 'Tender & Kolaborasi',
    'partners': 'Mitra & Komunitas',
    'reports': 'Laporan Kegiatan',
    'budgets': 'Realisasi Anggaran',
    'monitoring': 'Monitoring & Evaluasi',
    'documents': 'Dokumen Instansi',
    'announcements': 'Pengumuman Publik',
    'showcases': 'Karya & Portofolio Siswa',
  };

  static const Map<String, String> _actions = {
    'tenders': 'Buat Tender',
    'partners': 'Tambah Mitra',
    'reports': 'Buat Laporan',
    'budgets': 'Tambah Anggaran',
    'monitoring': 'Tambah Program',
    'documents': 'Tambah Dokumen',
    'announcements': 'Buat Pengumuman',
    'showcases': 'Tambah Karya Siswa',
  };

  static const Map<String, IconData> _icons = {
    'tenders': Icons.handshake_outlined,
    'partners': Icons.groups_outlined,
    'reports': Icons.summarize_outlined,
    'budgets': Icons.account_balance_wallet_outlined,
    'monitoring': Icons.monitor_heart_outlined,
    'documents': Icons.folder_outlined,
    'announcements': Icons.campaign_outlined,
    'showcases': Icons.palette_outlined,
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
    'reports': [
      _WorkspaceField('period', 'Periode Audit / Laporan', hint: 'Contoh: Triwulan I 2026 / TA 2026'),
      _WorkspaceField('category', 'Kategori Audit', hint: 'Audit Mutu Vendor, Kepatuhan Pajak, Efisiensi Anggaran'),
      _WorkspaceField('result', 'Hasil Utama & Temuan Audit', hint: 'Ringkasan evaluasi, temuan kepatuhan, dan persentase capaian'),
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
    'partners': ['active', 'inactive'],
    'reports': ['published', 'draft'],
    'budgets': ['in_progress', 'completed'],
    'monitoring': ['in_progress', 'completed', 'closed'],
    'documents': ['published', 'draft'],
    'announcements': ['draft', 'published'],
    'showcases': ['published', 'draft'],
  };

  String get _title {
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
    if (_isCorporate) {
      switch (widget.resourceType) {
        case 'tenders':
          return 'Buat Tender RFP';
        case 'partners':
          return 'Tambah Mitra Vendor';
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
      _records = succeeded
          ? List<Map<String, dynamic>>.from(response['data'])
          : [];
      _loadError = succeeded
          ? null
          : response['message']?.toString() ?? 'Data gagal dimuat dari backend.';
      _isLoading = false;
    });
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
        return const Color(0xFF10B981); // Emerald Green
      case 'in_progress':
        return const Color(0xFF2563EB); // Royal Blue
      case 'completed':
        return const Color(0xFF8B5CF6); // Purple
      case 'closed':
      case 'inactive':
        return Colors.grey.shade600;
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
      case 'inactive':
        return 'Nonaktif';
      default:
        return status;
    }
  }

  Future<void> _openEditor([Map<String, dynamic>? existing]) async {
    final metadata = existing == null
        ? <String, dynamic>{}
        : _metadata(existing);
    final titleController = TextEditingController(
      text: existing?['title']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: existing?['description']?.toString() ?? '',
    );
    final controllers = {
      for (final field in _resourceFields)
        field.key: TextEditingController(
          text: metadata[field.key]?.toString() ?? '',
        ),
    };
    var status = existing?['status']?.toString() ?? _resourceStatuses.first;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icons[widget.resourceType] ?? Icons.business, color: const Color(0xFF1E3A8A), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      existing == null ? _action : 'Edit $_title',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Tersimpan langsung ke database backend Kreavana',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      autofocus: true,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Nama / Judul',
                        hintText: 'Masukkan nama entitas / judul kegiatan',
                        prefixIcon: Icon(Icons.title_rounded, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Judul wajib diisi'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Deskripsi / Ruang Lingkup',
                        hintText: 'Jelaskan ringkasan kebutuhan, spesifikasi, atau catatan...',
                        prefixIcon: Icon(Icons.notes_rounded, size: 20),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final field in _resourceFields) ...[
                      TextFormField(
                        controller: controllers[field.key],
                        keyboardType: field.kind == _FieldKind.number
                            ? TextInputType.number
                            : (field.kind == _FieldKind.url ? TextInputType.url : TextInputType.text),
                        decoration: InputDecoration(
                          labelText: field.label,
                          hintText: field.hint,
                          prefixText: field.prefix,
                          prefixIcon: Icon(
                            field.kind == _FieldKind.number
                                ? Icons.payments_outlined
                                : (field.kind == _FieldKind.date
                                    ? Icons.calendar_today_outlined
                                    : (field.kind == _FieldKind.url ? Icons.link_rounded : Icons.label_outline)),
                            size: 20,
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'Status Verifikasi / Publikasi',
                        prefixIcon: Icon(Icons.flag_outlined, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      items: _resourceStatuses
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_statusLabel(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setDialogState(
                        () => status = value ?? _resourceStatuses.first,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton.icon(
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final payload = <String, dynamic>{
                        'resource_type': widget.resourceType,
                        'title': titleController.text.trim(),
                        'description': descriptionController.text.trim(),
                        'status': status,
                        'metadata': {
                          for (final field in _resourceFields)
                            if ((controllers[field.key]?.text.trim() ?? '').isNotEmpty)
                              field.key: controllers[field.key]!.text.trim(),
                        },
                      };
                      try {
                        setDialogState(() => _isSaving = true);
                        final response = existing == null
                            ? await ApiService.post('institution/resources', payload)
                            : await ApiService.put('institution/resources/${existing['id']}', payload);
                        if (!dialogContext.mounted || !mounted) return;
                        setDialogState(() => _isSaving = false);
                        if (response['status'] == true) {
                          Navigator.pop(dialogContext, true);
                        } else {
                          AppSweetAlert.error(
                            context,
                            response['message']?.toString() ?? 'Data gagal disimpan ke backend.',
                            title: 'Gagal Menyimpan',
                          );
                        }
                      } catch (e) {
                        if (!dialogContext.mounted || !mounted) return;
                        setDialogState(() => _isSaving = false);
                        AppSweetAlert.error(
                          context,
                          'Terjadi kendala saat menyimpan data: $e',
                          title: 'Gagal Menyimpan',
                        );
                      }
                    },
              label: Text(_isSaving ? 'Menyimpan...' : 'Simpan ke Backend'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
    for (final controller in controllers.values) {
      controller.dispose();
    }
    if (saved == true && mounted) {
      AppSweetAlert.success(
        context,
        'Data $_title berhasil disimpan ke database backend.',
        title: 'Berhasil Disimpan',
      );
      await _loadRecords();
    }
  }

  Future<void> _deleteRecord(Map<String, dynamic> record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Data Permanen?'),
        content: Text('Data "${record['title']}" akan dihapus langsung dari database backend.'),
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
        'Data "${record['title']}" berhasil dihapus dari backend.',
        title: 'Berhasil Dihapus',
      );
      await _loadRecords();
    } else {
      AppSweetAlert.error(
        context,
        response['message']?.toString() ?? 'Data gagal dihapus dari backend.',
        title: 'Gagal Menghapus',
      );
    }
  }

  Future<void> _launchUrl(String? urlStr) async {
    if (urlStr == null || urlStr.trim().isEmpty) return;
    try {
      final uri = Uri.parse(urlStr.trim());
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          AppSweetAlert.info(
            context,
            'Tautan: $urlStr',
            title: 'Tautan Dokumen',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        AppSweetAlert.info(
          context,
          'Tautan: $urlStr',
          title: 'Tautan Dokumen',
        );
      }
    }
  }

  // ── HEADER HERO EXECUTIVE ──────────────────────────────────────────────────
  Widget _buildExecutiveHero(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFF1E3A8A), const Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
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
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified_user_rounded, color: Colors.amberAccent, size: 14),
                                  SizedBox(width: 6),
                                  Text(
                                    'Enterprise B2B Governance',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_records.length} Berkas Aktif di Backend',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(width: 20),
                    ElevatedButton.icon(
                      onPressed: _openEditor,
                      icon: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF1E3A8A)),
                      label: Text(
                        _action,
                        style: const TextStyle(
                          color: Color(0xFF1E3A8A),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                    ),
                  ],
                ],
              ),
              if (isCompact) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openEditor,
                    icon: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF1E3A8A)),
                    label: Text(
                      _action,
                      style: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
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

  Widget _buildPartnerCard(Map<String, dynamic> record, bool isDark) {
    final meta = _metadata(record);
    final status = record['status']?.toString() ?? 'active';
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.business_center_rounded, color: Color(0xFF1E3A8A), size: 24),
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
                            record['title']?.toString() ?? '',
                            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded, color: Color(0xFF2563EB), size: 16),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta['category'] ?? 'Mitra B2B Terverifikasi',
                      style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: col),
                    const SizedBox(width: 5),
                    Text(_statusLabel(status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: col)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => value == 'edit' ? _openEditor(record) : _deleteRecord(record),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit Data Mitra')),
                  PopupMenuItem(value: 'delete', child: Text('Hapus Permanen')),
                ],
              ),
            ],
          ),
          if ((record['description']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              record['description'].toString(),
              style: TextStyle(fontSize: 13, height: 1.4, color: isDark ? AppTheme.textMuted : Colors.grey.shade700),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if ((meta['contact'] ?? '').isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDark2 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.email_outlined, size: 14, color: Colors.blueAccent),
                      const SizedBox(width: 6),
                      Text(meta['contact'], style: const TextStyle(fontSize: 11.5)),
                    ],
                  ),
                ),
              if ((meta['website'] ?? '').isNotEmpty)
                InkWell(
                  onTap: () => _launchUrl(meta['website']),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Text(meta['website'], style: const TextStyle(fontSize: 11.5, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 15, color: Colors.amber),
                    SizedBox(width: 4),
                    Text('4.9 Rekomendasi Unggulan', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.amber)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> record, bool isDark) {
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.verified_user_outlined, color: Color(0xFF10B981), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            meta['category'] ?? 'Dokumen Resmi',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          meta['document_date'] ?? '',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      record['title']?.toString() ?? '',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => value == 'edit' ? _openEditor(record) : _deleteRecord(record),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit Berkas')),
                  PopupMenuItem(value: 'delete', child: Text('Hapus Permanen')),
                ],
              ),
            ],
          ),
          if ((record['description']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              record['description'].toString(),
              style: TextStyle(fontSize: 13, height: 1.4, color: isDark ? AppTheme.textMuted : Colors.grey.shade700),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: col),
                    const SizedBox(width: 5),
                    Text(_statusLabel(status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: col)),
                  ],
                ),
              ),
              if ((meta['url'] ?? '').isNotEmpty)
                TextButton.icon(
                  onPressed: () => _launchUrl(meta['url']),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Buka Dokumen Resmi'),
                ),
            ],
          ),
        ],
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

  Widget _buildRecordCard(Map<String, dynamic> record, bool isDark) {
    if (_isCorporate) {
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
      }
    }

    // Default card for non-corporate or other types
    final metadata = _metadata(record);
    final status = record['status']?.toString() ?? 'draft';
    final color = _statusColor(status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icons[widget.resourceType] ?? Icons.folder_outlined, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record['title']?.toString() ?? '',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    if ((record['description']?.toString() ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(record['description'].toString(), maxLines: 3, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => value == 'edit' ? _openEditor(record) : _deleteRecord(record),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Hapus')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Chip(
                label: Text(_statusLabel(status)),
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
                backgroundColor: color.withValues(alpha: 0.1),
                labelStyle: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              for (final field in _resourceFields)
                if (metadata[field.key] != null && metadata[field.key].toString().isNotEmpty)
                  Chip(
                    label: Text('${field.label}: ${metadata[field.key]}'),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                    backgroundColor: isDark ? AppTheme.cardDark2 : Colors.grey.shade100,
                    labelStyle: const TextStyle(fontSize: 11),
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
                  tooltip: 'Muat Ulang dari Backend',
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
                          : 'Belum Ada Data $_title di Backend',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _search.isNotEmpty || _statusFilter != 'Semua'
                          ? 'Coba sesuaikan kata kunci pencarian atau ubah filter status.'
                          : 'Tambahkan data pertama Anda untuk disimpan langsung ke database backend.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Scaffold(
      appBar: AppBar(
        title: Text(
          _title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        automaticallyImplyLeading: MediaQuery.of(context).size.width <= 900,
        actions: [
          IconButton(
            tooltip: _action,
            onPressed: _openEditor,
            icon: const Icon(Icons.add_circle_outline),
          ),
          const SizedBox(width: 8),
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
