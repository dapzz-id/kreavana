import 'api_service.dart';
import '../models/schedule_model.dart';

class ScheduleResult<T> {
  final bool success;
  final T? data;
  final String? message;

  ScheduleResult({required this.success, this.data, this.message});
}

class ScheduleService {
  static Future<ScheduleResult<List<CreatorCapacitySchedule>>> getCreatorCalendar() async {
    try {
      final response = await ApiService.get('profile/calendar');
      if (response['status'] == true && response['data'] != null) {
        final data = response['data'] as List<dynamic>;
        final schedules = data.map((e) => CreatorCapacitySchedule.fromJson(e as Map<String, dynamic>)).toList();
        return ScheduleResult(success: true, data: schedules);
      }
      return ScheduleResult(success: false, message: response['message']?.toString() ?? 'Gagal memuat jadwal.');
    } catch (e) {
      return ScheduleResult(success: false, message: e.toString());
    }
  }

  static Future<ScheduleResult<CreatorCapacitySchedule>> saveCalendarOverride({
    required String date,
    int? maxCapacity,
    required bool isUnavailable,
    String? notes,
  }) async {
    try {
      final response = await ApiService.post('profile/calendar', {
        'date': date,
        'max_capacity': maxCapacity,
        'is_unavailable': isUnavailable,
        'notes': notes,
      });

      if (response['status'] == true && response['data'] != null) {
        final schedule = CreatorCapacitySchedule.fromJson(response['data'] as Map<String, dynamic>);
        return ScheduleResult(success: true, data: schedule, message: response['message']?.toString());
      }
      return ScheduleResult(success: false, message: response['message']?.toString() ?? 'Gagal menyimpan jadwal.');
    } catch (e) {
      return ScheduleResult(success: false, message: e.toString());
    }
  }

  static Future<ScheduleResult<void>> deleteCalendarOverride(String date) async {
    try {
      final response = await ApiService.delete('profile/calendar/$date');
      if (response['status'] == true) {
        return ScheduleResult(success: true, message: response['message']?.toString());
      }
      return ScheduleResult(success: false, message: response['message']?.toString() ?? 'Gagal menghapus jadwal.');
    } catch (e) {
      return ScheduleResult(success: false, message: e.toString());
    }
  }

  static Future<ScheduleResult<AvailabilityRange>> getCreatorAvailability(
    String creatorId, {
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await ApiService.get(
        'creators/$creatorId/availability',
        queryParams: {
          'start_date': startDate,
          'end_date': endDate,
        },
      );

      if (response['status'] == true && response['data'] != null) {
        final data = AvailabilityRange.fromJson(response['data'] as Map<String, dynamic>);
        return ScheduleResult(success: true, data: data);
      }
      return ScheduleResult(success: false, message: response['message']?.toString() ?? 'Gagal memuat ketersediaan.');
    } catch (e) {
      return ScheduleResult(success: false, message: e.toString());
    }
  }

  static Future<ScheduleResult<AvailabilityDetail>> getCreatorAvailabilityForDate(
    String creatorId,
    String date,
  ) async {
    try {
      final response = await ApiService.get(
        'creators/$creatorId/availability',
        queryParams: {
          'date': date,
        },
      );

      if (response['status'] == true && response['data'] != null) {
        final data = AvailabilityDetail.fromJson(response['data'] as Map<String, dynamic>);
        return ScheduleResult(success: true, data: data);
      }
      return ScheduleResult(success: false, message: response['message']?.toString() ?? 'Gagal memuat ketersediaan.');
    } catch (e) {
      return ScheduleResult(success: false, message: e.toString());
    }
  }
}
