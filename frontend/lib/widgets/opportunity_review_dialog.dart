import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../services/opportunity_service.dart';
import 'app_sweet_alert.dart';

class OpportunityReviewDialog extends StatefulWidget {
  final String opportunityId;
  final String projectTitle;
  final String targetUserId;
  final String targetUserName;
  final String? targetUserAvatar;
  final String? targetUserSubRole;
  final VoidCallback? onReviewSubmitted;

  const OpportunityReviewDialog({
    super.key,
    required this.opportunityId,
    required this.projectTitle,
    required this.targetUserId,
    required this.targetUserName,
    this.targetUserAvatar,
    this.targetUserSubRole,
    this.onReviewSubmitted,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String opportunityId,
    required String projectTitle,
    required String targetUserId,
    required String targetUserName,
    String? targetUserAvatar,
    String? targetUserSubRole,
    VoidCallback? onReviewSubmitted,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OpportunityReviewDialog(
        opportunityId: opportunityId,
        projectTitle: projectTitle,
        targetUserId: targetUserId,
        targetUserName: targetUserName,
        targetUserAvatar: targetUserAvatar,
        targetUserSubRole: targetUserSubRole,
        onReviewSubmitted: onReviewSubmitted,
      ),
    );
  }

  @override
  State<OpportunityReviewDialog> createState() =>
      _OpportunityReviewDialogState();
}

class _OpportunityReviewDialogState extends State<OpportunityReviewDialog> {
  double _rating = 5.0;
  bool _isOnTime = true;
  final _commentController = TextEditingController();
  final _deliveryDaysController = TextEditingController();
  final Set<String> _selectedAspects = {};
  bool _isSubmitting = false;
  String? _errorMessage;

  static const List<String> _quickAspects = [
    'Pengerjaan Tepat Waktu',
    'Komunikasi Responsif',
    'Hasil Sesuai Brief',
    'Kualitas Melebihi Ekspektasi',
    'Profesional & Kooperatif',
    'Revisi Cepat & Rapi',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    _deliveryDaysController.dispose();
    super.dispose();
  }

  String _getRatingLabel(double rating) {
    if (rating >= 4.8) return 'Sangat Puas & Sangat Direkomendasikan! 🌟';
    if (rating >= 4.0) return 'Pekerjaan Bagus & Memuaskan 👍';
    if (rating >= 3.0) return 'Cukup Baik & Sesuai Ekspektasi 👌';
    if (rating >= 2.0) return 'Perlu Peningkatan Kualitas ⚠️';
    return 'Kurang Memuaskan ❌';
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4.5) return const Color(0xFF10B981); // Emerald
    if (rating >= 3.5) return const Color(0xFFF59E0B); // Amber
    if (rating >= 2.5) return const Color(0xFF3B82F6); // Blue
    return const Color(0xFFEF4444); // Red
  }

  void _toggleAspect(String aspect) {
    setState(() {
      if (_selectedAspects.contains(aspect)) {
        _selectedAspects.remove(aspect);
      } else {
        _selectedAspects.add(aspect);
      }
    });
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final deliveryDays = int.tryParse(_deliveryDaysController.text.trim());

    // Build comment incorporating aspects if available
    String? finalComment = _commentController.text.trim();
    if (_selectedAspects.isNotEmpty) {
      final aspectText = 'Poin unggulan: ${_selectedAspects.join(', ')}.';
      if (finalComment.isEmpty) {
        finalComment = aspectText;
      } else if (!finalComment.contains('Poin unggulan:')) {
        finalComment = '$finalComment\n\n$aspectText';
      }
    }

    final res = await OpportunityService.submitOpportunityReview(
      opportunityId: widget.opportunityId,
      creatorId: widget.targetUserId,
      rating: _rating,
      comment: finalComment.isNotEmpty ? finalComment : null,
      isOnTime: _isOnTime,
      deliveryDays: deliveryDays,
    );

    if (!mounted) return;

    if (res['status'] == true) {
      widget.onReviewSubmitted?.call();
      Navigator.of(context).pop(true);
      AppSweetAlert.success(
        context,
        'Ulasan untuk "${widget.targetUserName}" berhasil dikirim! Terima kasih atas feedback Anda.',
        title: 'Ulasan Terkirim',
      );
    } else {
      final errorMsg = res['message']?.toString() ?? 'Gagal mengirim ulasan.';
      setState(() {
        _isSubmitting = false;
        _errorMessage = errorMsg;
      });
      AppSweetAlert.error(
        context,
        errorMsg,
        title: 'Gagal Kirim Ulasan',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ratingColor = _getRatingColor(_rating);

    final cardBg = isDark ? const Color(0xFF1E1B38) : Colors.white;
    final surfaceBg = isDark ? const Color(0xFF141226) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF2E2A4A) : const Color(0xFFE2E8F0);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final textHeading = isDark ? Colors.white : const Color(0xFF0F172A);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 540),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.rate_review_rounded,
                          color: Color(0xFFD97706),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Beri Ulasan & Rating Proyek',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textHeading,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.assignment_outlined,
                                  size: 14,
                                  color: textMuted,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    widget.projectTitle,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: IconButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : const Color(0xFFF1F5F9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── Target Recipient Card ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: surfaceBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.15),
                          backgroundImage: widget.targetUserAvatar != null &&
                                  widget.targetUserAvatar!.isNotEmpty
                              ? NetworkImage(widget.targetUserAvatar!)
                              : null,
                          child: widget.targetUserAvatar == null ||
                                  widget.targetUserAvatar!.isEmpty
                              ? Text(
                                  widget.targetUserName.isNotEmpty
                                      ? widget.targetUserName[0].toUpperCase()
                                      : 'K',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppTheme.primaryPurple,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.targetUserName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: textHeading,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.verified_rounded,
                                          size: 11,
                                          color: Color(0xFF059669),
                                        ),
                                        SizedBox(width: 3),
                                        Text(
                                          'Mitra',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF059669),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.targetUserSubRole != null &&
                                        widget.targetUserSubRole!.isNotEmpty
                                    ? widget.targetUserSubRole!
                                    : 'Mitra Kreator Kreavana',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Rating Score & Interactive Stars Card ──
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                    decoration: BoxDecoration(
                      color: surfaceBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              _rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                color: ratingColor,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '/ 5.0',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // 5 Interactive Stars
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            final starValue = index + 1.0;
                            final isFilled = _rating >= starValue;
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _rating = starValue;
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                child: Icon(
                                  isFilled
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  size: 40,
                                  color: isFilled
                                      ? ratingColor
                                      : (isDark
                                          ? const Color(0xFF475569)
                                          : const Color(0xFFCBD5E1)),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 10),
                        // Rating Label Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: ratingColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ratingColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            _getRatingLabel(_rating),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: ratingColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Quick Praise Aspects (Chips) ──
                  Text(
                    'Aspek yang Memuaskan (Pilih Sesuai Kolaborasi):',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: textHeading,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickAspects.map((aspect) {
                      final isSelected = _selectedAspects.contains(aspect);
                      return InkWell(
                        onTap: () => _toggleAspect(aspect),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF7C3AED).withValues(alpha: 0.14)
                                : surfaceBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF7C3AED)
                                  : borderColor,
                              width: isSelected ? 1.4 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.add_circle_outline_rounded,
                                size: 14,
                                color: isSelected
                                    ? const Color(0xFF7C3AED)
                                    : textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                aspect,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xFF7C3AED)
                                      : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── Timeline & On-Time Performance (2-Column Card) ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surfaceBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Evaluasi Waktu Pengerjaan',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: textHeading,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // On-Time Toggle
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _isOnTime
                                            ? Icons.check_circle_rounded
                                            : Icons.access_time_filled_rounded,
                                        size: 16,
                                        color: _isOnTime
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFF59E0B),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _isOnTime ? 'Tepat Waktu' : 'Ada Keterlambatan',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _isOnTime
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFF59E0B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => setState(() => _isOnTime = true),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            decoration: BoxDecoration(
                                              color: _isOnTime
                                                  ? const Color(0xFF10B981).withValues(alpha: 0.16)
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: _isOnTime
                                                    ? const Color(0xFF10B981)
                                                    : borderColor,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              'Tepat',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: _isOnTime
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: _isOnTime
                                                    ? const Color(0xFF059669)
                                                    : textMuted,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => setState(() => _isOnTime = false),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            decoration: BoxDecoration(
                                              color: !_isOnTime
                                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.16)
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: !_isOnTime
                                                    ? const Color(0xFFF59E0B)
                                                    : borderColor,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              'Terlambat',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: !_isOnTime
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: !_isOnTime
                                                    ? const Color(0xFFD97706)
                                                    : textMuted,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Delivery Days Input
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Durasi Aktual',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: textHeading,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _deliveryDaysController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Misal: 5',
                                      suffixText: 'Hari',
                                      suffixStyle: TextStyle(
                                        fontSize: 11.5,
                                        color: textMuted,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.timelapse_rounded,
                                        size: 16,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      filled: true,
                                      fillColor: isDark
                                          ? const Color(0xFF1E1B38)
                                          : Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: borderColor),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: borderColor),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Feedback Comment ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ulasan & Testimoni (Opsional):',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: textHeading,
                        ),
                      ),
                      Text(
                        'Membantu reputasi mitra',
                        style: TextStyle(
                          fontSize: 11,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentController,
                    maxLines: 4,
                    style: TextStyle(fontSize: 13, color: textHeading),
                    decoration: InputDecoration(
                      hintText:
                          'Ceritakan pengalaman kolaborasi Anda, kualitas hasil karya, komunikasi, dan profesionalisme...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
                      ),
                      filled: true,
                      fillColor: surfaceBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF7C3AED),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                  // ── Error Banner ──
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFEF4444),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── Action Buttons ──
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            foregroundColor: isDark ? Colors.white70 : const Color(0xFF475569),
                            side: BorderSide(color: borderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Batal',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.send_rounded, size: 16),
                                    SizedBox(width: 8),
                                    Text(
                                      'Kirim Ulasan',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ],
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
    );
  }
}
