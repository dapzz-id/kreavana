import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kreavana/models/user_model.dart';
import 'package:kreavana/services/subscription_service.dart';
import 'package:kreavana/widgets/upgrade_plan_modal.dart';

void main() {
  group('Pilih Paket Upgrade - Hide Boost Akun Text', () {
    test('SubscriptionService.fallbackPlans omits boost text across roles', () {
      for (final role in ['institution', 'creator', 'client', 'user', null]) {
        final plans = SubscriptionService.fallbackPlans(role: role);
        expect(plans, isNotEmpty);
        for (final plan in plans) {
          for (final feature in plan.features) {
            expect(feature.toLowerCase(), isNot(contains('boost')));
          }
        }
      }
    });

    testWidgets('UpgradePlanModal hides Boost akun text for institution and creator', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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
          home: Scaffold(
            body: UpgradePlanModal(user: institutionUser),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Pilih Paket Upgrade'), findsOneWidget);
      expect(find.textContaining('Boost akun'), findsNothing);
      expect(find.textContaining('boost'), findsNothing);
      expect(find.text('Voice call: 80 menit'), findsOneWidget);
      expect(find.text('Storage 20 GB'), findsOneWidget);

      final creatorUser = UserModel(
        id: 'creator-1',
        name: 'Kreavana Demo Creator',
        username: 'creator_demo',
        email: 'creator@demo.id',
        role: 'creator',
        subRole: 'videographer',
        isCreatorApproved: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpgradePlanModal(user: creatorUser),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Pilih Paket Upgrade'), findsOneWidget);
      expect(find.textContaining('Boost akun'), findsNothing);
      expect(find.textContaining('boost'), findsNothing);
    });
  });
}
