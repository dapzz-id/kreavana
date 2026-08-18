import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app/theme.dart';
import '../models/schedule_model.dart';
import '../services/schedule_service.dart';

class CreatorAvailabilityWidget extends StatefulWidget {
  final String creatorId;

  const CreatorAvailabilityWidget({super.key, required this.creatorId});

  @override
  State<CreatorAvailabilityWidget> createState() => _CreatorAvailabilityWidgetState();
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
    final res = await ScheduleService.getCreatorAvailabilityForDate(widget.creatorId, dateStr);

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
    return Card(
      color: AppTheme.cardLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cek Ketersediaan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pilih tanggal untuk melihat apakah kreator tersedia.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate ?? now,
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 90)), // Check up to 90 days ahead
                );
                if (d != null && d != _selectedDate) {
                  setState(() => _selectedDate = d);
                  _checkAvailability();
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
                      _selectedDate == null
                          ? 'Pilih Tanggal'
                          : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                      style: TextStyle(
                        fontSize: 14,
                        color: _selectedDate == null
                            ? AppTheme.textMuted
                            : AppTheme.textDark,
                      ),
                    ),
                    const Icon(Icons.calendar_today, color: AppTheme.primaryPurple, size: 20),
                  ],
                ),
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ] else if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(fontSize: 14, color: AppTheme.error)),
            ] else if (_availability != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getStatusColor(_availability!.availabilityStatus).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getStatusColor(_availability!.availabilityStatus).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _availability!.availabilityStatus.toLowerCase() == 'available'
                              ? Icons.check_circle_outline
                              : Icons.info_outline,
                          color: _getStatusColor(_availability!.availabilityStatus),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _availability!.availabilityStatus,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(_availability!.availabilityStatus),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (!_availability!.isWorkingDay)
                      const Text(
                        'Kreator tidak bekerja atau sedang libur pada tanggal ini.',
                        style: TextStyle(fontSize: 14, color: AppTheme.textDark),
                      )
                    else if (_availability!.availabilityStatus.toLowerCase() == 'full')
                      const Text(
                        'Jadwal kreator sudah penuh pada tanggal ini.',
                        style: TextStyle(fontSize: 14, color: AppTheme.textDark),
                      )
                    else
                      const Text(
                        'Kreator tersedia untuk menerima pekerjaan baru.',
                        style: TextStyle(fontSize: 14, color: AppTheme.textDark),
                      ),
                    if (_availability!.notes != null && _availability!.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Catatan: ${_availability!.notes}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
