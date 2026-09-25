import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/theme.dart';
import '../services/ai_service.dart';
import '../models/user_model.dart';
import '../models/opportunity_model.dart';
import '../features/auth/services/auth_service.dart';
import '../widgets/auth_guard_dialog.dart';
import '../widgets/upgrade_plan_modal.dart';
import '../widgets/opportunity_detail_sheet.dart';
import '../widgets/app_sweet_alert.dart';
import 'package:go_router/go_router.dart';
import '../services/app_router.dart';
import '../screens/explore_screen.dart';
import '../services/user_store.dart';

/// Floating Assistant Widget that opens the Kreavana.AI Dedicated Screen.
/// Supports both Light and Dark themes, draggable across Mobile & Desktop viewports.
class KreavanaAiFloatingWidget extends StatefulWidget {
  final bool hasPageFab;
  const KreavanaAiFloatingWidget({super.key, this.hasPageFab = false});

  @override
  State<KreavanaAiFloatingWidget> createState() =>
      _KreavanaAiFloatingWidgetState();
}

class _KreavanaAiFloatingWidgetState extends State<KreavanaAiFloatingWidget> {
  static Offset? _savedPosition;
  Offset? _position;
  bool _isDragging = false;
  bool _hasDragged = false;
  Offset? _dragStartPos;

  static const double _buttonWidth = 156.0;
  static const double _buttonHeight = 46.0;

  void _toggleWidget() {
    context.go(AppRoutes.aiAssistant);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width >= 768;

    final maxLeft = (screenSize.width - _buttonWidth - 12.0).clamp(
      12.0,
      double.infinity,
    );
    final maxTop = (screenSize.height - _buttonHeight - 12.0).clamp(
      12.0,
      double.infinity,
    );

    // Calculate or clamp position to viewport
    if (_savedPosition != null) {
      _position = Offset(
        _savedPosition!.dx.clamp(12.0, maxLeft),
        _savedPosition!.dy.clamp(12.0, maxTop),
      );
    } else {
      final initialBottomOffset = isDesktop
          ? (widget.hasPageFab ? 96.0 : 32.0)
          : (widget.hasPageFab ? 150.0 : 88.0);
      _position = Offset(
        (screenSize.width - _buttonWidth - 24.0).clamp(12.0, maxLeft),
        (screenSize.height - _buttonHeight - initialBottomOffset).clamp(
          12.0,
          maxTop,
        ),
      );
    }

    return Positioned(
      left: _position!.dx,
      top: _position!.dy,
      child: MouseRegion(
        cursor: _isDragging
            ? SystemMouseCursors.grabbing
            : SystemMouseCursors.grab,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            _dragStartPos = details.globalPosition;
            _hasDragged = false;
            setState(() {
              _isDragging = true;
            });
          },
          onPanUpdate: (details) {
            if (_dragStartPos != null) {
              if ((details.globalPosition - _dragStartPos!).distance > 4.0) {
                _hasDragged = true;
              }
            }
            final nextX = (_position!.dx + details.delta.dx).clamp(
              12.0,
              maxLeft,
            );
            final nextY = (_position!.dy + details.delta.dy).clamp(
              12.0,
              maxTop,
            );
            setState(() {
              _position = Offset(nextX, nextY);
              _savedPosition = _position;
            });
          },
          onPanEnd: (details) {
            setState(() {
              _isDragging = false;
            });
            Future.delayed(const Duration(milliseconds: 150), () {
              if (mounted) {
                _hasDragged = false;
              }
            });
          },
          onPanCancel: () {
            setState(() {
              _isDragging = false;
            });
            _hasDragged = false;
          },
          onTap: () {
            if (!_hasDragged) {
              _toggleWidget();
            }
          },
          child: Material(
            color: Colors.transparent,
            elevation: _isDragging ? 12 : 6,
            shadowColor: AppTheme.primaryPurple.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24),
            child: AnimatedScale(
              scale: _isDragging ? 1.04 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: Container(
                width: _buttonWidth,
                height: _buttonHeight,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryPurple.withValues(
                        alpha: _isDragging ? 0.6 : 0.35,
                      ),
                      blurRadius: _isDragging ? 16 : 10,
                      offset: Offset(0, _isDragging ? 6 : 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        'assets/brandlogo.png',
                        width: 22,
                        height: 22,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Kreavana AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.drag_indicator_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The sleek Kreavana.AI assistant window panel matching the user reference image.
class KreavanaAiPanel extends StatefulWidget {
  final bool isDesktop;
  final VoidCallback? onClose;
  final VoidCallback? onMinimize;

  const KreavanaAiPanel({
    super.key,
    required this.isDesktop,
    this.onClose,
    this.onMinimize,
  });

  @override
  State<KreavanaAiPanel> createState() => _KreavanaAiPanelState();
}

class _KreavanaAiPanelState extends State<KreavanaAiPanel> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  final List<_AiChatSession> _sessions = [];
  String _currentSessionId = '';
  bool _isLoadingHistory = false;
  bool _isRightHistoryOpen = true;
  String _historySearchQuery = '';

  final bool _isDataKreavanaActive = true;
  String? _attachedFileName;
  bool _isLoading = false;

  void _selectSession(String sessionId) {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx >= 0) {
      final session = _sessions[idx];
      setState(() {
        _currentSessionId = session.id;
        _messages.clear();
        _messages.addAll(session.messages);
      });
      _scrollToBottom();
    }
  }

  void _deleteSession(String sessionId) {
    final deletedId = sessionId;
    final isCurrent = _currentSessionId == deletedId;
    setState(() {
      _sessions.removeWhere((s) => s.id == deletedId);
      if (isCurrent) {
        _messages.clear();
        _currentSessionId = '';
      }
    });
    if (currentUserNotifier.value != null) {
      AiService.deleteChatSession(deletedId);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadHistoryFromBackend();
    currentUserNotifier.addListener(_onUserChanged);
  }

  @override
  void dispose() {
    currentUserNotifier.removeListener(_onUserChanged);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onUserChanged() {
    if (mounted) {
      _loadHistoryFromBackend();
    }
  }

  Future<void> _loadHistoryFromBackend() async {
    final user = currentUserNotifier.value;
    if (user == null) return;

    if (mounted) setState(() => _isLoadingHistory = true);

    try {
      final remoteSessions = await AiService.getChatSessions();
      if (!mounted) return;

      if (remoteSessions.isNotEmpty) {
        setState(() {
          _sessions.clear();
          for (final s in remoteSessions) {
            _sessions.add(_AiChatSession.fromJson(s));
          }
        });
      }
    } catch (_) {
      // Silently keep local state if offline
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  final List<Map<String, dynamic>> _examplePrompts = [
    {
      'title': 'Tentang Kreavana',
      'subtitle': 'Apa itu Kreavana? Bagaimana cara kerjanya?',
      'icon': Icons.person_rounded,
      'color': Color(0xFF8B5CF6), // Purple
      'category': 'about',
      'prompt': 'Apa itu Kreavana? Bagaimana cara kerjanya?',
    },
    {
      'title': 'Rekomendasi Kreator',
      'subtitle': 'Rekomendasi photographer untuk wedding di Bandung.',
      'icon': Icons.search_rounded,
      'color': Color(0xFF3B82F6), // Blue
      'category': 'creator',
      'prompt': 'Rekomendasi photographer untuk wedding di Bandung.',
    },
    {
      'title': 'Event & Acara',
      'subtitle': 'Event apa saja yang sedang berlangsung di Jakarta?',
      'icon': Icons.calendar_today_rounded,
      'color': Color(0xFF10B981), // Emerald/Green
      'category': 'event',
      'prompt': 'Event apa saja yang sedang berlangsung di Jakarta?',
    },
    {
      'title': 'Spot Terbaik',
      'subtitle': 'Spot terbaik untuk mengadakan event outdoor di Bali.',
      'icon': Icons.location_on_rounded,
      'color': Color(0xFFF59E0B), // Amber/Orange
      'category': 'spot',
      'prompt': 'Spot terbaik untuk mengadakan event outdoor di Bali.',
    },
    {
      'title': 'Tips & Panduan',
      'subtitle': 'Tips memilih videographer yang cocok untuk brand.',
      'icon': Icons.lightbulb_outline_rounded,
      'color': Color(0xFFEC4899), // Pink
      'category': 'tips',
      'prompt': 'Tips memilih videographer yang cocok untuk brand.',
    },
    {
      'title': 'Lainnya',
      'subtitle': 'Tanyakan apa saja seputar Kreavana dan ekosistemnya.',
      'icon': Icons.favorite_outline_rounded,
      'color': Color(0xFFF43F5E), // Rose/Red
      'category': 'general',
      'prompt': 'Tanyakan apa saja seputar Kreavana dan ekosistemnya.',
    },
  ];

  void _clearChat() {
    if (_messages.isNotEmpty) {
      _syncCurrentSession();
    }
    setState(() {
      _messages.clear();
      _currentSessionId = '';
      _attachedFileName = null;
    });
    AppSweetAlert.info(
      context,
      'Sesi baru dimulai. Percakapan sebelumnya tersimpan di Riwayat akun.',
      title: 'Sesi Baru',
    );
  }

  void _syncCurrentSession({bool saveToRemote = true}) {
    if (_messages.isEmpty) return;
    if (_currentSessionId.isEmpty) {
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    }

    final firstUserMsg =
        _messages.firstWhere(
              (m) => m['sender'] == 'user',
              orElse: () => {'text': 'Percakapan AI'},
            )['text']
            as String;

    final cleanTitle = firstUserMsg.replaceAll(RegExp(r'\s+'), ' ').trim();
    final shortTitle = cleanTitle.length > 45
        ? '${cleanTitle.substring(0, 45)}...'
        : cleanTitle;

    final idx = _sessions.indexWhere((s) => s.id == _currentSessionId);
    if (idx >= 0) {
      _sessions[idx].title = shortTitle;
      _sessions[idx].messages.clear();
      _sessions[idx].messages.addAll(_messages);
    } else {
      _sessions.insert(
        0,
        _AiChatSession(
          id: _currentSessionId,
          title: shortTitle,
          createdAt: DateTime.now(),
          messages: List.from(_messages),
        ),
      );
    }

    // Persist to user account in backend
    if (saveToRemote && currentUserNotifier.value != null) {
      final sessId = _currentSessionId;
      final copyMsgs = List<Map<String, dynamic>>.from(_messages);
      AiService.syncChatSession(
        sessionId: sessId,
        title: shortTitle,
        messages: copyMsgs,
      );
    }
  }

  void _showHistoryModal(bool isDark) {
    // Ensure current session is synced before showing history
    _syncCurrentSession();
    // Also trigger background fetch for freshest history across devices
    if (currentUserNotifier.value != null) {
      _loadHistoryFromBackend();
    }

    final currentUser = currentUserNotifier.value;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.72,
          ),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141829) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark ? const Color(0xFF252D48) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    color: AppTheme.primaryPurple,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Riwayat Obrolan Kreavana AI',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  if (_sessions.isNotEmpty)
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Hapus Semua Riwayat?'),
                            content: const Text(
                              'Semua riwayat obrolan Kreavana AI Anda akan dihapus permanen dari akun ini.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Batal'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text(
                                  'Hapus',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          setModalState(() {
                            _sessions.clear();
                            _messages.clear();
                            _currentSessionId = '';
                          });
                          setState(() {});
                          if (currentUserNotifier.value != null) {
                            AiService.clearChatSessions();
                          }
                        }
                      },
                      child: Text(
                        'Hapus Semua',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.red.shade300
                              : Colors.red.shade600,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: isDark ? Colors.white54 : Colors.black54,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (currentUser != null) ...[
                    Icon(
                      Icons.cloud_done_rounded,
                      size: 13,
                      color: isDark
                          ? const Color(0xFF10B981)
                          : const Color(0xFF059669),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      currentUser != null
                          ? 'Tersimpan aman di akun ${currentUser.name}. Tersinkron di Web, Android & iOS.'
                          : 'Pilih obrolan sebelumnya untuk melihat kembali jawaban tanpa mengirim ulang:',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_isLoadingHistory && _sessions.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 40,
                    horizontal: 20,
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Memuat riwayat obrolan dari akun...',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_sessions.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 36,
                    horizontal: 20,
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 38,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Belum ada riwayat percakapan.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentUser != null
                            ? 'Percakapan Anda akan otomatis tersimpan di akun ${currentUser.name} agar dapat ditinjau kembali kapan saja dari perangkat apa pun.'
                            : 'Percakapan kamu akan otomatis tersimpan di sini agar dapat ditinjau kembali kapan saja.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _sessions.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: isDark
                          ? const Color(0xFF242C48)
                          : const Color(0xFFF1F5F9),
                    ),
                    itemBuilder: (context, idx) {
                      final session = _sessions[idx];
                      final isCurrent =
                          session.id == _currentSessionId &&
                          _messages.isNotEmpty;
                      final dateStr =
                          '${session.createdAt.hour.toString().padLeft(2, '0')}:${session.createdAt.minute.toString().padLeft(2, '0')}';

                      String snippet = '';
                      for (final m in session.messages.reversed) {
                        if (m['sender'] == 'ai') {
                          snippet = (m['text'] as String)
                              .replaceAll(RegExp(r'[#*•\n]'), ' ')
                              .replaceAll(RegExp(r'\s+'), ' ')
                              .trim();
                          if (snippet.length > 65) {
                            snippet = '${snippet.substring(0, 65)}...';
                          }
                          break;
                        }
                      }

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? AppTheme.primaryPurple.withValues(alpha: 0.18)
                                : (isDark
                                      ? const Color(0xFF1E2438)
                                      : const Color(0xFFF3F4F6)),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCurrent
                                ? Icons.mark_chat_read_rounded
                                : Icons.chat_bubble_outline_rounded,
                            size: 18,
                            color: isCurrent
                                ? AppTheme.primaryPurple
                                : (isDark ? Colors.white60 : Colors.black54),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                session.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isCurrent
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: isCurrent
                                      ? AppTheme.primaryPurple
                                      : (isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A)),
                                ),
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryPurple.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Aktif',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryPurple,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (snippet.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 2,
                                  bottom: 2,
                                ),
                                child: Text(
                                  snippet,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black45,
                                  ),
                                ),
                              ),
                            Text(
                              '${session.messages.length} pesan • $dateStr',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? Colors.white30 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                          ),
                          color: isDark ? Colors.white30 : Colors.black38,
                          tooltip: 'Hapus sesi ini',
                          onPressed: () {
                            final deletedId = session.id;
                            setModalState(() {
                              _sessions.removeAt(idx);
                              if (isCurrent) {
                                _messages.clear();
                                _currentSessionId = '';
                              }
                            });
                            setState(() {});
                            if (currentUserNotifier.value != null) {
                              AiService.deleteChatSession(deletedId);
                            }
                          },
                        ),
                        onTap: () {
                          // DO NOT SEND NEW MESSAGE! Just load and view the previous chat session!
                          Navigator.pop(ctx);
                          setState(() {
                            _currentSessionId = session.id;
                            _messages.clear();
                            _messages.addAll(session.messages);
                          });
                          _scrollToBottom();
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }


  void _showDataKreavanaInfo(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF141829) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(
              Icons.language_rounded,
              color: AppTheme.primaryPurple,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Data Kreavana AI',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Asisten Kreavana.AI terhubung langsung dengan basis data ekosistem kreatif Kreavana (kreator terverifikasi, peluang proyek aktif, event terdaftar, standar fee, dan spot kreatif).\n\n'
          '⚠️ Catatan: Asisten ini berfokus khusus pada industri kreatif dan platform Kreavana (tidak melayani penulisan coding atau sains teknis non-kreatif).',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.5,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  /// Ensures the user is logged in and has an active designated subscription (Plus, Pro, or Super).
  bool _ensureAccess() {
    final user = currentUserNotifier.value;
    // 1. Guest check
    if (user == null || user.isGuest) {
      AuthGuardDialog.show(context, actionName: 'menggunakan Kreavana AI');
      return false;
    }

    // 2. Subscription check (Plus, Pro, Super)
    final tier = user.subscriptionTier.toLowerCase();
    final isAllowed = ['plus', 'pro', 'super'].contains(tier);
    if (!isAllowed) {
      UpgradePlanModal.show(context, user: user);
      AppSweetAlert.warning(
        context,
        'Fitur Kreavana AI Assistant hanya tersedia untuk pengguna Paket Plus, Pro, dan Super.',
        title: 'Paket Berlangganan Diperlukan',
      );
      return false;
    }

    return true;
  }

  void _handleUpload() {
    if (!_ensureAccess()) return;

    setState(() {
      _attachedFileName = 'brief_kebutuhan_kreatif.pdf';
    });
    AppSweetAlert.success(
      context,
      'Lampiran brief proyek berhasil ditambahkan.',
      title: 'Lampiran Berhasil',
    );
  }

  void _sendPrompt(String prompt, {String? category}) {
    if (!_ensureAccess()) return;

    _inputController.text = prompt;
    _sendMessage(category: category);
  }

  Future<void> _sendMessage({String? category}) async {
    if (!_ensureAccess()) return;

    final text = _inputController.text.trim();
    if (text.isEmpty && _attachedFileName == null) return;

    final promptText = _attachedFileName != null
        ? '$text (Lampiran: $_attachedFileName)'
        : text;

    if (_currentSessionId.isEmpty) {
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    }

    setState(() {
      _messages.add({'sender': 'user', 'text': promptText});
      _inputController.clear();
      _isLoading = true;
    });

    _syncCurrentSession();
    _scrollToBottom();

    final res = await AiService.messageAssistant(
      mode: 'chat',
      message: promptText,
      category: category,
      includeDataKreavana: _isDataKreavanaActive,
    );

    if (!mounted) return;

    if (res != null && AiService.isProSubscriptionRequiredError(res)) {
      setState(() => _isLoading = false);
      AiService.promptProUpgrade(context);
      return;
    }

    String aiResponse =
        "Halo! Saya Kreavana AI. Saya siap membantu mengoptimalkan proyek, konten, dan riset kreatif Anda.";

    List<Map<String, dynamic>> recommendationCards = [];

    if (res != null && res['data'] != null) {
      aiResponse =
          res['data']['answer'] ??
          (res['data']['polished_message'] ?? aiResponse);

      if (res['data']['recommendation_cards'] != null &&
          res['data']['recommendation_cards'] is List) {
        recommendationCards = List<Map<String, dynamic>>.from(
          (res['data']['recommendation_cards'] as List).map(
            (c) => Map<String, dynamic>.from(c),
          ),
        );
      }
    }

    setState(() {
      _messages.add({
        'sender': 'ai',
        'text': aiResponse,
        'provider': res?['data']?['ai_provider'] ?? 'Kreavana Core AI Engine',
        'cards': recommendationCards,
      });
      _isLoading = false;
      _attachedFileName = null;
    });

    _syncCurrentSession();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final isWideScreen = widget.isDesktop && screenSize.width >= 860;

    // Color tokens for Dark vs Light theme
    final cardBg = isDark ? const Color(0xFF0C0E1A) : const Color(0xFFF8FAFC);
    final headerBg = isDark ? const Color(0xFF101322) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF1F263D)
        : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final capsuleInputBg = isDark
        ? const Color(0xFF131728)
        : const Color(0xFFFFFFFF);

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: cardBg,
      child: Column(
        children: [
          // ── Header Bar ───────────────────────────────────────────────
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: headerBg,
              border: Border(
                bottom: BorderSide(color: borderColor, width: 1),
              ),
            ),
            child: Row(
              children: [
                // Logo + Brand Title
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.asset(
                    'assets/brandlogo.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 10),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'KREAVANA',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: textColor,
                        ),
                      ),
                      const TextSpan(
                        text: '.AI',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: Color(0xFFA855F7),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                // Model status tag (hidden on very compact screens)
                if (screenSize.width > 560)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.18 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: Color(0xFF8B5CF6),
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Kreavana Intelligence',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                      ],
                    ),
                  ),

                const Spacer(),

                // New Chat Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _clearChat,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E243A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 16, color: textColor),
                          const SizedBox(width: 5),
                          Text(
                            'Obrolan Baru',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // History Toggle Button
                Tooltip(
                  message: isWideScreen
                      ? (_isRightHistoryOpen ? 'Tutup Riwayat (Samping)' : 'Buka Riwayat (Samping)')
                      : 'Riwayat Obrolan',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (isWideScreen) {
                          setState(() => _isRightHistoryOpen = !_isRightHistoryOpen);
                        } else {
                          _showHistoryModal(isDark);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (isWideScreen && _isRightHistoryOpen)
                              ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                              : (isDark ? const Color(0xFF1E243A) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (isWideScreen && _isRightHistoryOpen)
                                ? const Color(0xFF8B5CF6).withValues(alpha: 0.4)
                                : borderColor,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 16,
                              color: (isWideScreen && _isRightHistoryOpen)
                                  ? const Color(0xFF8B5CF6)
                                  : subtitleColor,
                            ),
                            if (isWideScreen) ...[
                              const SizedBox(width: 5),
                              Text(
                                'Riwayat',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: (isWideScreen && _isRightHistoryOpen)
                                      ? const Color(0xFF8B5CF6)
                                      : textColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Minimize (-) Icon
                if (widget.onMinimize != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      Icons.remove_rounded,
                      color: subtitleColor,
                      size: 21,
                    ),
                    tooltip: 'Kecilkan',
                    onPressed: widget.onMinimize,
                  ),
                ],

                // Close (X) Icon
                if (widget.onClose != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: subtitleColor,
                      size: 21,
                    ),
                    tooltip: 'Tutup',
                    onPressed: widget.onClose,
                  ),
                ],
              ],
            ),
          ),

          // ── Main Content Area + Right History Sidebar ────────────────
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Main Workspace (Chat Area)
                Expanded(
                  child: Column(
                    children: [
                      // Chat feed or Welcome hero
                      Expanded(
                        child: _messages.isEmpty
                            ? _buildWelcomeHeroSection(
                                isDark,
                                textColor,
                                subtitleColor,
                                borderColor,
                              )
                            : _buildActiveChatStream(
                                isDark,
                                textColor,
                                subtitleColor,
                                borderColor,
                              ),
                      ),

                      // Bottom Floating Input Capsule (Centered max-width on wide screens)
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 860),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: capsuleInputBg,
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF28314E)
                                      : const Color(0xFFCBD5E1),
                                  width: 1.3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: isDark ? 0.25 : 0.04,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_attachedFileName != null)
                                    Container(
                                      margin: const EdgeInsets.only(
                                        bottom: 6,
                                        top: 4,
                                        left: 6,
                                        right: 6,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryPurple.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.attach_file_rounded,
                                            size: 14,
                                            color: AppTheme.primaryPurple,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              _attachedFileName!,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primaryPurple,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => setState(
                                                () => _attachedFileName = null),
                                            child: const Icon(
                                              Icons.close_rounded,
                                              size: 14,
                                              color: AppTheme.primaryPurple,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  Row(
                                    children: [
                                      // Paperclip Attachment Button
                                      InkWell(
                                        onTap: _handleUpload,
                                        borderRadius: BorderRadius.circular(24),
                                        child: Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF1D233A)
                                                : const Color(0xFFE2E8F0),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Transform.rotate(
                                            angle: -0.6,
                                            child: Icon(
                                              Icons.attach_file_rounded,
                                              size: 19,
                                              color: isDark
                                                  ? Colors.white70
                                                  : const Color(0xFF334155),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),

                                      // Text Input Field
                                      Expanded(
                                        child: ValueListenableBuilder<UserModel?>(
                                          valueListenable: currentUserNotifier,
                                          builder: (context, user, _) {
                                            final isGuest =
                                                user == null || user.isGuest;
                                            final tier = user
                                                    ?.subscriptionTier
                                                    .toLowerCase() ??
                                                'free';
                                            final hasSub = [
                                              'plus',
                                              'pro',
                                              'super',
                                            ].contains(tier);

                                            String hintText =
                                                'Tulis pesan kamu di sini...';
                                            if (isGuest) {
                                              hintText =
                                                  'Login untuk menggunakan Kreavana AI...';
                                            } else if (!hasSub) {
                                              hintText =
                                                  'Tingkatkan paket untuk menggunakan AI...';
                                            }

                                            return TextField(
                                              controller: _inputController,
                                              minLines: 1,
                                              maxLines: 3,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                color: textColor,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: hintText,
                                                filled: false,
                                                fillColor: Colors.transparent,
                                                border: InputBorder.none,
                                                enabledBorder: InputBorder.none,
                                                focusedBorder: InputBorder.none,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 8,
                                                ),
                                                hintStyle: TextStyle(
                                                  color: isDark
                                                      ? Colors.white38
                                                      : Colors.black38,
                                                  fontSize: 13.5,
                                                ),
                                              ),
                                              onSubmitted: (_) =>
                                                  _sendMessage(),
                                            );
                                          },
                                        ),
                                      ),

                                      // Data Kreavana Badge Button
                                      InkWell(
                                        onTap: () =>
                                            _showDataKreavanaInfo(isDark),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF1B2137)
                                                : const Color(0xFFF1F5F9),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isDark
                                                  ? const Color(0xFF2C3656)
                                                  : const Color(0xFFE2E8F0),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.language_rounded,
                                                size: 13,
                                                color: isDark
                                                    ? Colors.white70
                                                    : const Color(0xFF475569),
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                'Data Kreavana',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : const Color(0xFF475569),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.info_outline_rounded,
                                                size: 12,
                                                color: isDark
                                                    ? Colors.white38
                                                    : Colors.black45,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),

                                      // Circular Gradient Send Button
                                      GestureDetector(
                                        onTap: _isLoading
                                            ? null
                                            : () => _sendMessage(),
                                        child: Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF8B5CF6),
                                                Color(0xFF6366F1),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFF8B5CF6,
                                                ).withValues(alpha: 0.4),
                                                blurRadius: 10,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: _isLoading
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.send_rounded,
                                                    color: Colors.white,
                                                    size: 18,
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Footer
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 860),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 4, 24, 10),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.verified_user_outlined,
                                  size: 13,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black45,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Powered by Kreavana AI',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black45,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Bersama Kreator, Wujudkan Karya',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Right History Sidebar (on Wide Screen)
                if (isWideScreen && _isRightHistoryOpen)
                  _buildRightHistorySidebar(
                    isDark,
                    textColor,
                    subtitleColor,
                    borderColor,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightHistorySidebar(
    bool isDark,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
  ) {
    final bg = isDark ? const Color(0xFF101322) : const Color(0xFFF8FAFC);
    final itemBg = isDark ? const Color(0xFF161A2E) : Colors.white;
    final itemBorder = isDark ? const Color(0xFF232A45) : const Color(0xFFE2E8F0);

    final filteredSessions = _historySearchQuery.isEmpty
        ? _sessions
        : _sessions.where((s) {
            final q = _historySearchQuery.toLowerCase();
            return s.title.toLowerCase().contains(q) ||
                s.messages.any((m) =>
                    (m['text'] as String? ?? '').toLowerCase().contains(q));
          }).toList();

    return Container(
      width: 290,
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          left: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Sidebar Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor, width: 1)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 18,
                  color: AppTheme.primaryPurple,
                ),
                const SizedBox(width: 8),
                Text(
                  'Riwayat Obrolan',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_sessions.length}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Tutup Panel Riwayat',
                  color: subtitleColor,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _isRightHistoryOpen = false),
                ),
              ],
            ),
          ),

          // New Chat Action Button
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _clearChat,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, size: 17, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Percakapan Baru',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF28314E) : const Color(0xFFCBD5E1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 16, color: subtitleColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      style: TextStyle(fontSize: 12.5, color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Cari riwayat...',
                        hintStyle: TextStyle(fontSize: 12.5, color: subtitleColor),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        fillColor: Colors.transparent,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (val) => setState(() => _historySearchQuery = val),
                    ),
                  ),
                  if (_historySearchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _historySearchQuery = ''),
                      child: Icon(Icons.clear_rounded, size: 14, color: subtitleColor),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Session List
          Expanded(
            child: _isLoadingHistory && _sessions.isEmpty
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : filteredSessions.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 36,
                                color: subtitleColor.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _historySearchQuery.isNotEmpty
                                    ? 'Tidak ada hasil untuk "$_historySearchQuery"'
                                    : 'Belum ada riwayat',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        itemCount: filteredSessions.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (ctx, idx) {
                          final session = filteredSessions[idx];
                          final isCurrent = session.id == _currentSessionId && _messages.isNotEmpty;
                          final dateStr =
                              '${session.createdAt.day}/${session.createdAt.month} • ${session.createdAt.hour.toString().padLeft(2, '0')}:${session.createdAt.minute.toString().padLeft(2, '0')}';

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _selectSession(session.id),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? AppTheme.primaryPurple.withValues(alpha: isDark ? 0.2 : 0.1)
                                      : itemBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isCurrent
                                        ? AppTheme.primaryPurple.withValues(alpha: 0.5)
                                        : itemBorder,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isCurrent
                                          ? Icons.chat_rounded
                                          : Icons.chat_bubble_outline_rounded,
                                      size: 16,
                                      color: isCurrent ? AppTheme.primaryPurple : subtitleColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            session.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                              color: isCurrent ? AppTheme.primaryPurple : textColor,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${session.messages.length} pesan • $dateStr',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: subtitleColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 15),
                                      color: subtitleColor.withValues(alpha: 0.7),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Hapus',
                                      onPressed: () => _deleteSession(session.id),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Bottom Bar in Sidebar
          if (_sessions.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor, width: 1)),
              ),
              child: Row(
                children: [
                  Text(
                    '${_sessions.length} obrolan',
                    style: TextStyle(fontSize: 11, color: subtitleColor),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Hapus Semua Riwayat?'),
                          content: const Text(
                            'Semua riwayat percakapan Kreavana AI akan dihapus permanen.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Batal'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        setState(() {
                          _sessions.clear();
                          _messages.clear();
                          _currentSessionId = '';
                        });
                        if (currentUserNotifier.value != null) {
                          AiService.clearChatSessions();
                        }
                      }
                    },
                    child: Text(
                      'Hapus Semua',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Welcome Hero section with 6 interactive suggestion cards (matching reference image)
  Widget _buildWelcomeHeroSection(
    bool isDark,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              // Main Greeting Title: "Halo, [Nama Pengguna]!" or clean "Halo, apa yang bisa saya bantu hari ini?"
              ValueListenableBuilder<UserModel?>(
                valueListenable: currentUserNotifier,
                builder: (context, user, _) {
                  final isLoggedIn = user != null && !user.isGuest;
                  final displayName = isLoggedIn ? user.name.trim() : '';

                  if (isLoggedIn && displayName.isNotEmpty) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Halo, $displayName!',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: widget.isDesktop ? 28 : 22,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFC084FC), Color(0xFF60A5FA)],
                          ).createShader(bounds),
                          child: Text(
                            'apa yang bisa saya bantu hari ini?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: widget.isDesktop ? 26 : 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  // Guest mode: Single inline natural text without any WidgetSpan box padding or extra spaces
                  return RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: widget.isDesktop ? 28 : 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                      children: [
                        TextSpan(
                          text: 'Halo, ',
                          style: TextStyle(color: textColor),
                        ),
                        TextSpan(
                          text: 'apa yang bisa saya bantu hari ini?',
                          style: TextStyle(
                            foreground: Paint()
                              ..shader =
                                  const LinearGradient(
                                    colors: [Color(0xFFC084FC), Color(0xFF60A5FA)],
                                  ).createShader(
                                    const Rect.fromLTWH(0.0, 0.0, 480.0, 40.0),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Subtitle
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Text(
                  'Saya adalah asisten AI Kreavana. Saya bisa membantu kamu mencari informasi, memberikan rekomendasi, dan menjawab pertanyaan seputar platform Kreavana.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: subtitleColor,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Section Header: "✦ Contoh yang bisa saya bantu:"
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: Color(0xFFC084FC),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Contoh yang bisa saya bantu:',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 6 Suggestion Cards (2 Columns x 3 Rows)
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final isTwoColumn = constraints.maxWidth >= 540;
                  return isTwoColumn
                      ? Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSuggestionCard(
                                    _examplePrompts[0],
                                    isDark,
                                    borderColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSuggestionCard(
                                    _examplePrompts[1],
                                    isDark,
                                    borderColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSuggestionCard(
                                    _examplePrompts[2],
                                    isDark,
                                    borderColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSuggestionCard(
                                    _examplePrompts[3],
                                    isDark,
                                    borderColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSuggestionCard(
                                    _examplePrompts[4],
                                    isDark,
                                    borderColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSuggestionCard(
                                    _examplePrompts[5],
                                    isDark,
                                    borderColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Column(
                          children: _examplePrompts
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _buildSuggestionCard(
                                    item,
                                    isDark,
                                    borderColor,
                                  ),
                                ),
                              )
                              .toList(),
                        );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Single suggestion card widget with icon, title, subtitle, and arrow
  Widget _buildSuggestionCard(
    Map<String, dynamic> item,
    bool isDark,
    Color borderColor,
  ) {
    final Color iconColor = item['color'] as Color;
    final cardBg = isDark ? const Color(0xFF131728) : Colors.white;

    return InkWell(
      onTap: () => _sendPrompt(
        item['prompt'] as String,
        category: item['category'] as String?,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF222B48) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Circle
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: isDark ? 0.18 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(item['icon'] as IconData, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),

            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item['subtitle'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Trailing Arrow
            Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  /// Active conversation stream view
  Widget _buildActiveChatStream(
    bool isDark,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isLoading) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF161B2E)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Kreavana.AI sedang berpikir...',
                    style: TextStyle(fontSize: 12, color: subtitleColor),
                  ),
                ],
              ),
            ),
          );
        }

        final msg = _messages[index];
        final isUser = msg['sender'] == 'user';

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            constraints: BoxConstraints(
              maxWidth:
                  MediaQuery.of(context).size.width *
                  (widget.isDesktop ? 0.6 : 0.82),
            ),
            child: isUser
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      msg['text'] ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        height: 1.45,
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF15192C) : Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF242C48)
                            : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.2 : 0.04,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.asset(
                                'assets/brandlogo.png',
                                width: 16,
                                height: 16,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Kreavana AI',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? const Color(0xFFC084FC)
                                    : AppTheme.primaryPurple,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 14),
                              color: subtitleColor,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                              tooltip: 'Salin Jawaban',
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: msg['text'] ?? ''),
                                );
                                AppSweetAlert.success(
                                  context,
                                  'Jawaban berhasil disalin ke clipboard.',
                                  title: 'Tersalin',
                                  duration: const Duration(milliseconds: 2200),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AiFormattedMarkdownView(
                          text: msg['text'] ?? '',
                          isDark: isDark,
                          textColor: textColor,
                          subtitleColor: subtitleColor,
                        ),
                        if (msg['cards'] != null &&
                            (msg['cards'] as List).isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildRecommendationCardsSection(
                            context,
                            List<Map<String, dynamic>>.from(msg['cards']),
                            isDark,
                            textColor,
                            subtitleColor,
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildRecommendationCardsSection(
    BuildContext context,
    List<Map<String, dynamic>> cards,
    bool isDark,
    Color textColor,
    Color subtitleColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 13,
                color: AppTheme.primaryPurple,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Rekomendasi Terpilih (Sistem Booster Akun):',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? const Color(0xFFE2E8F0)
                    : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 195,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (ctx, idx) {
              final card = cards[idx];
              return _buildRecommendationCardItem(
                ctx,
                card,
                isDark,
                textColor,
                subtitleColor,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCardItem(
    BuildContext context,
    Map<String, dynamic> card,
    bool isDark,
    Color textColor,
    Color subtitleColor,
  ) {
    final isEvent = card['type'] == 'event';
    final name = (isEvent ? card['title'] : card['name']) ?? 'Rekomendasi AI';
    final subRole =
        (isEvent ? card['category'] : card['sub_role']) ?? 'Kreator';
    final location = card['location'] ?? 'Bandung';
    final boostBadge = card['performance_boost']?.toString() ?? '⚡ Booster';
    final ratingVal = card['rating'] != null
        ? (card['rating'] as num).toDouble()
        : 4.9;
    final reviewCount = card['review_count']?.toString() ?? '35 Ulasan';
    final actionLabel =
        card['action_label'] ?? (isEvent ? 'Lihat Acara' : 'Lihat Profil');
    final avatarUrl = isEvent ? card['poster_url'] : card['avatar_url'];

    return Container(
      width: 255,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2237) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2B3654) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top: Avatar & Name & Role
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(isEvent ? 8 : 19),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: avatarUrl != null && avatarUrl.toString().isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(isEvent ? 8 : 19),
                        child: Image.network(
                          avatarUrl.toString(),
                          width: 38,
                          height: 38,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Center(
                            child: Icon(
                              isEvent
                                  ? Icons.event_note_rounded
                                  : Icons.person_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          isEvent
                              ? Icons.event_note_rounded
                              : Icons.person_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subRole,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryPurple,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Middle 1: Booster badge & Location
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: boostBadge.contains('Booster')
                        ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                        : [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  boostBadge,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 12,
                    color: subtitleColor,
                  ),
                  const SizedBox(width: 2),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 85),
                    child: Text(
                      location,
                      style: TextStyle(fontSize: 10.5, color: subtitleColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Middle 2: Rating ⭐ & Reviews count
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                size: 15,
                color: Color(0xFFF59E0B),
              ),
              const SizedBox(width: 3),
              Text(
                ratingVal.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '($reviewCount)',
                style: TextStyle(fontSize: 10, color: subtitleColor),
              ),
              const Spacer(),
              if (card['match_score'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    card['match_score'].toString(),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
            ],
          ),

          // Bottom: Action Button (Lihat Profil / Lihat Acara)
          SizedBox(
            width: double.infinity,
            height: 32,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _handleCardAction(context, card, isDark),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isEvent
                              ? Icons.calendar_month_outlined
                              : Icons.person_search_outlined,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          actionLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 9,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCardAction(
    BuildContext context,
    Map<String, dynamic> card,
    bool isDark,
  ) async {
    final isEvent = card['type'] == 'event';
    final user = await AuthService.getCurrentUser();

    if (!context.mounted) return;

    if (user?.isGuest == true) {
      AuthGuardDialog.show(
        context,
        actionName: isEvent
            ? 'melihat rincian acara rekomendasi AI'
            : 'melihat profil kreator rekomendasi AI',
      );
      return;
    }

    if (isEvent) {
      final opp = OpportunityModel(
        id: card['id']?.toString() ?? '1',
        title:
            card['title']?.toString() ??
            card['name']?.toString() ??
            'Acara Kreavana',
        description:
            'Peluang dan agenda kreatif terkurasi oleh asisten Kreavana AI.',
        subRoleSlug: card['category']?.toString() ?? 'event_organizer',
        type: 'project',
        location: card['location']?.toString() ?? 'Indonesia',
        budgetRange: card['budget_range']?.toString() ?? 'Kompetitif',
        status: 'open',
        postedBy: 'admin',
        posterUrl: card['poster_url'],
        requirements: [],
        approvedCreators: [],
      );

      OpportunityDetailSheet.show(
        context,
        opportunity: opp,
        currentUserId: user?.id ?? '',
      );
    } else {
      _showCreatorDetailModal(context, card, user, isDark);
    }
  }

  void _showCreatorDetailModal(
    BuildContext context,
    Map<String, dynamic> card,
    UserModel? user,
    bool isDark,
  ) {
    final name = card['name'] ?? 'Kreator Kreavana';
    final username = card['username'] ?? '';
    final subRole = card['sub_role'] ?? 'Kreator';
    final location = card['location'] ?? 'Indonesia';
    final boostBadge =
        card['performance_boost']?.toString() ?? '⚡ Booster Akun';
    final ratingVal = card['rating'] != null
        ? (card['rating'] as num).toDouble()
        : 4.9;
    final reviewCount = card['review_count']?.toString() ?? '40 Ulasan';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B2E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF283250) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header: Avatar, Name, Username
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
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
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: Color(0xFF3B82F6),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@$username • $subRole',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryPurple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Rating & Booster Row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E2438)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2B3654)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rating & Ulasan',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFF59E0B),
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${ratingVal.toStringAsFixed(1)} / 5.0',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          reviewCount,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 38,
                    color: Colors.grey.withValues(alpha: 0.2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status Booster',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            boostBadge,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '📍 $location',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Booster Explanation Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        size: 15,
                        color: Color(0xFF8B5CF6),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Perhitungan Rekomendasi Profil Beranda:',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• Status Akun Kreator: Terverifikasi & aktif\n• Poin Review Positif: Bintang 5 konsisten dari klien\n• Transaksi Proyek: Memenuhi standar escrow Kreavana',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: isDark
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.explore_outlined, size: 16),
                    label: const Text(
                      'Jelajahi di Explore',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (user != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExploreScreen(user: user),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Tutup',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Representation of a saved chat conversation session
class _AiChatSession {
  final String id;
  String title;
  final DateTime createdAt;
  final List<Map<String, dynamic>> messages;

  _AiChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
  });

  factory _AiChatSession.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate = DateTime.now();
    if (json['created_at'] != null) {
      try {
        parsedDate = DateTime.parse(json['created_at'].toString());
      } catch (_) {}
    }
    List<Map<String, dynamic>> msgs = [];
    if (json['messages'] is List) {
      msgs = List<Map<String, dynamic>>.from(
        (json['messages'] as List).map((m) => Map<String, dynamic>.from(m)),
      );
    }
    return _AiChatSession(
      id:
          json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? 'Percakapan AI',
      createdAt: parsedDate,
      messages: msgs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'created_at': createdAt.toIso8601String(),
    'messages': messages,
  };
}

/// Rich Formatted Markdown Text View that cleanly renders headings, bullets, numbers,
/// bold, and italic without showing raw syntax characters like '***', '**', or '###'.
class AiFormattedMarkdownView extends StatelessWidget {
  final String text;
  final bool isDark;
  final Color textColor;
  final Color subtitleColor;

  const AiFormattedMarkdownView({
    super.key,
    required this.text,
    required this.isDark,
    required this.textColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final widgets = <Widget>[];

    final normalStyle = TextStyle(fontSize: 13, color: textColor, height: 1.5);

    final boldStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: isDark ? Colors.white : const Color(0xFF0F172A),
      height: 1.5,
    );

    final italicStyle = TextStyle(
      fontSize: 13,
      fontStyle: FontStyle.italic,
      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
      height: 1.5,
    );

    final boldItalicStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      fontStyle: FontStyle.italic,
      color: isDark ? Colors.white : const Color(0xFF0F172A),
      height: 1.5,
    );

    final headingColor = isDark
        ? const Color(0xFFC084FC)
        : AppTheme.primaryPurple;

    for (int i = 0; i < lines.length; i++) {
      final rawLine = lines[i];
      final trimmed = rawLine.trim();

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // Headings: ###, ##, #
      if (trimmed.startsWith('#')) {
        final headingText = trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
        final hStyle = TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w800,
          color: headingColor,
          height: 1.4,
        );
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text.rich(
              TextSpan(
                children: _parseInlineSpans(
                  headingText,
                  hStyle,
                  hStyle,
                  hStyle.copyWith(fontStyle: FontStyle.italic),
                  hStyle.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ),
          ),
        );
        continue;
      }

      // Bullet points: •, -, * (when followed by space)
      final isBullet =
          trimmed.startsWith('• ') ||
          trimmed.startsWith('- ') ||
          (trimmed.startsWith('* ') && !trimmed.startsWith('**'));
      if (isBullet) {
        final content = trimmed.substring(2).trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7, right: 8, left: 2),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFFA855F7)
                          : AppTheme.primaryPurple,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _parseInlineSpans(
                        content,
                        normalStyle,
                        boldStyle,
                        italicStyle,
                        boldItalicStyle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Numbered items: 1. , 2. , etc.
      final numMatch = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmed);
      if (numMatch != null) {
        final numStr = numMatch.group(1)!;
        final content = numMatch.group(2)!;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$numStr.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFFA855F7)
                        : AppTheme.primaryPurple,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _parseInlineSpans(
                        content,
                        normalStyle,
                        boldStyle,
                        italicStyle,
                        boldItalicStyle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Normal text paragraph
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(
            TextSpan(
              children: _parseInlineSpans(
                trimmed,
                normalStyle,
                boldStyle,
                italicStyle,
                boldItalicStyle,
              ),
            ),
          ),
        ),
      );
    }

    return SelectableRegion(
      focusNode: FocusNode(),
      selectionControls: materialTextSelectionControls,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      ),
    );
  }

  /// Parses inline markdown elements (***bold-italic***, **bold**, *italic*, _italic_)
  /// and strips raw syntax characters completely!
  static List<InlineSpan> _parseInlineSpans(
    String input,
    TextStyle normal,
    TextStyle bold,
    TextStyle italic,
    TextStyle boldItalic,
  ) {
    final spans = <InlineSpan>[];
    final reg = RegExp(
      r'(\*\*\*[^\*]+?\*\*\*|\*\*[^\*]+?\*\*|\*[^\*]+?\*|_[^_]+?_)',
    );
    int lastEnd = 0;

    for (final match in reg.allMatches(input)) {
      if (match.start > lastEnd) {
        final textBefore = input
            .substring(lastEnd, match.start)
            .replaceAll('***', '')
            .replaceAll('**', '')
            .replaceAll('###', '');
        if (textBefore.isNotEmpty) {
          spans.add(TextSpan(text: textBefore, style: normal));
        }
      }

      final matchedText = match.group(0)!;
      if (matchedText.startsWith('***') &&
          matchedText.endsWith('***') &&
          matchedText.length > 6) {
        final inner = matchedText.substring(3, matchedText.length - 3);
        spans.add(TextSpan(text: inner, style: boldItalic));
      } else if (matchedText.startsWith('**') &&
          matchedText.endsWith('**') &&
          matchedText.length > 4) {
        final inner = matchedText.substring(2, matchedText.length - 2);
        spans.add(TextSpan(text: inner, style: bold));
      } else if (matchedText.startsWith('*') &&
          matchedText.endsWith('*') &&
          matchedText.length > 2) {
        final inner = matchedText.substring(1, matchedText.length - 1);
        spans.add(TextSpan(text: inner, style: italic));
      } else if (matchedText.startsWith('_') &&
          matchedText.endsWith('_') &&
          matchedText.length > 2) {
        final inner = matchedText.substring(1, matchedText.length - 1);
        spans.add(TextSpan(text: inner, style: italic));
      } else {
        spans.add(TextSpan(text: matchedText, style: normal));
      }

      lastEnd = match.end;
    }

    if (lastEnd < input.length) {
      final trailing = input
          .substring(lastEnd)
          .replaceAll('***', '')
          .replaceAll('**', '')
          .replaceAll('###', '');
      if (trailing.isNotEmpty) {
        spans.add(TextSpan(text: trailing, style: normal));
      }
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: input, style: normal));
    }

    return spans;
  }
}
