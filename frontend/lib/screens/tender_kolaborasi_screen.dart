import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../models/user_model.dart';
import '../widgets/desktop_sidebar_layout.dart';

class TenderKolaborasiScreen extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const TenderKolaborasiScreen({super.key, this.user, this.onUserUpdated});

  @override
  State<TenderKolaborasiScreen> createState() => _TenderKolaborasiScreenState();
}

class _TenderKolaborasiScreenState extends State<TenderKolaborasiScreen> {
  String _selectedFilter = 'Semua';
  final _filters = ['Semua', 'Terbuka', 'Dalam Review', 'Selesai'];

  final _tenders = [
    {
      'title': 'Pengadaan Jasa Dokumentasi Festival Budaya 2025',
      'vendor': 'CV Kreasi Nusantara',
      'status': 'Terbuka',
      'status_color': Color(0xFF10B981),
      'budget': 'Rp 45.000.000',
      'deadline': '15 Agustus 2025',
      'category': 'Dokumentasi',
    },
    {
      'title': 'Pembuatan Video Profil Dinas Kominfo',
      'vendor': 'PT Media Digital',
      'status': 'Dalam Review',
      'status_color': Color(0xFFF59E0B),
      'budget': 'Rp 75.000.000',
      'deadline': '20 Juli 2025',
      'category': 'Videografi',
    },
    {
      'title': 'Desain Grafis Materi Sosialisasi',
      'vendor': 'Studio Desain Kreatif',
      'status': 'Terbuka',
      'status_color': Color(0xFF10B981),
      'budget': 'Rp 15.000.000',
      'deadline': '10 Agustus 2025',
      'category': 'Desain',
    },
    {
      'title': 'Pengelolaan Media Sosial Instansi',
      'vendor': 'Tim Kreasi Studio',
      'status': 'Selesai',
      'status_color': Color(0xFF6B7280),
      'budget': 'Rp 120.000.000/tahun',
      'deadline': '30 Juni 2025',
      'category': 'Media Sosial',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final content = Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text(
          'Tender & Kolaborasi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final f = _filters[index];
                final isSelected = _selectedFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      f,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? AppTheme.primaryPurple : null,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryPurple.withValues(
                      alpha: 0.15,
                    ),
                    checkmarkColor: AppTheme.primaryPurple,
                    onSelected: (_) => setState(() => _selectedFilter = f),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tenders.length,
        itemBuilder: (context, index) =>
            _buildTenderCard(_tenders[index], isDark),
      ),
    );

    if (widget.user != null) {
      return DesktopSidebarLayout(
        user: widget.user!,
        activeRoute: 'tender_kolaborasi',
        onUserUpdated: widget.onUserUpdated,
        child: content,
      );
    }

    return content;
  }

  Widget _buildTenderCard(Map<String, dynamic> t, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t['title'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: t['status_color'].withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  t['status'],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: t['status_color'],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            t['vendor'],
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.category_outlined,
                size: 12,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
              ),
              const SizedBox(width: 4),
              Text(
                t['category'],
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.calendar_today_outlined,
                size: 12,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
              ),
              const SizedBox(width: 4),
              Text(
                t['deadline'],
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.monetization_on_outlined,
                size: 14,
                color: AppTheme.primaryPurple,
              ),
              const SizedBox(width: 4),
              Text(
                t['budget'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Lihat Detail',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
