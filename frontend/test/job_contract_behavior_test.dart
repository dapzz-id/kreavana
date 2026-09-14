import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kreavana/models/job_contract.dart';
import 'package:kreavana/screens/proyek_saya_screen.dart';
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
  group('JobContract Model & State Machine Behavior Tests', () {
    test(
      'JobContract.fromJson parses all 6 status combinations accurately',
      () {
        final scenarios = [
          {'cs': 'proposed', 'ws': 'pending', 'price': '1000000'},
          {'cs': 'approved', 'ws': 'scheduled', 'price': 1500000},
          {'cs': 'active', 'ws': 'in_progress', 'price': 2000000.0},
          {'cs': 'active', 'ws': 'review', 'price': '2500000.50'},
          {'cs': 'active', 'ws': 'revision', 'price': '3000000'},
          {'cs': 'completed', 'ws': 'completed', 'price': 5000000},
        ];

        for (final s in scenarios) {
          final json = {
            'id': 'contract-${s['cs']}-${s['ws']}',
            'client_id': 'client-1',
            'creator_id': 'creator-1',
            'title': 'Test Job ${s['cs']}',
            'contract_status': s['cs'],
            'work_status': s['ws'],
            'agreed_price': s['price'],
            'escrow_amount': '0.00',
            'scheduled_start_date': '2026-10-01',
            'scheduled_end_date': '2026-10-05',
            'deadline': '2026-10-06',
            'creator': {'name': 'Budi Creator'},
            'client': {'name': 'Ani Client'},
          };

          final contract = JobContract.fromJson(json);

          expect(contract.id, 'contract-${s['cs']}-${s['ws']}');
          expect(contract.contractStatus, s['cs']);
          expect(contract.workStatus, s['ws']);
          expect(contract.creatorName, 'Budi Creator');
          expect(contract.clientName, 'Ani Client');
          expect(contract.scheduledStartDate, DateTime(2026, 10, 1));
          expect(contract.scheduledEndDate, DateTime(2026, 10, 5));
          expect(contract.deadline, DateTime(2026, 10, 6));
          expect(contract.agreedPrice, isPositive);
        }
      },
    );

    test('JobContract handles null optional fields safely', () {
      final json = {
        'id': 'minimal-1',
        'client_id': 'c1',
        'creator_id': 'cr1',
        'title': 'Minimal Contract',
        'contract_status': 'draft',
        'work_status': 'pending',
      };

      final contract = JobContract.fromJson(json);
      expect(contract.id, 'minimal-1');
      expect(contract.agreedPrice, 0.0);
      expect(contract.escrowAmount, 0.0);
      expect(contract.scheduledStartDate, isNull);
      expect(contract.scheduledEndDate, isNull);
      expect(contract.deadline, isNull);
      expect(contract.isPastDeadline, isFalse);
      expect(contract.creatorName, 'Kreator');
      expect(contract.clientName, 'Klien');
    });

    test('Deadline getters evaluate correctly', () {
      final pastContract = JobContract.fromJson({
        'id': 'past-1',
        'client_id': 'c1',
        'creator_id': 'cr1',
        'title': 'Past Job',
        'deadline': '2020-01-01',
      });
      expect(pastContract.isPastDeadline, isTrue);
      expect(pastContract.isPastOneWeekDeadline, isTrue);

      final futureContract = JobContract.fromJson({
        'id': 'future-1',
        'client_id': 'c1',
        'creator_id': 'cr1',
        'title': 'Future Job',
        'deadline': '2099-01-01',
      });
      expect(futureContract.isPastDeadline, isFalse);
      expect(futureContract.isPastOneWeekDeadline, isFalse);
    });
  });

  group('ProyekSayaScreen Presentation, Empty State & Error Handling Tests', () {
    late Dio dio;
    late FakeSecureStorage fakeStorage;

    setUp(() {
      fakeStorage = FakeSecureStorage();
      fakeStorage.saveToken('test_token');
      DioClient.instance.setStorageForTesting(fakeStorage);
      dio = DioClient.instance.dio;
    });

    testWidgets(
      'Renders empty state when API returns empty list without synthetic fallback',
      (WidgetTester tester) async {
        dio.httpClientAdapter = MockAdapter((options) async {
          return ResponseBody.fromString(
            jsonEncode({'status': 'success', 'data': []}),
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });

        await tester.pumpWidget(
          const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: MaterialApp(home: ProyekSayaScreen()),
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        // Ensure the search field and filter tabs are visible
        expect(find.text('Proyek Saya'), findsOneWidget);
        expect(find.widgetWithText(ChoiceChip, 'Semua'), findsOneWidget);
        expect(find.widgetWithText(ChoiceChip, 'Berjalan'), findsOneWidget);
        expect(find.widgetWithText(ChoiceChip, 'Menunggu'), findsOneWidget);
        expect(find.widgetWithText(ChoiceChip, 'Selesai'), findsOneWidget);

        // When list is empty, expect empty state
        expect(find.text('Belum ada proyek pada status ini'), findsOneWidget);

        // Verify that NO synthetic mock project cards are rendered
        expect(find.text('Sample Project'), findsNothing);
        expect(find.text('Mock Contract'), findsNothing);
        expect(find.text('Dummy Project'), findsNothing);
      },
    );

    testWidgets('Renders error state with retry button when API fails', (
      WidgetTester tester,
    ) async {
      bool shouldFail = true;

      dio.httpClientAdapter = MockAdapter((options) async {
        if (shouldFail) {
          return ResponseBody.fromString(
            jsonEncode({'message': 'Network Connection Error'}),
            500,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        } else {
          return ResponseBody.fromString(
            jsonEncode({'status': 'success', 'data': []}),
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
          child: MaterialApp(home: ProyekSayaScreen()),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Error message and retry button must be rendered
      expect(find.text('Coba Lagi'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

      // Now simulate retry succeeding
      shouldFail = false;
      await tester.tap(find.text('Coba Lagi'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Error should be cleared and empty state rendered
      expect(find.text('Belum ada proyek pada status ini'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsNothing);
    });

    testWidgets(
      'Renders actual contract card with contractLabel and workLabel',
      (WidgetTester tester) async {
        dio.httpClientAdapter = MockAdapter((options) async {
          return ResponseBody.fromString(
            jsonEncode({
              'status': 'success',
              'data': [
                {
                  'id': 'contract-real-1',
                  'client_id': 'c1',
                  'creator_id': 'cr1',
                  'title': 'Pembuatan Video Iklan Komersial',
                  'contract_status': 'active',
                  'work_status': 'in_progress',
                  'agreed_price': '2500000.00',
                  'creator': {'name': 'Dimas Videographer'},
                  'scheduled_end_date': '2026-10-30',
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
            child: MaterialApp(home: ProyekSayaScreen()),
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        // Assert contract title is rendered
        expect(find.text('Pembuatan Video Iklan Komersial'), findsOneWidget);
        // ContractStatus label
        expect(find.text('Aktif'), findsOneWidget);
        // WorkStatus label and progress
        expect(find.text('Progres: Sedang Dikerjakan'), findsOneWidget);
        expect(find.text('50%'), findsOneWidget);
        // Price
        expect(find.text('Rp 2500000'), findsOneWidget);
        // Partner
        expect(find.text('Dimas Videographer'), findsOneWidget);
      },
    );
  });
}
