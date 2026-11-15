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
        expect(find.text('Kuota Magang Peserta/Tahun'), findsNothing);
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
                    'phone': '081111222333',
                    'sub_role': 'institution',
                  },
                  'metadata': {
                    'sender_user_id': 'inst-demo-1',
                    'sender_name': 'SMK Telekomunikasi Telesandi Bekasi',
                    'sender_username': 'institution_demo',
                    'sender_phone': '081111222333',
                    'sender_role': 'institution',
                    'target_user_id': 'corp-demo-1',
                    'target_name': 'PT Kreavana Nusantara Korporat',
                    'target_username': 'corporate_demo',
                    'target_role': 'corporate',
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
        expect(find.text('081111222333'), findsOneWidget);
        expect(find.text('Kerjasama magang siswa DKV, guru tamu industri, dan uji kompetensi.'), findsOneWidget);
        expect(find.text('Menunggu Persetujuan Anda'), findsWidgets);
        expect(find.text('Tolak'), findsOneWidget);
        expect(find.text('Setujui Kemitraan'), findsOneWidget);
        expect(find.text('Kelola'), findsNothing);
        expect(find.text('Dokumen MoU (3 Berkas)'), findsOneWidget);

        // Saat dibuka, tampilkan pemilih berkas asli langsung tanpa pratinjau dokumen palsu
        await tester.tap(find.text('Dokumen MoU (3 Berkas)'));
        await tester.pumpAndSettle();

        expect(find.text('PRATINJAU DOKUMEN RESMI'), findsNothing);
        expect(find.text('Draft / Dalam Proses'), findsNothing);
        expect(find.text('Berkas Kerjasama Asli (3)'), findsOneWidget);
        expect(find.text('mou_draf.pdf'), findsWidgets);
        expect(find.text('kurikulum_industri.docx'), findsWidgets);
        expect(find.text('silabus_pkl.pdf'), findsWidgets);
        expect(find.text('Buka Berkas'), findsNWidgets(3));
      },
    );

    testWidgets(
      'Pengirim tidak melihat tombol Tolak/Setujui pada pengajuan miliknya dan data disetujui tidak bisa diedit',
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
                  'id': 'partner-outgoing-pending',
                  'user_id': 'inst-demo-1',
                  'resource_type': 'partners',
                  'title': 'PT Kreavana Nusantara Korporat',
                  'description': 'Mau kerja sama',
                  'status': 'pending',
                  'viewer_is_sender': true,
                  'viewer_is_recipient': false,
                  'viewer_can_review': false,
                  'recipient': {
                    'id': 'corp-demo-1',
                    'name': 'PT Kreavana Nusantara Korporat',
                    'username': 'corporate_demo',
                    'phone': '082222333444',
                    'sub_role': 'corporate',
                  },
                  'metadata': {
                    'sender_user_id': 'inst-demo-1',
                    'target_user_id': 'corp-demo-1',
                    'target_phone': '082222333444',
                    'corporate_username': 'corporate_demo',
                    'mou_files': [
                      {
                        'url': 'https://example.test/storage/doc1.pdf',
                        'filename': 'doc1.pdf',
                        'filesize': '36 KB',
                        'extension': 'pdf',
                      },
                    ],
                  },
                },
                {
                  'id': 'partner-approved-locked',
                  'user_id': 'inst-demo-1',
                  'resource_type': 'partners',
                  'title': 'PT Mitra Terkunci',
                  'description': 'Sudah disetujui penerima',
                  'status': 'active',
                  'viewer_is_sender': true,
                  'viewer_is_recipient': false,
                  'viewer_can_review': false,
                  'metadata': {
                    'approval_status': 'approved',
                    'locked_after_approval': true,
                    'sender_user_id': 'inst-demo-1',
                    'target_user_id': 'corp-demo-2',
                    'target_phone': '085555666777',
                    'mou_files': [
                      {
                        'url': 'https://example.test/storage/mou_final.pdf',
                        'filename': 'mou_final.pdf',
                        'filesize': '50 KB',
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

        final institutionUser = UserModel(
          id: 'inst-demo-1',
          name: 'SMK Telekomunikasi Telesandi Bekasi',
          username: 'smk_telesandi',
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

        expect(find.text('PT Kreavana Nusantara Korporat'), findsOneWidget);
        expect(find.text('082222333444'), findsOneWidget);
        expect(find.text('Menunggu Persetujuan Mitra'), findsWidgets);
        // Tombol Tolak / Setujui / Setujui (Simulasi) HARAM muncul di sisi pengirim
        expect(find.text('Tolak'), findsNothing);
        expect(find.textContaining('Setujui'), findsNothing);

        // Hanya pengajuan pending yang masih punya Kelola; yang sudah active/approved terkunci
        expect(find.text('PT Mitra Terkunci'), findsOneWidget);
        expect(find.text('MoU Disetujui & Terkunci Permanen'), findsOneWidget);
        expect(find.text('Kelola'), findsOneWidget);
      },
    );

    testWidgets(
      'Corporate dapat mencari Institusi untuk mengajukan kerjasama dan Institusi penerima hanya meninjau Tolak/Setujui',
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
                  'id': 'inst-demo-1',
                  'name': 'SMK Telekomunikasi Telesandi Bekasi',
                  'username': 'smk_telesandi',
                  'email': 'institution@kreavana.id',
                  'phone': '081111222333',
                  'selected_sub_role': 'institution',
                  'is_verified': true,
                },
              ],
            });
          }
          if (path.endsWith('/institution/resources')) {
            return _jsonResponse({
              'status': true,
              'data': [
                {
                  'id': 'partner-corp-to-inst',
                  'user_id': 'corp-demo-1',
                  'resource_type': 'partners',
                  'title': 'SMK Telekomunikasi Telesandi Bekasi',
                  'description': 'Undangan kerjasama kelas industri dari PT Kreavana.',
                  'status': 'pending',
                  'owner': {
                    'id': 'corp-demo-1',
                    'name': 'PT Kreavana Nusantara Korporat',
                    'username': 'corporate_demo',
                    'email': 'corporate@kreavana.id',
                    'phone': '082222333444',
                    'sub_role': 'corporate',
                  },
                  'metadata': {
                    'sender_user_id': 'corp-demo-1',
                    'sender_name': 'PT Kreavana Nusantara Korporat',
                    'sender_username': 'corporate_demo',
                    'sender_phone': '082222333444',
                    'sender_role': 'corporate',
                    'target_user_id': 'inst-demo-1',
                    'target_name': 'SMK Telekomunikasi Telesandi Bekasi',
                    'target_username': 'smk_telesandi',
                    'target_role': 'institution',
                    'mou_files': [
                      {
                        'url': 'https://example.test/storage/undangan_corp.pdf',
                        'filename': 'undangan_corp.pdf',
                        'filesize': '90 KB',
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

        // 1. Corporate membuka modal pengajuan mitra dan mencari Institusi by @username
        final corporateUser = UserModel(
          id: 'corp-demo-1',
          name: 'PT Kreavana Nusantara Korporat',
          username: 'corporate_demo',
          email: 'corporate@kreavana.id',
          phone: '082222333444',
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

        await tester.tap(find.text('Tambah Mitra Vendor').first);
        await tester.pumpAndSettle();

        expect(find.text('1. Cari Institusi / Sekolah / Kampus Mitra'), findsOneWidget);
        expect(find.text('Nama Resmi Institusi / Mitra *'), findsOneWidget);

        final searchInstField = find.widgetWithText(
          TextField,
          'Ketik nama Institusi/Sekolah atau @username (contoh: @smk_telesandi)...',
        );
        await tester.enterText(searchInstField, '@smk_telesandi');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        final resultTile = find.descendant(
          of: find.byType(ListTile),
          matching: find.text('SMK Telekomunikasi Telesandi Bekasi'),
        );
        expect(resultTile, findsOneWidget);
        await tester.tap(resultTile);
        await tester.pumpAndSettle();
        expect(find.text('Institusi Terverifikasi'), findsOneWidget);
        expect(find.textContaining('081111222333'), findsWidgets);

        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();

        // 2. Institusi penerima melihat pengajuan dari Corporate & hanya bisa Tolak/Setujui
        final institutionUser = UserModel(
          id: 'inst-demo-1',
          name: 'SMK Telekomunikasi Telesandi Bekasi',
          username: 'smk_telesandi',
          email: 'institution@kreavana.id',
          phone: '081111222333',
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

        expect(find.text('PT Kreavana Nusantara Korporat'), findsOneWidget);
        expect(find.text('@corporate_demo • Pengajuan Kemitraan Corporate'), findsOneWidget);
        expect(find.text('082222333444'), findsOneWidget);
        expect(find.text('Tolak'), findsOneWidget);
        expect(find.text('Setujui Kemitraan'), findsOneWidget);
        expect(find.text('Kelola'), findsNothing);
      },
    );

    testWidgets(
      'Institution showcases workspace uses general Peserta terminology across schools and campuses',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        DioClient.instance.dio.httpClientAdapter = _MockAdapter((options) async {
          return _jsonResponse({'status': true, 'data': []});
        });

        final campusUser = UserModel(
          id: 'inst-univ-1',
          name: 'Institut Seni Kreatif Nusantara',
          username: 'iskn_official',
          email: 'campus@kreavana.id',
          role: 'institution',
          subRole: 'institution',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: InstitutionWorkspaceScreen(
              user: campusUser,
              resourceType: 'showcases',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Karya & Portofolio Peserta'), findsWidgets);
        expect(find.text('Tambah Karya Peserta'), findsWidgets);
        expect(find.text('Total Karya Peserta'), findsOneWidget);
        expect(find.text('Karya & Portofolio Siswa'), findsNothing);
        expect(find.text('Tambah Karya Siswa'), findsNothing);
        expect(find.text('Total Karya Siswa'), findsNothing);

        await tester.tap(find.text('Tambah Karya Peserta').first);
        await tester.pumpAndSettle();

        expect(find.text('Nama Peserta / Tim'), findsOneWidget);
        expect(find.text('Nama Siswa / Tim'), findsNothing);
      },
    );
  });
}
