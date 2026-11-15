import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app/theme.dart';
import '../services/job_contract_service.dart';
import 'app_sweet_alert.dart';

class RepeatOrderDialog extends StatefulWidget {
  final String? contractId;
  final String creatorId;
  final String creatorName;
  final String? creatorAvatar;
  final String? originalTitle;
  final double? originalPrice;
  final String? defaultTerms;
  final VoidCallback? onSuccess;

  const RepeatOrderDialog({
    super.key,
    this.contractId,
    required this.creatorId,
    required this.creatorName,
    this.creatorAvatar,
    this.originalTitle,
    this.originalPrice,
    this.defaultTerms,
    this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    String? contractId,
    required String creatorId,
    required String creatorName,
    String? creatorAvatar,
    String? originalTitle,
    double? originalPrice,
    String? defaultTerms,
    VoidCallback? onSuccess,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => RepeatOrderDialog(
        contractId: contractId,
        creatorId: creatorId,
        creatorName: creatorName,
        creatorAvatar: creatorAvatar,
        originalTitle: originalTitle,
        originalPrice: originalPrice,
        defaultTerms: defaultTerms,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<RepeatOrderDialog> createState() => _RepeatOrderDialogState();
}

class _RepeatOrderDialogState extends State<RepeatOrderDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _priceController;
  late TextEditingController _notesController;
  late TextEditingController _termsController;

  late DateTime _startDate;
  late DateTime _endDate;
  bool _submitting = false;
  bool _showGuideDetails = true;

  final NumberFormat _currencyFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    final baseTitle = widget.originalTitle ?? 'Proyek Kreatif';
    _titleController = TextEditingController(
      text: baseTitle.toLowerCase().startsWith('repeat order')
          ? baseTitle
          : 'Repeat Order - $baseTitle',
    );

    final initialPrice = widget.originalPrice ?? 0.0;
    _priceController = TextEditingController(
      text: initialPrice > 0 ? _formatNumber(initialPrice.round()) : '',
    );

    _notesController = TextEditingController(
      text: 'Pemesanan ulang proyek dengan mitra kreator. Kualitas dan ruang lingkup mengacu pada proyek sebelumnya.',
    );

    _termsController = TextEditingController(
      text: widget.defaultTerms ??
          'Penyelesaian pekerjaan wajib dikonfirmasi kedua belah pihak. Garansi revisi standar 2x.',
    );

    _startDate = DateTime.now().add(const Duration(days: 2));
    _endDate = DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  String _formatNumber(num number) {
    return _currencyFmt.format(number).trim();
  }

  void _onPriceChanged(String value) {
    final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) {
      _priceController.value = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      return;
    }
    final numVal = int.tryParse(clean) ?? 0;
    final formatted = _formatNumber(numVal);
    _priceController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatDate(DateTime dt) {
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      return DateFormat('dd MMM yyyy').format(dt);
    }
  }

  int get _projectDurationDays {
    final diff = _endDate.difference(_startDate).inDays;
    return diff < 1 ? 1 : diff;
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final firstDate = now.isBefore(_startDate)
        ? now.subtract(const Duration(days: 1))
        : _startDate.subtract(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 3));
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final initialDate = _endDate.isAfter(_startDate) ? _endDate : _startDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  void _applyScopePreset(String text) {
    setState(() {
      final current = _notesController.text.trim();
      if (current.isEmpty) {
        _notesController.text = text;
      } else if (!current.contains(text)) {
        _notesController.text = '$current\n- $text';
      }
    });
  }

  void _applyTermsPreset(String text) {
    setState(() {
      final current = _termsController.text.trim();
      if (current.isEmpty) {
        _termsController.text = text;
      } else if (!current.contains(text)) {
        _termsController.text = '$current. $text';
      }
    });
  }

  Future<void> _submitRepeatOrder() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cleanDigits = _priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final parsedPrice = double.tryParse(cleanDigits) ?? (widget.originalPrice ?? 0.0);

    setState(() => _submitting = true);

    final df = DateFormat('yyyy-MM-dd');
    final payload = {
      'title': _titleController.text.trim(),
      'description': _notesController.text.trim(),
      'terms': _termsController.text.trim(),
      'agreed_price': parsedPrice,
      'scheduled_start_date': df.format(_startDate),
      'scheduled_end_date': df.format(_endDate),
      'deadline': df.format(_endDate),
      'notes': _notesController.text.trim(),
      'partner_id': widget.creatorId,
      'my_role': 'client',
    };

    try {
      if (widget.contractId != null && widget.contractId!.isNotEmpty) {
        await JobContractService.repeatOrder(widget.contractId!, payload);
      } else {
        await JobContractService.createContract(payload);
      }

      if (!mounted) return;
      Navigator.pop(context);

      AppSweetAlert.success(
        context,
        'Repeat order berhasil diajukan ke ${widget.creatorName}! Kontrak kerja baru telah resmi diterbitkan.',
        title: 'Repeat Order Berhasil',
      );

      widget.onSuccess?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      AppSweetAlert.error(
        context,
        errorMsg,
        title: 'Gagal Mengirim Repeat Order',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          constraints: const BoxConstraints(maxWidth: 620),
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
              child: Form(
                key: _formKey,
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
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.replay_circle_filled_rounded,
                            color: Color(0xFF7C3AED),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Repeat Order (Pesan Ulang)',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textHeading,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Pesan ulang proyek langsung dengan mitra kreator tanpa proses seleksi baru.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: _submitting ? null : () => Navigator.pop(context),
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

                    // ── Panduan Alur Repeat Order (User-Requested Guide) ──
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: isDark ? 0.08 : 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.22),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.auto_stories_rounded,
                                size: 16,
                                color: Color(0xFF7C3AED),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Panduan Alur Repeat Order',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7C3AED),
                                ),
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: () => setState(() => _showGuideDetails = !_showGuideDetails),
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Row(
                                    children: [
                                      Text(
                                        _showGuideDetails ? 'Ringkas' : 'Pelajari',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF7C3AED),
                                        ),
                                      ),
                                      Icon(
                                        _showGuideDetails
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                        size: 16,
                                        color: const Color(0xFF7C3AED),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_showGuideDetails) ...[
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildGuideStep(
                                  number: '1',
                                  title: 'Tanpa Seleksi Ulang',
                                  desc: 'Kontrak langsung ditugaskan ke mitra tanpa tender terbuka.',
                                  isDark: isDark,
                                ),
                                const SizedBox(width: 8),
                                _buildGuideStep(
                                  number: '2',
                                  title: 'Atur Kesepakatan',
                                  desc: 'Tentukan tanggal, harga, dan catatan lingkup baru.',
                                  isDark: isDark,
                                ),
                                const SizedBox(width: 8),
                                _buildGuideStep(
                                  number: '3',
                                  title: 'Kontrak Resmi',
                                  desc: 'Setelah kreator konfirmasi, kontrak langsung aktif terproteksi.',
                                  isDark: isDark,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.2)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.lightbulb_outline_rounded,
                                    size: 14,
                                    color: Color(0xFFD97706),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Menghemat waktu persiapan karena mitra telah memahami standar dan gaya kerja Anda.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Creator Partner Card ──
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: surfaceBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.15),
                            backgroundImage: (widget.creatorAvatar != null &&
                                    widget.creatorAvatar!.trim().isNotEmpty)
                                ? NetworkImage(widget.creatorAvatar!)
                                : null,
                            child: (widget.creatorAvatar == null ||
                                    widget.creatorAvatar!.trim().isEmpty)
                                ? Text(
                                    widget.creatorName.trim().isNotEmpty
                                        ? widget.creatorName.trim()[0].toUpperCase()
                                        : 'K',
                                    style: const TextStyle(
                                      color: AppTheme.primaryPurple,
                                      fontWeight: FontWeight.bold,
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
                                  widget.creatorName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: textHeading,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Penerima Kontrak Kerja Repeat Order',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded, size: 12, color: Color(0xFF10B981)),
                                SizedBox(width: 4),
                                Text(
                                  'Verified',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ── Bagian 1: Judul Proyek ──
                    Text(
                      'Judul Proyek Repeat Order',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: textHeading,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _titleController,
                      style: TextStyle(fontSize: 13, color: textHeading),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Judul proyek wajib diisi' : null,
                      decoration: InputDecoration(
                        hintText: 'Misal: Repeat Order - Pembuatan Video Cinematic Batch 2',
                        prefixIcon: const Icon(Icons.work_outline_rounded, size: 18),
                        filled: true,
                        fillColor: surfaceBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Bagian 2: Tanggal & Jadwal Pengerjaan ──
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tanggal Mulai',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: textHeading,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: _pickStartDate,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: surfaceBg,
                                    border: Border.all(color: borderColor),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_rounded,
                                        size: 16,
                                        color: Color(0xFF7C3AED),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _formatDate(_startDate),
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: textHeading,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Target Selesai',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: textHeading,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: _pickEndDate,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: surfaceBg,
                                    border: Border.all(color: borderColor),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.event_available_rounded,
                                        size: 16,
                                        color: Color(0xFF10B981),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _formatDate(_endDate),
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: textHeading,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Calculated duration indicator
                    Row(
                      children: [
                        const Icon(
                          Icons.timelapse_rounded,
                          size: 13,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Estimasi Waktu Pengerjaan: $_projectDurationDays Hari Kalender',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Bagian 3: Kesepakatan Biaya / Harga (Rp) ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kesepakatan Dana / Harga (Rp)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: textHeading,
                          ),
                        ),
                        if (widget.originalPrice != null && widget.originalPrice! > 0)
                          InkWell(
                            onTap: () {
                              _onPriceChanged(widget.originalPrice!.round().toString());
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Text(
                                'Gunakan Harga Lalu (Rp ${_formatNumber(widget.originalPrice!.round())})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7C3AED),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      onChanged: _onPriceChanged,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textHeading,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Nominal harga wajib diisi';
                        final numVal = double.tryParse(v.replaceAll(RegExp(r'[^0-9]'), ''));
                        if (numVal == null || numVal <= 0) return 'Nominal harga tidak valid';
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'Misal: 18.000.000',
                        prefixText: 'Rp  ',
                        prefixStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7C3AED),
                          fontSize: 13.5,
                        ),
                        prefixIcon: const Icon(Icons.payments_outlined, size: 18),
                        filled: true,
                        fillColor: surfaceBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Bagian 4: Ruang Lingkup & Catatan ──
                    Text(
                      'Ruang Lingkup & Catatan Repeat Order',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: textHeading,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      style: TextStyle(fontSize: 12.5, color: textHeading),
                      decoration: InputDecoration(
                        hintText: 'Jelaskan kebutuhan atau spesifikasi khusus untuk order kali ini...',
                        filled: true,
                        fillColor: surfaceBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Quick Scope Chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildPresetChip('Sesuai SOP Sebelumnya', _applyScopePreset, isDark),
                        _buildPresetChip('Pembaruan Aset Baru', _applyScopePreset, isDark),
                        _buildPresetChip('Penyesuaian Durasi', _applyScopePreset, isDark),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Bagian 5: Ketentuan Tambahan & Garansi ──
                    Text(
                      'Ketentuan Tambahan & Garansi',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: textHeading,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _termsController,
                      maxLines: 2,
                      style: TextStyle(fontSize: 12.5, color: textHeading),
                      decoration: InputDecoration(
                        hintText: 'Ketentuan kerja sama dan revisi...',
                        filled: true,
                        fillColor: surfaceBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildPresetChip('Garansi Revisi 2x', _applyTermsPreset, isDark),
                        _buildPresetChip('Garansi Revisi 3x & File Mentah', _applyTermsPreset, isDark),
                        _buildPresetChip('Approval Bertahap', _applyTermsPreset, isDark),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Action Buttons ──
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _submitting ? null : () => Navigator.pop(context),
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
                            onPressed: _submitting ? null : _submitRepeatOrder,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _submitting
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
                                      Icon(Icons.replay_rounded, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Kirim Repeat Order',
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
      ),
    );
  }

  Widget _buildGuideStep({
    required String number,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.black.withValues(alpha: 0.15) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Color(0xFF7C3AED),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, Function(String) onTap, bool isDark) {
    return InkWell(
      onTap: () => onTap(label),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 12, color: Color(0xFF7C3AED)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
