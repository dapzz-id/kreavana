import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kreavana/models/opportunity_model.dart';
import 'package:kreavana/screens/corporate_lowongan_screen.dart';
import 'package:kreavana/widgets/app_pagination_bar.dart';
import 'package:kreavana/widgets/program_magang_card.dart';

void main() {
  group('Distinguish Job Vacancies from Magang (Internship) Tests', () {
    final jobOpportunity = OpportunityModel(
      id: 'opp-job-pv-electric',
      title: 'Project Manager PV Electric',
      description: 'Menghandle segala hal yang berkaitan dengan semua kelistrikan',
      subRoleSlug: 'electrician',
      status: 'open',
      deadline: '2026-11-30',
      budgetRange: 'Rp 5.000.000 - Rp 8.000.000',
      applicationsCount: 1,
      requirements: [
        OpportunityRequirementModel(
          subRoleSlug: 'electrician',
          quantity: 4,
          notes: 'Spesialisasi Electrician (4 kuota)',
        ),
        OpportunityRequirementModel(
          subRoleSlug: 'kualifikasi',
          quantity: 1,
          notes: 'Memiliki portofolio karya yang relevan',
        ),
        OpportunityRequirementModel(
          subRoleSlug: 'kualifikasi',
          quantity: 1,
          notes: 'Mampu bekerja sama dalam tim dan komunikatif',
        ),
      ],
    );

    final magangOpportunity = OpportunityModel(
      id: 'opp-magang-mbkm',
      title: 'Program Magang MBKM 3D Modeler Batch I 2026',
      description: 'Kerja sama penempatan talenta vokasi dan mahasiswa magang.',
      subRoleSlug: 'magang',
      status: 'open',
      deadline: '2026-09-21',
      budgetRange: 'Rp 2.500.000 - Rp 3.500.000 / bulan',
      applicationsCount: 0,
      requirements: [
        OpportunityRequirementModel(
          subRoleSlug: 'animator',
          quantity: 10,
          notes: 'Spesialisasi 3D Modeler (10 kuota)',
        ),
        OpportunityRequirementModel(
          subRoleSlug: 'kualifikasi',
          quantity: 1,
          notes: 'Siswa SMK vokasi atau Mahasiswa aktif jurusan terkait',
        ),
      ],
    );

    test('OpportunityModel correctly distinguishes isMagang and isJob', () {
      expect(jobOpportunity.isMagang, isFalse);
      expect(jobOpportunity.isJob, isTrue);

      expect(magangOpportunity.isMagang, isTrue);
      expect(magangOpportunity.isJob, isFalse);
    });

    test('CorporateVacancyItem correctly categorizes job as "Lowongan Kerja" and calculates quota strictly from specializations', () {
      final item = CorporateVacancyItem.fromOpportunity(jobOpportunity);
      expect(item.category, equals('job'));
      expect(item.categoryLabel, equals('Lowongan Kerja'));
      expect(item.title, equals('Project Manager PV Electric'));
      expect(item.quotaText, equals('4 dari 4 posisi'));

      final magangItem = CorporateVacancyItem.fromOpportunity(magangOpportunity);
      expect(magangItem.category, equals('magang'));
      expect(magangItem.categoryLabel, equals('Magang'));
      expect(magangItem.quotaText, equals('10 dari 10 posisi'));
    });

    test('ProgramMagangCard.fromOpportunity generates correct badge, button, and quota for job vs magang', () {
      final jobCard = ProgramMagangCard.fromOpportunity(
        jobOpportunity,
        buttonLabel: 'Detail & Lamar Magang →',
      );
      expect(jobCard.categoryBadge, equals('Lowongan Kerja'));
      expect(jobCard.categoryBadgeColor, equals(const Color(0xFF7E22CE)));
      expect(jobCard.categoryBadgeBg, equals(const Color(0xFFF3E8FF)));
      expect(jobCard.buttonLabel, equals('Detail & Lamar Lowongan →'));
      expect(jobCard.quotaText, equals('4 dari 4 posisi'));

      final magangCard = ProgramMagangCard.fromOpportunity(
        magangOpportunity,
        buttonLabel: 'Detail & Lamar Magang →',
      );
      expect(magangCard.categoryBadge, equals('Magang'));
      expect(magangCard.categoryBadgeColor, equals(const Color(0xFF0284C7)));
      expect(magangCard.categoryBadgeBg, equals(const Color(0xFFE0F2FE)));
      expect(magangCard.buttonLabel, equals('Detail & Lamar Magang →'));
      expect(magangCard.quotaText, equals('10 dari 10 posisi'));
    });

    testWidgets('Widget test: Job card renders "Lowongan Kerja" badge and "Detail & Lamar Lowongan →" button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgramMagangCard.fromOpportunity(
              jobOpportunity,
              buttonLabel: 'Detail & Lamar Magang →', // Caller passes default magang label
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should display "Lowongan Kerja" badge
      expect(find.text('Lowongan Kerja'), findsOneWidget);

      // Should NOT display "Magang" anywhere on the card
      expect(find.text('Magang'), findsNothing);
      expect(find.text('Detail & Lamar Magang →'), findsNothing);

      // Should display adapted button "Detail & Lamar Lowongan" (arrow is rendered as separate icon)
      expect(find.text('Detail & Lamar Lowongan'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

      // Should display correct quota "4 dari 4 posisi"
      expect(find.text('4 dari 4 posisi'), findsOneWidget);

      // Should display title and subtitle
      expect(find.text('Project Manager PV Electric'), findsOneWidget);
      expect(find.text('Menghandle segala hal yang berkaitan dengan semua kelistrikan'), findsOneWidget);
    });

    testWidgets('Widget test: AppPaginationBar renders compact, fixed-size 36x36 pill and does not stretch', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppPaginationBar(
              currentPage: 1,
              totalItems: 5,
              pageSize: 6,
              itemLabel: 'program',
              onPageChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Menampilkan 1–5 dari 5 program'), findsOneWidget);
      expect(find.text('Prev'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Verify pill size is exactly 36x36 and not stretched full-width
      final pillFinder = find.ancestor(
        of: find.text('1'),
        matching: find.byType(Container),
      ).first;
      final Size pillSize = tester.getSize(pillFinder);
      expect(pillSize.width, equals(36));
      expect(pillSize.height, equals(36));
    });
  });
}
