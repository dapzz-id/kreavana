import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../services/opportunity_service.dart';

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
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _commentController.dispose();
    _deliveryDaysController.dispose();
    super.dispose();
  }

  String _getRatingLabel(double rating) {
    if (rating >= 4.5) return 'Sangat Puas & Sangat Direkomendasikan! 🌟';
    if (rating >= 3.5) return 'Bagus & Memuaskan 👍';
    if (rating >= 2.5) return 'Cukup Memadai 👌';
    if (rating >= 1.5) return 'Kurang Memuaskan ⚠️';
    return 'Sangat Mengecewakan ❌';
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4.0) return const Color(0xFFF59E0B);
    if (rating >= 3.0) return const Color(0xFF3B82F6);
    return const Color(0xFFEF4444);
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final deliveryDays = int.tryParse(_deliveryDaysController.text.trim());

    final res = await OpportunityService.submitOpportunityReview(
      opportunityId: widget.opportunityId,
      creatorId: widget.targetUserId,
      rating: _rating,
      comment: _commentController.text.trim().isNotEmpty
          ? _commentController.text.trim()
          : null,
      isOnTime: _isOnTime,
      deliveryDays: deliveryDays,
    );

    if (!mounted) return;

    if (res['status'] == true) {
      widget.onReviewSubmitted?.call();
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ulasan berhasil dikirim! Terima kasih atas feedback Anda.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage = res['message']?.toString() ?? 'Gagal mengirim ulasan.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ratingColor = _getRatingColor(_rating);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardBg : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.rate_review_rounded,
                        color: Color(0xFFF59E0B),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Beri Ulasan & Rating Proyek',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.projectTitle,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade100,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ── Review Target Card ──
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
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
                                    : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
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
                            Text(
                              'Menilai: ${widget.targetUserName}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (widget.targetUserSubRole != null &&
                                widget.targetUserSubRole!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.targetUserSubRole!,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Interactive Star Rating ──
                Center(
                  child: Column(
                    children: [
                      Text(
                        _rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: ratingColor,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starValue = index + 1.0;
                          return IconButton(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() => _rating = starValue);
                            },
                            icon: Icon(
                              _rating >= starValue
                                  ? Icons.star_rounded
                                  : (_rating >= starValue - 0.5
                                      ? Icons.star_half_rounded
                                      : Icons.star_outline_rounded),
                              size: 36,
                              color: ratingColor,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _getRatingLabel(_rating),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: ratingColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Specific Criteria: On-Time & Delivery Days ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.02)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.schedule_rounded, size: 18, color: Color(0xFF3B82F6)),
                              SizedBox(width: 8),
                              Text(
                                'Pengerjaan Tepat Waktu',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _isOnTime,
                            activeThumbColor: const Color(0xFF10B981),
                            onChanged: (val) => setState(() => _isOnTime = val),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text(
                            'Durasi Kerja:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 80,
                            height: 36,
                            child: TextField(
                              controller: _deliveryDaysController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 12.5),
                              decoration: InputDecoration(
                                hintText: 'Hari',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'hari selesai',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Feedback Comment ──
                const Text(
                  'Ulasan & Testimoni (Opsional):',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText:
                        'Ceritakan pengalaman kolaborasi Anda, kualitas hasil, komunikasi, dan profesionalitas...',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryPurple,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

                // ── Error Banner ──
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
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
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.send_rounded, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    'Kirim Ulasan',
                                    style: TextStyle(fontWeight: FontWeight.bold),
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
    );
  }
}
