import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app/theme.dart';
import '../models/schedule_model.dart';
import '../models/user_model.dart';
import '../services/schedule_service.dart';
import '../widgets/app_empty_state.dart';

class CreatorCalendarScreen extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const CreatorCalendarScreen({
    super.key,
    this.user,
    this.onUserUpdated,
  });

  @override
  State<CreatorCalendarScreen> createState() => _CreatorCalendarScreenState();
}

class _CreatorCalendarScreenState extends State<CreatorCalendarScreen> {
  bool _isLoading = true;
  String? _error;
  List<CreatorCapacitySchedule> _schedules = [];

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final res = await ScheduleService.getCreatorCalendar();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.success) {
          _schedules = res.data ?? [];
        } else {
          _error = res.message;
        }
      });
    }
  }

  Future<void> _showScheduleDialog([CreatorCapacitySchedule? schedule]) async {
    DateTime? selectedDate = schedule != null
        ? DateTime.parse(schedule.date)
        : null;
    bool isUnavailable = schedule?.isUnavailable ?? false;
    final maxCapacityCtrl = TextEditingController(
      text: schedule?.maxCapacity?.toString() ?? '',
    );
    final notesCtrl = TextEditingController(text: schedule?.notes ?? '');

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (dialogCtx, setStateDialog) {
            return Dialog(
              backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPurple.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.calendar_month_rounded,
                                color: AppTheme.primaryPurple,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    schedule == null
                                        ? 'Tambah Jadwal'
                                        : 'Edit Jadwal',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : AppTheme.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Atur ketersediaan dan kuota tanggal ini',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                              onPressed: () => Navigator.pop(ctx),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Tanggal
                        Text(
                          'Pilih Tanggal',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final now = DateTime.now();
                            final d = await showDatePicker(
                              context: context,
                              initialDate: selectedDate ?? now,
                              firstDate: now.subtract(const Duration(days: 30)),
                              lastDate: now.add(const Duration(days: 365)),
                            );
                            if (d != null) {
                              setStateDialog(() {
                                selectedDate = d;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1A33) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  color: AppTheme.primaryPurple,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedDate == null
                                            ? 'Pilih Tanggal Kalender'
                                            : _formatDate(DateFormat('yyyy-MM-dd').format(selectedDate!)),
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: selectedDate == null
                                              ? AppTheme.textMuted
                                              : (isDark ? Colors.white : AppTheme.textDark),
                                        ),
                                      ),
                                      if (selectedDate != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          DateFormat('yyyy-MM-dd').format(selectedDate!),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Ubah',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryPurple,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Status Ketersediaan
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUnavailable
                                ? AppTheme.error.withValues(alpha: isDark ? 0.15 : 0.08)
                                : (isDark ? const Color(0xFF1E1A33) : Colors.grey.shade50),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isUnavailable
                                  ? AppTheme.error.withValues(alpha: 0.4)
                                  : (isDark ? AppTheme.inputBorder : Colors.grey.shade300),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isUnavailable
                                      ? AppTheme.error.withValues(alpha: 0.2)
                                      : Colors.green.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isUnavailable
                                      ? Icons.block_rounded
                                      : Icons.check_circle_outline_rounded,
                                  color: isUnavailable ? AppTheme.error : Colors.green.shade600,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tandai sebagai Tidak Tersedia',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isUnavailable
                                            ? AppTheme.error
                                            : (isDark ? Colors.white : AppTheme.textDark),
                                      ),
                                    ),
                                    Text(
                                      isUnavailable
                                          ? 'Klien tidak dapat memesan Anda pada tanggal ini'
                                          : 'Anda siap menerima order / tugas pekerjaan',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: isUnavailable,
                                activeThumbColor: AppTheme.error,
                                onChanged: (val) {
                                  setStateDialog(() {
                                    isUnavailable = val;
                                    if (isUnavailable) maxCapacityCtrl.clear();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Kapasitas Maksimal
                        if (!isUnavailable) ...[
                          Text(
                            'Kapasitas Maksimal (Opsional)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: maxCapacityCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Contoh: 1, 2, atau kosongkan (default)',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white38 : Colors.grey.shade400,
                              ),
                              prefixIcon: const Icon(Icons.people_alt_outlined, size: 18),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E1A33) : Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Catatan Operasional
                        Text(
                          'Catatan (Opsional)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: notesCtrl,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Misal: Sesi foto outdoor pagi saja, Libur keluarga, dll.',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white38 : Colors.grey.shade400,
                            ),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 18),
                              child: Icon(Icons.note_alt_outlined, size: 18),
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E1A33) : Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(
                                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                                  ),
                                ),
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(
                                  'Batal',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : AppTheme.textMuted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryPurple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                                label: const Text(
                                  'Simpan',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                onPressed: () async {
                                  if (selectedDate == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Silakan pilih tanggal')),
                                    );
                                    return;
                                  }
                                  Navigator.pop(ctx);

                                  setState(() => _isLoading = true);
                                  final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate!);
                                  final res = await ScheduleService.saveCalendarOverride(
                                    date: dateStr,
                                    isUnavailable: isUnavailable,
                                    maxCapacity: isUnavailable
                                        ? null
                                        : int.tryParse(maxCapacityCtrl.text),
                                    notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                                  );

                                  if (res.success) {
                                    _loadSchedules();
                                  } else {
                                    setState(() => _isLoading = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(res.message ?? 'Gagal menyimpan')),
                                      );
                                    }
                                  }
                                },
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
          },
        );
      },
    );
  }

  Future<void> _deleteSchedule(String date) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Hapus Jadwal',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
            ],
          ),
          content: Text(
            'Yakin ingin menghapus override jadwal tanggal $date?',
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? Colors.white70 : AppTheme.textDark,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Batal',
                style: TextStyle(
                  color: isDark ? Colors.white60 : AppTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final res = await ScheduleService.deleteCalendarOverride(date);
      if (res.success) {
        _loadSchedules();
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.message ?? 'Gagal menghapus')),
          );
        }
      }
    }
  }

  String _formatDate(String rawDate) {
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      const monthNames = [
        '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      const dayNames = [
        '', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
      ];
      final dayName = dayNames[dt.weekday];
      final monthName = monthNames[dt.month];
      return '$dayName, ${dt.day} $monthName ${dt.year}';
    } catch (_) {
      return rawDate;
    }
  }

  String _cleanIsoDate(String rawDate) {
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      return DateFormat('yyyy-MM-dd').format(dt);
    } catch (_) {
      return rawDate.split('T').first;
    }
  }

  String _extractDayNumber(String rawDate) {
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      return dt.day.toString().padLeft(2, '0');
    } catch (_) {
      return '01';
    }
  }

  String _extractMonthYear(String rawDate) {
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      const mNames = [
        '', 'JAN', 'FEB', 'MAR', 'APR', 'MEI', 'JUN',
        'JUL', 'AGU', 'SEP', 'OKT', 'NOV', 'DES'
      ];
      return '${mNames[dt.month]} ${dt.year}';
    } catch (_) {
      return '2026';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    final totalOverrides = _schedules.length;
    final totalUnavailable = _schedules.where((s) => s.isUnavailable).length;
    final totalAvailable = totalOverrides - totalUnavailable;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      appBar: AppBar(
        automaticallyImplyLeading: Navigator.canPop(context),
        toolbarHeight: 80,
        titleSpacing: isDesktop ? 32 : 16,
        title: Text(
          'Jadwal & Ketersediaan',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadSchedules,
            tooltip: 'Perbarui Jadwal',
          ),
          SizedBox(width: isDesktop ? 24 : 8),
        ],
        backgroundColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'creator_calendar_fab',
        backgroundColor: AppTheme.primaryPurple,
        elevation: 4,
        onPressed: () => _showScheduleDialog(),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Atur Jadwal Baru',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(fontSize: 14, color: AppTheme.error),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadSchedules,
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            )
          : _schedules.isEmpty
          ? const AppEmptyState(
              icon: Icons.calendar_today,
              title: 'Belum Ada Jadwal Khusus',
              subtitle:
                  'Tambahkan override jadwal jika Anda ingin mengatur hari libur atau kapasitas maksimal harian.',
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 32 : 16,
                20,
                isDesktop ? 32 : 16,
                90,
              ),
                  children: [
                    // Top Summary Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            title: 'Total Override',
                            value: '$totalOverrides Tanggal',
                            icon: Icons.date_range_rounded,
                            color: AppTheme.primaryPurple,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSummaryCard(
                            title: 'Hari Tersedia',
                            value: '$totalAvailable Hari',
                            icon: Icons.check_circle_rounded,
                            color: const Color(0xFF10B981),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSummaryCard(
                            title: 'Hari Libur',
                            value: '$totalUnavailable Hari',
                            icon: Icons.block_rounded,
                            color: AppTheme.error,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Info helper banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFF1E1A33) : Colors.grey.shade100)
                            .withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb_outline_rounded,
                              size: 18, color: AppTheme.primaryPurple),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tanggal yang tidak tercantum di sini akan otomatis mengikuti kapasitas reguler profil Anda.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: isDark ? Colors.white70 : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Schedule Items
                    ..._schedules.map((s) => _buildScheduleItemCard(s, isDark)),
                  ],
                ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
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
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleItemCard(CreatorCapacitySchedule s, bool isDark) {
    final isUnavailable = s.isUnavailable;
    final cardColor = isDark ? AppTheme.cardDark : Colors.white;
    final borderColor = isDark ? AppTheme.inputBorder : Colors.grey.shade200;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Calendar Date Block
            Container(
              width: 58,
              height: 62,
              decoration: BoxDecoration(
                color: isUnavailable
                    ? AppTheme.error.withValues(alpha: isDark ? 0.2 : 0.08)
                    : AppTheme.primaryPurple.withValues(alpha: isDark ? 0.2 : 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isUnavailable
                      ? AppTheme.error.withValues(alpha: 0.3)
                      : AppTheme.primaryPurple.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _extractDayNumber(s.date),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isUnavailable ? AppTheme.error : AppTheme.primaryPurple,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _extractMonthYear(s.date),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Content details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        _formatDate(s.date),
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2D2A3E) : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          _cleanIsoDate(s.date),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Status badge row
                  Row(
                    children: [
                      if (isUnavailable)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.block_rounded, size: 12, color: AppTheme.error),
                              SizedBox(width: 4),
                              Text(
                                'Tidak Tersedia',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.error,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                              const SizedBox(width: 4),
                              Text(
                                'Kapasitas: ${s.maxCapacity ?? 'Tidak terbatas'}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Notes section
                  if (s.notes != null && s.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161326) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.sticky_note_2_outlined,
                              size: 13,
                              color: isDark ? AppTheme.textMuted : Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Catatan: ${s.notes}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
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
            const SizedBox(width: 10),

            // Action buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit Jadwal',
                  icon: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: AppTheme.primaryPurple,
                      size: 17,
                    ),
                  ),
                  onPressed: () => _showScheduleDialog(s),
                ),
                IconButton(
                  tooltip: 'Hapus Jadwal',
                  icon: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.error,
                      size: 17,
                    ),
                  ),
                  onPressed: () => _deleteSchedule(s.date),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

