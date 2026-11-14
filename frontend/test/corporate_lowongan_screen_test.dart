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
  });
}
