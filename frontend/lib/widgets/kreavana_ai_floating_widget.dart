import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../services/ai_service.dart';

/// Floating Blackbox.AI-style Assistant Widget.
/// Draggable across Mobile & Desktop viewport with violet styling, bounds clamping, and active action buttons.
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
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: _BlackboxAiPanel(
            isDesktop: true,
            onClose: () => Navigator.pop(ctx),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: _BlackboxAiPanel(
            isDesktop: false,
            onClose: () => Navigator.pop(ctx),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width >= 768;

    final maxLeft =
        (screenSize.width - _buttonWidth - 12.0).clamp(12.0, double.infinity);
    final maxTop =
        (screenSize.height - _buttonHeight - 12.0).clamp(12.0, double.infinity);

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
        (screenSize.height - _buttonHeight - initialBottomOffset)
            .clamp(12.0, maxTop),
      );
    }

    return Positioned(
      left: _position!.dx,
      top: _position!.dy,
      child: MouseRegion(
        cursor:
            _isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
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
            final nextX =
                (_position!.dx + details.delta.dx).clamp(12.0, maxLeft);
            final nextY =
                (_position!.dy + details.delta.dy).clamp(12.0, maxTop);
            setState(() {
              _position = Offset(nextX, nextY);
              _savedPosition = _position;
            });
          },
          onPanEnd: (details) {
            setState(() {
              _isDragging = false;
            });
            // Delay resetting _hasDragged slightly to prevent synthetic click events
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
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

class _BlackboxAiPanel extends StatefulWidget {
  final bool isDesktop;
  final VoidCallback onClose;

  const _BlackboxAiPanel({required this.isDesktop, required this.onClose});

  @override
  State<_BlackboxAiPanel> createState() => _BlackboxAiPanelState();
}

class _BlackboxAiPanelState extends State<_BlackboxAiPanel> {
  final TextEditingController _inputController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final List<String> _chatHistoryLogs = [
    'Riset peluang event budaya 2026',
    'Optimasi deskripsi portofolio kreator',
    'Rekomendasi harga jasa videografi',
  ];

  bool _includeContext = true;
  bool _isSearchMode = false;
  String? _attachedFileName;
  bool _isLoading = false;

  void _clearChat() {
    setState(() {
      _messages.clear();
      _attachedFileName = null;
      _isSearchMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sesi percakapan AI baru dimulai.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showHistoryModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.history_rounded, color: AppTheme.primaryPurple),
                SizedBox(width: 8),
                Text(
                  'Riwayat Obrolan AI',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._chatHistoryLogs.map(
              (item) => ListTile(
                leading: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 20,
                ),
                title: Text(item, style: const TextStyle(fontSize: 13)),
                onTap: () {
                  Navigator.pop(ctx);
                  _inputController.text = item;
                  _sendMessage();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleUpload() {
    setState(() {
      _attachedFileName = 'dokumen_lampiran_kreatif.pdf';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dokumen berhasil dilampirkan untuk analisis AI.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _toggleSearchMode() {
    setState(() {
      _isSearchMode = !_isSearchMode;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSearchMode
              ? 'Mode Web Search AI Diaktifkan.'
              : 'Mode Web Search AI Dinonaktifkan.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleVideoMode() {
    setState(() {
      _attachedFileName = 'sampel_video_promo.mp4';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Video berhasil dilampirkan untuk evaluasi visual AI.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty && _attachedFileName == null) return;

    final promptText = _attachedFileName != null
        ? '$text (Lampiran: $_attachedFileName)'
        : text;

    setState(() {
      _messages.add({'sender': 'user', 'text': promptText});
      _inputController.clear();
      _isLoading = true;
    });

    Map<String, dynamic>? res;
    if (_isSearchMode) {
      res = await AiService.getRecommendations(
        role: 'creator',
        niche: promptText,
      );
    } else {
      res = await AiService.messageAssistant(
        mode: 'polish',
        message: promptText,
      );
    }

    if (!mounted) return;

    if (res != null && AiService.isProSubscriptionRequiredError(res)) {
      setState(() => _isLoading = false);
      AiService.promptProUpgrade(context);
      return;
    }

    String aiResponse =
        "Halo! Saya Kreavana AI. Saya siap membantu mengoptimalkan proyek, konten, dan riset Anda.";
    if (res != null && res['data'] != null) {
      if (_isSearchMode) {
        final recs = res['data']['recommendations'] as List?;
        if (recs != null && recs.isNotEmpty) {
          aiResponse = "Rekomendasi Web Search AI:\n• ${recs.join('\n• ')}";
        } else {
          aiResponse =
              "Hasil pencarian AI: ${res['data']['analysis'] ?? aiResponse}";
        }
      } else {
        aiResponse = res['data']['polished_message'] ?? aiResponse;
      }
    }

    setState(() {
      _messages.add({'sender': 'ai', 'text': aiResponse});
      _isLoading = false;
      _attachedFileName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = widget.isDesktop
        ? 420.0
        : MediaQuery.of(context).size.width - 24;
    final height = widget.isDesktop
        ? 580.0
        : MediaQuery.of(context).size.height * 0.72;

    const accentColor = AppTheme.primaryPurple;
    final cardBg = isDark ? const Color(0xFF13111F) : Colors.white;
    final inputBg = isDark ? const Color(0xFF1A172A) : const Color(0xFFF5F3FF);
    final borderColor = isDark
        ? const Color(0xFF2D264A)
        : const Color(0xFFE4DEF6);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header Bar ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(bottom: BorderSide(color: borderColor, width: 1)),
            ),
            child: Row(
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
                const SizedBox(width: 10),
                const Text(
                  'KREAVANA.AI',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.history_rounded, size: 20),
                  onPressed: _showHistoryModal,
                  tooltip: 'Riwayat AI',
                ),
                IconButton(
                  icon: const Icon(Icons.add_rounded, size: 22),
                  onPressed: _clearChat,
                  tooltip: 'Percakapan Baru',
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: widget.onClose,
                  tooltip: 'Tutup',
                ),
              ],
            ),
          ),

          // ── Main Body (Greeting or Chat History) ──────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _messages.isEmpty
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(),
                        const Text(
                          'How can I help you today?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tanyakan strategi proyek, ringkasan laporan, atau optimasi pesan secara instan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const Spacer(),
                        // Include Context & Open Website Toggle Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Include Context',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Switch(
                                  value: _includeContext,
                                  activeTrackColor: accentColor.withValues(
                                    alpha: 0.4,
                                  ),
                                  thumbColor: WidgetStateProperty.resolveWith((
                                    states,
                                  ) {
                                    if (states.contains(WidgetState.selected))
                                      return accentColor;
                                    return null;
                                  }),
                                  onChanged: (val) {
                                    setState(() => _includeContext = val);
                                  },
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Membuka portal resmi Kreavana.com...',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: const Text(
                                'Open Website',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: accentColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isUser = msg['sender'] == 'user';
                        return Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            constraints: BoxConstraints(maxWidth: width * 0.82),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? accentColor
                                  : (isDark
                                        ? const Color(0xFF1E1B32)
                                        : const Color(0xFFF1EEFF)),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              msg['text'] ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: isUser
                                    ? Colors.white
                                    : (isDark ? Colors.white : Colors.black87),
                                height: 1.4,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          // ── Bottom Input Container ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 1.2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_attachedFileName != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.attach_file_rounded,
                            size: 14,
                            color: accentColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _attachedFileName!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _attachedFileName = null),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextField(
                    controller: _inputController,
                    minLines: 1,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'Message Kreavana AI...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.grey.shade500,
                        fontSize: 13.5,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Upload Action Button
                      InkWell(
                        onTap: _handleUpload,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _attachedFileName != null
                                ? accentColor
                                : (isDark ? Colors.white10 : Colors.white),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.attach_file_rounded,
                                size: 16,
                                color: _attachedFileName != null
                                    ? Colors.white
                                    : accentColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Upload',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _attachedFileName != null
                                      ? Colors.white
                                      : (isDark
                                            ? Colors.white
                                            : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Search Action Button
                      InkWell(
                        onTap: _toggleSearchMode,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _isSearchMode
                                ? accentColor
                                : (isDark ? Colors.white10 : Colors.white),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.public_rounded,
                                size: 16,
                                color: _isSearchMode
                                    ? Colors.white
                                    : accentColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Search',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _isSearchMode
                                      ? Colors.white
                                      : (isDark
                                            ? Colors.white
                                            : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Video / Camera Icon
                      IconButton(
                        icon: const Icon(Icons.videocam_outlined, size: 20),
                        onPressed: _handleVideoMode,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Circular Send Button
                      GestureDetector(
                        onTap: _isLoading ? null : _sendMessage,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.arrow_upward_rounded,
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
        ],
      ),
    );
  }
}
