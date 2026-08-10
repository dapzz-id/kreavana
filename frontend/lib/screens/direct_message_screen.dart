import 'dart:async';
import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as record;

import '../services/badge_service.dart';
import '../services/encryption_service.dart';
import '../services/chat_service.dart';
import '../services/call_service.dart';
import '../services/audio_player_service.dart';
import '../widgets/skeleton_box.dart';
import '../features/auth/services/auth_service.dart';
import '../services/api_service.dart';
import '../app/theme.dart';
import '../app/app_animations.dart';
import '../utils/app_errors.dart';
import 'call_screen.dart';
import 'transfer_screen.dart';
import 'contacts_screen.dart';

import '../models/user_model.dart';

class DirectMessageScreen extends StatefulWidget {
  final UserModel? currentUser;
  final dynamic chatId;

  const DirectMessageScreen({super.key, this.currentUser, this.chatId});

  @override
  State<DirectMessageScreen> createState() => _DirectMessageScreenState();
}

class _DirectMessageScreenState extends State<DirectMessageScreen> {
  // State untuk melacak obrolan yang dipilih di tampilan Master-Detail (Desktop/Web)
  Map<String, dynamic>? selectedChat;
  final GlobalKey<ChatListSectionState> chatListKey =
      GlobalKey<ChatListSectionState>();

  @override
  void initState() {
    super.initState();
    BadgeService().markMessagesRead();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Jika lebar layar besar (Web/Tablet/Desktop), gunakan Master-Detail layout
          if (constraints.maxWidth > 800) {
            return Row(
              children: [
                SizedBox(
                  width: 380,
                  child: ChatListSection(
                    key: chatListKey,
                    onChatSelected: (chat) {
                      setState(() {
                        selectedChat = chat;
                      });
                    },
                    onPresenceUpdated: (chat) {
                      if (selectedChat?['id'].toString() ==
                          chat['id'].toString()) {
                        setState(() {
                          selectedChat = chat;
                        });
                      }
                    },
                    selectedChat: selectedChat,
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: selectedChat == null
                      ? _buildEmptyState(context)
                      : ChatDetailSection(
                          chat: selectedChat!,
                          onMessageSent: () {
                            chatListKey.currentState?.loadChats();
                          },
                          onChatLeft: () {
                            setState(() {
                              selectedChat = null;
                            });
                            chatListKey.currentState?.loadChats();
                          },
                        ),
                ),
              ],
            );
          } else {
            // Jika lebar layar kecil (Mobile), hanya tampilkan daftar chat
            return ChatListSection(
              key: chatListKey,
              onChatSelected: (chat) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      body: ChatDetailSection(
                        chat: chat,
                        isMobile: true,
                        onMessageSent: () {
                          chatListKey.currentState?.loadChats();
                        },
                        onChatLeft: () {
                          chatListKey.currentState?.loadChats();
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: AnimatedEntrance(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Kreavana Chat',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih obrolan untuk mulai mengirim pesan',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _openContacts(context),
              icon: const Icon(Icons.contacts_rounded),
              label: const Text('Lihat Kontak'),
            ),
          ],
        ),
      ),
    );
  }

  void _openContacts(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ContactsScreen()),
    );
  }
}

class ChatListSection extends StatefulWidget {
  final Function(Map<String, dynamic>) onChatSelected;
  final Map<String, dynamic>? selectedChat;
  final void Function(Map<String, dynamic>)? onPresenceUpdated;

  const ChatListSection({
    super.key,
    required this.onChatSelected,
    this.selectedChat,
    this.onPresenceUpdated,
  });

  @override
  State<ChatListSection> createState() => ChatListSectionState();
}

class ChatListSectionState extends State<ChatListSection> {
  String viewType = 'personal';
  String searchQuery = '';
  bool isLoading = true;
  bool isSearching = false;
  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, dynamic>> _personalChats = [];
  List<Map<String, dynamic>> _groupChats = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _invitations = [];

  StreamSubscription? _messageSubscription;
  final Set<String> _subscribedChats = {};
  Timer? _presenceTimer;
  Timer? _pingTimer;
  bool _isRefreshingPresence = false;

  @override
  void initState() {
    super.initState();
    loadChats();
    _messageSubscription = ChatService.messageStream.listen((msg) {
      if (mounted) loadChats();
    });
    // Ping presence setiap 5 detik untuk menandai user online
    _pingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (mounted) ChatService.pingPresence();
      },
    );
    // Refresh daftar chat setiap 15 detik untuk update status online teman
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) {
        if (mounted && !_isRefreshingPresence) _refreshPresence();
      },
    );
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _presenceTimer?.cancel();
    _messageSubscription?.cancel();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> refreshChats() async {
    await loadChats();
  }

  Future<void> _refreshPresence() async {
    _isRefreshingPresence = true;
    try {
      final chats = await ChatService.fetchChats();
      if (!mounted) return;
      final personal = chats
          .where((c) => c['isGroup'] == false)
          .map((c) => Map<String, dynamic>.from(c))
          .toList();
      final groups = chats
          .where((c) => c['isGroup'] == true)
          .map((c) => Map<String, dynamic>.from(c))
          .toList();
      setState(() {
        _personalChats = personal;
        _groupChats = groups;
      });
      final selectedId = widget.selectedChat?['id']?.toString();
      if (selectedId != null) {
        for (final chat in chats) {
          if (chat['id'].toString() == selectedId) {
            widget.onPresenceUpdated?.call(
              Map<String, dynamic>.from(chat),
            );
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('Presence refresh error: $e');
    } finally {
      _isRefreshingPresence = false;
    }
  }

  Future<void> loadChats() async {
    try {
      final chats = await ChatService.fetchChats();
      final invs = await ChatService.fetchInvitations();
      if (mounted) {
        setState(() {
          _personalChats = chats
              .where((c) => c['isGroup'] == false)
              .map((c) => Map<String, dynamic>.from(c))
              .toList();
          _groupChats = chats
              .where((c) => c['isGroup'] == true)
              .map((c) => Map<String, dynamic>.from(c))
              .toList();
          _invitations = invs.map((i) => Map<String, dynamic>.from(i)).toList();
          isLoading = false;
        });

        for (var chat in chats) {
          final chatId = chat['id'].toString();
          if (!_subscribedChats.contains(chatId)) {
            _subscribedChats.add(chatId);
            ChatService.subscribeToChat(chatId);
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      debugPrint('Error loading chats: $e');
    }
  }

  void _showInvitationsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Undangan Grup'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _invitations.length,
            itemBuilder: (context, index) {
              final inv = _invitations[index];
              return ListTile(
                title: Text(inv['group_name']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () {
                        ChatService.respondInvitation(
                          inv['chat_id'].toString(),
                          true,
                        ).then((_) {
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          loadChats();
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () {
                        ChatService.respondInvitation(
                          inv['chat_id'].toString(),
                          false,
                        ).then((_) {
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          loadChats();
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showCreateGroupDialog() {
    final TextEditingController groupNameController = TextEditingController();
    final TextEditingController groupDescController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buat Grup Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: groupNameController,
              decoration: const InputDecoration(
                labelText: 'Nama Grup',
                hintText: 'Masukkan nama grup',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: groupDescController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Deskripsi Grup (Opsional)',
                hintText: 'Tuliskan tujuan atau deskripsi grup...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (groupNameController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                _createGroup(
                  groupNameController.text.trim(),
                  groupDescController.text.trim(),
                );
              }
            },
            child: const Text('Buat'),
          ),
        ],
      ),
    );
  }

  void _createGroup(String name, String description) {
    setState(() => isLoading = true);
    ChatService.createGroup(name, description).then((newGroup) {
      setState(() {
        isLoading = false;
        _groupChats.insert(
          0,
          Map<String, dynamic>.from(newGroup),
        );
      });
      widget.onChatSelected(
        Map<String, dynamic>.from(newGroup),
      );
    }).catchError((e) {
      setState(() => isLoading = false);
      debugPrint('Error creating group: $e');
    });
  }

  // ── Empty state chat list ──────────────────────────────────────────────────
  Widget _buildChatEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                viewType == 'group' ? Icons.groups_rounded : Icons.forum_rounded,
                size: 44,
                color: AppTheme.primaryPurple.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              searchQuery.isNotEmpty
                  ? 'Obrolan tidak ditemukan'
                  : viewType == 'group'
                      ? 'Belum ada grup'
                      : 'Belum ada obrolan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.isNotEmpty
                  ? 'Coba kata kunci lain'
                  : viewType == 'group'
                      ? 'Buat grup baru untuk berkolaborasi'
                      : 'Cari kontak untuk mulai mengobrol',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 20),
            if (viewType == 'personal' && searchQuery.isEmpty)
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ContactsScreen()),
                  );
                },
                icon: const Icon(Icons.contacts_rounded, size: 18),
                label: const Text('Lihat Kontak'),
              )
            else if (viewType == 'group')
              FilledButton.icon(
                onPressed: _showCreateGroupDialog,
                icon: const Icon(Icons.group_add_rounded, size: 18),
                label: const Text('Buat Grup'),
              ),
          ],
        ),
      ),
    );
  }

  // ── Tile hasil pencarian pengguna baru ─────────────────────────────────────
  Widget _buildNewUserTile(BuildContext context, Map<String, dynamic> user) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryPurple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: AppTheme.primaryPurple.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primary,
            child: Icon(
              Icons.person_add_alt_1_rounded,
              color: theme.colorScheme.onPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user['name']}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  user['email'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Pressable(
            onTap: () async {
              try {
                final result = await ChatService.startPersonalChat(
                  user['userId'],
                );
                if (!context.mounted) return;

                final chatData = result['data'];
                if (chatData == null) {
                  if (context.mounted) {
                    AppSnackbar.error(context, 'Gagal membuka chat.');
                  }
                  return;
                }

                final chat = Map<String, dynamic>.from(chatData is Map ? chatData : result);
                setState(() {
                  _personalChats.insert(0, chat);
                  searchQuery = '';
                  _searchResults = [];
                });
                widget.onChatSelected(chat);
              } catch (e) {
                if (!context.mounted) return;
                AppSnackbar.error(context, AppErrors.friendly(e));
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_rounded, size: 15, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Chat',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

  // ── Tile obrolan utama ─────────────────────────────────────────────────────
  Widget _buildChatTile(
    BuildContext context,
    Map<String, dynamic> chat,
    bool isSelected,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final unread = chat['unread'] == true;
    final isGroup = chat['isGroup'] == true;
    final isTyping = chat['isTyping'] == true;
    final isOnline = chat['isOnline'] == true;
    final name = chat['name']?.toString() ?? 'Unknown';
    final lastMessage = chat['lastMessage']?.toString() ?? '';
    final time = chat['time']?.toString() ?? '';
    final avatarUrl = ApiService.resolveAssetUrl(chat['avatar_url']?.toString() ?? '');
    final statusText = isTyping
        ? 'Sedang mengetik...'
        : isOnline
            ? 'Online'
            : _formatChatLastOnline(
                (chat['last_online'] ?? chat['lastOnline'] ?? chat['last_seen'] ?? chat['lastSeen'])?.toString() ?? '',
              );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        color: isSelected
            ? (isDark
                ? AppTheme.primaryPurple.withValues(alpha: 0.12)
                : AppTheme.primaryPurple.withValues(alpha: 0.07))
            : Colors.transparent,
        border: Border.all(
          color: isSelected
              ? AppTheme.primaryPurple.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
      ),
      child: Pressable(
        onTap: () => widget.onChatSelected(chat),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // ── Avatar ──
              Stack(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: isGroup
                        ? theme.colorScheme.tertiaryContainer
                        : AppTheme.primaryPurple.withValues(alpha: 0.12),
                    backgroundImage: !isGroup && avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : !isGroup
                            ? NetworkImage(
                                'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=7C3AED&color=fff&size=128',
                              )
                            : null,
                    child: isGroup
                        ? Icon(
                            Icons.groups_rounded,
                            color: theme.colorScheme.onTertiaryContainer,
                            size: 26,
                          )
                        : null,
                  ),
                  if (unread)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? AppTheme.cardDark
                                : AppTheme.cardLight,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  if (!isGroup && (isOnline || isTyping))
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isTyping ? AppTheme.accentPink : AppTheme.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // ── Info ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  unread ? FontWeight.w700 : FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.w500,
                            color: unread
                                ? AppTheme.primaryPurple
                                : (isDark
                                    ? Colors.white38
                                    : Colors.grey.shade400),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isOnline
                            ? AppTheme.success
                            : (isTyping
                                ? AppTheme.accentPink
                                : (isDark ? Colors.white38 : Colors.grey.shade500)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  unread ? FontWeight.w600 : FontWeight.w400,
                              color: unread
                                  ? theme.colorScheme.onSurface
                                  : (isDark
                                      ? Colors.white38
                                      : Colors.grey.shade500),
                            ),
                          ),
                        ),
                        if (unread) ... [
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${chat['unread_count'] ?? ''}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatChatLastOnline(String value) {
    if (value.isEmpty) return '';
    // Already formatted by backend (e.g. "5 menit lalu", "Kemarin")
    if (!value.contains('T') && !value.contains('-')) return value;
    try {
      final timestamp = DateTime.tryParse(value);
      if (timestamp == null) return value;
      final diff = DateTime.now().difference(timestamp);
      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
      if (diff.inHours < 24) return '${diff.inHours} jam lalu';
      if (diff.inDays < 7) return '${diff.inDays} hari lalu';
      return '${diff.inDays} hari lalu';
    } catch (_) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    var baseChats = viewType == 'personal' ? _personalChats : _groupChats;
    var chats = List<Map<String, dynamic>>.from(baseChats);
    List<Map<String, dynamic>> additionalResults = [];

    if (searchQuery.isNotEmpty) {
      chats = chats
          .where(
            (chat) => chat['name'].toString().toLowerCase().contains(
              searchQuery.toLowerCase(),
            ),
          )
          .toList();

      if (viewType == 'personal') {
        // Tambahkan hasil pencarian dari database yang belum ada di daftar chat
        for (var user in _searchResults) {
          bool exists = _personalChats.any((c) => c['name'] == user['name']);
          if (!exists) {
            additionalResults.add({
              'isNewUser': true,
              'userId': user['id'],
              'name': user['name'],
              'email': user['email'],
            });
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Obrolan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_invitations.isNotEmpty)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: _showInvitationsDialog,
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_invitations.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.contacts_rounded),
            tooltip: 'Kontak',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContactsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Pencarian Material 3
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: SearchBar(
              focusNode: _searchFocusNode,
              hintText: 'Cari akun atau pesan...',
              leading: const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(Icons.search),
              ),
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(
                Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              onChanged: (value) async {
                setState(() {
                  searchQuery = value;
                  isSearching = true;
                });
                if (value.isNotEmpty) {
                  try {
                    final results = await ChatService.searchUsers(value);
                    setState(() {
                      _searchResults = results
                          .map((r) => Map<String, dynamic>.from(r))
                          .toList();
                      isSearching = false;
                    });
                  } catch (e) {
                    setState(() => isSearching = false);
                  }
                } else {
                  setState(() {
                    _searchResults = [];
                    isSearching = false;
                  });
                }
              },
            ),
          ),
          // Pemilihan Tipe Obrolan menggunakan SegmentedButton
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'personal',
                    label: Text('Personal'),
                    icon: Icon(Icons.person_outline),
                  ),
                  ButtonSegment(
                    value: 'group',
                    label: Text('Grup'),
                    icon: Icon(Icons.groups_outlined),
                  ),
                ],
                selected: {viewType},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    viewType = newSelection.first;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Daftar Obrolan
          Expanded(
            child: isLoading
                ? ListView.builder(
                    itemCount: 7,
                    itemBuilder: (context, index) => const ChatListSkeleton(),
                  )
                : chats.isEmpty && additionalResults.isEmpty
                    ? _buildChatEmptyState(context)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        itemCount: chats.length + additionalResults.length,
                        itemBuilder: (context, index) {
                          if (index >= chats.length) {
                            final user =
                                additionalResults[index - chats.length];
                            return _buildNewUserTile(context, user);
                          }

                          final chat = chats[index];
                          final isSelected =
                              widget.selectedChat?['id'] == chat['id'];
                          return AnimatedEntrance(
                            delay: Duration(milliseconds: 40 * index.clamp(0, 6)),
                            child: _buildChatTile(context, chat, isSelected),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        // Angkat FAB hanya di layar mobile agar tidak tertutup bottom navbar
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).size.width < 800 ? 95 : 0),
        child: FloatingActionButton(
          heroTag: null,
          onPressed: viewType == 'group' 
              ? _showCreateGroupDialog 
              : () {
                  _searchFocusNode.requestFocus();
                },
          child: Icon(viewType == 'group' ? Icons.group_add : Icons.chat),
        ),
      ),
    );
  }
}

class ChatDetailSection extends StatefulWidget {
  final Map<String, dynamic> chat;
  final bool isMobile;
  final VoidCallback? onMessageSent;
  final VoidCallback? onChatLeft;

  const ChatDetailSection({
    super.key,
    required this.chat,
    this.isMobile = false,
    this.onMessageSent,
    this.onChatLeft,
  });

  @override
  State<ChatDetailSection> createState() => _ChatDetailSectionState();
}

class _ChatDetailSectionState extends State<ChatDetailSection> {
  final TextEditingController _messageController = TextEditingController();
  record.AudioRecorder? _record;
  late final BaseAudioPlayer _appAudioPlayer = getAudioPlayer();

  List<Map<String, dynamic>> _messages = [];
  bool isLoading = true;
  bool _isRecording = false;
  bool _isAudioLoading = false;
  int _recordingSeconds = 0;
  Timer? _recordTimer;
  String? _playingMessageId;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;

  Map<String, dynamic>? _replyingTo;
  bool _showEmojiPicker = false;

  Map<String, dynamic>? _chatPresence;

  Map<String, dynamic> get _chat =>
      _chatPresence ?? widget.chat;

  StreamSubscription? _messageSubscription;
  StreamSubscription? _deletedMessageSubscription;
  Timer? _presenceTimer;
  Timer? _pingTimer;
  bool _isRefreshingPresence = false;

  Map<String, dynamic> _processMessage(Map<String, dynamic> msg) {
    if (msg['encryption_version'] == 1) {
      if (!EncryptionService().isInitialized) {
        msg['_decrypt_failed'] = true;
        return msg;
      }
      final messageKeys = msg['message_keys'] as List<dynamic>? ?? [];
      final deviceId = EncryptionService().deviceId;
      
      // Look for envelope for this device
      final envelope = messageKeys.firstWhere(
        (k) => k['device_id'] == deviceId,
        orElse: () => null,
      );

      if (envelope == null) {
        msg['_decrypt_failed'] = true;
        return msg;
      }

      final plaintext = EncryptionService().decryptMessageMultiDevice(
        msg['ciphertext'] ?? '',
        msg['iv'] ?? '',
        envelope['encrypted_key'] ?? '',
      );

      if (plaintext == null) {
        msg['_decrypt_failed'] = true;
      } else {
        msg['text'] = plaintext;
        msg['_decrypt_failed'] = false;
      }
    } else {
      msg['_decrypt_failed'] = false;
    }
    return msg;
  }

  @override
  void initState() {
    super.initState();
    _record = record.AudioRecorder();
    ChatService.markAsRead(widget.chat['id'].toString());
    _loadMessages();
    _messageSubscription = ChatService.messageStream.listen((msg) {
      if (msg['chat_id'] == widget.chat['id'].toString()) {
        if (mounted) {
          ChatService.markAsRead(widget.chat['id'].toString());
          setState(() {
            if (!_messages.any((m) => m['id'].toString() == msg['id'].toString())) {
              final processed = _processMessage(Map<String, dynamic>.from(msg));
              _messages.insert(0, processed);
            }
          });
        }
      }
    });

    _deletedMessageSubscription = ChatService.deletedMessageStream.listen((data) {
      if (data['chat_id'] == widget.chat['id'].toString()) {
        if (mounted) {
          setState(() {
            _messages.removeWhere((m) => m['id'].toString() == data['id'].toString());
          });
        }
      }
    });

    // Ping presence setiap 5 detik
    _pingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (mounted) ChatService.pingPresence();
      },
    );
    // Refresh header presence setiap 10 detik
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (mounted && !_isRefreshingPresence) _refreshPresence();
      },
    );
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _presenceTimer?.cancel();
    _recordTimer?.cancel();
    _messageSubscription?.cancel();
    _deletedMessageSubscription?.cancel();
    _messageController.dispose();
    _appAudioPlayer.dispose();
    _record?.dispose();
    super.dispose();
  }

  Future<void> _refreshPresence() async {
    _isRefreshingPresence = true;
    try {
      final chats = await ChatService.fetchChats();
      if (!mounted) return;
      final chatId = widget.chat['id'].toString();
      for (final chat in chats) {
        if (chat['id'].toString() == chatId) {
          setState(() {
            _chatPresence = Map<String, dynamic>.from(chat);
          });
          break;
        }
      }
    } catch (e) {
      debugPrint('Detail presence refresh error: $e');
    } finally {
      _isRefreshingPresence = false;
    }
  }

  @override
  void didUpdateWidget(ChatDetailSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chat['id'] != widget.chat['id']) {
      ChatService.markAsRead(widget.chat['id'].toString());
      _loadMessages();
    }
  }

  Future<void> _loadMessages() async {
    if (mounted) setState(() => isLoading = true);
    try {
      final msgs = await ChatService.fetchMessages(
        widget.chat['id'].toString(),
      );
      if (mounted) {
        setState(() {
          _messages = msgs.map((m) {
            final map = Map<String, dynamic>.from(m);
            return _processMessage(map);
          }).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      debugPrint('Error loading messages: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      final replyId = _replyingTo?['id']?.toString();
      _messageController.clear();
      setState(() {
        _replyingTo = null;
        _showEmojiPicker = false;
      });
      try {
        final result = await ChatService.sendMessage(
          widget.chat['id'].toString(),
          text,
          replyToId: replyId,
        );
        final msgData = result['data'];
        if (msgData != null) {
          setState(() {
            if (!_messages.any((m) => m['id'].toString() == msgData['id'].toString())) {
              final processed = _processMessage(Map<String, dynamic>.from(msgData));
              _messages.insert(0, processed);
            }
          });
        }
        widget.onMessageSent?.call();
      } catch (e) {
        debugPrint('Error sending message: $e');
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopAndSendRecording();
      return;
    }

    try {
      _record ??= record.AudioRecorder();
      final recorder = _record!;
      final hasPermission = await recorder.hasPermission();
      if (!hasPermission) {
        AppSnackbar.error(context, 'Izin mikrofon diperlukan untuk voice note.');
        return;
      }

      try {
        HapticFeedback.heavyImpact();
      } catch (_) {}

      if (kIsWeb) {
        await recorder.start(
          const record.RecordConfig(
            encoder: record.AudioEncoder.opus,
          ),
          path: '',
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        final fileName = 'kreavana_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        final filePath = '${tempDir.path}/$fileName';

        await recorder.start(
          const record.RecordConfig(
            encoder: record.AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: filePath,
        );
      }

      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingSeconds++;
          });
        }
      });
    } catch (e) {
      AppSnackbar.error(context, AppErrors.friendly(e));
    }
  }

  Future<void> _stopAndSendRecording() async {
    _recordTimer?.cancel();
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    final recordPath = await _record?.stop();
    final replyId = _replyingTo?['id']?.toString();

    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
      _replyingTo = null;
    });

    if (recordPath != null && recordPath.isNotEmpty) {
      setState(() => _isAudioLoading = true);
      try {
        Map<String, dynamic> result;
        if (kIsWeb) {
          final response = await http.get(Uri.parse(recordPath));
          final bytes = response.bodyBytes;
          result = await ChatService.sendAudioBytes(
            widget.chat['id'].toString(),
            bytes,
            'audio/webm',
            replyToId: replyId,
          );
        } else {
          result = await ChatService.sendAudioMessage(
            widget.chat['id'].toString(),
            recordPath,
            replyToId: replyId,
          );
        }

        final msgData = result['data'];
        if (msgData != null) {
          setState(() {
            if (!_messages.any((m) => m['id'].toString() == msgData['id'].toString())) {
              _messages.insert(0, Map<String, dynamic>.from(msgData));
            }
          });
        }
        widget.onMessageSent?.call();
      } catch (e) {
        if (mounted) AppSnackbar.error(context, AppErrors.friendly(e));
      } finally {
        if (mounted) setState(() => _isAudioLoading = false);
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
    await _record?.stop();
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });
  }

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _toggleAudioPlayback(Map<String, dynamic> message) async {
    if (message['media_url'] == null || message['media_url'].toString().isEmpty) {
      return;
    }

    final messageId = message['id']?.toString() ?? '';
    if (_playingMessageId == messageId && _appAudioPlayer.isPlaying) {
      await _appAudioPlayer.pause();
      setState(() => _playingMessageId = null);
      return;
    }

    try {
      setState(() {
        _isAudioLoading = true;
        _playingMessageId = messageId;
        _audioPosition = Duration.zero;
        _audioDuration = Duration.zero;
      });

      await _appAudioPlayer.playUrl(
        message['media_url'].toString(),
        onDuration: (duration) {
          if (mounted && _playingMessageId == messageId) {
            setState(() => _audioDuration = duration);
          }
        },
        onPosition: (position) {
          if (mounted && _playingMessageId == messageId) {
            setState(() => _audioPosition = position);
          }
        },
        onCompleted: () {
          if (mounted && _playingMessageId == messageId) {
            setState(() {
              _playingMessageId = null;
              _audioPosition = Duration.zero;
            });
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() => _playingMessageId = null);
            AppSnackbar.error(context, err);
          }
        },
      );
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppErrors.friendly(e));
    } finally {
      if (mounted) {
        setState(() {
          _isAudioLoading = false;
        });
      }
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> message, String scope) async {
    try {
      final result = await ChatService.deleteMessage(
        widget.chat['id'].toString(),
        message['id'].toString(),
        scope: scope,
      );
      if (result['status'] == true) {
        if (mounted) {
          setState(() {
            _messages.removeWhere((m) => m['id'] == message['id']);
          });
        }
        widget.onMessageSent?.call();
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppErrors.friendly(e));
    }
  }

  Widget _buildAudioMessageBubble(Map<String, dynamic> message, bool isMe) {
    final messageId = message['id']?.toString() ?? '';
    final isPlaying = _playingMessageId == messageId && _appAudioPlayer.isPlaying;
    final progress = _audioDuration.inMilliseconds > 0
        ? _audioPosition.inMilliseconds / _audioDuration.inMilliseconds
        : 0.0;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _toggleAudioPlayback(message),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  size: 28,
                  color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voice note',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isMe
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _audioDuration > Duration.zero
                            ? '${_audioDuration.inSeconds}s'
                            : 'Sentuh untuk memutar',
                        style: TextStyle(
                          fontSize: 12,
                          color: isMe
                              ? theme.colorScheme.onPrimary.withValues(alpha: 0.75)
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isAudioLoading && _playingMessageId == messageId)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_audioDuration > Duration.zero)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor:
                  (isMe ? theme.colorScheme.onPrimary : theme.colorScheme.surfaceContainerHighest)
                      .withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                isMe ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReplyQuote(Map<String, dynamic> replyTo, bool isMe) {
    final theme = Theme.of(context);
    final sender = replyTo['sender']?.toString() ?? 'Pengguna';
    final text = replyTo['type'] == 'audio'
        ? '🎵 Voice note'
        : (replyTo['text']?.toString() ?? 'Pesan');

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withValues(alpha: 0.2)
            : theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white : theme.colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sender,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isMe ? Colors.white : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isMe
                  ? Colors.white.withValues(alpha: 0.9)
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageActions(Map<String, dynamic> message) {
    final isMe = message['isMe'] == true;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply_rounded, color: AppTheme.primaryPurple),
                title: const Text('Balas Pesan'),
                subtitle: const Text('Kutip pesan ini untuk membalas'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _replyingTo = message;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.orange),
                title: const Text('Hapus untuk saya'),
                subtitle: const Text('Hapus hanya dari tampilan Anda'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message, 'me');
                },
              ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                  title: const Text('Hapus untuk semua orang'),
                  subtitle: const Text('Hapus pesan untuk semua orang dalam obrolan'),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteForEveryone(message);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Batal'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteForEveryone(Map<String, dynamic> message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus untuk semua orang?'),
        content: const Text('Pesan ini akan dihapus permanen untuk Anda dan lawan bicara.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              Navigator.pop(context);
              _deleteMessage(message, 'everyone');
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendSystemMessage(String text) async {
    try {
      final result = await ChatService.sendMessage(
        widget.chat['id'].toString(),
        text,
      );
      final msgData = result['data'];
      if (msgData != null) {
        setState(() {
          _messages.insert(0, Map<String, dynamic>.from(msgData));
        });
      }
      widget.onMessageSent?.call();
    } catch (e) {
      debugPrint('Error sending system message: $e');
    }
  }

  // ── Helpers header & info kontak ───────────────────────────────────────────

  String get _headerSubtitle {
    if (_chat['isGroup'] == true) {
      return 'Ketuk untuk info grup';
    }

    final isTyping = _chat['isTyping'] == true;
    if (isTyping) {
      return 'Sedang mengetik...';
    }

    final isOnline = _chat['isOnline'] == true;
    if (isOnline) {
      return 'Online';
    }

    final lastOnline = _formatLastOnline(
      (_chat['last_online'] ?? _chat['lastOnline'] ?? _chat['last_seen'] ?? _chat['lastSeen'])?.toString() ?? '',
    );
    if (lastOnline.isNotEmpty) {
      return 'Offline • terakhir online $lastOnline';
    }

    final username = _chat['username']?.toString();
    if (username != null && username.isNotEmpty) {
      return '@$username';
    }
    return 'Kreavana User';
  }

  String _formatLastOnline(String value) {
    if (value.isEmpty) return '';
    // Already formatted by backend (e.g. "5 menit lalu", "Kemarin")
    if (!value.contains('T') && !value.contains('-')) return value;
    try {
      final timestamp = DateTime.tryParse(value);
      if (timestamp == null) return value;
      final diff = DateTime.now().difference(timestamp);
      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
      if (diff.inHours < 24) return '${diff.inHours} jam lalu';
      if (diff.inDays < 7) return '${diff.inDays} hari lalu';
      return '${diff.inDays} hari lalu';
    } catch (_) {
      return value;
    }
  }

  Widget _buildHeaderAvatar(ThemeData theme) {
    final isGroup = _chat['isGroup'] == true;
    final name = _chat['name']?.toString() ?? 'U';
    final avatarUrl = ApiService.resolveAssetUrl(_chat['avatar_url']?.toString() ?? '');

    return CircleAvatar(
      radius: 20,
      backgroundColor: isGroup
          ? theme.colorScheme.tertiaryContainer
          : AppTheme.primaryPurple.withValues(alpha: 0.12),
      backgroundImage: isGroup
          ? null
          : NetworkImage(
              avatarUrl.isNotEmpty
                  ? avatarUrl
                  : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=7C3AED&color=fff&size=128',
            ),
      child: isGroup
          ? Icon(
              Icons.groups_rounded,
              color: theme.colorScheme.onTertiaryContainer,
              size: 22,
            )
          : null,
    );
  }

  Future<void> _startCall(bool video) async {
    final userIdStr = _chat['user_id']?.toString() ?? _chat['userId']?.toString() ?? '';
    if (userIdStr.isEmpty) {
      if (mounted) {
        AppSnackbar.error(context, 'Tidak dapat melakukan panggilan: ID pengguna tidak tersedia.');
      }
      return;
    }

    try {
      final callService = CallService();
      await callService.initPusher();
      await callService.startCall(
        userIdStr,
        video,
        remoteUserName: _chat['name'] ?? 'User',
        remoteAvatarUrl: ApiService.resolveAssetUrl(_chat['avatar_url'] ?? ''),
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CallScreen(
            callService: callService,
            remoteUserName: _chat['name'] ?? 'User',
            remoteAvatarUrl: ApiService.resolveAssetUrl(_chat['avatar_url'] ?? ''),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, AppErrors.friendly(e));
      }
    }
  }

  void _showContactInfoSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chat = _chat;
    final isGroup = chat['isGroup'] == true;
    final isTyping = chat['isTyping'] == true;
    final isOnline = chat['isOnline'] == true;

    final name = chat['name']?.toString() ?? 'Unknown';
    final username = chat['username']?.toString();
    final phone = chat['phone']?.toString() ?? '';
    final email = chat['email']?.toString();
    final avatarUrl = ApiService.resolveAssetUrl(chat['avatar_url']?.toString() ?? '');
    final lastOnline = (chat['last_online'] ?? chat['lastOnline'] ?? chat['last_seen'] ?? chat['lastSeen'])?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.12),
                  backgroundImage: isGroup
                      ? null
                      : NetworkImage(
                          avatarUrl.isNotEmpty
                              ? avatarUrl
                              : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=7C3AED&color=fff&size=128',
                        ),
                  child: isGroup
                      ? Icon(
                          Icons.groups_rounded,
                          size: 34,
                          color: theme.colorScheme.onTertiaryContainer,
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (username != null && username.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '@$username',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.grey.shade500,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (isTyping)
                  _InfoRow(
                    icon: Icons.edit_note_rounded,
                    label: 'Sedang mengetik...',
                  )
                else if (isOnline)
                  _InfoRow(
                    icon: Icons.circle,
                    label: 'Online',
                  )
                else if (lastOnline.isNotEmpty)
                  _InfoRow(
                    icon: Icons.access_time,
                    label: 'Terakhir online $lastOnline',
                  ),
                const SizedBox(height: 8),
                if (!isGroup && phone.isNotEmpty)
                  _InfoRow(
                    icon: Icons.phone_rounded,
                    label: phone,
                    onTap: () {
                      Navigator.pop(ctx);
                      _showDialerSheet();
                    },
                  ),
                if (!isGroup && email != null && email.isNotEmpty)
                  _InfoRow(
                    icon: Icons.email_rounded,
                    label: email,
                  ),
                if (isGroup)
                  _InfoRow(
                    icon: Icons.groups_rounded,
                    label: 'Grup',
                  ),
                const SizedBox(height: 20),

                if (!isGroup)
                  Row(
                    children: [
                      Expanded(
                        child: _ContactAction(
                          icon: Icons.chat_bubble_rounded,
                          label: 'Chat',
                          color: AppTheme.primaryPurple,
                          onTap: () => Navigator.pop(ctx),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ContactAction(
                          icon: Icons.call_rounded,
                          label: 'Telepon',
                          color: AppTheme.success,
                          onTap: () {
                            Navigator.pop(ctx);
                            _startCall(false);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ContactAction(
                          icon: Icons.videocam_rounded,
                          label: 'Video',
                          color: AppTheme.accentPink,
                          onTap: () {
                            Navigator.pop(ctx);
                            _startCall(true);
                          },
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Kembali ke Obrolan'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDialerSheet() {
    final phone = widget.chat['phone']?.toString() ?? '';
    if (phone.isEmpty) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Nomor Kontak',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.phone_rounded,
                      size: 18,
                      color: AppTheme.success,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      phone,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: phone));
                        Navigator.pop(ctx);
                        AppSnackbar.success(context, 'Nomor disalin');
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Salin'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _startCall(false);
                      },
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: const Text('Telepon'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: widget.isMobile
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: InkWell(
          onTap: () {
            if (widget.chat['isGroup'] == true) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupInfoScreen(
                    chat: widget.chat,
                    onGroupLeft: () {
                      if (widget.isMobile) {
                        Navigator.pop(context);
                      }
                      widget.onChatLeft?.call();
                    },
                  ),
                ),
              );
            } else {
              _showContactInfoSheet();
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              _buildHeaderAvatar(theme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.chat['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _headerSubtitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (widget.chat['isGroup'] != true) ... [
            _CallActionButton(
              icon: Icons.call_rounded,
              tooltip: 'Telepon',
              color: AppTheme.success,
              onPressed: () => _startCall(false),
            ),
            _CallActionButton(
              icon: Icons.videocam_rounded,
              tooltip: 'Video Call',
              color: AppTheme.accentPink,
              onPressed: () => _startCall(true),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Info Kontak',
            onPressed: _showContactInfoSheet,
          ),
          if (widget.isMobile) const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: isLoading
                  ? ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16.0),
                      itemCount: 8,
                      itemBuilder: (context, index) {
                        // Selang-seling kiri dan kanan seperti bubble chat
                        final isRight = index % 3 != 0;
                        return Align(
                          alignment: isRight
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.65,
                            ),
                            child: SkeletonBox(
                              width: isRight ? 180 : 220,
                              height: 44,
                              borderRadius: 16,
                            ),
                          ),
                        );
                      },
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];

                        if (message['_decrypt_failed'] == true) {
                          return const SizedBox.shrink();
                        }

                        final isMe = message['isMe'] == true;
                        final isAudio = message['type'] == 'audio';

                        return AnimatedEntrance(
                          duration: AppMotion.fast,
                          delay: const Duration(milliseconds: 30),
                          child: Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: GestureDetector(
                              onLongPress: () => _showMessageActions(message),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12.0),
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 12.0,
                                ),
                                decoration: BoxDecoration(
                                  gradient: isMe
                                      ? AppTheme.primaryGradient
                                      : null,
                                  color: isMe
                                      ? null
                                      : theme.colorScheme.surface,
                                  borderRadius:
                                      BorderRadius.circular(20).copyWith(
                                    bottomRight: isMe
                                        ? const Radius.circular(4)
                                        : const Radius.circular(20),
                                    bottomLeft: !isMe
                                        ? const Radius.circular(4)
                                        : const Radius.circular(20),
                                  ),
                                  boxShadow: [
                                    if (!isMe)
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (message['reply_to'] != null)
                                      _buildReplyQuote(
                                        Map<String, dynamic>.from(message['reply_to']),
                                        isMe,
                                      ),
                                    if (isAudio)
                                      _buildAudioMessageBubble(message, isMe)
                                    else
                                      Text(
                                        message['text'],
                                        style: TextStyle(
                                          color: isMe
                                              ? theme.colorScheme.onPrimary
                                              : theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          message['time'],
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isMe
                                                ? theme.colorScheme.onPrimary
                                                      .withValues(alpha: 0.7)
                                                : theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        if (isMe) ... [
                                          const SizedBox(width: 4),
                                          Icon(
                                            message['isRead'] == true
                                                ? Icons.done_all_rounded
                                                : Icons.done_rounded,
                                            size: 14,
                                            color: message['isRead'] == true
                                                ? Colors.lightBlueAccent
                                                : theme.colorScheme.onPrimary
                                                      .withValues(alpha: 0.7),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_replyingTo != null) _buildReplyBanner(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      offset: const Offset(0, -2),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: _isRecording
                    ? Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.fiber_manual_record_rounded,
                              color: AppTheme.error,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _formatDuration(_recordingSeconds),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Sedang merekam voice note...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            color: AppTheme.error,
                            tooltip: 'Batal',
                            onPressed: _cancelRecording,
                          ),
                          IconButton(
                            icon: const Icon(Icons.send_rounded),
                            color: theme.colorScheme.primary,
                            tooltip: 'Kirim',
                            onPressed: _stopAndSendRecording,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            color: theme.colorScheme.primary,
                            onPressed: _showAttachmentMenu,
                          ),
                          IconButton(
                            icon: Icon(
                              _showEmojiPicker
                                  ? Icons.keyboard_rounded
                                  : Icons.sentiment_satisfied_alt_rounded,
                            ),
                            color: theme.colorScheme.primary,
                            onPressed: () {
                              setState(() {
                                _showEmojiPicker = !_showEmojiPicker;
                              });
                            },
                          ),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: 'Ketik pesan...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24.0),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                                  alpha: 0.5,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20.0,
                                  vertical: 10.0,
                                ),
                              ),
                              onTap: () {
                                if (_showEmojiPicker) {
                                  setState(() {
                                    _showEmojiPicker = false;
                                  });
                                }
                              },
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.mic_none_rounded),
                            color: theme.colorScheme.primary,
                            tooltip: 'Merekam Voice Note',
                            onPressed: _toggleRecording,
                          ),
                          const SizedBox(width: 4),
                          FloatingActionButton.small(
                            heroTag: null,
                            elevation: 0,
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            onPressed: _sendMessage,
                            child: const Icon(Icons.send),
                          ),
                        ],
                      ),
              ),
              if (_showEmojiPicker) _buildEmojiPicker(),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildEmojiPicker() {
    final emojis = [
      '😀', '😂', '🤣', '😃', '😄', '😅', '😆', '😉', '😊', '😋',
      '😎', '😍', '😘', '🥰', '😗', '😙', '😚', '☺️', '🙂', '🤗',
      '🤩', '🤔', '🤨', '😐', '😑', '😶', '🙄', '😏', '😣', '😥',
      '😮', '🤐', '😯', '😪', '😫', '😴', '😌', '😛', '😜', '😝',
      '🤤', '😒', '😓', '😔', '😕', '🙃', '🤑', '😲', '☹️', '🙁',
      '😖', '😞', '😟', '😤', '😢', '😭', '😦', '😧', '😬', '🤯',
      '😳', '🤪', '😵', '😡', '😠', '🤬', '😷', '🤒', '🤕', '🤢',
      '👍', '👎', '👏', '🙌', '👐', '🤲', '🤝', '🙏', '✌️', '🤞',
      '🤟', '🤘', '🤙', '👈', '👉', '👆', '👇', '☝️', '👋', '🤚',
      '💓', '💔', '💕', '💖', '💗', '💘', '💙', '💚', '💛', '🧡',
      '💜', '🖤', '🤍', '🤎', '💯', '🔥', '✨', '🌟', '🎉', '🎈',
      '💡', '💬', '📱', '💻', '📷', '🎁', '🏆', '🎯', '🎨', '🎵',
    ];

    return Container(
      height: 220,
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: emojis.length,
        itemBuilder: (context, index) {
          final emoji = emojis[index];
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              final text = _messageController.text;
              final selection = _messageController.selection;
              final start = selection.start < 0 ? text.length : selection.start;
              final end = selection.end < 0 ? text.length : selection.end;
              final newText = text.replaceRange(start, end, emoji);
              _messageController.value = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(
                  offset: start + emoji.length,
                ),
              );
            },
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReplyBanner() {
    if (_replyingTo == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final sender = _replyingTo!['sender']?.toString() ?? 'Pengguna';
    final text = _replyingTo!['type'] == 'audio'
        ? '🎵 Voice note'
        : (_replyingTo!['text']?.toString() ?? 'Pesan');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 4),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Membalas $sender',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () {
              setState(() {
                _replyingTo = null;
              });
            },
          ),
        ],
      ),
    );
  }

  void _showAttachmentMenu() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.mic_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Kirim Voice Note'),
                subtitle: const Text(
                  'Rekam suara dan kirim langsung sebagai pesan audio.',
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _toggleRecording();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.payments_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Kirim Saldo'),
                subtitle: const Text(
                  'Kirim pembayaran instan ke lawan obrolan (pajak 5%)',
                ),
                onTap: () async {
                  Navigator.pop(context);
                  if (widget.chat['isGroup'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Kirim saldo hanya didukung untuk obrolan personal.',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  final currentUser = await AuthService.getCurrentUser();
                  if (currentUser == null) return;

                  final partnerUsername = widget.chat['username'];
                  if (partnerUsername == null) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Gagal menemukan username lawan bicara.',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  if (!context.mounted) return;
                  final transferResult = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TransferScreen(
                        user: currentUser,
                        preFilledUsername: partnerUsername,
                      ),
                    ),
                  );

                  if (transferResult is Map && transferResult['success'] == true) {
                    final double amt = transferResult['amount'];
                    final double fee = transferResult['fee'];
                    final amtStr = amt.toStringAsFixed(0).replaceAllMapped(
                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                        (Match m) => '${m[1]}.');
                    final feeStr = fee.toStringAsFixed(0).replaceAllMapped(
                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                        (Match m) => '${m[1]}.');

                    _sendSystemMessage(
                      '💸 Pembayaran Berhasil sebesar Rp $amtStr. (Pajak Platform 5%: Rp $feeStr)',
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class GroupInfoScreen extends StatefulWidget {
  final Map<String, dynamic> chat;
  final VoidCallback? onGroupLeft;

  const GroupInfoScreen({super.key, required this.chat, this.onGroupLeft});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  bool onlyAdminCanAdd = false;
  List<Map<String, dynamic>> members = [];
  bool isLoading = true;
  late String groupName;
  late String groupDescription;

  @override
  void initState() {
    super.initState();
    onlyAdminCanAdd = widget.chat['onlyAdminCanAdd'] ?? false;
    groupName = widget.chat['name'] ?? 'Grup';
    groupDescription = widget.chat['description'] ?? '';
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final msgs = await ChatService.fetchGroupMembers(
        widget.chat['id'].toString(),
      );
      setState(() {
        members = msgs.map((m) => Map<String, dynamic>.from(m)).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _showEditGroupDialog() {
    final nameController = TextEditingController(text: groupName);
    final descController = TextEditingController(text: groupDescription);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Info Grup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Grup',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Deskripsi Grup',
                hintText: 'Tuliskan deskripsi atau tujuan grup...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              try {
                await ChatService.updateGroupDetails(
                  widget.chat['id'].toString(),
                  name,
                  descController.text.trim(),
                );
                setState(() {
                  groupName = name;
                  groupDescription = descController.text.trim();
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Info grup berhasil diperbarui!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gagal memperbarui info grup.')),
                  );
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _addMember() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        bool isSearching = false;
        List<dynamic> searchResults = [];
        List<dynamic> selectedUsers = [];

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            List<dynamic> displayList = List.from(selectedUsers);
            for (var result in searchResults) {
              if (!displayList.any((u) => u['id'] == result['id'])) {
                displayList.add(result);
              }
            }

            return AlertDialog(
              title: const Text('Tambah Anggota'),
              content: SizedBox(
                width: 350,
                height: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'Cari Nama Anggota...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  controller.clear();
                                  setStateDialog(() {
                                    searchResults = [];
                                    isSearching = false;
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) async {
                        setStateDialog(() {
                          isSearching = true;
                        });
                        if (value.isNotEmpty) {
                          try {
                            final results = await ChatService.searchUsers(
                              value,
                            );
                            setStateDialog(() {
                              searchResults = results;
                              isSearching = false;
                            });
                          } catch (e) {
                            setStateDialog(() => isSearching = false);
                          }
                        } else {
                          setStateDialog(() {
                            searchResults = [];
                            isSearching = false;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    if (isSearching)
                      const CircularProgressIndicator()
                    else if (controller.text.isNotEmpty &&
                        searchResults.isEmpty &&
                        selectedUsers.isEmpty)
                      const Text(
                        'Pengguna tidak ditemukan',
                        style: TextStyle(color: Colors.red),
                      )
                    else if (displayList.isNotEmpty)
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: displayList.length,
                          itemBuilder: (context, index) {
                            final user = displayList[index];
                            final isAlreadyMember = members.any(
                              (m) => m['id'] == user['id'],
                            );
                            final isSelected = selectedUsers.any(
                              (u) => u['id'] == user['id'],
                            );

                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: Text(user['name']),
                              subtitle: Text(
                                isAlreadyMember
                                    ? 'Sudah berada di dalam grup'
                                    : user['email'],
                              ),
                              enabled: !isAlreadyMember,
                              trailing: isAlreadyMember
                                  ? const Icon(Icons.groups, color: Colors.grey)
                                  : Checkbox(
                                      value: isSelected,
                                      onChanged: (val) {
                                        setStateDialog(() {
                                          if (val == true) {
                                            selectedUsers.add(user);
                                          } else {
                                            selectedUsers.removeWhere(
                                              (u) => u['id'] == user['id'],
                                            );
                                          }
                                        });
                                      },
                                    ),
                              onTap: isAlreadyMember
                                  ? null
                                  : () {
                                      setStateDialog(() {
                                        if (isSelected) {
                                          selectedUsers.removeWhere(
                                            (u) => u['id'] == user['id'],
                                          );
                                        } else {
                                          selectedUsers.add(user);
                                        }
                                      });
                                    },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: selectedUsers.isEmpty
                      ? null
                      : () async {
                          for (var user in selectedUsers) {
                            try {
                              await ChatService.addGroupMember(
                                widget.chat['id'].toString(),
                                user['id'],
                              );
                            } catch (e) {
                              debugPrint('Failed to add ${user['id']}: $e');
                            }
                          }
                          _loadMembers();
                          if (context.mounted) Navigator.pop(context);
                        },
                  child: const Text('Tambah'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Info Grup'),
        backgroundColor: theme.colorScheme.surface,
        actions: [
          // Tombol edit hanya muncul jika user adalah admin
          if (members.any((m) => m['name'] == 'Anda' && m['isAdmin'] == true))
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Nama & Deskripsi',
              onPressed: _showEditGroupDialog,
            ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          Center(
            child: CircleAvatar(
              radius: 60,
              backgroundColor: theme.colorScheme.tertiaryContainer,
              child: Icon(
                Icons.group,
                size: 60,
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              groupName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Center(
            child: Text(
              'Grup · ${members.length} Anggota',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          // Tampilkan deskripsi jika ada
          if (groupDescription.isNotEmpty) ... [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                groupDescription,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Divider(
            thickness: 8,
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          ),

          // Pengaturan
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Pengaturan Grup'),
            subtitle: const Text(
              'Hanya Admin yang dapat menambahkan anggota baru',
            ),
            trailing: Switch(
              value: onlyAdminCanAdd,
              activeThumbColor: theme.colorScheme.primary,
              onChanged: (val) {
                ChatService.updateGroupSettings(
                  widget.chat['id'].toString(),
                  val,
                ).then((_) {
                  setState(() {
                    onlyAdminCanAdd = val;
                  });
                });
              },
            ),
          ),
          Divider(
            thickness: 8,
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          ),

          // Daftar Anggota
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${members.length} Anggota',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Icon(Icons.search, color: Colors.grey),
              ],
            ),
          ),

          // Tombol Tambah Anggota
          ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              child: Icon(Icons.person_add, color: theme.colorScheme.onPrimary),
            ),
            title: const Text(
              'Tambah Anggota',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            onTap: () {
              if (onlyAdminCanAdd) {
                // Check if I am admin
                final myMember = members.firstWhere(
                  (m) => m['name'] == 'Anda',
                  orElse: () => {'isAdmin': false},
                );
                final isMeAdmin = myMember['isAdmin'];
                if (!isMeAdmin) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Hanya Admin yang dapat menambahkan anggota!',
                      ),
                    ),
                  );
                  return;
                }
              }
              _addMember();
            },
          ),

          if (isLoading)
            ...List.generate(
              4,
              (i) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ChatListSkeleton(),
              ),
            )
          else
            ...members.map(
              (m) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  backgroundImage: NetworkImage(
                    'https://ui-avatars.com/api/?name=${m['name']}&background=random',
                  ),
                ),
                title: Text(
                  m['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: m['name'] == 'Anda' ? const Text('Ponsel ini') : null,
                trailing: m['isAdmin']
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Admin',
                          style: TextStyle(
                            color: theme.colorScheme.onTertiaryContainer,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
                onTap: m['name'] == 'Anda'
                    ? null
                    : () {
                        final myMember = members.firstWhere(
                          (memb) => memb['name'] == 'Anda',
                          orElse: () => {'isAdmin': false},
                        );
                        if (myMember['isAdmin']) {
                          showModalBottomSheet(
                            context: context,
                            builder: (context) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(
                                      Icons.admin_panel_settings,
                                    ),
                                    title: const Text('Jadikan Admin'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      ChatService.makeAdmin(
                                        widget.chat['id'].toString(),
                                        m['id'].toString(),
                                      ).then((_) => _loadMembers());
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(
                                      Icons.person_remove,
                                      color: Colors.red,
                                    ),
                                    title: const Text(
                                      'Keluarkan dari Grup',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      ChatService.kickMember(
                                        widget.chat['id'].toString(),
                                        m['id'].toString(),
                                      ).then((_) => _loadMembers());
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      },
              ),
            ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: OutlinedButton.icon(
              onPressed: () {
                ChatService.leaveGroup(widget.chat['id'].toString()).then((_) {
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  widget.onGroupLeft?.call();
                });
              },
              icon: const Icon(Icons.exit_to_app, color: Colors.red),
              label: const Text(
                'Keluar dari Grup',
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Call Action Button (header chat) ────────────────────────────────────────

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  const _CallActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: color.withValues(alpha: 0.1),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(icon, size: 20, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Info Row (bottom sheet info kontak) ─────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _InfoRow({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.inputDark : AppTheme.inputLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primaryPurple),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Contact Action (tombol cepat di bottom sheet) ───────────────────────────

class _ContactAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ContactAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
