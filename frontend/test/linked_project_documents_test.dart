import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kreavana/models/user_model.dart';
import 'package:kreavana/screens/institution_workspace_screen.dart';
import 'package:kreavana/services/dio_client.dart';

import 'fake_secure_storage.dart';

class _DocumentsMockAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.path.endsWith('/institution/resources') &&
        options.uri.queryParameters['type'] == 'documents') {
      return ResponseBody.fromString(
        jsonEncode({
          'status': true,
          'data': [
            {
              'id': 'project-contract-1',
              'user_id': 'inst-1',
              'resource_type': 'documents',
              'title': 'Kontrak Proyek - Riset Kolaborasi Preservasi Budaya',
              'description': 'Kontrak resmi proyek kolaborasi digital.',
              'status': 'published',
              'is_linked_project_document': true,
              'metadata': {
                'source_type': 'project_contract',
                'source_label': 'Proyek Saya',
                'category': 'Kontrak Kerja Proyek (MoU / SPK)',
                'authority': 'CV Transforma Alam Kreasi — Aplikasi Kreavana',
                'author': 'SMK Telesandi & Kreator Video',
                'document_number': 'KRV/CTR/2026/001',
                'opportunity_id': 'opp-1',
                'project_title': 'Riset Kolaborasi Preservasi Budaya',
                'document_date': '2026-12-30',
                'file_format': 'PDF',
                'file_size': 'Kontrak Digital',
                'agreed_price_formatted': 'Rp 65.000.000',
                'client_name': 'SMK Telesandi',
                'creator_name': 'Kreator Video',
                'dynamic_terms': ['Wajib menyerahkan file arsip master 3D.'],
                'locked_after_approval': true,
              },
            },
            {
              'id': 'doc-partner-1',
              'user_id': 'inst-1',
              'resource_type': 'documents',
              'title': 'Perjanjian Kerjasama (MoU) - PT Mitra Industri',
              'description': 'MoU kemitraan disetujui.',
              'status': 'published',
              'metadata': {
                'category': 'MoU Kemitraan',
                'partner_name': 'PT Mitra Industri',
                'partner_resource_id': 'partner-1',
                'document_number': 'MOU-ABC123/2026',
                'valid_until': '2029-11-16',
                'file_format': 'PDF',
                'file_size': '1.2 MB',
                'locked_after_approval': true,
              },
            },
          ],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode({'status': true, 'data': []}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late HttpClientAdapter originalAdapter;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    DioClient.instance.setStorageForTesting(FakeSecureStorage());
    originalAdapter = DioClient.instance.dio.httpClientAdapter;
  });

  tearDown(() {
    DioClient.instance.dio.httpClientAdapter = originalAdapter;
  });

  testWidgets(
    'Dokumen & MoU renders linked Proyek Saya and Mitra Industri badges cleanly and opens contract preview dialog',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      DioClient.instance.dio.httpClientAdapter = _DocumentsMockAdapter();

      final institutionUser = UserModel(
        id: 'inst-1',
        name: 'SMK Telesandi',
        username: 'smk_telesandi',
        email: 'smk@kreavana.id',
        role: 'user',
        subRole: 'institution',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: InstitutionWorkspaceScreen(
            user: institutionUser,
            resourceType: 'documents',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kontrak Proyek - Riset Kolaborasi Preservasi Budaya'), findsOneWidget);
      expect(find.text('Perjanjian Kerjasama (MoU) - PT Mitra Industri'), findsOneWidget);

      // Source pills and explicit category/authority from metadata
      expect(find.text('Proyek Saya'), findsAtLeastNWidgets(2));
      expect(find.text('Mitra Industri'), findsOneWidget);
      expect(find.text('Kontrak Kerja Proyek (MoU / SPK)'), findsOneWidget);
      expect(find.text('MoU Kemitraan'), findsOneWidget);
      expect(find.text('PT Mitra Industri'), findsOneWidget);

      // Tapping "Buka Dokumen Resmi" on a digital contract opens OfficialDocumentViewerDialog
      final openButtons = find.text('Buka Dokumen Resmi');
      expect(openButtons, findsWidgets);
      await tester.tap(openButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('PRATINJAU DOKUMEN RESMI'), findsOneWidget);
      expect(find.text('Nomor Registrasi: KRV/CTR/2026/001'), findsOneWidget);
      expect(find.text('Nilai: Rp 65.000.000'), findsOneWidget);
      expect(find.text('1. Wajib menyerahkan file arsip master 3D.'), findsOneWidget);
    },
  );
}
