import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../models/opportunity_model.dart';
import '../services/opportunity_service.dart';
import '../widgets/feature_card.dart';
import '../widgets/opportunity_detail_sheet.dart';

class PeluangProyekScreen extends StatefulWidget {
  final UserModel user;
  final String pihakSlug;

  const PeluangProyekScreen({
    super.key,
    required this.user,
    this.pihakSlug = 'all',
  });

  @override
  State<PeluangProyekScreen> createState() => _PeluangProyekScreenState();
}

class _PeluangProyekScreenState extends State<PeluangProyekScreen> {
  bool _isLoading = true;
  List<OpportunityModel> _projects = [];
  final TextEditingController _searchController = TextEditingController();
  List<OpportunityModel> _filtered = [];

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    final list = await OpportunityService.getOpportunities(
      pihak: widget.pihakSlug,
      type: 'project',
    );
    if (mounted) {
      setState(() {
        _projects = list;
        _filtered = list;
        _isLoading = false;
      });
    }
  }

  void _filter() {
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _filtered = _projects;
      } else {
        _filtered = _projects
            .where(
              (p) =>
                  p.title.toLowerCase().contains(q) ||
                  (p.description?.toLowerCase().contains(q) ?? false) ||
                  (p.location?.toLowerCase().contains(q) ?? false),
            )
            .toList();
      }
    });
  }

  Future<void> _openDetail(OpportunityModel opp) async {
    var detail = opp;
    if (opp.poster == null) {
      final fetched = await OpportunityService.getDetail(opp.id);
      if (fetched != null) detail = fetched;
    }
    if (mounted) {
      OpportunityDetailSheet.show(
        context,
        opportunity: detail,
        currentUserId: widget.user.id,
      );
    }
  }

  Color _getPihakColor(String slug) {
    switch (slug) {
      case 'kreator':
        return const Color(0xFFF97316);
      case 'eo':
        return const Color(0xFF3B82F6);
      case 'wo':
        return const Color(0xFF8B5CF6);
      case 'sekolah':
        return const Color(0xFF10B981);
      case 'umkm':
        return const Color(0xFF06B6D4);
      case 'pemerintah':
        return const Color(0xFF1E3A8A);
      case 'komunitas':
        return const Color(0xFFEC4899);
      case 'organisasi':
        return const Color(0xFF3F51B5);
      default:
        return Colors.indigo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Peluang Proyek',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Kebutuhan proyek kreatif dari klien',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Cari proyek, lokasi, atau keahlian...',
              leading: const Icon(Icons.search, color: Colors.grey),
              elevation: WidgetStateProperty.all(0),
              backgroundColor: WidgetStateProperty.all(
                isDark ? AppTheme.cardBg : Colors.grey.shade100,
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadProjects,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          children: [
                            Icon(Icons.work_off_outlined,
                                size: 60, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            const Text(
                              'Belum ada peluang proyek',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : isDesktop
                    ? GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 2.5,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final op = _filtered[index];
                          return FeatureCard(
                            opportunity: op,
                            accentColor: _getPihakColor(op.pihakSlug),
                            onTap: () => _openDetail(op),
                          );
                        },
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final op = _filtered[index];
                          return FeatureCard(
                            opportunity: op,
                            accentColor: _getPihakColor(op.pihakSlug),
                            onTap: () => _openDetail(op),
                          );
                        },
                      ),
      ),
    );
  }
}
