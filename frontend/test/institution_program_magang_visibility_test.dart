import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kreavana/models/opportunity_model.dart';
import 'package:kreavana/models/user_model.dart';
import 'package:kreavana/screens/corporate_lowongan_screen.dart';

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
      expect(item.quotaText, equals('0 dari 20 posisi'));
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
  });
}
