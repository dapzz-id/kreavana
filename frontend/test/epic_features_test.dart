import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kreavana/models/opportunity_model.dart';
import 'package:kreavana/models/opportunity_application_model.dart';
import 'package:kreavana/models/user_model.dart';
import 'package:kreavana/services/portfolio_service.dart';
import 'package:kreavana/widgets/responsive_modal.dart';

void main() {
  group('Epic Feature Tests - Models & Domain', () {
    test('OpportunityModel deserializes multi-capability, poster, and schedule', () {
      final json = {
        'id': 101,
        'title': 'Konser Festival Budaya Nusantara',
        'sub_role_slug': 'tukang_kendang',
        'type': 'project',
        'poster_url': 'https://storage.kreavana.com/posters/festival.jpg',
        'event_date': '2026-10-25',
        'event_start_time': '18:00',
        'event_end_time': '23:00',
        'requirements': [
          {
            'id': 1,
            'opportunity_id': 101,
            'sub_role_slug': 'tukang_kendang',
            'quantity_needed': 2,
            'allocated_budget': '1500000.00',
            'notes': 'Kendang rampak Sunda',
          },
          {
            'id': 2,
            'opportunity_id': 101,
            'sub_role_slug': 'photographer',
            'quantity_needed': 1,
            'allocated_budget': '2000000.00',
          },
        ],
        'approved_creators': [
          {
            'id': 'cr-1',
            'name': 'Budi Santoso',
            'sub_role': 'tukang_kendang',
          }
        ],
      };

      final opp = OpportunityModel.fromJson(json);

      expect(opp.id, '101');
      expect(opp.title, 'Konser Festival Budaya Nusantara');
      expect(opp.subRoleSlug, 'tukang_kendang');
      expect(opp.subRoleLabel, '🥁 Tukang Kendang');
      expect(opp.posterUrl, 'https://storage.kreavana.com/posters/festival.jpg');
      expect(opp.eventDate, '2026-10-25');
      expect(opp.eventStartTime, '18:00');
      expect(opp.eventEndTime, '23:00');
      expect(opp.requirements.length, 2);
      expect(opp.requirements[0].quantity, 2);
      expect(opp.requirements[0].label, '🥁 Tukang Kendang (2 orang)');
      expect(opp.requirements[1].label, '📸 Fotografer (1 orang)');
      expect(opp.approvedCreators.length, 1);
      expect(opp.approvedCreators[0].name, 'Budi Santoso');
    });

    test('OpportunityApplicationModel deserializes status correctly', () {
      final json = {
        'id': 505,
        'opportunity_id': 101,
        'creator_id': 42,
        'sub_role_slug': 'tukang_kendang',
        'status': 'pending',
        'pitch_message': 'Siap tampil dengan kendang rampak profesional.',
        'proposed_rate': '1500000.00',
        'creator': {
          'id': 42,
          'name': 'Asep Kendang',
          'username': 'asepkendang',
        },
      };

      final app = OpportunityApplicationModel.fromJson(json);

      expect(app.id, '505');
      expect(app.opportunityId, '101');
      expect(app.subRoleSlug, 'tukang_kendang');
      expect(app.subRoleLabel, '🥁 Tukang Kendang');
      expect(app.status, 'pending');
      expect(app.isPending, true);
      expect(app.isApproved, false);
      expect(app.creator?.name, 'Asep Kendang');
    });

    test('UserModel guest and marketing roles', () {
      final guest = UserModel.guest();
      expect(guest.isGuest, true);
      expect(guest.name, 'Tamu Kreavana');
      expect(guest.role, 'guest');

      final marketing = UserModel(
        id: '99',
        name: 'Staff Marketing',
        username: 'marketing_ops',
        email: 'marketing@kreavana.com',
        role: 'marketing',
      );
      expect(marketing.isMarketing, true);
      expect(marketing.isGuest, false);
    });

    test('PortfolioItemModel handles external pre-Kreavana provenance', () {
      final json = {
        'id': 12,
        'title': 'Konser Gamelan Keraton 2024',
        'category': 'Musisi Kendang',
        'event_date': '2024-05-10',
        'location': 'Surakarta',
        'source': 'external',
        'verification_status': 'self_reported',
        'client_name': 'Dinas Kebudayaan Surakarta',
      };

      final item = PortfolioItemModel.fromJson(json);

      expect(item.id, 12);
      expect(item.title, 'Konser Gamelan Keraton 2024');
      expect(item.isExternal, true);
      expect(item.source, 'external');
      expect(item.clientName, 'Dinas Kebudayaan Surakarta');
      expect(item.eventDate, '2024-05-10');
      expect(item.location, 'Surakarta');
    });
  });

  group('ResponsiveModal Widget Test', () {
    testWidgets('Renders modal header, content and actions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveModal(
              title: 'Konfirmasi Pengajuan',
              subtitle: 'Detail data pengajuan Anda',
              body: const Text('Isi konten dialog modal responsif'),
              footer: Row(
                children: [
                  TextButton(
                    onPressed: () {},
                    child: const Text('Batal'),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Kirim'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Konfirmasi Pengajuan'), findsOneWidget);
      expect(find.text('Detail data pengajuan Anda'), findsOneWidget);
      expect(find.text('Isi konten dialog modal responsif'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
      expect(find.text('Kirim'), findsOneWidget);
    });
  });
}
