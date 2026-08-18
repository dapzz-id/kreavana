import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app/theme.dart';
import '../app/app_animations.dart';
import '../utils/app_errors.dart';
import '../services/chat_service.dart';
import '../services/call_service.dart';
import '../services/api_service.dart';
import '../widgets/app_status_widgets.dart';
import 'call_screen.dart';
import 'direct_message_screen.dart';

/// Layar kontak: admin, kreator, dan klien lain.
/// Setiap kontak bisa langsung di-chat, ditelepon, atau video call.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _loading = true;
  bool _searching = false;
  String _query = '';
  String _tab = 'Semua';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() => _loading = true);
    try {
      final data = await ChatService.fetchContacts();
      if (mounted) {
        setState(() {
          _contacts = data.map((c) => Map<String, dynamic>.from(c)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onSearch(String value) async {
    setState(() {
      _query = value;
      _searching = value.isNotEmpty;
    });
    if (value.trim().isEmpty) {
      setState(() => _searching = false);
      return;
    }
    try {
      final results = await ChatService.searchUsers(value.trim());
      if (mounted) {
        setState(() {
          _searchResults = results
              .map((r) => Map<String, dynamic>.from(r))
              .toList();
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _searching = false);
    }
  }

  List<Map<String, dynamic>> get _visibleContacts {
    if (_tab == 'Semua') return _contacts;
    return _contacts.where((c) => _roleOf(c) == _tab).toList();
  }

  String _roleOf(Map<String, dynamic> contact) {
    final role = (contact['role'] ?? '').toString();
    if (role == 'admin') return 'Official';
    if (role == 'creator') return 'Kreator';
    return 'Klien';
  }

  Future<void> _startChat(Map<String, dynamic> contact) async {
    try {
      final result = await ChatService.startPersonalChat(
        contact['id'].toString(),
      );
      if (!mounted) return;

      final chatData = result['data'];
      if (chatData == null) {
        if (mounted) {
          AppSnackbar.error(context, 'Gagal membuka chat.');
        }
        return;
      }

      final chat = Map<String, dynamic>.from(
        chatData is Map ? chatData : result,
      );
      chat['username'] = contact['username'] ?? chat['username'];
      chat['phone'] = contact['phone'];
      chat['avatar_url'] = ApiService.resolveAssetUrl(contact['avatar_url']);
      chat['role'] = contact['role'];
      chat['email'] = contact['email'];

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              Scaffold(body: ChatDetailSection(chat: chat, isMobile: true)),
        ),
      );
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, AppErrors.friendly(e));
      }
    }
  }

  Future<void> _startCall(Map<String, dynamic> contact, bool video) async {
    try {
      final callService = CallService();
      await callService.initPusher();
      final receiverId = contact['id'].toString();
      await callService.startCall(
        receiverId,
        video,
        remoteUserName: contact['name'] ?? 'User',
        remoteAvatarUrl: ApiService.resolveAssetUrl(
          contact['avatar_url'] ?? '',
        ),
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            callService: callService,
            remoteUserName: contact['name'] ?? 'User',
            remoteAvatarUrl: ApiService.resolveAssetUrl(
              contact['avatar_url'] ?? '',
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, AppErrors.friendly(e));
      }
    }
  }

  Future<void> _openDialer(Map<String, dynamic> contact) async {
    final phone = contact['phone']?.toString();
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        AppSnackbar.info(context, 'Nomor kontak: $phone');
      }
    }
  }

  void _copyPhone(Map<String, dynamic> contact) {
    final phone = contact['phone']?.toString();
    if (phone == null || phone.isEmpty) return;
    Clipboard.setData(ClipboardData(text: phone));
    if (mounted) {
      AppSnackbar.success(context, 'Nomor $phone disalin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Kontak',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // ── Search ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Cari nama, username, atau nomor...',
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search),
              ),
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(
                theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
              ),
              onChanged: _onSearch,
            ),
          ),

          // ── Filter chips ──
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('Semua', Icons.people_alt_rounded),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Official',
                  Icons.admin_panel_settings_rounded,
                ),
                const SizedBox(width: 8),
                _buildFilterChip('Kreator', Icons.brush_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('Klien', Icons.storefront_rounded),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Content ──
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _tab == label;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: FilterChip(
        selected: selected,
        showCheckmark: false,
        avatar: Icon(
          icon,
          size: 16,
          color: selected
              ? Colors.white
              : (isDark ? AppTheme.textMuted : AppTheme.textMutedLight),
        ),
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected
              ? Colors.white
              : (isDark ? AppTheme.textMuted : AppTheme.textMutedLight),
        ),
        selectedColor: AppTheme.primaryPurple,
        backgroundColor: isDark ? AppTheme.inputDark : AppTheme.inputLight,
        side: BorderSide(
          color: selected
              ? AppTheme.primaryPurple
              : (isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight),
        ),
        onSelected: (_) => setState(() => _tab = label),
      ),
    );
  }

  Widget _buildContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const AppLoadingState(message: 'Memuat kontak...', child: null);
    }

    if (_query.isNotEmpty) {
      if (_searching) {
        return const AppLoadingState(message: 'Mencari...', child: null);
      }
      if (_searchResults.isEmpty) {
        return _buildEmpty(
          icon: Icons.person_search_rounded,
          title: 'Tidak ditemukan',
          subtitle: 'Coba kata kunci lain',
          isDark: isDark,
        );
      }
      return _buildList(_searchResults, isDark);
    }

    final visible = _visibleContacts;
    if (visible.isEmpty) {
      return _buildEmpty(
        icon: Icons.contacts_rounded,
        title: 'Belum ada kontak',
        subtitle: 'Cari kreator atau klien untuk memulai obrolan',
        isDark: isDark,
      );
    }
    return _buildList(visible, isDark);
  }

  Widget _buildList(List<Map<String, dynamic>> contacts, bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadContacts,
      color: AppTheme.primaryPurple,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          return AnimatedEntrance(
            delay: Duration(milliseconds: 45 * (index % 8)),
            child: _ContactCard(
              contact: contacts[index],
              isDark: isDark,
              onChat: () => _startChat(contacts[index]),
              onCall: () => _startCall(contacts[index], false),
              onVideoCall: () => _startCall(contacts[index], true),
              onDialer: () => _openDialer(contacts[index]),
              onCopy: () => _copyPhone(contacts[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 44,
                color: AppTheme.primaryPurple.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Contact Card ─────────────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final Map<String, dynamic> contact;
  final bool isDark;
  final VoidCallback onChat;
  final VoidCallback onCall;
  final VoidCallback onVideoCall;
  final VoidCallback onDialer;
  final VoidCallback onCopy;

  const _ContactCard({
    required this.contact,
    required this.isDark,
    required this.onChat,
    required this.onCall,
    required this.onVideoCall,
    required this.onDialer,
    required this.onCopy,
  });

  String get _roleLabel {
    final role = (contact['role'] ?? '').toString();
    if (role == 'admin') return 'Official';
    if (role == 'creator') return 'Kreator';
    return 'Klien';
  }

  Color get _roleColor {
    final role = (contact['role'] ?? '').toString();
    if (role == 'admin') return AppTheme.warning;
    if (role == 'creator') return AppTheme.primaryPurple;
    return AppTheme.success;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = (contact['name'] ?? 'User').toString();
    final username = (contact['username'] ?? '').toString();
    final phone = contact['phone']?.toString() ?? '';
    final avatarUrl = ApiService.resolveAssetUrl(
      contact['avatar_url']?.toString() ?? '',
    );
    final hasPhone = phone.isNotEmpty;

    return Pressable(
      onTap: onChat,
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(
            color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // ── Avatar ──
            _Avatar(name: name, avatarUrl: avatarUrl, roleColor: _roleColor),
            const SizedBox(width: 12),

            // ── Info ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _roleColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _roleLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _roleColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '@$username',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasPhone) ...[
                    const SizedBox(height: 3),
                    InkWell(
                      onTap: onCopy,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.phone_rounded,
                            size: 12,
                            color: AppTheme.success.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            phone,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Quick actions ──
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _QuickAction(
                      icon: Icons.chat_bubble_rounded,
                      color: AppTheme.primaryPurple,
                      tooltip: 'Chat',
                      onTap: onChat,
                    ),
                    const SizedBox(width: 6),
                    _QuickAction(
                      icon: Icons.call_rounded,
                      color: AppTheme.success,
                      tooltip: 'Telepon',
                      onTap: onCall,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _QuickAction(
                      icon: Icons.videocam_rounded,
                      color: AppTheme.accentPink,
                      tooltip: 'Video Call',
                      onTap: onVideoCall,
                    ),
                    if (hasPhone) ...[
                      const SizedBox(width: 6),
                      _QuickAction(
                        icon: Icons.dialpad_rounded,
                        color: AppTheme.warning,
                        tooltip: 'Buka Dialer',
                        onTap: onDialer,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Avatar ───────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final Color roleColor;

  const _Avatar({
    required this.name,
    required this.avatarUrl,
    required this.roleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: roleColor, width: 2),
      ),
      child: CircleAvatar(
        radius: 22,
        backgroundColor: Colors.transparent,
        backgroundImage: avatarUrl.isNotEmpty
            ? NetworkImage(avatarUrl)
            : NetworkImage(
                'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=7C3AED&color=fff&size=128',
              ),
        child: avatarUrl.isNotEmpty ? null : null,
      ),
    );
  }
}

// ─── Quick Action Button ──────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.9,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}
