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
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppTheme.cardLight,
              title: Text(
                schedule == null ? 'Tambah Jadwal' : 'Edit Jadwal',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? now,
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 365)),
                        );
                        if (d != null) {
                          setStateDialog(() {
                            selectedDate = d;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.inputBorderLight),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              selectedDate == null
                                  ? 'Pilih Tanggal'
                                  : DateFormat(
                                      'yyyy-MM-dd',
                                    ).format(selectedDate!),
                              style: TextStyle(
                                fontSize: 14,
                                color: selectedDate == null
                                    ? AppTheme.textMuted
                                    : AppTheme.textDark,
                              ),
                            ),
                            const Icon(
                              Icons.calendar_today,
                              color: AppTheme.primaryPurple,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: isUnavailable,
                          activeColor: AppTheme.primaryPurple,
                          onChanged: (val) {
                            setStateDialog(() {
                              isUnavailable = val ?? false;
                              if (isUnavailable) maxCapacityCtrl.clear();
                            });
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Tandai sebagai Tidak Tersedia',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!isUnavailable) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: maxCapacityCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textDark,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Kapasitas Maksimal (Opsional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesCtrl,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textDark,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Catatan (Opsional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
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
                    final dateStr = DateFormat(
                      'yyyy-MM-dd',
                    ).format(selectedDate!);
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
                          SnackBar(
                            content: Text(res.message ?? 'Gagal menyimpan'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteSchedule(String date) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardLight,
        title: const Text(
          'Hapus Jadwal',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        content: Text(
          'Yakin ingin menghapus override jadwal tanggal $date?',
          style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

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
      floatingActionButton: FloatingActionButton(
        heroTag: 'creator_calendar_fab',
        backgroundColor: AppTheme.primaryPurple,
        onPressed: () => _showScheduleDialog(),
        child: const Icon(Icons.add, color: Colors.white),
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
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 32 : 16,
                16,
                isDesktop ? 32 : 16,
                24,
              ),
              itemCount: _schedules.length,
              itemBuilder: (context, index) {
                final s = _schedules[index];
                return Card(
                  color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          _formatDate(s.date),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF2D2A3E)
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            _cleanIsoDate(s.date),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        if (s.isUnavailable)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Tidak Tersedia',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.error,
                              ),
                            ),
                          )
                        else
                          Text(
                            'Kapasitas: ${s.maxCapacity ?? 'Tidak terbatas'}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        if (s.notes != null && s.notes!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Catatan: ${s.notes}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: AppTheme.primaryPurple,
                          ),
                          onPressed: () => _showScheduleDialog(s),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: AppTheme.error),
                          onPressed: () => _deleteSchedule(s.date),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
