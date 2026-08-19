import 'package:flutter_test/flutter_test.dart';
import 'package:kreavana/models/schedule_model.dart';

void main() {
  group('Schedule Models JSON Parsing', () {
    test('CreatorCapacitySchedule parses correctly', () {
      final json = {
        'id': '123',
        'creator_id': '456',
        'date': '2026-08-20',
        'max_capacity': '5',
        'is_unavailable': 0,
        'notes': 'Test notes',
      };

      final schedule = CreatorCapacitySchedule.fromJson(json);

      expect(schedule.id, '123');
      expect(schedule.creatorId, '456');
      expect(schedule.date, '2026-08-20');
      expect(schedule.maxCapacity, 5);
      expect(schedule.isUnavailable, false);
      expect(schedule.notes, 'Test notes');
    });

    test('AvailabilityDay parses correctly', () {
      final json = {
        'date': '2026-08-21',
        'is_working_day': true,
        'availability_status': 'Available',
      };

      final day = AvailabilityDay.fromJson(json);

      expect(day.date, '2026-08-21');
      expect(day.isWorkingDay, true);
      expect(day.availabilityStatus, 'Available');
    });

    test('AvailabilityRange parses correctly', () {
      final json = {
        'available': true,
        'working_days': 20,
        'unavailable_days': 10,
        'days': [],
        'conflicts': [
          {
            'date': '2026-08-25',
            'reason': 'CAPACITY_FULL',
            'remaining_capacity': 0,
          },
        ],
      };

      final range = AvailabilityRange.fromJson(json);

      expect(range.available, true);
      expect(range.workingDays, 20);
      expect(range.unavailableDays, 10);
      expect(range.conflicts?.length, 1);
      expect(range.conflicts?.first.date, '2026-08-25');
    });

    test('AvailabilityDetail parses correctly', () {
      final json = {
        'date': '2026-08-22',
        'is_working_day': 1,
        'effective_capacity': '2',
        'active_work_count': 1,
        'booking_count': 1,
        'used_capacity': '1',
        'remaining_capacity': 1,
        'availability_status': 'Limited',
      };

      final detail = AvailabilityDetail.fromJson(json);

      expect(detail.date, '2026-08-22');
      expect(detail.isWorkingDay, true);
      expect(detail.effectiveCapacity, 2);
      expect(detail.activeWorkCount, 1);
      expect(detail.availabilityStatus, 'Limited');
    });
  });
}
