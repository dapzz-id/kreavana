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

    testWidgets('Groups applicants by institution and shows Setujui and Tolak buttons',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 2200));

      await tester.pumpWidget(
        MaterialApp(
          home: CorporateVacancyDetailScreen(
            item: sampleVacancy,
            user: corpUser,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Daftar Pelamar tab
      await tester.tap(find.text('Daftar Pelamar (3)'));
      await tester.pumpAndSettle();

      // Verify institution group names are rendered
      expect(find.text('SMKN 4 Bandung'), findsOneWidget);
      expect(find.text('Politeknik Negeri Media Kreatif'), findsWidgets);
      expect(find.text('SMKN 1 Surabaya'), findsOneWidget);

      // Verify Setujui and Tolak buttons exist for institutions
      final approveBtn = find.byKey(const ValueKey('btn_approve_inst_SMKN 4 Bandung'));
      final rejectBtn = find.byKey(const ValueKey('btn_reject_inst_SMKN 4 Bandung'));
      expect(approveBtn, findsOneWidget);
      expect(rejectBtn, findsOneWidget);

      // Click Setujui on SMKN 4 Bandung
      await tester.ensureVisible(approveBtn);
      await tester.tap(approveBtn);
      await tester.pumpAndSettle();

      // Verify status badge updated to Disetujui
      expect(find.text('Disetujui'), findsWidgets);

      // Verify that once approved, Setujui and Tolak buttons are removed/hidden
      expect(find.byKey(const ValueKey('btn_approve_inst_SMKN 4 Bandung')), findsNothing);
      expect(find.byKey(const ValueKey('btn_reject_inst_SMKN 4 Bandung')), findsNothing);
    });

    testWidgets('Rejecting institution automatically removes it and all its applicants from list',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 2200));

      await tester.pumpWidget(
        MaterialApp(
          home: CorporateVacancyDetailScreen(
            item: sampleVacancy,
            user: corpUser,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Daftar Pelamar tab
      await tester.tap(find.text('Daftar Pelamar (3)'));
      await tester.pumpAndSettle();

      // SMKN 4 Bandung and Dimas Aditya are initially visible
      expect(find.text('SMKN 4 Bandung'), findsOneWidget);
      expect(find.text('Dimas Aditya'), findsOneWidget);

      // Click Tolak on SMKN 4 Bandung
      final rejectBtn = find.byKey(const ValueKey('btn_reject_inst_SMKN 4 Bandung'));
      await tester.ensureVisible(rejectBtn);
      await tester.tap(rejectBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('Tolak Kemitraan Institusi?'), findsOneWidget);
      expect(find.text('Ya, Tolak Institusi'), findsOneWidget);

      // Confirm rejection
      await tester.tap(find.text('Ya, Tolak Institusi'));
      await tester.pumpAndSettle();

      // SMKN 4 Bandung and Dimas Aditya must immediately disappear from the list!
      expect(find.text('SMKN 4 Bandung'), findsNothing);
      expect(find.text('Dimas Aditya'), findsNothing);

      // Tab count updates from 3 to 2
      expect(find.text('Daftar Pelamar (2)'), findsOneWidget);

      // Other institutions remain in the list
      expect(find.text('Politeknik Negeri Media Kreatif'), findsWidgets);
      expect(find.text('SMKN 1 Surabaya'), findsOneWidget);
    });

    testWidgets('Corporate applicant card does not display "Ajukan Siswa Pengganti" button when an applicant is rejected',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 2200));

      final vacancyWithRejectedStudent = CorporateVacancyItem(
        id: 'test_vac_2',
        title: sampleVacancy.title,
        description: sampleVacancy.description,
        category: sampleVacancy.category,
        categoryLabel: sampleVacancy.categoryLabel,
        status: sampleVacancy.status,
        statusLabel: sampleVacancy.statusLabel,
        statusBadgeColor: sampleVacancy.statusBadgeColor,
        statusBadgeBg: sampleVacancy.statusBadgeBg,
        registrationPeriod: sampleVacancy.registrationPeriod,
        quotaText: sampleVacancy.quotaText,
        allowance: sampleVacancy.allowance,
        requirements: sampleVacancy.requirements,
        applicantsCount: 2,
        applicants: const [
          CorporateApplicant(
            name: 'Siti Nurhaliza',
            institution: 'Politeknik Negeri Media Kreatif',
            role: '3D Texture & Lookdev',
            appliedDate: '11 Feb 2026',
            status: 'Ditolak',
            note: 'Portofolio belum memenuhi standar.',
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

      await tester.pumpWidget(
        MaterialApp(
          home: CorporateVacancyDetailScreen(
            item: vacancyWithRejectedStudent,
            user: corpUser,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Daftar Pelamar tab
      await tester.tap(find.text('Daftar Pelamar (2)'));
      await tester.pumpAndSettle();

      // Verify 'Ajukan Siswa Pengganti' button is absent for rejected student
      expect(find.byKey(const ValueKey('btn_propose_replacement_Siti Nurhaliza')), findsNothing);
      expect(find.text('Ajukan Siswa Pengganti'), findsNothing);
    });

    testWidgets('Applicant card renders student name, description, institution in accordion header, and handles showcase popup / hidden portfolio button',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 2200));

      final testVacancyWithShowcase = CorporateVacancyItem(
        id: 'test_vac_showcase',
        title: 'Program Magang PV Electric Batch I 2027',
        description: 'Kerja sama penempatan talenta vokasi.',
        category: 'magang',
        categoryLabel: 'Magang',
        status: 'open',
        statusLabel: 'Pendaftaran Dibuka',
        statusBadgeColor: const Color(0xFF16A34A),
        statusBadgeBg: const Color(0xFFDCFCE7),
        registrationPeriod: '28 Nov 2026',
        quotaText: '10 dari 10 posisi',
        allowance: 'Rp 2.000.000 / bulan',
        requirements: const ['Siswa SMK vokasi'],
        applicantsCount: 2,
        applicants: const [
          CorporateApplicant(
            name: 'Achmad Bilzan',
            institution: 'Kreavana Demo Institution',
            studentDescription: 'Desain Komunikasi Visual',
            role: 'VIDEOGRAPHER',
            appliedDate: '15 Nov 2026',
            status: 'Menunggu Review',
            portfolioUrl: 'https://github.com/blznqhtn',
            showcaseItem: {
              'title': 'Portofolio Videografi & Sinematografi Komersial 4K',
              'description': 'Kompilasi karya video iklan komersial resolusi 4K.',
              'metadata': {
                'category': 'Desain Komunikasi Visual & Videografi',
                'year': '2026',
                'portfolio_url': 'https://github.com/blznqhtn',
              },
            },
          ),
          CorporateApplicant(
            name: 'Siswa Tanpa Portofolio',
            institution: 'Kreavana Demo Institution',
            studentDescription: 'Teknik Komputer',
            role: 'IT SUPPORT',
            appliedDate: '15 Nov 2026',
            status: 'Menunggu Review',
            portfolioUrl: '',
            showcaseItem: null,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CorporateVacancyDetailScreen(
            item: testVacancyWithShowcase,
            user: corpUser,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Daftar Pelamar tab
      await tester.tap(find.text('Daftar Pelamar (2)'));
      await tester.pumpAndSettle();

      // 1. Accordion header must display the institution name (Kreavana Demo Institution)
      expect(find.text('Kreavana Demo Institution'), findsWidgets);

      // 2. Applicant card must display student name (Achmad Bilzan) and student description (Desain Komunikasi Visual)
      expect(find.text('Achmad Bilzan'), findsOneWidget);
      expect(find.text('Desain Komunikasi Visual'), findsOneWidget);

      // 3. Achmad Bilzan has a portfolio/showcase -> Portofolio button MUST be present
      final bilzanPortBtn = find.byKey(const ValueKey('btn_portfolio_Achmad Bilzan'));
      expect(bilzanPortBtn, findsOneWidget);

      // 4. Siswa Tanpa Portofolio has NO portfolio and NO showcase -> button MUST NOT be present
      final noPortBtn = find.byKey(const ValueKey('btn_portfolio_Siswa Tanpa Portofolio'));
      expect(noPortBtn, findsNothing);

      // 5. Clicking Achmad Bilzan's Portofolio button opens the popup dialog with showcase details
      await tester.ensureVisible(bilzanPortBtn);
      await tester.tap(bilzanPortBtn);
      await tester.pumpAndSettle();

      // Verify popup content
      expect(find.text('Karya & Portofolio Siswa'), findsOneWidget);
      expect(find.text('Portofolio Videografi & Sinematografi Komersial 4K'), findsOneWidget);
      expect(find.text('Desain Komunikasi Visual & Videografi'), findsOneWidget);
      expect(find.textContaining('https://github.com/blznqhtn'), findsWidgets);
      expect(find.text('Buka Repositori GitHub (Tab Baru)'), findsOneWidget);

      // Close popup
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(find.text('Karya & Portofolio Siswa'), findsNothing);
    });

    testWidgets('Accepted student displays Diterima Magang status badge and hides Ubah Status dropdown',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 2200));

      final testVacancyWithAcceptedStudent = CorporateVacancyItem(
        id: 'test_vac_accepted',
        title: 'Program Magang PV Electric Batch I 2027',
        description: 'Kerja sama penempatan talenta vokasi.',
        category: 'magang',
        categoryLabel: 'Magang',
        status: 'open',
        statusLabel: 'Pendaftaran Dibuka',
        statusBadgeColor: const Color(0xFF16A34A),
        statusBadgeBg: const Color(0xFFDCFCE7),
        registrationPeriod: '28 Nov 2026',
        quotaText: '10 dari 10 posisi',
        allowance: 'Rp 2.000.000 / bulan',
        requirements: const ['Siswa SMK vokasi'],
        applicantsCount: 3,
        applicants: const [
          CorporateApplicant(
            name: 'Achmad Bilzan',
            institution: 'Kreavana Demo Institution',
            studentDescription: 'Desain Komunikasi Visual',
            role: 'VIDEOGRAPHER',
            appliedDate: '15 Nov 2026',
            status: 'Diterima',
            portfolioUrl: 'https://github.com/blznqhtn',
          ),
          CorporateApplicant(
            name: 'Rian Pratama',
            institution: 'Kreavana Demo Institution',
            studentDescription: 'RPL',
            role: 'VIDEOGRAPHER',
            appliedDate: '15 Nov 2026',
            status: 'Menunggu Review',
          ),
          CorporateApplicant(
            name: 'Kadavi Raditya',
            institution: 'Kreavana Demo Institution',
            studentDescription: 'RPL',
            role: 'VIDEOGRAPHER',
            appliedDate: '15 Nov 2026',
            status: 'Ditolak',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CorporateVacancyDetailScreen(
            item: testVacancyWithAcceptedStudent,
            user: corpUser,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Daftar Pelamar tab
      await tester.tap(find.text('Daftar Pelamar (3)'));
      await tester.pumpAndSettle();

      // 1. Verify Achmad Bilzan has Diterima Magang badge and Resmi Diterima Magang confirmation
      expect(find.text('Diterima Magang'), findsOneWidget);
      expect(find.text('Resmi Diterima Magang'), findsOneWidget);

      // 2. Verify Achmad Bilzan's Ubah Status dropdown is HIDDEN
      expect(find.byKey(const ValueKey('popup_status_Achmad Bilzan')), findsNothing);

      // 3. Verify pending student (Rian Pratama) still HAS the Ubah Status dropdown
      final rianPopup = find.byKey(const ValueKey('popup_status_Rian Pratama'));
      expect(rianPopup, findsOneWidget);
      await tester.tap(rianPopup);
      await tester.pumpAndSettle();

      // Ensure dropdown options contain Jadwalkan Interview, Terima Magang, Tolak Berkas, but NO Menunggu Review
      expect(find.text('Jadwalkan Interview'), findsOneWidget);
      expect(find.text('Terima Magang'), findsOneWidget);
      expect(find.text('Tolak Berkas'), findsOneWidget);
      expect(find.widgetWithText(PopupMenuItem<String>, 'Menunggu Review'), findsNothing);

      // Close the popup by tapping outside / back
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // 4. Verify rejected student (Kadavi Raditya) has Ubah Status dropdown HIDDEN and does NOT show Ajukan Siswa Pengganti
      expect(find.byKey(const ValueKey('popup_status_Kadavi Raditya')), findsNothing);
      expect(find.byKey(const ValueKey('btn_propose_replacement_Kadavi Raditya')), findsNothing);
      expect(find.text('Ajukan Siswa Pengganti'), findsNothing);
    });
  });
}
