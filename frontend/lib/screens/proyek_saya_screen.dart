import 'package:flutter/material.dart';
import '../utils/debouncer.dart';
import '../app/theme.dart';
import '../app/subrole_theme_engine.dart';
import '../models/user_model.dart';
import '../services/job_contract_service.dart';
import '../models/job_contract.dart';
import 'direct_message_screen.dart';
import 'buat_kebutuhan_screen.dart';

import '../widgets/skeleton/skeleton_list.dart';

class ProyekSayaScreen extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const ProyekSayaScreen({super.key, this.user, this.onUserUpdated});

  @override
  State<ProyekSayaScreen> createState() => _ProyekSayaScreenState();
}

class _ProyekSayaScreenState extends State<ProyekSayaScreen> {
  bool _isLoading = false;
  String _selectedStatus = 'Semua';
  String _searchQuery = '';
  final _debouncer = Debouncer(milliseconds: 500);

  List<JobContract> _projects = [];

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchRealtimeProjects();
  }

  Future<void> _fetchRealtimeProjects() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final list = await JobContractService.getUserContracts();
      if (mounted) {
        setState(() {
          _projects = list;
        });
      }
    } catch (e) {
      // Error handling removed or ignored as the field was unused.
      debugPrint('Error fetching projects: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final role = widget.user?.role ?? 'user';
    final subRole = widget.user?.subRole ?? 'general';
    final accentColor = SubRoleThemeEngine.getAccentColor(role, subRole);

    final filtered = _projects.where((p) {
      final st = p.contractStatus;
      if (_selectedStatus != 'Semua' && st != _selectedStatus) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final title = p.title.toLowerCase();
        final creator = p.creatorName.toLowerCase();
        return title.contains(q) || creator.contains(q);
      }
      return true;
    }).toList();

    final activeCount = _projects
        .where((p) => p.contractStatus == 'Berjalan')
        .length;
    final pendingCount = _projects
        .where((p) => p.contractStatus == 'Menunggu')
        .length;
    final doneCount = _projects
        .where((p) => p.contractStatus == 'Selesai')
        .length;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text(
          'Proyek Saya',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: widget.user != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRealtimeProjects,
            tooltip: 'Refresh Data Realtime',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchRealtimeProjects,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Summary Cards ──
              _buildSummaryHeader(
                accentColor,
                activeCount,
                pendingCount,
                doneCount,
                isDark,
              ),
              const SizedBox(height: 20),

              // ── Search & Filters ──
              TextField(
                onChanged: (v) {
                  _debouncer.run(() {
                    setState(() => _searchQuery = v);
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Cari nama proyek atau partner...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF1A1830)
                      : Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Semua', 'Berjalan', 'Menunggu', 'Selesai'].map((
                    st,
                  ) {
                    final isSel = _selectedStatus == st;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(st),
                        selected: isSel,
                        selectedColor: accentColor,
                        labelStyle: TextStyle(
                          color: isSel
                              ? Colors.white
                              : (isDark
                                    ? Colors.white70
                                    : Colors.grey.shade800),
                          fontWeight: isSel
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedStatus = st);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // ── Projects List ──
              if (_isLoading)
                const SkeletonList()
              else if (filtered.isEmpty)
                _buildEmptyState(isDark)
              else
                ...filtered.map(
                  (p) => _buildProjectCard(p, accentColor, isDark),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BuatKebutuhanScreen()),
          );
        },
        backgroundColor: accentColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Buat Proyek Baru',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(
    Color accentColor,
    int active,
    int pending,
    int done,
    bool isDark,
  ) {
    final List<Map<String, dynamic>> items = [];

    return Row(
      children: items.map((it) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBg : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  (it['icon'] as IconData?) ?? Icons.image_outlined,
                  color: it['color'] as Color,
                  size: 20,
                ),
                const SizedBox(height: 6),
                Text(
                  it['val'] as String,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  it['label'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProjectCard(JobContract p, Color accentColor, bool isDark) {
    Color statusColor;
    if (p.contractStatus == 'Selesai') {
      statusColor = Colors.green;
    } else if (p.contractStatus == 'Berjalan') {
      statusColor = AppTheme.primaryPurple;
    } else {
      statusColor = Colors.orange;
    }

    final progressPct = 0; // Not available in JobContract directly

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
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
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  p.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  p.contractStatus,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 14,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
              Text(
                p.creatorName,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
              Text(
                p.scheduledEndDate?.toString().split(' ')[0] ?? '-',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progres Pekerjaan',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                ),
              ),
              Text(
                '$progressPct%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressPct / 100,
              minHeight: 8,
              backgroundColor: isDark
                  ? Colors.grey.shade800
                  : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rp ${p.agreedPrice.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DirectMessageScreen(),
                        ),
                      );
                    },
                    tooltip: 'Chat Partner',
                  ),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Detail Brief',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 48,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada proyek pada status ini',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
