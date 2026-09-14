import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/portfolio_service.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/kreavana_image.dart';

class PortfolioScreen extends StatefulWidget {
  final UserModel? user;

  const PortfolioScreen({super.key, this.user});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  List<PortfolioItemModel> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPortfolio();
  }

  Future<void> _loadPortfolio() async {
    setState(() => _isLoading = true);
    try {
      final items = await PortfolioService.getPortfolio();
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text(
          'Portfolio Saya',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? AppTheme.cardBg : Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Tambah Portfolio',
            onPressed: () => _showAddPortfolioDialog(context),
          ),
        ],
      ),
      body: _isLoading
          ? GridView.builder(
              padding: const EdgeInsets.all(16),
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.72,
              ),
              itemCount: 6,
              itemBuilder: (context, index) {
                return const SkeletonLoader(
                  height: double.infinity,
                  borderRadius: 16,
                );
              },
            )
          : _items.isEmpty
          ? AppEmptyState(
              icon: Icons.photo_library_outlined,
              title: 'Belum Ada Portfolio',
              subtitle: 'Anda belum menambahkan karya apapun ke portfolio.',
              onAction: _loadPortfolio,
              actionLabel: 'Muat Ulang',
            )
          : RefreshIndicator(
              onRefresh: _loadPortfolio,
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.of(context).size.width > 800 ? 3 : 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.72,
                ),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return _buildPortfolioCard(item, isDark);
                },
              ),
            ),
    );
  }

  Widget _buildPortfolioCard(PortfolioItemModel item, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 4,
            child: item.imageUrl != null
                ? KreavanaImage(
                    url: item.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: const SkeletonLoader(
                      height: double.infinity,
                      borderRadius: 0,
                    ),
                  )
                : Container(
                    color: Colors.grey.withValues(alpha: 0.15),
                    child: Center(
                      child: Icon(
                        item.isExternal ? Icons.work_history_outlined : Icons.verified_outlined,
                        color: Colors.teal.shade300,
                        size: 36,
                      ),
                    ),
                  ),
          ),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Provenance Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.isExternal
                          ? Colors.amber.withValues(alpha: 0.15)
                          : Colors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: item.isExternal
                            ? Colors.amber.shade700
                            : Colors.teal.shade600,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.isExternal ? Icons.history_edu : Icons.verified,
                          size: 10,
                          color: item.isExternal ? Colors.amber.shade800 : Colors.teal.shade700,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            item.isExternal
                                ? 'Pengalaman Eksternal'
                                : 'Proyek Kreavana',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: item.isExternal
                                  ? Colors.amber.shade900
                                  : Colors.teal.shade800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.clientName != null && item.clientName!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Klien: ${item.clientName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (item.eventDate != null || item.location != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      [item.eventDate, item.location].where((e) => e != null && e.isNotEmpty).join(' • '),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const Spacer(),
                  if (item.isExternal)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Dilaporkan Mandiri',
                        style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPortfolioDialog(BuildContext context) {
    final titleController = TextEditingController();
    final categoryController = TextEditingController();
    final descController = TextEditingController();
    final clientNameController = TextEditingController();
    final locationController = TextEditingController();
    final eventDateController = TextEditingController();
    String source = 'external';
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, scrollController) => Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardBg : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tambah Pengalaman / Portfolio',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Dokumentasikan portofolio karya Anda, baik yang dikerjakan melalui Kreavana maupun pengalaman profesional eksternal sebelumnya.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Provenance Source Selector
                  const Text(
                    'Asal Pengalaman Proyek',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Eksternal (Pra-Kreavana)'),
                          selected: source == 'external',
                          selectedColor: Colors.amber.shade100,
                          onSelected: (_) => setSheetState(() => source = 'external'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Proyek Kreavana'),
                          selected: source == 'kreavana',
                          selectedColor: Colors.teal.shade100,
                          onSelected: (_) => setSheetState(() => source = 'kreavana'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Judul Karya / Proyek *',
                      hintText: 'Contoh: Dokumentasi Wedding Adat Jawa',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: clientNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Klien / Penyelenggara',
                      hintText: 'Contoh: PT Nusantara Kreatif / Pribadi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: eventDateController,
                          decoration: const InputDecoration(
                            labelText: 'Tanggal Acara (YYYY-MM-DD)',
                            hintText: '2025-08-15',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: locationController,
                          decoration: const InputDecoration(
                            labelText: 'Lokasi Kota',
                            hintText: 'Yogyakarta',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Kategori / Peran',
                      hintText: 'Contoh: Fotografer / Tukang Kendang / MC',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: descController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi Singkat',
                      hintText: 'Jelaskan cakupan pekerjaan, alat yang digunakan, dll.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final title = titleController.text.trim();
                            if (title.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Judul karya wajib diisi!')),
                              );
                              return;
                            }

                            setSheetState(() => isSaving = true);
                            final newItem = await PortfolioService.addPortfolio(
                              title: title,
                              category: categoryController.text.trim().isEmpty ? null : categoryController.text.trim(),
                              description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                              clientName: clientNameController.text.trim().isEmpty ? null : clientNameController.text.trim(),
                              eventDate: eventDateController.text.trim().isEmpty ? null : eventDateController.text.trim(),
                              location: locationController.text.trim().isEmpty ? null : locationController.text.trim(),
                              source: source,
                            );

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              if (newItem != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Portfolio berhasil ditambahkan!'),
                                    backgroundColor: Colors.teal,
                                  ),
                                );
                                _loadPortfolio();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Gagal menambahkan portfolio. Periksa input Anda.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Simpan Portfolio', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
