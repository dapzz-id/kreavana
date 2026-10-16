import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../widgets/desktop_sidebar_layout.dart';
import '../widgets/official_document_viewer_dialog.dart';
import 'institution_workspace_screen.dart';

class DokumenInstansiScreen extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const DokumenInstansiScreen({super.key, this.user, this.onUserUpdated});

  @override
  State<DokumenInstansiScreen> createState() => _DokumenInstansiScreenState();
}

class _DokumenInstansiScreenState extends State<DokumenInstansiScreen> {
  bool _isLoading = true;
  String _searchQuery = '';
  List<Map<String, dynamic>> _documents = [];

  bool get _isGovernment {
    final sub = widget.user?.subRole?.toLowerCase() ?? '';
    return [
      'government',
      'pemerintah',
      'instansi',
      'dinas',
      'bumn',
      'kementerian',
    ].contains(sub);
  }

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  Future<void> _fetchDocuments() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get(
        'institution/resources',
        queryParams: {'type': 'documents'},
      ).catchError((_) => <String, dynamic>{});

      final dList = res['data'] as List<dynamic>? ?? [];
      final mapped = <Map<String, dynamic>>[];

      for (final item in dList) {
        if (item is Map<String, dynamic>) {
          final meta = item['metadata'] is Map<String, dynamic>
              ? item['metadata'] as Map<String, dynamic>
              : <String, dynamic>{};

          final cat = (meta['category'] ?? 'Surat Keputusan (SK)').toString();
          Color color = const Color(0xFF1D4ED8);
          IconData icon = Icons.description_outlined;

          final catLower = cat.toLowerCase();
          if (catLower.contains('mou') || catLower.contains('kesepahaman')) {
            color = const Color(0xFF0F766E);
            icon = Icons.handshake_outlined;
          } else if (catLower.contains('sk') || catLower.contains('keputusan')) {
            color = const Color(0xFF1D4ED8);
            icon = Icons.gavel_rounded;
          } else if (catLower.contains('bast') || catLower.contains('serah terima')) {
            color = const Color(0xFF10B981);
            icon = Icons.task_alt_rounded;
          } else if (catLower.contains('perda') || catLower.contains('peraturan')) {
            color = const Color(0xFFD97706);
            icon = Icons.policy_outlined;
          } else if (catLower.contains('sop') || catLower.contains('standar')) {
            color = const Color(0xFF7C3AED);
            icon = Icons.rule_folder_outlined;
          }

          mapped.add({
            'id': item['id'],
            'title': item['title'] ?? 'Dokumen Resmi',
            'description': item['description'] ?? '',
            'status': item['status'] ?? 'published',
            'category': cat,
            'color': color,
            'icon': icon,
            'metadata': meta,
            'document_date': meta['document_date'] ?? '2026',
            'author': meta['author'] ?? 'Pejabat Berwenang',
          });
        }
      }

      if (mounted) {
        setState(() {
          _documents = mapped;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredDocuments {
    if (_searchQuery.trim().isEmpty) return _documents;
    final q = _searchQuery.toLowerCase();
    return _documents.where((d) {
      final t = (d['title'] ?? '').toString().toLowerCase();
      final desc = (d['description'] ?? '').toString().toLowerCase();
      final cat = (d['category'] ?? '').toString().toLowerCase();
      return t.contains(q) || desc.contains(q) || cat.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    final content = Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        automaticallyImplyLeading: !isDesktop,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isGovernment ? 'Dokumen & Berkas Resmi Kedinasan' : 'Dokumen Resmi Instansi',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Arsip Surat Keputusan (SK), MoU Kemitraan, SPK, dan BAST tersertifikasi BSrE',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.user != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InstitutionWorkspaceScreen(
                        user: widget.user!,
                        resourceType: 'documents',
                        onUserUpdated: widget.onUserUpdated,
                      ),
                    ),
                  ).then((_) => _fetchDocuments());
                },
                icon: const Icon(Icons.upload_file_outlined, size: 16),
                label: const Text('Unggah Berkas SK/BAST'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDocuments,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 24 : 16,
            16,
            isDesktop ? 24 : 16,
            80,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardBg : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  ),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Cari nomor SK, judul MoU, atau perihal dokumen...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF151326) : Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Content Area
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_filteredDocuments.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open_outlined,
                          size: 64,
                          color: isDark ? AppTheme.textMuted : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum Ada Dokumen Ditemukan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Berkas, SK, dan dokumen resmi instansi yang diunggah akan tersimpan rapi di sini.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredDocuments.length,
                  itemBuilder: (context, index) {
                    final d = _filteredDocuments[index];
                    final color = d['color'] as Color;
                    final icon = d['icon'] as IconData;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.cardBg : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, color: color, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        d['category'] as String,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      d['document_date'] as String,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  d['title'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  d['author'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () {
                              OfficialDocumentViewerDialog.show(
                                context,
                                document: d,
                                isGovernment: _isGovernment,
                              );
                            },
                            icon: const Icon(Icons.verified_user_outlined, size: 15),
                            label: const Text('Buka Dokumen Resmi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );

    if (widget.user != null) {
      return DesktopSidebarLayout(
        user: widget.user!,
        activeRoute: 'dokumen_instansi',
        onUserUpdated: widget.onUserUpdated,
        child: content,
      );
    }

    return content;
  }
}
