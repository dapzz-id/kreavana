import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kreavana/features/dashboard/screens/dashboard_screen.dart';
import 'package:kreavana/models/user_model.dart';
import 'package:kreavana/services/dio_client.dart';
import 'package:kreavana/widgets/subrole_right_sidebar.dart';

import 'fake_secure_storage.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    DioClient.instance.setStorageForTesting(FakeSecureStorage());
  });

  group('Quick Actions (Aksi Cepat) visibility by role', () {
    testWidgets('SubRoleRightSidebar hides Aksi Cepat for institution users', (
      WidgetTester tester,
    ) async {
      final institutionUser = UserModel(
        id: 'inst-1',
        name: 'SMK Telesandi',
        username: 'smk_telesandi',
        email: 'smk@kreavana.id',
        role: 'institution',
        subRole: 'institution',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 340,
                child: SubRoleRightSidebar(
                  user: institutionUser,
                  isDark: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Aksi Cepat'), findsNothing);
      expect(find.text('Program Magang'), findsNothing);
      expect(find.text('SMK Telesandi'), findsOneWidget);
    });

    testWidgets('SubRoleRightSidebar keeps Aksi Cepat for company users', (
      WidgetTester tester,
    ) async {
      final companyUser = UserModel(
        id: 'corp-1',
        name: 'PT Kreavana Studio',
        username: 'kreavana_studio',
        email: 'corp@kreavana.id',
        role: 'user',
        subRole: 'company',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 340,
                child: SubRoleRightSidebar(
                  user: companyUser,
                  isDark: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Aksi Cepat'), findsOneWidget);
    });

    test('DashboardScreen.isInstitutionUser accurately detects institution roles', () {
      final instSubRole = UserModel(
        id: 'inst-2',
        name: 'Kreavana Demo Institution',
        username: 'SMK_TELESANDI',
        email: 'demo-inst@kreavana.id',
        role: 'user',
        subRole: 'school',
      );
      final corporateUser = UserModel(
        id: 'corp-2',
        name: 'PT Kreavana Korporat',
        username: 'corp_demo',
        email: 'corp2@kreavana.id',
        role: 'user',
        subRole: 'corporate',
      );

      expect(DashboardScreen.isInstitutionUser(instSubRole), isTrue);
      expect(DashboardScreen.isInstitutionUser(corporateUser), isFalse);
    });

    testWidgets('DashboardQuickActionsCard hides Aksi Cepat for institution users', (
      WidgetTester tester,
    ) async {
      final instUser = UserModel(
        id: 'inst-3',
        name: 'SMK Negeri 1',
        username: 'smkn1',
        email: 'smkn1@kreavana.id',
        role: 'user',
        subRole: 'institution',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: DashboardQuickActionsCard(
                isInstitution: DashboardScreen.isInstitutionUser(instUser),
                actions: const [
                  {'icon': Icons.work_outline, 'label': 'Program & Magang'},
                ],
                isDark: false,
                onTapAction: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Aksi Cepat'), findsNothing);
      expect(find.text('Program & Magang'), findsNothing);
    });

    testWidgets('DashboardQuickActionsCard renders Aksi Cepat for corporate users', (
      WidgetTester tester,
    ) async {
      final corporateUser = UserModel(
        id: 'corp-3',
        name: 'PT Kreavana Korporat',
        username: 'corp_demo',
        email: 'corp3@kreavana.id',
        role: 'user',
        subRole: 'corporate',
      );
      String? tapped;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 340,
              child: DashboardQuickActionsCard(
                isInstitution: DashboardScreen.isInstitutionUser(corporateUser),
                actions: const [
                  {'icon': Icons.work_outline, 'label': 'Lowongan'},
                ],
                isDark: false,
                onTapAction: (label) => tapped = label,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Aksi Cepat'), findsOneWidget);
      expect(find.text('Lowongan'), findsOneWidget);

      await tester.tap(find.text('Lowongan'));
      expect(tapped, equals('Lowongan'));
    });
  });
}
