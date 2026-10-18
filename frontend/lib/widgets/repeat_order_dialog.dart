import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app/theme.dart';
import '../models/job_contract.dart';
import '../services/job_contract_service.dart';

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
      barrierDismissible: false,
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

  final NumberFormat _currencyFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
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
      text: initialPrice > 0 ? initialPrice.toStringAsFixed(0) : '',
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

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isAfter(_startDate) ? _endDate : _startDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _submitRepeatOrder() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final parsedPrice = double.tryParse(
      _priceController.text.replaceAll('.', '').replaceAll(',', '').trim(),
    ) ?? (widget.originalPrice ?? 0.0);

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Repeat order berhasil diajukan ke ${widget.creatorName}! Kontrak kerja baru telah terbit.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      widget.onSuccess?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFmt = DateFormat('dd MMM yyyy', 'id_ID');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E1B38) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.replay_circle_filled_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Repeat Order (Pesan Ulang)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pesan ulang proyek dengan kreator mitra pilihan Anda',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _submitting ? null : () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 18),

                // Creator Card Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141226) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.2),
                        child: Text(
                          widget.creatorName.isNotEmpty
                              ? widget.creatorName[0].toUpperCase()
                              : 'K',
                          style: const TextStyle(
                            color: AppTheme.primaryPurple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.creatorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                            Text(
                              'Mitra Kreator Terpercaya Kreavana',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
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

                // Input: Judul Proyek
                const Text(
                  'Judul Proyek Repeat Order',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Judul proyek wajib diisi' : null,
                  decoration: InputDecoration(
                    hintText: 'Misal: Repeat Order - Pembuatan Video Cinematic',
                    isDense: true,
                    prefixIcon: const Icon(Icons.work_outline_rounded, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),

                // Input: Tanggal Mulai & Selesai
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tanggal Mulai',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: _pickStartDate,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.primaryPurple),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      dateFmt.format(_startDate),
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
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
                          const Text(
                            'Target Selesai',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: _pickEndDate,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.event_available_rounded, size: 16, color: Color(0xFF10B981)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      dateFmt.format(_endDate),
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
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
                const SizedBox(height: 14),

                // Input: Kesepakatan Biaya
                const Text(
                  'Kesepakatan Dana / Harga (Rp)',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Nominal harga wajib diisi';
                    final num = double.tryParse(v.replaceAll('.', '').replaceAll(',', ''));
                    if (num == null || num <= 0) return 'Nominal harga tidak valid';
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Misal: 3500000',
                    prefixText: 'Rp ',
                    isDense: true,
                    prefixIcon: const Icon(Icons.payments_outlined, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),

                // Input: Ruang Lingkup & Catatan
                const Text(
                  'Ruang Lingkup & Catatan Repeat Order',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Jelaskan kebutuhan atau spesifikasi khusus untuk order kali ini...',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),

                // Input: Ketentuan & Garansi
                const Text(
                  'Ketentuan Tambahan & Garansi',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _termsController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Ketentuan kerja sama dan revisi...',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 22),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _submitting ? null : () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _submitting ? null : _submitRepeatOrder,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.replay_rounded, size: 18),
                      label: Text(
                        _submitting ? 'Memproses...' : 'Kirim Repeat Order',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
