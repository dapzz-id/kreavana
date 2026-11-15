import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kreavana/models/user_model.dart';
import 'package:kreavana/screens/institution_workspace_screen.dart';
import 'package:kreavana/services/dio_client.dart';

import 'fake_secure_storage.dart';

class _MockAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;
  _MockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
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

  group('Partnership Proposal Popup & Corporate Sync UI', () {
    testWidgets(
      'Popup pengajuan mitra hanya berisi Cari PT, Deskripsi Kerjasama, dan Upload Berkas Wajib (Max 3) tanpa Spesifikasi Industri',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(860, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        DioClient.instance.dio.httpClientAdapter = _MockAdapter((options) async {
          final path = options.uri.path;
          if (path.endsWith('/institution/resources/corporate-search')) {
            return _jsonResponse({
              'status': true,
              'data': [
                {
                  'id': 'corp-demo-1',
                  'name': 'PT Kreavana Nusantara Korporat',
                  'username': 'corporate_demo',
                  'email': 'corporate@kreavana.id',
                  'is_verified': true,
                },
              ],
            });
          }
          if (path.endsWith('/institution/resources')) {
            return _jsonResponse({'status': true, 'data': []});
          }
          return _jsonResponse({'status': true, 'data': []});
        });

        final institutionUser = UserModel(
          id: 'inst-demo-1',
          name: 'SMK Telekomunikasi Telesandi Bekasi',
          username: 'institution_demo',
          email: 'institution@kreavana.id',
          role: 'user',
          subRole: 'institution',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: InstitutionWorkspaceScreen(
              user: institutionUser,
              resourceType: 'partners',
            ),
          ),
        );
        await tester.pumpAndSettle();

        final addBtn = find.text('Tambah Mitra Industri');
        expect(addBtn, findsWidgets);
        await tester.tap(addBtn.first);
        await tester.pumpAndSettle();

        // 3 bagian utama yang wajib ada
        expect(find.text('1. Cari PT / Akun Corporate Mitra'), findsOneWidget);
        expect(find.text('Nama Resmi Perusahaan / Mitra Industri *'), findsOneWidget);
        expect(find.text('2. Deskripsi & Ruang Lingkup Kerjasama'), findsOneWidget);
        expect(find.text('Deskripsi Kerjasama *'), findsOneWidget);
        expect(find.text('3. Upload Berkas Kerjasama *'), findsOneWidget);
        expect(find.text('0/3 Berkas • Wajib'), findsOneWidget);

        // Spesifikasi Industri & seluruh field lamanya harus terhapus
        expect(find.text('Spesifikasi Industri & Kontak Penanggung Jawab'), findsNothing);
        expect(find.text('Kategori Spesialisasi'), findsNothing);
        expect(find.text('Kontak Person / Email'), findsNothing);
        expect(find.text('Nama PIC Penanggung Jawab'), findsNothing);
        expect(find.text('Jabatan PIC Industri'), findsNothing);
        expect(find.text('Kuota Magang Siswa/Tahun'), findsNothing);
        expect(find.text('Nomor Registrasi MoU / PKS'), findsNothing);
        expect(find.text('Masa Berlaku MoU'), findsNothing);
        expect(find.text('Website / Portofolio Resmi'), findsNothing);

        // Cari PT by @username
        final searchField = find.widgetWithText(
          TextField,
          'Ketik nama PT/Perusahaan atau @username (contoh: @corporate_demo)...',
        );
        expect(searchField, findsOneWidget);
        await tester.enterText(searchField, '@corporate_demo');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.text('PT Kreavana Nusantara Korporat'), findsWidgets);
        await tester.tap(find.text('PT Kreavana Nusantara Korporat').first);
        await tester.pumpAndSettle();

        // Nama perusahaan terisi otomatis dan kartu Corporate terpilih tampil
        expect(find.text('Corporate Terverifikasi'), findsOneWidget);

        // Validasi submit tanpa deskripsi & tanpa berkas kerjasama
        final submitBtn = find.text('Ajukan Kemitraan');
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(find.text('Deskripsi kerjasama wajib diisi'), findsOneWidget);
        expect(
          find.text('Minimal 1 berkas kerjasama wajib diunggah (maksimal 3 berkas).'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Corporate melihat pengajuan mitra dari institusi dengan 3 berkas MoU tanpa error',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(860, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        DioClient.instance.dio.httpClientAdapter = _MockAdapter((options) async {
          if (options.uri.path.endsWith('/institution/resources')) {
            return _jsonResponse({
              'status': true,
              'data': [
                {
                  'id': 'partner-prop-1',
                  'user_id': 'inst-demo-1',
                  'resource_type': 'partners',
                  'title': 'PT Kreavana Nusantara Korporat',
                  'description': 'Kerjasama magang siswa DKV, guru tamu industri, dan uji kompetensi.',
                  'status': 'pending',
                  'owner': {
                    'id': 'inst-demo-1',
                    'name': 'SMK Telekomunikasi Telesandi Bekasi',
                    'username': 'institution_demo',
                    'email': 'institution@kreavana.id',
                  },
                  'metadata': {
                    'corporate_user_id': 'corp-demo-1',
                    'corporate_name': 'PT Kreavana Nusantara Korporat',
                    'corporate_username': 'corporate_demo',
                    'institution_name': 'SMK Telekomunikasi Telesandi Bekasi',
                    'institution_username': 'institution_demo',
                    'mou_url': 'https://example.test/storage/mou_draf.pdf',
                    'mou_filename': 'mou_draf.pdf',
                    'mou_filesize': '240 KB',
                    'mou_files': [
                      {
                        'url': 'https://example.test/storage/mou_draf.pdf',
                        'filename': 'mou_draf.pdf',
                        'filesize': '240 KB',
                        'extension': 'pdf',
                      },
                      {
                        'url': 'https://example.test/storage/kurikulum_industri.docx',
                        'filename': 'kurikulum_industri.docx',
                        'filesize': '180 KB',
                        'extension': 'docx',
                      },
                      {
                        'url': 'https://example.test/storage/silabus_pkl.pdf',
                        'filename': 'silabus_pkl.pdf',
                        'filesize': '320 KB',
                        'extension': 'pdf',
                      },
                    ],
                  },
                },
              ],
            });
          }
          return _jsonResponse({'status': true, 'data': []});
        });

        final corporateUser = UserModel(
          id: 'corp-demo-1',
          name: 'PT Kreavana Nusantara Korporat',
          username: 'corporate_demo',
          email: 'corporate@kreavana.id',
          role: 'user',
          subRole: 'corporate',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: InstitutionWorkspaceScreen(
              user: corporateUser,
              resourceType: 'partners',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('SMK Telekomunikasi Telesandi Bekasi'), findsOneWidget);
        expect(find.text('@institution_demo • Pengajuan Kemitraan Institusi'), findsOneWidget);
        expect(find.text('Kerjasama magang siswa DKV, guru tamu industri, dan uji kompetensi.'), findsOneWidget);
        expect(find.text('Menunggu Persetujuan Anda'), findsWidgets);
        expect(find.text('Tolak'), findsOneWidget);
        expect(find.text('Setujui Kemitraan'), findsOneWidget);
        expect(find.text('Kelola'), findsNothing);
        expect(find.text('Dokumen MoU (3 Berkas)'), findsOneWidget);

        // Pastikan seluruh 3 berkas tampil di dialog OfficialDocumentViewerDialog saat dibuka
        await tester.tap(find.text('Dokumen MoU (3 Berkas)'));
        await tester.pumpAndSettle();

        expect(find.text('Berkas Lampiran Tersedia (3 Berkas)'), findsOneWidget);
        expect(find.text('mou_draf.pdf'), findsWidgets);
        expect(find.text('kurikulum_industri.docx'), findsWidgets);
        expect(find.text('silabus_pkl.pdf'), findsWidgets);
      },
    );
  });
}
