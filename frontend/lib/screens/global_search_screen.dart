import 'dart:async';
import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../models/opportunity_model.dart';
import '../services/chat_service.dart';
import '../services/opportunity_service.dart';
import '../services/api_service.dart';
import '../widgets/opportunity_detail_sheet.dart';
import 'profile_screen.dart';

import '../widgets/skeleton/skeleton_list.dart';
class GlobalSearchScreen extends StatefulWidget {
  final UserModel user;
  final String? initialQuery;

  const GlobalSearchScreen({super.key, required this.user, this.initialQuery});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  List<Map<String, dynamic>> _userResults = [];
  List<OpportunityModel> _opportunityResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  String _selectedFilter = 'Semua';
  final List<String> _filters = [
    'Semua',
    'Kreator',
    'Proyek',
    'Lokasi',
    'Komunitas',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
        _performSearch(widget.initialQuery!);
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final query = _searchController.text.trim();
      if (query.length >= 2) {
        _performSearch(query);
      } else {
        setState(() {
          _userResults = [];
          _opportunityResults = [];
          _hasSearched = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    final q = query.toLowerCase();

    try {
      final userRaw = await ChatService.searchUsers(query);
      final opps = await OpportunityService.getOpportunities(limit: 50);

      if (!mounted) return;

      final matchedUsers = userRaw.cast<Map<String, dynamic>>().where((u) {
        final name = (u['name'] ?? '').toString().toLowerCase();
        final username = (u['username'] ?? '').toString().toLowerCase();
        return name.contains(q) || username.contains(q);
      }).toList();

      final matchedOpps = opps.where((o) {
        final title = o.title.toLowerCase();
        final desc = (o.description ?? '').toLowerCase();
        final loc = (o.location ?? '').toLowerCase();
        final subRole = o.subRoleSlug.toLowerCase();
        return title.contains(q) ||
            desc.contains(q) ||
            loc.contains(q) ||
            subRole.contains(q);
      }).toList();

      setState(() {
        _userResults = matchedUsers;
        _opportunityResults = matchedOpps;
        _isSearching = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  List<OpportunityModel> get _filteredOpportunities {
    switch (_selectedFilter) {
      case 'Kreator':
        return _opportunityResults
            .where((o) => o.subRoleSlug.toLowerCase() != 'community')
            .toList();
      case 'Proyek':
        return _opportunityResults.where((o) => o.isProject).toList();
      case 'Lokasi':
        return _opportunityResults.where((o) => o.isLocation).toList();
      case 'Komunitas':
        return _opportunityResults
            .where((o) => o.subRoleSlug.toLowerCase() == 'community')
            .toList();
      default:
        return _opportunityResults;
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_selectedFilter == 'Semua' || _selectedFilter == 'Kreator') {
      return _userResults;
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1830) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(
                Icons.search,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Cari kreator, layanan, proyek, atau komunitas...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) {
                    final q = v.trim();
                    if (q.length >= 2) _performSearch(q);
                  },
                ),
              ),
              if (_searchController.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _userResults = [];
                      _opportunityResults = [];
                      _hasSearched = false;
                    });
                  },
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                  ),
                ),
              const SizedBox(width: 14),
            ],
          ),
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
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? AppTheme.primaryPurple
                            : (isDark
                                ? AppTheme.textMuted
                                : Colors.grey.shade600),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryPurple.withValues(alpha: 0.15),
                    checkmarkColor: AppTheme.primaryPurple,
                    onSelected: (_) {
                      setState(() => _selectedFilter = f);
                    },
                    side: BorderSide(
                      color: isSelected
                          ? AppTheme.primaryPurple.withValues(alpha: 0.3)
                          : (isDark
                              ? AppTheme.inputBorder
                              : Colors.grey.shade300),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isSearching) {
      return const SkeletonList();
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Ketik untuk mulai mencari',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cari kreator, proyek, lokasi, atau komunitas',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    final users = _filteredUsers;
    final opps = _filteredOpportunities;

    if (users.isEmpty && opps.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 64,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'Tidak ditemukan hasil',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Coba kata kunci lain',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        if (users.isNotEmpty) ...[
          _sectionHeader('Kreator', isDark),
          ...users.map((u) => _userTile(u, isDark)),
        ],
        if (opps.isNotEmpty) ...[
          _sectionHeader('Peluang', isDark),
          ...opps.map((o) => _opportunityTile(o, isDark)),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _userTile(Map<String, dynamic> user, bool isDark) {
    final name = user['name'] ?? 'Unknown';
    final username = user['username'] ?? '';
    final subRole = user['selected_sub_role'] ?? '';
    final avatarUrl = ApiService.resolveAssetUrl(user['avatar_url']?.toString() ?? '');

    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.15),
        backgroundImage:
            avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
        child: avatarUrl.isEmpty
            ? Text(
                name.toString().isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppTheme.primaryPurple,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        subRole.toString().isNotEmpty ? '@$username · $subRole' : '@$username',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDark ? AppTheme.textMuted : Colors.grey.shade400,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileScreen(
              user: widget.user,
              onUserUpdated: (_) {},
              onLogout: () {},
            ),
          ),
        );
      },
    );
  }

  Widget _opportunityTile(OpportunityModel opp, bool isDark) {
    final isLoc = opp.isLocation;
    final color = isLoc
        ? const Color(0xFF10B981)
        : const Color(0xFF6366F1);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          isLoc ? Icons.place_outlined : Icons.work_outline,
          color: color,
          size: 20,
        ),
      ),
      title: Text(
        opp.title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        [
          if (opp.location != null) opp.location,
          if (opp.budgetRange != null) opp.budgetRange,
        ].where((e) => e != null).join(' · '),
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDark ? AppTheme.textMuted : Colors.grey.shade400,
      ),
      onTap: () => _openDetail(opp),
    );
  }

  Future<void> _openDetail(OpportunityModel opp) async {
    var detail = opp;
    if (opp.poster == null) {
      final fetched = await OpportunityService.getDetail(opp.id ?? '');
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
}
