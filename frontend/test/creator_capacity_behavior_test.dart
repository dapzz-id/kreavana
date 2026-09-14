import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kreavana/models/schedule_model.dart';
import 'package:kreavana/screens/creator_calendar_screen.dart';
import 'package:kreavana/services/dio_client.dart';

import 'fake_secure_storage.dart';

class MockAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onFetch;
  MockAdapter(this.onFetch);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return await onFetch(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('Creator Schedule & Capacity Model Behavior Tests', () {
    test(
      'CreatorCapacitySchedule parses custom capacity and off-duty accurately',
      () {
        final customScheduleJson = {
          'id': 'sched-1',
          'creator_id': 'creator-1',
          'date': '2026-10-25',
          'max_capacity': 1,
          'is_unavailable': false,
          'notes': 'Sesi Khusus Tambahan',
          'created_at': '2026-10-01T00:00:00Z',
          'updated_at': '2026-10-01T00:00:00Z',
        };

        final customSchedule = CreatorCapacitySchedule.fromJson(
          customScheduleJson,
        );
        expect(customSchedule.id, 'sched-1');
        expect(customSchedule.date, '2026-10-25');
        expect(customSchedule.maxCapacity, 1);
        expect(customSchedule.isUnavailable, isFalse);
        expect(customSchedule.notes, 'Sesi Khusus Tambahan');

        final offDutyScheduleJson = {
          'id': 'sched-2',
          'creator_id': 'creator-1',
          'date': '2026-10-26',
          'max_capacity': 0,
          'is_unavailable': true,
          'notes': 'Off Duty / Libur',
        };

        final offDutySchedule = CreatorCapacitySchedule.fromJson(
          offDutyScheduleJson,
        );
        expect(offDutySchedule.id, 'sched-2');
        expect(offDutySchedule.isUnavailable, isTrue);
        expect(offDutySchedule.notes, 'Off Duty / Libur');
      },
    );

    test(
      'AvailabilityRange parses range details and working days accurately',
      () {
        final rangeJson = {
          'available': true,
          'working_days': 5,
          'unavailable_days': 2,
          'days': [
            {
              'date': '2026-10-20',
              'is_working_day': true,
              'availability_status': 'Available',
            },
            {
              'date': '2026-10-21',
              'is_working_day': false,
              'availability_status': 'Unavailable',
            },
          ],
          'conflicts': null,
        };

        final range = AvailabilityRange.fromJson(rangeJson);
        expect(range.available, isTrue);
        expect(range.workingDays, 5);
        expect(range.unavailableDays, 2);
        expect(range.days.length, 2);
        expect(range.days[0].isWorkingDay, isTrue);
        expect(range.days[1].isWorkingDay, isFalse);
        expect(range.conflicts, isNull);
      },
    );

    test(
      'AvailabilityDetail parses date-specific used capacity and status accurately',
      () {
        final detailJson = {
          'date': '2026-10-28',
          'is_working_day': true,
          'effective_capacity': 2,
          'used_capacity': 2,
          'remaining_capacity': 0,
          'availability_status': 'Full',
          'notes': null,
        };

        final detail = AvailabilityDetail.fromJson(detailJson);
        expect(detail.date, '2026-10-28');
        expect(detail.isWorkingDay, isTrue);
        expect(detail.effectiveCapacity, 2);
        expect(detail.usedCapacity, 2);
        expect(detail.remainingCapacity, 0);
        expect(detail.availabilityStatus, 'Full');
      },
    );
  });

  group('CreatorCalendarScreen Widget & Presentation Tests', () {
    late Dio dio;
    late FakeSecureStorage fakeStorage;

    setUp(() {
      fakeStorage = FakeSecureStorage();
      fakeStorage.saveToken('test_token');
      DioClient.instance.setStorageForTesting(fakeStorage);
      dio = DioClient.instance.dio;
    });

    testWidgets('Renders empty state cleanly when no schedule overrides exist', (
      WidgetTester tester,
    ) async {
      dio.httpClientAdapter = MockAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({'status': true, 'data': []}),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(home: CreatorCalendarScreen()),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Jadwal & Ketersediaan'), findsOneWidget);

      // Verify empty state is displayed when schedule list is empty
      expect(find.text('Belum Ada Jadwal Khusus'), findsOneWidget);
      expect(
        find.text(
          'Tambahkan override jadwal jika Anda ingin mengatur hari libur atau kapasitas maksimal harian.',
        ),
        findsOneWidget,
      );

      // Verify no fake schedules are rendered
      expect(find.text('Mock Schedule'), findsNothing);
      expect(find.text('Fake Day'), findsNothing);
    });

    testWidgets(
      'Renders error message and retry button when calendar fetch fails',
      (WidgetTester tester) async {
        bool shouldFail = true;

        dio.httpClientAdapter = MockAdapter((options) async {
          if (shouldFail) {
            return ResponseBody.fromString(
              jsonEncode({
                'status': false,
                'message': 'Koneksi ke server gagal',
              }),
              500,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          } else {
            return ResponseBody.fromString(
              jsonEncode({'status': true, 'data': []}),
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          }
        });

        await tester.pumpWidget(
          const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: MaterialApp(home: CreatorCalendarScreen()),
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        // Error and retry button must be rendered
        expect(find.text('Coba Lagi'), findsOneWidget);

        // Tap retry and verify recovery
        shouldFail = false;
        await tester.tap(find.text('Coba Lagi'));
        await tester.pump();
        await tester.pumpAndSettle();

        // Recovered into empty state cleanly
        expect(find.text('Belum Ada Jadwal Khusus'), findsOneWidget);
        expect(find.text('Coba Lagi'), findsNothing);
      },
    );

    testWidgets('Renders actual schedule card when data is returned', (
      WidgetTester tester,
    ) async {
      dio.httpClientAdapter = MockAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({
            'status': true,
            'data': [
              {
                'id': 'sched-real-1',
                'creator_id': 'cr1',
                'date': '2026-11-01',
                'max_capacity': 1,
                'is_unavailable': false,
                'notes': 'Sesi Tambahan Reguler',
              },
            ],
          }),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(home: CreatorCalendarScreen()),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('2026-11-01'), findsOneWidget);
      expect(find.text('Kapasitas: 1'), findsOneWidget);
      expect(find.text('Catatan: Sesi Tambahan Reguler'), findsOneWidget);
    });
  });
}
