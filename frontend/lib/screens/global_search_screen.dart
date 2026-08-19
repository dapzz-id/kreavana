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
import 'direct_message_screen.dart';
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

  final List<String> _trendingSearches = [
    '🎥 Videografer',
    '🎨 Desain Logo',
    '📷 Foto Katalog',
    '🚀 Campaign TikTok',
    '📍 Jakarta',
    '🤝 Kolaborasi',
    '💻 UI/UX Design',
  ];

  final List<String> _recentSearches = [
    'Editor Video',
    'Festival Budaya',
    'Fotografer Summer',
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
    _debounce = Timer(const Duration(milliseconds: 500), () {
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
    final cleanQuery = query.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    if (cleanQuery.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    final q = cleanQuery.toLowerCase();

    try {
      final userRaw = await ChatService.searchUsers(cleanQuery);
      final contactsRaw = await ChatService.fetchContacts();
      final opps = await OpportunityService.getOpportunities(limit: 50);

      if (!mounted) return;

      final allUsers = <Map<String, dynamic>>[];
      final userIds = <String>{};

      for (var u in [...userRaw, ...contactsRaw]) {
        final id = u['id']?.toString() ?? '';
        if (id.isNotEmpty && !userIds.contains(id)) {
          userIds.add(id);
          allUsers.add(Map<String, dynamic>.from(u));
        }
      }

      final matchedUsers = allUsers.where((u) {
        final name = (u['name'] ?? '').toString().toLowerCase();
        final username = (u['username'] ?? '').toString().toLowerCase();
        final subRole = (u['selected_sub_role'] ?? u['sub_role'] ?? '')
            .toString()
            .toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();

        return name.contains(q) ||
            username.contains(q) ||
            subRole.contains(q) ||
            email.contains(q);
      }).toList();

      final matchedOpps = opps.where((o) {
        final title = o.title.toLowerCase();
        final desc = (o.description ?? '').toLowerCase();
        final loc = (o.location ?? '').toLowerCase();
        final subRole = o.subRoleSlug.toLowerCase();
        final category = (o.locationCategory ?? '').toLowerCase();

        return title.contains(q) ||
            desc.contains(q) ||
            loc.contains(q) ||
            subRole.contains(q) ||
            category.contains(q);
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

  void _applyTagQuery(String tag) {
    final clean = tag.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    _searchController.text = clean;
    _performSearch(clean);
  }

  List<OpportunityModel> get _filteredOpportunities {
    switch (_selectedFilter) {
      case 'Kreator':
        return [];
      case 'Proyek':
        return _opportunityResults.where((o) => o.isProject).toList();
      case 'Lokasi':
        return _opportunityResults
            .where(
              (o) =>
                  o.isLocation ||
                  (o.location != null && o.location!.isNotEmpty),
            )
            .toList();
      case 'Komunitas':
        return _opportunityResults
            .where(
              (o) =>
                  o.subRoleSlug.toLowerCase() == 'community' ||
                  o.title.toLowerCase().contains('komunitas'),
            )
            .toList();
      default:
        return _opportunityResults;
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_selectedFilter == 'Semua' || _selectedFilter == 'Kreator') {
      return _userResults;
    }
    if (_selectedFilter == 'Lokasi') {
      final q = _searchController.text.toLowerCase();
      return _userResults
          .where(
            (u) => (u['location'] ?? u['city'] ?? '')
                .toString()
                .toLowerCase()
                .contains(q),
          )
          .toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F0D1B)
          : const Color(0xFFF8F9FE),
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: isDark ? const Color(0xFF141221) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 46,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1B32) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? AppTheme.inputBorder
                  : AppTheme.primaryPurple.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              const Icon(
                Icons.search_rounded,
                color: AppTheme.primaryPurple,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Cari kreator, layanan, proyek, atau lokasi...',
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
                    if (q.isNotEmpty) _performSearch(q);
                  },
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _userResults = [];
                      _opportunityResults = [];
                      _hasSearched = false;
                    });
                  },
                ),
              const SizedBox(width: 6),
            ],
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Container(
            color: isDark ? const Color(0xFF141221) : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final f = _filters[index];
                  final isSelected = _selectedFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        f,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                    ? Colors.white70
                                    : Colors.grey.shade700),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryPurple,
                      backgroundColor: isDark
                          ? const Color(0xFF1E1B32)
                          : Colors.grey.shade100,
                      onSelected: (_) {
                        setState(() => _selectedFilter = f);
                      },
                      side: BorderSide(
                        color: isSelected
                            ? AppTheme.primaryPurple
                            : (isDark ? Colors.white10 : Colors.grey.shade200),
                      ),
                    ),
                  );
                },
              ),
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
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.orangeAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Pencarian Populer',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _trendingSearches.map<Widget>((tag) {
                return ActionChip(
                  label: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.grey.shade800,
                    ),
                  ),
                  backgroundColor: isDark
                      ? const Color(0xFF1E1B32)
                      : Colors.white,
                  side: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                  onPressed: () => _applyTagQuery(tag),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      color: AppTheme.primaryPurple,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Pencarian Terakhir',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => setState(() => _recentSearches.clear()),
                  child: const Text(
                    'Hapus',
                    style: TextStyle(fontSize: 12, color: Colors.redAccent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches.map<Widget>((tag) {
                return Chip(
                  avatar: const Icon(
                    Icons.search_rounded,
                    size: 14,
                    color: AppTheme.primaryPurple,
                  ),
                  label: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.grey.shade800,
                    ),
                  ),
                  backgroundColor: isDark
                      ? const Color(0xFF1A1830)
                      : Colors.grey.shade100,
                  deleteIcon: const Icon(Icons.arrow_forward_rounded, size: 14),
                  onDeleted: () => _applyTagQuery(tag),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),

            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161426) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.search_rounded,
                        size: 40,
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Temukan Kreator & Proyek Terbaik',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ketik nama kreator, bidang keahlian, judul proyek, atau lokasi kota pada kolom pencarian di atas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.textMuted
                            : Colors.grey.shade600,
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

    final users = _filteredUsers;
    final opps = _filteredOpportunities;

    if (users.isEmpty && opps.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161426) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 56,
                color: AppTheme.primaryPurple,
              ),
              const SizedBox(height: 14),
              const Text(
                'Tidak Ditemukan Hasil',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'Coba gunakan kata kunci lain seperti "Videografer", "Desain", "Foto", atau nama lokasi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (users.isNotEmpty) ...[
          _buildSectionHeader('Kreator & Pengguna (${users.length})', isDark),
          ...users.map((u) => _buildUserCard(u, isDark)),
          const SizedBox(height: 20),
        ],
        if (opps.isNotEmpty) ...[
          _buildSectionHeader('Peluang & Proyek (${opps.length})', isDark),
          ...opps.map((o) => _buildOpportunityCard(o, isDark)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white70 : Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, bool isDark) {
    final name = user['name'] ?? 'Unknown';
    final username = user['username'] ?? '';
    final subRole = user['selected_sub_role'] ?? user['sub_role'] ?? 'Kreator';
    final avatarUrl = ApiService.resolveAssetUrl(
      user['avatar_url']?.toString() ?? '',
    );
    final userId = user['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161426) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.15),
          backgroundImage: avatarUrl.isNotEmpty
              ? NetworkImage(avatarUrl)
              : null,
          child: avatarUrl.isEmpty
              ? Text(
                  name.toString().isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppTheme.primaryPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.verified_rounded,
              size: 15,
              color: AppTheme.primaryPurple,
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '@$username',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                subRole.toString(),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryPurple,
                ),
              ),
            ),
          ],
        ),
        trailing: ElevatedButton.icon(
          onPressed: () async {
            if (userId.isNotEmpty) {
              final chatRes = await ChatService.startPersonalChat(userId);
              final chatData = chatRes['data'];
              final chatId = chatData != null ? chatData['id'] : null;
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DirectMessageScreen(
                      currentUser: widget.user,
                      chatId: chatId,
                    ),
                  ),
                );
              }
            }
          },
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
          label: const Text(
            'Chat',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileScreen(
                user: UserModel.fromJson(user),
                onUserUpdated: (_) {},
                onLogout: () {},
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOpportunityCard(OpportunityModel opp, bool isDark) {
    final isLoc = opp.isLocation;
    final color = isLoc ? const Color(0xFF10B981) : const Color(0xFF6366F1);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161426) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isLoc ? Icons.place_rounded : Icons.work_rounded,
            color: color,
            size: 22,
          ),
        ),
        title: Text(
          opp.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            if (opp.location != null && opp.location!.isNotEmpty) ...[
              Icon(
                Icons.place_outlined,
                size: 12,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
              ),
              const SizedBox(width: 2),
              Text(
                opp.location!,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (opp.budgetRange != null && opp.budgetRange!.isNotEmpty)
              Text(
                opp.budgetRange!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
          ],
        ),
        trailing: OutlinedButton(
          onPressed: () => _openDetail(opp),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: BorderSide(color: color.withValues(alpha: 0.5)),
            foregroundColor: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'Detail',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        onTap: () => _openDetail(opp),
      ),
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
