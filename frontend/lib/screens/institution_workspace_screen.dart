import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../utils/app_errors.dart';
import '../widgets/desktop_sidebar_layout.dart';

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

  static const Map<String, String> _titles = {
    'tenders': 'Tender & Kolaborasi',
    'partners': 'Mitra & Komunitas',
    'reports': 'Laporan Kegiatan',
    'budgets': 'Realisasi Anggaran',
    'monitoring': 'Monitoring & Evaluasi',
    'documents': 'Dokumen Instansi',
    'announcements': 'Pengumuman Publik',
  };

  static const Map<String, String> _actions = {
    'tenders': 'Buat Tender',
    'partners': 'Tambah Mitra',
    'reports': 'Buat Laporan',
    'budgets': 'Tambah Anggaran',
    'monitoring': 'Tambah Program',
    'documents': 'Tambah Dokumen',
    'announcements': 'Buat Pengumuman',
  };

  static const Map<String, IconData> _icons = {
    'tenders': Icons.handshake_outlined,
    'partners': Icons.groups_outlined,
    'reports': Icons.summarize_outlined,
    'budgets': Icons.account_balance_wallet_outlined,
    'monitoring': Icons.monitor_heart_outlined,
    'documents': Icons.folder_outlined,
    'announcements': Icons.campaign_outlined,
  };

  static const Map<String, List<_WorkspaceField>> _fields = {
    'tenders': [
      _WorkspaceField('category', 'Kategori', hint: 'Contoh: Pengadaan'),
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
        'Jenis Mitra',
        hint: 'Komunitas, vendor, lembaga',
      ),
      _WorkspaceField('contact', 'Kontak', hint: 'Email atau nomor telepon'),
      _WorkspaceField('website', 'Situs / Profil', kind: _FieldKind.url),
    ],
    'reports': [
      _WorkspaceField('period', 'Periode', hint: 'Contoh: Triwulan I 2026'),
      _WorkspaceField('category', 'Program / Kegiatan'),
      _WorkspaceField('result', 'Hasil Utama'),
    ],
    'budgets': [
      _WorkspaceField('period', 'Tahun Anggaran', hint: '2026'),
      _WorkspaceField(
        'allocation',
        'Pagu Anggaran',
        kind: _FieldKind.number,
        prefix: 'Rp ',
      ),
      _WorkspaceField(
        'realization',
        'Realisasi',
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
        'Jenis Dokumen',
        hint: 'Surat, laporan, peraturan',
      ),
      _WorkspaceField(
        'document_date',
        'Tanggal Dokumen',
        kind: _FieldKind.date,
      ),
      _WorkspaceField(
        'url',
        'Tautan Dokumen',
        kind: _FieldKind.url,
        hint: 'https://...',
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
  };

  static const Map<String, List<String>> _statuses = {
    'tenders': ['open', 'in_progress', 'completed', 'closed'],
    'partners': ['active', 'inactive'],
    'reports': ['draft', 'published'],
    'budgets': ['in_progress', 'completed'],
    'monitoring': ['in_progress', 'completed', 'closed'],
    'documents': ['published', 'draft'],
    'announcements': ['draft', 'published'],
  };

  String get _title => _titles[widget.resourceType] ?? 'Data Instansi';
  String get _action => _actions[widget.resourceType] ?? 'Tambah Data';
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
          : response['message']?.toString() ?? 'Data gagal dimuat.';
      _isLoading = false;
    });
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
          title: Text(
            existing == null ? _action : 'Edit ${_title.toLowerCase()}',
          ),
          content: SizedBox(
            width: 480,
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
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Judul wajib diisi'
                          : null,
                    ),
                    TextFormField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Deskripsi / Catatan',
                      ),
                    ),
                    for (final field in _resourceFields)
                      TextFormField(
                        controller: controllers[field.key],
                        keyboardType: field.kind == _FieldKind.number
                            ? TextInputType.number
                            : TextInputType.text,
                        decoration: InputDecoration(
                          labelText: field.label,
                          hintText: field.hint,
                          prefixText: field.prefix,
                        ),
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Status'),
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
            FilledButton(
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
                            if ((controllers[field.key]?.text.trim() ?? '')
                                .isNotEmpty)
                              field.key: controllers[field.key]!.text.trim(),
                        },
                      };
                      setDialogState(() => _isSaving = true);
                      final response = existing == null
                          ? await ApiService.post(
                              'institution/resources',
                              payload,
                            )
                          : await ApiService.put(
                              'institution/resources/${existing['id']}',
                              payload,
                            );
                      if (!dialogContext.mounted) return;
                      setDialogState(() => _isSaving = false);
                      if (response['status'] == true) {
                        Navigator.pop(dialogContext, true);
                      } else {
                        AppSnackbar.error(
                          dialogContext,
                          response['message']?.toString() ??
                              'Data gagal disimpan.',
                        );
                      }
                    },
              child: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
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
      await _loadRecords();
    }
  }

  Future<void> _deleteRecord(Map<String, dynamic> record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus data?'),
        content: Text('Data "${record['title']}" akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Hapus'),
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
      await _loadRecords();
    } else {
      AppSnackbar.error(
        context,
        response['message']?.toString() ?? 'Data gagal dihapus.',
      );
    }
  }

  String _statusLabel(String status) => switch (status) {
    'draft' => 'Draft',
    'published' => 'Dipublikasikan',
    'open' => 'Terbuka',
    'in_progress' => 'Berjalan',
    'completed' => 'Selesai',
    'closed' => 'Ditutup',
    _ => status,
  };

  Color _statusColor(String status) => switch (status) {
    'published' || 'open' => const Color(0xFF27845A),
    'completed' => const Color(0xFF3267A8),
    'closed' => Colors.grey,
    'in_progress' => const Color(0xFF9A6A16),
    _ => Colors.blueGrey,
  };

  String _formatValue(String key, dynamic value) {
    if (key == 'allocation' || key == 'realization' || key == 'budget') {
      final digits = value.toString().replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isEmpty) return value.toString();
      return 'Rp ${digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';
    }
    if (key == 'progress') return '$value%';
    if (key == 'url' || key == 'website') {
      return Uri.tryParse(value.toString())?.host ?? value.toString();
    }
    return value.toString();
  }

  Widget _buildRecordCard(Map<String, dynamic> record, bool isDark) {
    final metadata = _metadata(record);
    final status = record['status']?.toString() ?? 'draft';
    final color = _statusColor(status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(10),
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
              Icon(
                _icons[widget.resourceType] ?? Icons.folder_outlined,
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record['title']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((record['description']?.toString() ?? '')
                        .isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        record['description'].toString(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => value == 'edit'
                    ? _openEditor(record)
                    : _deleteRecord(record),
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
                labelStyle: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              for (final field in _resourceFields)
                if (metadata[field.key] != null &&
                    metadata[field.key].toString().isNotEmpty)
                  Chip(
                    label: Text(
                      '${field.label}: ${_formatValue(field.key, metadata[field.key])}',
                    ),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                    backgroundColor: isDark
                        ? AppTheme.cardDark2
                        : Colors.grey.shade100,
                    labelStyle: const TextStyle(fontSize: 11),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    final records = _filteredRecords;
    final isBudget = widget.resourceType == 'budgets';
    final allocated = _records.fold<double>(0, (sum, record) {
      final amount =
          double.tryParse(_metadata(record)['allocation']?.toString() ?? '') ??
          0;
      return sum + amount;
    });
    final realized = _records.fold<double>(0, (sum, record) {
      final amount =
          double.tryParse(_metadata(record)['realization']?.toString() ?? '') ??
          0;
      return sum + amount;
    });

    return Column(
      children: [
        if (isBudget)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _summary(
                    'Pagu',
                    _formatValue('allocation', allocated),
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summary(
                    'Realisasi',
                    _formatValue('realization', realized),
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summary(
                    'Serapan',
                    allocated <= 0
                        ? '0%'
                        : '${(realized / allocated * 100).clamp(0, 100).toStringAsFixed(1)}%',
                    isDark,
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final search = TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _search = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Cari data...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              );
              final status = DropdownButtonFormField<String>(
                initialValue: _statusFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'Semua',
                    child: Text('Semua status'),
                  ),
                  for (final value in _resourceStatuses)
                    DropdownMenuItem(
                      value: value,
                      child: Text(_statusLabel(value)),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _statusFilter = value ?? 'Semua'),
              );
              final refresh = IconButton(
                tooltip: 'Muat ulang',
                onPressed: _loadRecords,
                icon: const Icon(Icons.refresh),
              );

              if (constraints.maxWidth < 560) {
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
                  const SizedBox(width: 10),
                  SizedBox(width: 190, child: status),
                  refresh,
                ],
              );
            },
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 40),
                        const SizedBox(height: 8),
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _loadRecords,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _icons[widget.resourceType],
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Belum ada data ${_title.toLowerCase()}.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _openEditor,
                        icon: const Icon(Icons.add),
                        label: Text(_action),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRecords,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                    itemCount: records.length,
                    itemBuilder: (context, index) =>
                        _buildRecordCard(records[index], isDark),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _summary(String title, String value, bool isDark) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isDark ? AppTheme.cardBg : Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

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
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(isDark),
    );

    if (MediaQuery.of(context).size.width > 900) {
      return DesktopSidebarLayout(
        user: widget.user,
        activeRoute: widget.resourceType,
        child: content,
      );
    }
    return content;
  }
}
