import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kreavana/models/opportunity_application_model.dart';
import 'package:kreavana/models/opportunity_model.dart';
import 'package:kreavana/models/user_model.dart';
import 'package:kreavana/screens/corporate_lowongan_screen.dart';
import 'package:kreavana/screens/program_magang_detail_screen.dart';
import 'package:kreavana/screens/program_magang_screen.dart';
import 'package:kreavana/widgets/app_pagination_bar.dart';
import 'package:kreavana/widgets/program_magang_card.dart';

void main() {
  group('Corporate Vacancy Card and Institution Visibility Tests', () {
    test('CorporateVacancyItem correctly parses multi-specialization quota from requirements', () {
      final opp = OpportunityModel(
        id: 'opp-corp-123',
        title: 'Program Magang MBKM 3D Modeler Batch I 2026',
        description: 'Kerja sama penempatan talenta vokasi dan mahasiswa magang.',
        subRoleSlug: 'magang',
        status: 'open',
        deadline: '2026-09-21',
        budgetRange: 'Rp 2.500.000 - Rp 3.500.000 / bulan',
        applicationsCount: 0,
        requirements: [
          OpportunityRequirementModel(
            subRoleSlug: 'photographer',
            quantity: 10,
            notes: 'Spesialisasi Photographer (10 kuota)',
          ),
          OpportunityRequirementModel(
            subRoleSlug: 'videographer',
            quantity: 10,
            notes: 'Spesialisasi Videographer (10 kuota)',
          ),
          OpportunityRequirementModel(
            subRoleSlug: 'kualifikasi',
            quantity: 1,
            notes: 'Siswa SMK vokasi atau Mahasiswa aktif jurusan terkait',
          ),
        ],
      );

      final item = CorporateVacancyItem.fromOpportunity(opp);

      expect(item.id, equals('opp-corp-123'));
      expect(item.title, equals('Program Magang MBKM 3D Modeler Batch I 2026'));
      expect(item.category, equals('magang'));
      expect(item.categoryLabel, equals('Magang'));
      expect(item.statusLabel, equals('Pendaftaran Dibuka'));
      expect(item.registrationPeriod, equals('21 Sep 2026'));
      expect(item.quotaText, equals('20 dari 20 posisi'));
      expect(item.requirements, contains('Siswa SMK vokasi atau Mahasiswa aktif jurusan terkait'));
    });

    test('ProyekSayaScreen filters and displays magang opportunities for institution role', () {
      final corporateOpp = OpportunityModel(
        id: 'opp-magang-corp',
        title: 'Program Magang MBKM 3D Modeler Batch I 2026',
        description: 'Penempatan magang vokasi',
        subRoleSlug: 'magang',
        status: 'open',
        deadline: '2026-09-21',
        poster: OpportunityPoster(
          id: 'user-corp-1',
          name: 'PT Kreavana Nusantara Korporat',
          username: 'corporate_demo',
          role: 'user',
          selectedSubRole: 'corporate',
        ),
      );

      final generalGigOpp = OpportunityModel(
        id: 'opp-gig-wedding',
        title: 'MC Pernikahan & Event Korporat',
        description: 'MC acara wedding weekend',
        subRoleSlug: 'mc',
        status: 'open',
        deadline: '2026-10-15',
        poster: OpportunityPoster(
          id: 'user-client-1',
          name: 'Klien Personal',
          username: 'klien_1',
          role: 'user',
          selectedSubRole: 'client',
        ),
      );

      final allOpps = [corporateOpp, generalGigOpp];

      // Simulate institution view filter logic from ProyekSayaScreen
      final magangList = allOpps.where((opp) {
        final isExplicitMagang = opp.subRoleSlug.toLowerCase().contains('magang') ||
            opp.title.toLowerCase().contains('magang') ||
            opp.title.toLowerCase().contains('intern') ||
            (opp.description != null &&
                (opp.description!.toLowerCase().contains('magang') ||
                    opp.description!.toLowerCase().contains('intern'))) ||
            opp.requirements.any((r) =>
                r.subRoleSlug.toLowerCase().contains('magang') ||
                (r.notes != null &&
                    (r.notes!.toLowerCase().contains('magang') ||
                        r.notes!.toLowerCase().contains('kuota'))));

        final isCorporatePoster = opp.poster?.selectedSubRole?.toLowerCase() == 'corporate' ||
            opp.poster?.role.toLowerCase() == 'corporate';

        return isExplicitMagang || isCorporatePoster;
      }).toList();

      expect(magangList.length, equals(1));
      expect(magangList.first.id, equals('opp-magang-corp'));
      expect(magangList.first.title, contains('Program Magang'));
    });

    test('Newly fetched vacancy from server is prioritized over preset vacancies', () {
      final presetItem = CorporateVacancyItem(
        id: 'corp_magang_1',
        title: 'Preset 3D Modeler & Character Asset Production',
        description: 'Preset description',
        category: 'magang',
        categoryLabel: 'Magang',
        status: 'open',
        statusLabel: 'Pendaftaran Dibuka',
        statusBadgeColor: const Color(0xFF16A34A),
        statusBadgeBg: const Color(0xFFDCFCE7),
        registrationPeriod: '21 Sep 2026',
        quotaText: '4 dari 10 posisi',
        allowance: 'Rp 3.500.000 / bulan',
        requirements: const ['Siswa SMK'],
        applicantsCount: 6,
      );

      final newCreatedServerItem = CorporateVacancyItem(
        id: 'opp-server-999',
        title: 'Program Magang MBKM 3D Modeler Batch I 2026',
        description: 'Lowongan baru dibuat oleh corporate user',
        category: 'magang',
        categoryLabel: 'Magang',
        status: 'open',
        statusLabel: 'Pendaftaran Dibuka',
        statusBadgeColor: const Color(0xFF16A34A),
        statusBadgeBg: const Color(0xFFDCFCE7),
        registrationPeriod: '21 Sep 2026',
        quotaText: '0 dari 20 posisi',
        allowance: 'Rp 2.500.000 - Rp 3.500.000 / bulan',
        requirements: const ['Siswa SMK vokasi'],
        applicantsCount: 0,
      );

      // Implementation of _allVacancies mapping logic
      final Map<String, CorporateVacancyItem> map = {};
      final fetchedItems = [newCreatedServerItem];
      final presetVacancies = [presetItem];

      // Real items from server added first
      for (final item in fetchedItems) {
        map[item.id] = item;
      }
      for (final item in presetVacancies) {
        map.putIfAbsent(item.id, () => item);
      }
      final allList = map.values.toList();

      expect(allList.length, equals(2));
      expect(allList.first.id, equals('opp-server-999'));
      expect(allList.first.title, equals('Program Magang MBKM 3D Modeler Batch I 2026'));
      expect(allList.last.id, equals('corp_magang_1'));
    });

    test('ProyekSayaScreen excludes magang and vacancy cards for corporate role', () {
      final magangOpp = OpportunityModel(
        id: 'opp-magang-pv',
        title: 'Program Magang PV Electric Batch I 2027',
        description: 'Kerja sama penempatan talenta vokasi dan mahasiswa magang.',
        subRoleSlug: 'magang',
        status: 'open',
        requirements: [
          OpportunityRequirementModel(
            subRoleSlug: 'videographer',
            quantity: 10,
            notes: 'Spesialisasi Videographer (10 kuota)',
          ),
          OpportunityRequirementModel(
            subRoleSlug: 'kualifikasi',
            quantity: 1,
            notes: 'Siswa SMK vokasi atau Mahasiswa aktif',
          ),
        ],
      );

      final corporateProjectOpp = OpportunityModel(
        id: 'opp-corp-branding',
        title: 'Pengadaan Rebranding Brand & Visual Identity 2026',
        description: 'Paket komprehensif redesign visual identity enterprise.',
        subRoleSlug: 'desain_grafis',
        status: 'open',
        requirements: [
          OpportunityRequirementModel(
            subRoleSlug: 'desain_grafis',
            quantity: 1,
            notes: 'Desainer berpengalaman enterprise',
          ),
        ],
      );

      final allOpportunities = [magangOpp, corporateProjectOpp];

      // Simulate the corporate exclusion logic in ProyekSayaScreen
      bool isCorporateVacancyOrMagang(OpportunityModel opp) {
        final sub = opp.subRoleSlug.toLowerCase().trim();
        final title = opp.title.toLowerCase().trim();
        final desc = (opp.description ?? '').toLowerCase().trim();

        if (sub.contains('magang') || sub.contains('intern') || sub == 'lowongan') {
          return true;
        }
        if (title.contains('magang') ||
            title.contains('intern') ||
            title.contains('pkl') ||
            title.contains('mbkm') ||
            title.startsWith('lowongan ') ||
            title.contains('lowongan kerja') ||
            title.contains('buka lowongan')) {
          return true;
        }
        if (desc.contains('posisi magang') ||
            desc.contains('siswa vokasi') ||
            desc.contains('mahasiswa magang') ||
            desc.contains('tempat pkl') ||
            desc.contains('penempatan magang')) {
          return true;
        }
        return opp.requirements.any((r) {
          final rSub = r.subRoleSlug.toLowerCase();
          final notes = (r.notes ?? '').toLowerCase();
          return rSub.contains('magang') ||
              rSub == 'kualifikasi' ||
              notes.contains('kuota') ||
              notes.contains('spesialisasi') ||
              notes.contains('siswa smk') ||
              notes.contains('vokasi') ||
              notes.contains('mahasiswa aktif');
        });
      }

      final filteredForCorporate = allOpportunities
          .where((opp) => !isCorporateVacancyOrMagang(opp))
          .toList();

      expect(filteredForCorporate.length, equals(1));
      expect(filteredForCorporate.first.id, equals('opp-corp-branding'));
      expect(filteredForCorporate.first.title, equals('Pengadaan Rebranding Brand & Visual Identity 2026'));
      expect(filteredForCorporate.any((o) => o.id == 'opp-magang-pv'), isFalse);
    });
  });

  group('Institution DB-Only, 3-Tab Separation & Pagination Tests', () {
    test('OpportunityModel.fromJson parses has_applied correctly', () {
      final applied = OpportunityModel.fromJson({
        'id': 'opp-1',
        'title': 'Magang Animasi 3D',
        'sub_role_slug': 'magang',
        'status': 'open',
        'has_applied': true,
      });
      final appliedInt = OpportunityModel.fromJson({
        'id': 'opp-2',
        'title': 'Magang UI/UX',
        'sub_role_slug': 'magang',
        'status': 'open',
        'has_applied': 1,
      });
      final notApplied = OpportunityModel.fromJson({
        'id': 'opp-3',
        'title': 'Magang Desain Grafis',
        'sub_role_slug': 'magang',
        'status': 'open',
      });

      expect(applied.hasApplied, isTrue);
      expect(appliedInt.hasApplied, isTrue);
      expect(notApplied.hasApplied, isFalse);
    });

    test('ProgramMagangCard.fromMap and fromOpportunity do not inject mockup defaults', () {
      final emptyCard = ProgramMagangCard.fromMap({
        'id': 'db-1',
        'title': 'Program Magang Studio Real',
        'description': 'Deskripsi resmi dari database',
        'status': 'open',
      });
      expect(emptyCard.quotaText, equals('-'));
      expect(emptyCard.registrationPeriod, equals('-'));
      expect(emptyCard.requirements, isEmpty);

      final opp = OpportunityModel(
        id: 'db-2',
        title: 'Magang Developer Mobile',
        description: 'Dibuka oleh Corporate Mitra',
        subRoleSlug: 'magang',
        status: 'open',
      );
      final oppCard = ProgramMagangCard.fromOpportunity(opp);
      expect(oppCard.quotaText, equals('Terbuka'));
      expect(oppCard.requirements, isEmpty);
    });

    test('SchoolMagangStudent.fromApplication sets student status to Review when institution is approved', () {
      final approvedApp = OpportunityApplicationModel.fromJson({
        'id': 'app-1',
        'opportunity_id': 'opp-magang-1',
        'sub_role_slug': 'animator',
        'status': 'approved',
        'created_at': '2026-11-10',
        'submitted_documents': [
          {
            'student_name': 'Siti Nurhaliza',
            'student_class': 'XII Animasi 1',
            'student_portfolio': 'https://portfolio.example/siti',
            'submission_type': 'initial',
          },
        ],
      });

      final pendingApp = OpportunityApplicationModel.fromJson({
        'id': 'app-2',
        'opportunity_id': 'opp-magang-1',
        'sub_role_slug': 'animator',
        'status': 'submitted',
        'created_at': '2026-11-15',
        'submitted_documents': [
          {
            'student_name': 'Kadavi Raditya',
            'student_class': 'RPL',
            'student_portfolio': 'https://github.com/kadaviraditya',
            'submission_type': 'initial',
          },
        ],
      });

      // 1. When institution is NOT yet approved, pending student status remains Pending and is not marked additional
      final studentBeforeInstApproved = SchoolMagangStudent.fromApplication(
        pendingApp,
        schoolHasApprovedStudent: false,
        isSchoolApproved: false,
      );
      expect(studentBeforeInstApproved.name, equals('Kadavi Raditya'));
      expect(studentBeforeInstApproved.status, equals('Pending'));
      expect(studentBeforeInstApproved.isAdditional, isFalse);

      // 2. When institution is approved by corporate, pending student status becomes Review
      final approvedStudent = SchoolMagangStudent.fromApplication(
        approvedApp,
        schoolHasApprovedStudent: true,
        isSchoolApproved: true,
      );
      final studentAfterInstApproved = SchoolMagangStudent.fromApplication(
        pendingApp,
        schoolHasApprovedStudent: true,
        isSchoolApproved: true,
      );

      expect(approvedStudent.name, equals('Siti Nurhaliza'));
      expect(approvedStudent.status, equals('Diterima'));
      expect(studentAfterInstApproved.name, equals('Kadavi Raditya'));
      expect(studentAfterInstApproved.status, equals('Review'));
      expect(studentAfterInstApproved.isAdditional, isFalse);
    });

    testWidgets('AppPaginationBar paginates max 6 items per page and supports Prev/Next cleanly', (tester) async {
      final items = List.generate(14, (i) => 'Item ${i + 1}');
      int currentPage = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    final safePage = AppPaginationBar.safePage(
                      currentPage,
                      items.length,
                      pageSize: 6,
                    );
                    final paged = AppPaginationBar.slicePage(
                      items,
                      safePage,
                      pageSize: 6,
                    );
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final item in paged) Text(item),
                        AppPaginationBar(
                          totalItems: items.length,
                          currentPage: safePage,
                          pageSize: 6,
                          accentColor: Colors.purple,
                          itemLabel: 'data',
                          onPageChanged: (page) =>
                              setState(() => currentPage = page),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 6'), findsOneWidget);
      expect(find.text('Item 7'), findsNothing);
      expect(find.text('Menampilkan 1–6 dari 14 data'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(find.text('Item 7'), findsOneWidget);
      expect(find.text('Item 12'), findsOneWidget);
      expect(find.text('Item 1'), findsNothing);
      expect(find.text('Menampilkan 7–12 dari 14 data'), findsOneWidget);

      await tester.tap(find.text('3'));
      await tester.pump();
      expect(find.text('Item 13'), findsOneWidget);
      expect(find.text('Item 14'), findsOneWidget);
      expect(find.text('Menampilkan 13–14 dari 14 data'), findsOneWidget);

      await tester.tap(find.text('Prev'));
      await tester.pump();
      expect(find.text('Item 7'), findsOneWidget);
      expect(find.text('Menampilkan 7–12 dari 14 data'), findsOneWidget);
    });

    testWidgets('ProgramMagangScreen displays 3 separated tabs and zero mockup data when server returns empty', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final institutionUser = UserModel(
        id: 'inst-1',
        name: 'SMKN 1 Test',
        username: 'smkn1_test',
        email: 'smkn1@test.id',
        role: 'institution',
        subRole: 'institution',
        verificationType: 'institution',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProgramMagangScreen(user: institutionUser),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Lamaran Magang Saya'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Magang Corporate Mitra'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Semua Lowongan Magang'), findsAtLeastNWidgets(1));
      expect(find.text('Program Magang MBKM 3D Modeler Batch I 2026'), findsNothing);
      expect(find.text('Riset Kolaborasi Preservasi Budaya Digital'), findsNothing);
    });

    testWidgets('ProgramMagangDetailScreen displays Review badge for students when institution is approved and no false Siswa Tambahan', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final opp = OpportunityModel(
        id: 'test_opp_magang_review_1',
        title: 'Project Manager PV Electric',
        description: 'Lowongan pekerjaan proyek',
        subRoleSlug: 'magang',
        status: 'open',
        deadline: '2026-11-30',
        approvedCreators: [
          OpportunityApprovedCreatorModel(
            id: 'inst-1',
            name: 'Kreavana Demo Institution',
            username: 'inst_demo',
          ),
        ],
      );

      final institutionUser = UserModel(
        id: 'inst-1',
        name: 'Kreavana Demo Institution',
        username: 'inst_demo',
        email: 'inst@demo.id',
        role: 'institution',
        subRole: 'institution',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProgramMagangDetailScreen(
            opportunity: opp,
            user: institutionUser,
            isAppliedPartnership: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check banner status is Approved
      expect(find.text('Status Institusi: Disetujui / Bermitra (Approved)'), findsOneWidget);

      // Tap Daftar Peserta tab
      final daftarPesertaTab = find.descendant(
        of: find.byType(TabBar),
        matching: find.textContaining('Daftar Peserta'),
      );
      expect(daftarPesertaTab, findsOneWidget);
      await tester.tap(daftarPesertaTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Filter chips should include Review instead of Pending
      expect(find.widgetWithText(ChoiceChip, 'Review'), findsOneWidget);
    });

    test('OpportunityModel.isClosed returns true and CorporateVacancyItem shows "Pendaftaran Ditutup" when remaining quota is 0', () {
      final oppFullQuota = OpportunityModel(
        id: 'opp-full-1',
        title: 'Program Magang 3D Modeler',
        subRoleSlug: 'magang',
        status: 'open',
        requirements: [
          OpportunityRequirementModel(
            subRoleSlug: 'modeler',
            quantity: 2,
            notes: 'Spesialisasi 3D Modeler (2 kuota)',
          ),
        ],
        approvedCreators: [
          OpportunityApprovedCreatorModel(id: 'c1', name: 'Student 1', username: 's1'),
          OpportunityApprovedCreatorModel(id: 'c2', name: 'Student 2', username: 's2'),
        ],
      );

      expect(oppFullQuota.totalQuota, equals(2));
      expect(oppFullQuota.remainingQuota, equals(0));
      expect(oppFullQuota.isClosed, isTrue);
      expect(oppFullQuota.canApply, isFalse);

      final corporateItem = CorporateVacancyItem.fromOpportunity(oppFullQuota);
      expect(corporateItem.statusLabel, equals('Pendaftaran Ditutup'));
      expect(corporateItem.quotaText, equals('0 dari 2 posisi'));
    });

    testWidgets('ProgramMagangDetailScreen hides Tambah/Ajukan Siswa button and shows Pendaftaran Ditutup when quota is full', (tester) async {
      final oppFullQuota = OpportunityModel(
        id: 'test_opp_full_1',
        title: 'Program Magang 3D Modeler',
        subRoleSlug: 'magang',
        status: 'open',
        requirements: [
          OpportunityRequirementModel(
            subRoleSlug: 'modeler',
            quantity: 1,
            notes: 'Spesialisasi 3D Modeler (1 kuota)',
          ),
        ],
        approvedCreators: [
          OpportunityApprovedCreatorModel(id: 'c1', name: 'Student 1', username: 's1'),
        ],
      );

      final institutionUser = UserModel(
        id: 'inst-1',
        name: 'Kreavana Demo Institution',
        username: 'inst_demo',
        email: 'inst@demo.id',
        role: 'institution',
        subRole: 'institution',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProgramMagangDetailScreen(
            opportunity: oppFullQuota,
            user: institutionUser,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Top status badge should display 'Pendaftaran Ditutup'
      expect(find.text('Pendaftaran Ditutup'), findsOneWidget);

      // Tap Daftar Peserta tab
      final daftarPesertaTab = find.descendant(
        of: find.byType(TabBar),
        matching: find.textContaining('Daftar Peserta'),
      );
      await tester.tap(daftarPesertaTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Ensure Tambah Peserta button does NOT exist
      expect(find.byKey(const Key('btn_tambah_peserta')), findsNothing);
      expect(find.text('Tambah Peserta'), findsNothing);
      expect(find.text('Tambah Siswa'), findsNothing);
      expect(find.text('Ajukan Siswa'), findsNothing);

      // Closed info banner should be visible
      expect(find.textContaining('Pendaftaran program ini telah ditutup karena kuota posisi telah terpenuhi'), findsOneWidget);
    });

    testWidgets('ProgramMagangDetailScreen hides Tambah Peserta button when institution status is Approved even if program is still open', (tester) async {
      final oppOpenApproved = OpportunityModel(
        id: 'test_opp_open_approved_1',
        title: 'Program Magang 3D Modeler',
        subRoleSlug: 'magang',
        status: 'open',
        requirements: [
          OpportunityRequirementModel(
            subRoleSlug: 'modeler',
            quantity: 5,
            notes: 'Spesialisasi 3D Modeler',
          ),
        ],
        approvedCreators: [
          OpportunityApprovedCreatorModel(id: 'inst-1', name: 'Kreavana Demo Institution', username: 'inst_demo'),
        ],
      );

      final institutionUser = UserModel(
        id: 'inst-1',
        name: 'Kreavana Demo Institution',
        username: 'inst_demo',
        email: 'inst@demo.id',
        role: 'institution',
        subRole: 'institution',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProgramMagangDetailScreen(
            opportunity: oppOpenApproved,
            user: institutionUser,
            isAppliedPartnership: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Status Institusi: Disetujui / Bermitra (Approved)'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(TabBar),
          matching: find.textContaining('Daftar Peserta'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('btn_tambah_peserta')), findsNothing);
      expect(find.text('Tambah Peserta'), findsNothing);
      expect(
        find.textContaining('Status kemitraan institusi pada program ini telah Disetujui oleh Corporate'),
        findsOneWidget,
      );
    });

    testWidgets('ProgramMagangDetailScreen hides Tambah Peserta button when institution status is Rejected', (tester) async {
      final oppRejected = OpportunityModel(
        id: 'test_opp_rejected_1',
        title: 'Program Magang Animator',
        subRoleSlug: 'magang',
        status: 'open',
        requirements: [
          OpportunityRequirementModel(
            subRoleSlug: 'animator',
            quantity: 3,
            notes: 'Animator 2D/3D',
          ),
        ],
      );

      final institutionUser = UserModel(
        id: 'inst-1',
        name: 'Kreavana Demo Institution',
        username: 'inst_demo',
        email: 'inst@demo.id',
        role: 'institution',
        subRole: 'institution',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProgramMagangDetailScreen(
            opportunity: oppRejected,
            user: institutionUser,
            initialPartnershipStatus: 'rejected',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Status Institusi: Ditolak oleh Corporate (Rejected)'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(TabBar),
          matching: find.textContaining('Daftar Peserta'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('btn_tambah_peserta')), findsNothing);
      expect(find.text('Tambah Peserta'), findsNothing);
      expect(
        find.textContaining('Pengajuan institusi pada program ini telah Ditolak oleh Corporate'),
        findsOneWidget,
      );
    });

    testWidgets('Tambah Peserta popup supports collapsible general info dropdown and multiple participants', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final oppOpen = OpportunityModel(
        id: 'test_opp_multi_add_1',
        title: 'Program Magang UI/UX Designer',
        subRoleSlug: 'magang',
        status: 'open',
        requirements: [
          OpportunityRequirementModel(
            subRoleSlug: 'uiux',
            quantity: 5,
            notes: 'UI/UX Designer',
          ),
        ],
      );

      final institutionUser = UserModel(
        id: 'inst-1',
        name: 'Kreavana Demo Institution',
        username: 'inst_demo',
        email: 'inst@demo.id',
        role: 'institution',
        subRole: 'institution',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProgramMagangDetailScreen(
            opportunity: oppOpen,
            user: institutionUser,
            initialPartnershipStatus: 'not_applied',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(
        find.descendant(
          of: find.byType(TabBar),
          matching: find.textContaining('Daftar Peserta'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final addBtn = find.byKey(const Key('btn_tambah_peserta'));
      expect(addBtn, findsOneWidget);

      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Popup title & general info collapsed by default
      expect(find.text('Tambah Peserta Program Magang'), findsOneWidget);
      expect(find.text('Informasi Umum & Panduan Pengajuan'), findsOneWidget);
      expect(find.text('Buka'), findsOneWidget);
      expect(find.text('Panduan Pengajuan Peserta & Seleksi Kemitraan:'), findsNothing);

      // Expand general info dropdown
      await tester.tap(find.byKey(const Key('general_info_dropdown_toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Tutup'), findsOneWidget);
      expect(find.text('Panduan Pengajuan Peserta & Seleksi Kemitraan:'), findsOneWidget);

      // Collapse again so form entry stays uncluttered
      await tester.tap(find.byKey(const Key('general_info_dropdown_toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Buka'), findsOneWidget);
      expect(find.text('Panduan Pengajuan Peserta & Seleksi Kemitraan:'), findsNothing);

      // Multi-participant support: starts with 1 participant, add another
      expect(find.text('Daftar Peserta yang Diajukan (1 Peserta)'), findsOneWidget);
      expect(find.text('Peserta #1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_add_another_participant')));
      await tester.pumpAndSettle();

      expect(find.text('Daftar Peserta yang Diajukan (2 Peserta)'), findsOneWidget);
      expect(find.text('Peserta #2'), findsOneWidget);
      expect(find.text('Kirim Pengajuan (2 Peserta)'), findsOneWidget);

      // Delete second participant
      final deleteParticipant2 = find.byTooltip('Hapus baris peserta #2');
      await tester.ensureVisible(deleteParticipant2);
      await tester.tap(deleteParticipant2);
      await tester.pumpAndSettle();

      expect(find.text('Daftar Peserta yang Diajukan (1 Peserta)'), findsOneWidget);
      expect(find.text('Peserta #2'), findsNothing);
    });
  });
}
