import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kreavana/models/user_model.dart';
import 'package:kreavana/screens/corporate_lowongan_screen.dart';
import 'package:kreavana/screens/corporate_vacancy_detail_screen.dart';

void main() {
  final sampleVacancy = CorporateVacancyItem(
    id: 'test_vac_1',
    title: 'Program Magang MBKM 3D Modeler Batch I 2026',
    description: 'Kerja sama penempatan 10 siswa vokasi magang pada produksi serial animasi nusantara.',
    category: 'magang',
    categoryLabel: 'Magang',
    status: 'open',
    statusLabel: 'Pendaftaran Dibuka',
    statusBadgeColor: const Color(0xFF16A34A),
    statusBadgeBg: const Color(0xFFDCFCE7),
    registrationPeriod: '21 Sep 2026',
    quotaText: '4 dari 10 posisi',
    allowance: 'Rp 2.500.000 - Rp 3.500.000 / bulan',
    requirements: const [
      'Siswa SMK vokasi atau Mahasiswa jurusan Animasi',
      'Menguasai dasar 3D Modeling (Blender / Maya)',
      'Memiliki portofolio karya modeling aset 3D',
    ],
    applicantsCount: 3,
    applicants: const [
      CorporateApplicant(
        name: 'Dimas Aditya',
        institution: 'SMKN 4 Bandung - Animasi',
        role: 'Junior 3D Modeler',
        appliedDate: '10 Feb 2026',
        status: 'Interview',
        note: 'Showreel modeling hard-surface sangat rapi.',
      ),
      CorporateApplicant(
        name: 'Siti Nurhaliza',
        institution: 'Politeknik Negeri Media Kreatif',
        role: '3D Texture & Lookdev',
        appliedDate: '11 Feb 2026',
        status: 'Menunggu Review',
        note: 'Mahir Substance Painter.',
      ),
      CorporateApplicant(
        name: 'Reza Pratama',
        institution: 'SMKN 1 Surabaya - Multimedia',
        role: '3D Environment Artist',
        appliedDate: '12 Feb 2026',
        status: 'Diterima',
        note: 'Telah menandatangani MoU.',
      ),
    ],
  );

  final corpUser = UserModel(
    id: 'corp_user_1',
    name: 'PT Kreavana Nusantara',
    username: 'corp_demo',
    email: 'corporate@kreavana.id',
    role: 'client',
    subRole: 'corporate',
  );

  group('CorporateVacancyDetailScreen Tests', () {
    testWidgets('Renders full detail page with hero card, breadcrumbs, metrics, and tabs',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1000));

      await tester.pumpWidget(
        MaterialApp(
          home: CorporateVacancyDetailScreen(
            item: sampleVacancy,
            user: corpUser,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify breadcrumbs and title
      expect(find.text('Program & Magang Corporate'), findsOneWidget);
      expect(find.text('Program Magang MBKM 3D Modeler Batch I 2026'), findsWidgets);

      // Verify Back button & actions
      expect(find.text('Kembali ke Daftar Lowongan'), findsOneWidget);
      expect(find.text('Bagikan'), findsOneWidget);
      expect(find.text('Tutup Pendaftaran'), findsOneWidget);

      // Verify 4 key metrics
      expect(find.text('Periode Pendaftaran'), findsOneWidget);
      expect(find.text('21 Sep 2026'), findsOneWidget);
      expect(find.text('Alokasi / Sisa Kuota'), findsOneWidget);
      expect(find.text('4 dari 10 posisi'), findsOneWidget);
      expect(find.text('Estimasi Gaji / Uang Saku'), findsOneWidget);
      expect(find.text('Rp 2.500.000 - Rp 3.500.000 / bulan'), findsOneWidget);
      expect(find.text('Pelamar Terdaftar'), findsOneWidget);
      expect(find.text('3 Orang'), findsOneWidget);

      // Verify tabs
      expect(find.text('Rincian & Kualifikasi Program'), findsOneWidget);
      expect(find.text('Daftar Pelamar (3)'), findsOneWidget);

      // Verify Tab 1 content is visible initially
      expect(find.text('Syarat & Kualifikasi Pelamar'), findsOneWidget);
      expect(find.text('Tata Kelola & Kemitraan Industri Resmi'), findsOneWidget);
      expect(find.text('Siswa SMK vokasi atau Mahasiswa jurusan Animasi'), findsOneWidget);
    });

    testWidgets('Switches to Daftar Pelamar tab and filters/searches applicants',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1000));

      await tester.pumpWidget(
        MaterialApp(
          home: CorporateVacancyDetailScreen(
            item: sampleVacancy,
            user: corpUser,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Daftar Pelamar tab
      final pelamarTab = find.text('Daftar Pelamar (3)');
      await tester.tap(pelamarTab);
      await tester.pumpAndSettle();

      // Verify applicants are listed
      expect(find.text('Dimas Aditya'), findsOneWidget);
      expect(find.text('Siti Nurhaliza'), findsOneWidget);
      expect(find.text('Reza Pratama'), findsOneWidget);

      // Verify status filter chips are present
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Interview'), findsWidgets);
      expect(find.text('Diterima'), findsWidgets);

      // Search for 'Dimas'
      final searchField = find.widgetWithText(TextFormField, 'Cari nama pelamar, asal sekolah/kampus, atau posisi...');
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Dimas');
      await tester.pumpAndSettle();

      // Only Dimas should be visible
      expect(find.text('Dimas Aditya'), findsOneWidget);
      expect(find.text('Siti Nurhaliza'), findsNothing);
      expect(find.text('Reza Pratama'), findsNothing);
    });

    testWidgets('Toggle status Buka/Tutup Pendaftaran updates state and button label',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1000));

      await tester.pumpWidget(
        MaterialApp(
          home: CorporateVacancyDetailScreen(
            item: sampleVacancy,
            user: corpUser,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially 'Tutup Pendaftaran' because status is 'open'
      final toggleBtn = find.text('Tutup Pendaftaran');
      expect(toggleBtn, findsOneWidget);

      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();

      // Now button switches to 'Buka Pendaftaran'
      expect(find.text('Buka Pendaftaran'), findsOneWidget);
    });
  });
}
