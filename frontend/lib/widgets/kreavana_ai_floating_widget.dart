import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../services/ai_service.dart';

/// Floating Blackbox.AI-style Assistant Widget.
/// Responsive for Mobile & Desktop with monochromatic violet styling and fully active action buttons.
class KreavanaAiFloatingWidget extends StatefulWidget {
  const KreavanaAiFloatingWidget({super.key});

  @override
  State<KreavanaAiFloatingWidget> createState() =>
      _KreavanaAiFloatingWidgetState();
}

class _KreavanaAiFloatingWidgetState extends State<KreavanaAiFloatingWidget> {
  bool _isOpen = false;
  double? _left;
  double? _top;

  void _toggleWidget() {
    setState(() {
      _isOpen = !_isOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width >= 768;

    final safeBottom = mediaQuery.padding.bottom;
    // Assume BottomNavigationBar is present on mobile (height ~56)
    final navBarHeight = isDesktop ? 0.0 : kBottomNavigationBarHeight;
    final baseBottomOffset = safeBottom + navBarHeight;

    final defaultLeft = mediaQuery.size.width - (isDesktop ? 180.0 : 150.0);
    final defaultTop = mediaQuery.size.height - baseBottomOffset - (isDesktop ? 80.0 : 70.0);

    final currentLeft = (_left ?? defaultLeft).clamp(
      10.0,
      mediaQuery.size.width - 140.0,
    );
    final currentTop = (_top ?? defaultTop).clamp(
      10.0,
      mediaQuery.size.height - 60.0 - baseBottomOffset,
    );

    final panelLeft = (currentLeft - (isDesktop ? 260.0 : 180.0)).clamp(
      10.0,
      mediaQuery.size.width - (isDesktop ? 440.0 : mediaQuery.size.width * 0.9),
    );
    final panelTop = (currentTop - (isDesktop ? 580.0 : 500.0)).clamp(
      10.0,
      mediaQuery.size.height - (isDesktop ? 620.0 : 540.0),
    );

    return Stack(
      children: [
        if (_isOpen)
          Positioned(
            left: panelLeft,
            top: panelTop,
            child: Material(
              color: Colors.transparent,
              elevation: 16,
              borderRadius: BorderRadius.circular(24),
              child: _BlackboxAiPanel(
                isDesktop: isDesktop,
                onClose: _toggleWidget,
              ),
            ),
          ),

        // Floating Launcher Button (Zero-delay Draggable)
        Positioned(
          left: currentLeft,
          top: currentTop,
          child: GestureDetector(
            onPanStart: (_) {
              _left = currentLeft;
              _top = currentTop;
            },
            onPanUpdate: (details) {
              setState(() {
                _left = (_left! + details.delta.dx).clamp(
                  10.0,
                  mediaQuery.size.width - 140.0,
                );
                _top = (_top! + details.delta.dy).clamp(
                  10.0,
                  mediaQuery.size.height - 60.0,
                );
              });
            },
            child: Material(
              elevation: 10,
              borderRadius: BorderRadius.circular(30),
              color: AppTheme.primaryPurple,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: _toggleWidget,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: AppTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isOpen)
                        const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 22,
                        )
                      else
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
                      Text(
                        _isOpen ? 'Tutup' : 'Kreavana AI',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
