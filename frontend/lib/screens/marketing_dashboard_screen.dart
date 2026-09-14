import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/skeleton_loader.dart';

class MarketingDashboardScreen extends StatefulWidget {
  final UserModel user;

  const MarketingDashboardScreen({super.key, required this.user});

  @override
  State<MarketingDashboardScreen> createState() => _MarketingDashboardScreenState();
}

class _MarketingDashboardScreenState extends State<MarketingDashboardScreen> {
  bool _isLoading = true;
  List<dynamic> _reviews = [];
  String _selectedStatus = 'all';

  static const _statusFilters = [
    {'value': 'all', 'label': 'Semua Transaksi'},
    {'value': 'pending', 'label': 'Menunggu Review'},
    {'value': 'under_review', 'label': 'Sedang Ditinjau'},
    {'value': 'verified', 'label': 'Terverifikasi'},
    {'value': 'approved', 'label': 'Disetujui'},
    {'value': 'rejected', 'label': 'Ditolak'},
  ];

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    try {
      final queryParams = <String, String>{};
      if (_selectedStatus != 'all') {
        queryParams['status'] = _selectedStatus;
      }

      final response = await ApiService.get('marketing/large-transactions', queryParams: queryParams);
      if (mounted) {
        setState(() {
          if (response['status'] == true && response['data'] != null) {
            _reviews = response['data'] is List ? response['data'] : (response['data']['data'] ?? []);
          } else {
            _reviews = [];
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.amber.shade700;
      case 'under_review':
        return Colors.blue.shade600;
      case 'verified':
        return Colors.indigo.shade600;
      case 'approved':
        return Colors.teal.shade700;
      case 'rejected':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'pending':
        return 'Menunggu Tindakan';
      case 'under_review':
        return 'Sedang Ditinjau';
      case 'verified':
        return 'Terverifikasi';
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      default:
        return status ?? '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audit Transaksi Bernilai Tinggi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Marketing & Enterprise Compliance Portal (≥ Rp 100.000.000)',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReviews,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Status Filter Chips ──────────────────────────────────────────
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _statusFilters.length,
              itemBuilder: (context, index) {
                final filter = _statusFilters[index];
                final isSelected = _selectedStatus == filter['value'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter['label']!),
                    selected: isSelected,
                    selectedColor: Colors.teal.shade100,
                    onSelected: (_) {
                      setState(() => _selectedStatus = filter['value']!);
                      _loadReviews();
                    },
                  ),
                );
              },
            ),
          ),

          // ── Reviews List ─────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 4,
                    itemBuilder: (_, _) => const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: SkeletonLoader(height: 140, borderRadius: 16),
                    ),
                  )
                : _reviews.isEmpty
                ? AppEmptyState(
                    icon: Icons.verified_user_outlined,
                    title: 'Tidak Ada Transaksi',
                    subtitle: 'Semua transaksi bernilai tinggi telah diproses atau belum ada yang melebihi ambang batas.',
                    onAction: _loadReviews,
                    actionLabel: 'Muat Ulang',
                  )
                : RefreshIndicator(
                    onRefresh: _loadReviews,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reviews.length,
                      itemBuilder: (context, index) {
                        final item = _reviews[index];
                        final amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0;
                        final status = item['status']?.toString();
                        final reviewer = item['reviewer'];
                        final contract = item['job_contract'];
                        final opportunity = contract?['opportunity'];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _statusLabel(status),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _statusColor(status),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      currencyFormatter.format(amount),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  opportunity?['title'] ?? 'Kontrak Proyek #${contract?['id'] ?? item['id']}',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Klien: ${contract?['client']?['name'] ?? '-'} • Kreator: ${contract?['creator']?['name'] ?? '-'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (reviewer != null)
                                  Text(
                                    'Reviewer: ${reviewer['name']}',
                                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                                  )
                                else
                                  const Text(
                                    'Belum ditugaskan ke marketing staff',
                                    style: TextStyle(fontSize: 11, color: Colors.orange),
                                  ),
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (reviewer == null || status == 'pending')
                                      TextButton.icon(
                                        onPressed: () => _assignToSelf(item['id']),
                                        icon: const Icon(Icons.person_add_alt_1, size: 16),
                                        label: const Text('Ambil Tugas'),
                                      ),
                                    if (status == 'under_review' || status == 'pending') ...[
                                      OutlinedButton(
                                        onPressed: () => _showVerifyDialog(item['id']),
                                        child: const Text('Catat Berita Acara'),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    if (status == 'verified' || status == 'under_review') ...[
                                      ElevatedButton(
                                        onPressed: () => _showApproveRejectDialog(item['id'], true),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                                        child: const Text('Setujui', style: TextStyle(color: Colors.white)),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: () => _showApproveRejectDialog(item['id'], false),
                                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                        child: const Text('Tolak'),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _assignToSelf(dynamic reviewId) async {
    final res = await ApiService.post('marketing/large-transactions/$reviewId/assign', {});
    if (res['status'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tugas berhasil diambil.'), backgroundColor: Colors.teal),
      );
      _loadReviews();
    }
  }

  void _showVerifyDialog(dynamic reviewId) {
    final notesController = TextEditingController();
    final proofController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Berita Acara Verifikasi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Catat hasil pertemuan / konfirmasi langsung dengan pihak klien & kreator terkait transaksi bernilai tinggi ini.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan Verifikasi *',
                hintText: 'Hasil meeting, validitas identitas, dll.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: proofController,
              decoration: const InputDecoration(
                labelText: 'Bukti / Tautan Berita Acara',
                hintText: 'URL Dokumen / Ref Cloud',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final notes = notesController.text.trim();
              if (notes.isEmpty) return;
              Navigator.pop(ctx);
              final res = await ApiService.post(
                'marketing/large-transactions/$reviewId/verify',
                {
                  'notes': notes,
                  'verification_proof': proofController.text.trim(),
                },
              );
              if (res['status'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Verifikasi dicatat.'), backgroundColor: Colors.teal),
                );
                _loadReviews();
              }
            },
            child: const Text('Simpan Verifikasi'),
          ),
        ],
      ),
    );
  }

  void _showApproveRejectDialog(dynamic reviewId, bool isApprove) {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isApprove ? 'Setujui Transaksi Bernilai Tinggi' : 'Tolak Transaksi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isApprove
                  ? 'Transaksi ini telah diverifikasi dan dana dapat diteruskan/dilepaskan ke alur kontrak normal.'
                  : 'Transaksi akan ditolak dan dana/kontrak akan dihentikan.',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: isApprove ? 'Catatan Persetujuan' : 'Alasan Penolakan *',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final notes = notesController.text.trim();
              if (!isApprove && notes.isEmpty) return;
              Navigator.pop(ctx);
              final endpoint = isApprove
                  ? 'marketing/large-transactions/$reviewId/approve'
                  : 'marketing/large-transactions/$reviewId/reject';
              final res = await ApiService.post(endpoint, {'decision_notes': notes});
              if (res['status'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isApprove ? 'Transaksi disetujui!' : 'Transaksi ditolak.'),
                    backgroundColor: isApprove ? Colors.teal : Colors.red,
                  ),
                );
                _loadReviews();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isApprove ? Colors.teal : Colors.red,
            ),
            child: Text(isApprove ? 'Konfirmasi Setujui' : 'Konfirmasi Tolak', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
