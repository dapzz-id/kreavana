import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kreavana/models/opportunity_model.dart';
import 'package:kreavana/screens/corporate_lowongan_screen.dart';

void main() {
  group('CorporateLowongan Vacancy Item Tests', () {
    test('CorporateVacancyItem.fromOpportunity properly maps magang opportunity', () {
      final opp = OpportunityModel(
        id: 'opp-magang-1',
        title: 'Program Magang MBKM 3D Modeler Batch I 2026',
        description: 'Kerja sama vokasi 10 siswa magang',
        subRoleSlug: 'magang',
        status: 'open',
        deadline: '2026-09-21',
        budgetRange: 'Rp 3.500.000 / bulan',
        applicationsCount: 4,
        requirements: [
          OpportunityRequirementModel(
            subRoleSlug: 'animator',
            notes: 'Menguasai Blender dan 3D Modeling',
          ),
        ],
      );

      final item = CorporateVacancyItem.fromOpportunity(opp);

      expect(item.id, equals('opp-magang-1'));
      expect(item.title, equals('Program Magang MBKM 3D Modeler Batch I 2026'));
      expect(item.category, equals('magang'));
      expect(item.categoryLabel, equals('Magang'));
      expect(item.statusLabel, equals('Pendaftaran Dibuka'));
      expect(item.registrationPeriod, equals('21 Sep 2026'));
      expect(item.allowance, equals('Rp 3.500.000 / bulan'));
      expect(item.applicantsCount, equals(4));
      expect(item.requirements, contains('Menguasai Blender dan 3D Modeling'));
    });

    test('CorporateVacancyItem.fromOpportunity properly maps creative job opportunity', () {
      final opp = OpportunityModel(
        id: 'opp-job-1',
        title: 'Senior Creative Director & Brand Strategist',
        description: 'Memimpin kampanye visual korporat',
        subRoleSlug: 'director',
        status: 'open',
        deadline: '2026-11-30',
        budgetRange: 'Rp 20.000.000 / bulan',
        applicationsCount: 2,
        requirements: [
          OpportunityRequirementModel(
            subRoleSlug: 'creative_director',
            notes: 'Minimal 4 tahun pengalaman di industri',
          ),
        ],
      );

      final item = CorporateVacancyItem.fromOpportunity(opp);

      expect(item.id, equals('opp-job-1'));
      expect(item.category, equals('job'));
      expect(item.categoryLabel, equals('Pekerjaan'));
      expect(item.statusLabel, equals('Pendaftaran Dibuka'));
      expect(item.registrationPeriod, equals('30 Nov 2026'));
      expect(item.allowance, equals('Rp 20.000.000 / bulan'));
      expect(item.applicantsCount, equals(2));
    });

    test('CorporateVacancyItem status color and label for in_progress status', () {
      final opp = OpportunityModel(
        id: 'opp-ongoing-1',
        title: '2D Animator & Motion Graphic Intern',
        subRoleSlug: 'animator',
        status: 'in_progress',
        deadline: '2026-08-10',
      );

      final item = CorporateVacancyItem.fromOpportunity(opp);
      expect(item.statusLabel, equals('Sedang Berjalan'));
      expect(item.statusBadgeColor.toARGB32(), equals(const Color(0xFF2563EB).toARGB32()));
    });

    test('SpecializationQuotaEntry correctly computes and accumulates quotas', () {
      final entry1 = SpecializationQuotaEntry(
        roleSlug: 'photographer',
        roleLabel: 'Photographer',
        initialQuota: 10,
      );
      final entry2 = SpecializationQuotaEntry(
        roleSlug: 'videographer',
        roleLabel: 'Videographer',
        initialQuota: 10,
      );

      expect(entry1.quota, equals(10));
      expect(entry2.quota, equals(10));

      final totalQuota = entry1.quota + entry2.quota;
      expect(totalQuota, equals(20));

      // Update quota in text field
      entry1.quotaController.text = '15';
      expect(entry1.quota, equals(15));
      expect(entry1.quota + entry2.quota, equals(25));

      entry1.dispose();
      entry2.dispose();
    });

    test('kCorporateSpecializationOptions contains core creative roles', () {
      final slugs = kCorporateSpecializationOptions.map((e) => e['slug']).toList();
      expect(slugs, contains('photographer'));
      expect(slugs, contains('videographer'));
      expect(slugs, contains('3d_modeler'));
      expect(slugs, contains('ui_ux_designer'));
    });
  });

  group('CorporateVacancyFormDialog Widget Tests', () {
    testWidgets('Displays modal form with multi-specialization quota calculation', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CorporateVacancyFormDialog(),
          ),
        ),
      );
      await tester.pump();

      // Verify the modal dialog components
      expect(find.text('Buka Lowongan Kerja & Magang'), findsOneWidget);
      expect(find.text('B2B Corporate'), findsOneWidget);
      expect(find.text('Tervalidasi Sistem Instansi Kreavana'), findsOneWidget);

      // Verify guidance banner
      expect(find.textContaining('Panduan Buka Lowongan:'), findsOneWidget);

      // Verify 3 sections
      expect(find.text('Informasi Lowongan & Program'), findsOneWidget);
      expect(find.text('Spesifikasi Keahlian & Alokasi Kuota'), findsOneWidget);
      expect(find.text('Syarat & Kualifikasi Pelamar'), findsOneWidget);

      // Verify multi-specializations and live calculation: Photographer 10 + Videographer 10 = 20
      expect(find.text('Total Kuota Terakumulasi: 20 Posisi'), findsOneWidget);
      expect(find.text('Photographer (10) + Videographer (10) = 20 Total Posisi Dibuka'), findsOneWidget);

      // Verify buttons
      expect(find.text('Batal'), findsOneWidget);
      expect(find.text('Publikasikan Lowongan'), findsOneWidget);
    });

    testWidgets('Dynamically updates total quota when individual quota changes', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CorporateVacancyFormDialog(),
          ),
        ),
      );
      await tester.pump();

      // Find TextFormField for quota (both photographer and videographer initially '10')
      final quotaFields = find.widgetWithText(TextFormField, '10');
      expect(quotaFields, findsAtLeastNWidgets(1));

      // Scroll to quota field and enter text
      await tester.ensureVisible(quotaFields.first);
      await tester.enterText(quotaFields.first, '15');
      await tester.pump();

      // Verify updated total quota (15 + 10 = 25)
      expect(find.text('Total Kuota Terakumulasi: 25 Posisi'), findsOneWidget);
    });

    testWidgets('Displays salary range inputs by default and can toggle to fixed', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1000));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CorporateVacancyFormDialog(),
          ),
        ),
      );
      await tester.pump();

      // Verify Rentang Gaji and Nominal Tetap options are present
      final tetapBtn = find.text('Nominal Tetap');
      expect(find.text('Rentang Gaji'), findsOneWidget);
      expect(tetapBtn, findsOneWidget);

      // Verify default salary range preview
      expect(find.text('Pratinjau: Rp 2.500.000 - Rp 3.500.000 / bulan'), findsOneWidget);
      expect(find.text('s/d'), findsOneWidget);

      // Toggle to Nominal Tetap
      await tester.ensureVisible(tetapBtn);
      await tester.tap(tetapBtn);
      await tester.pump();

      // Verify updated preview in fixed mode
      expect(find.text('Pratinjau: Rp 2.500.000 / bulan'), findsOneWidget);
      expect(find.text('s/d'), findsNothing);
    });

    testWidgets('Salary is optional: can toggle to Kompetitif / Negosiasi or clear nominal', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1000));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CorporateVacancyFormDialog(),
          ),
        ),
      );
      await tester.pump();

      // Verify label is optional
      expect(find.text('Estimasi Gaji / Uang Saku (Opsional)'), findsOneWidget);

      // Verify Kompetitif / Negosiasi option exists
      final negoBtn = find.text('Kompetitif / Negosiasi');
      expect(negoBtn, findsOneWidget);

      // Tap Kompetitif / Negosiasi
      await tester.ensureVisible(negoBtn);
      await tester.tap(negoBtn);
      await tester.pump();

      // Verify preview displays Kompetitif / Sesuai Kesepakatan
      expect(find.text('Pratinjau: Kompetitif / Sesuai Kesepakatan'), findsOneWidget);
    });

    testWidgets('Searchable specialization dropdown filters options and adds new custom role', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1200));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CorporateVacancyFormDialog(),
          ),
        ),
      );
      await tester.pump();

      // Tap the first specialization dropdown
      final specField = find.byKey(const ValueKey('spec_dropdown_0'));
      expect(specField, findsOneWidget);
      await tester.ensureVisible(specField);
      await tester.tap(specField);
      await tester.pumpAndSettle();

      // Verify Searchable Dialog is open
      expect(find.text('Pilih Spesialisasi Keahlian'), findsOneWidget);

      // Search for '3D'
      final searchField = find.widgetWithText(TextFormField, 'Cari spesialisasi atau ketik opsi baru...');
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, '3D');
      await tester.pumpAndSettle();

      // Verify '3D Modeler & Texture Artist' is present
      expect(find.text('3D Modeler & Texture Artist'), findsOneWidget);

      // Search for a non-existent new role: 'AI Prompt Engineer'
      await tester.enterText(searchField, 'AI Prompt Engineer');
      await tester.pumpAndSettle();

      // Verify "+ Tambahkan 'AI Prompt Engineer'" tile appears
      final addTile = find.byKey(const ValueKey('btn_add_typed_spec_option'));
      expect(addTile, findsOneWidget);
      expect(find.text('Tambahkan "AI Prompt Engineer"'), findsOneWidget);

      // Tap to add and select the new role
      await tester.tap(addTile);
      await tester.pumpAndSettle();

      // Dialog should close and first specialization row should now have 'AI Prompt Engineer'
      expect(find.text('AI Prompt Engineer'), findsWidgets);
    });
  });
}
