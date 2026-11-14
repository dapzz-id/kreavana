import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app/theme.dart';
import '../models/schedule_model.dart';
import '../services/schedule_service.dart';

class CreatorAvailabilityWidget extends StatefulWidget {
  final String creatorId;
  final Color? accentColor;

  const CreatorAvailabilityWidget({
    super.key,
    required this.creatorId,
    this.accentColor,
  });

  @override
  State<CreatorAvailabilityWidget> createState() =>
      _CreatorAvailabilityWidgetState();
}

class _CreatorAvailabilityWidgetState extends State<CreatorAvailabilityWidget> {
  DateTime? _selectedDate;
  bool _isLoading = false;
  String? _error;
  AvailabilityDetail? _availability;

  Future<void> _checkAvailability() async {
    if (_selectedDate == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _availability = null;
    });

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    final res = await ScheduleService.getCreatorAvailabilityForDate(
      widget.creatorId,
      dateStr,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.success) {
          _availability = res.data;
        } else {
          _error = res.message;
        }
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return AppTheme.success;
      case 'limited':
        return AppTheme.warning;
      case 'busy':
        return Colors.deepOrange;
      case 'full':
      case 'unavailable':
        return AppTheme.error;
      default:
        return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accentColor ?? AppTheme.primaryPurple;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.event_available_rounded, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cek Ketersediaan Tanggal',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pilih tanggal untuk melihat ketersediaan jadwal kreator.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final now = DateTime.now();
              final d = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? now,
                firstDate: now,
                lastDate: now.add(const Duration(days: 90)),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                        primary: accent,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (d != null && d != _selectedDate) {
                setState(() => _selectedDate = d);
                _checkAvailability();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark2 : Colors.grey.shade50,
                border: Border.all(
                  color: _selectedDate != null
                      ? accent.withValues(alpha: 0.6)
                      : (isDark ? AppTheme.inputBorder : Colors.grey.shade300),
                  width: _selectedDate != null ? 1.4 : 1.0,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        color: accent,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _selectedDate == null
                            ? 'Pilih tanggal kalender...'
                            : DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_selectedDate!),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _selectedDate != null ? FontWeight.w600 : FontWeight.normal,
                          color: _selectedDate == null
                              ? (isDark ? AppTheme.textMuted : Colors.grey.shade500)
                              : (isDark ? Colors.white : AppTheme.textDark),
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
            if (_isLoading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ] else if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(fontSize: 14, color: AppTheme.error),
              ),
            ] else if (_availability != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getStatusColor(
                    _availability!.availabilityStatus,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getStatusColor(
                      _availability!.availabilityStatus,
                    ).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _availability!.availabilityStatus.toLowerCase() ==
                                  'available'
                              ? Icons.check_circle_outline
                              : Icons.info_outline,
                          color: _getStatusColor(
                            _availability!.availabilityStatus,
                          ),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _availability!.availabilityStatus,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(
                              _availability!.availabilityStatus,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (!_availability!.isWorkingDay)
                      const Text(
                        'Kreator tidak bekerja atau sedang libur pada tanggal ini.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textDark,
                        ),
                      )
                    else if (_availability!.availabilityStatus.toLowerCase() ==
                        'full')
                      const Text(
                        'Jadwal kreator sudah penuh pada tanggal ini.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textDark,
                        ),
                      )
                    else
                      const Text(
                        'Kreator tersedia untuk menerima pekerjaan baru.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textDark,
                        ),
                      ),
                    if (_availability!.notes != null &&
                        _availability!.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Catatan: ${_availability!.notes}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      );
  }
}
