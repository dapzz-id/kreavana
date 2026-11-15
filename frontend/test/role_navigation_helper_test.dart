import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kreavana/models/user_model.dart';
import 'package:kreavana/services/dio_client.dart';
import 'package:kreavana/services/system_settings_service.dart';
import 'package:kreavana/widgets/custom_bottom_nav_bar.dart';
import 'package:kreavana/widgets/desktop_sidebar_layout.dart';
import 'package:kreavana/widgets/kreavana_ai_floating_widget.dart';
import 'package:kreavana/widgets/role_navigation_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_secure_storage.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    DioClient.instance.setStorageForTesting(FakeSecureStorage());
  });

  setUp(() {
    SystemSettingsService.moduleStatuses.value = {
      'direct_message_enabled': true,
      'voice_call_enabled': true,
      'video_call_enabled': true,
      'ai_features_enabled': true,
      'marketplace_enabled': true,
      'collaboration_enabled': true,
      'opportunities_enabled': true,
      'wallet_enabled': true,
      'client_verification_enabled': true,
      'user_registration_enabled': true,
      'creator_registration_enabled': true,
      'maintenance_mode': false,
    };
  });

  UserModel makeUser({
    String id = 'u-1',
    String name = 'Test User',
    String username = 'test_user',
    String email = 'test@kreavana.id',
    String role = 'user',
    String? subRole,
    String? institutionRole,
    List<String> institutionPermissions = const [],
  }) {
    return UserModel(
      id: id,
      name: name,
      username: username,
      email: email,
      role: role,
      subRole: subRole,
      institutionRole: institutionRole,
      institutionPermissions: institutionPermissions,
    );
  }

  group('RoleNavigationHelper.getMobileBottomNavDestinations', () {
    test('Institution admin gets Beranda, Magang, Proyek, Pesan, Menu (no Jelajahi)', () {
      final schoolAdmin = makeUser(
        name: 'SMK Telesandi',
        username: 'smk_telesandi',
        email: 'smk@kreavana.id',
        role: 'institution',
        subRole: 'school',
      );

      final dests = RoleNavigationHelper.getMobileBottomNavDestinations(
        schoolAdmin,
        unreadMessages: 3,
      );

      expect(dests.length, 5);
      expect(dests.map((d) => d.routeKey).toList(), [
        'beranda',
        'program_magang',
        'proyek_saya',
        'pesan',
        'menu',
      ]);
      expect(dests.any((d) => d.routeKey == 'explore'), isFalse);
      expect(dests[3].badgeCount, 3);
      expect(dests.last.isMenuTrigger, isTrue);
    });

    test('Institution staff bottom nav respects granular RBAC permissions', () {
      final schoolStaff = makeUser(
        name: 'Staf Kurikulum',
        username: 'staff_kurikulum',
        email: 'staff@smk.sch.id',
        role: 'institution',
        subRole: 'institution',
        institutionRole: 'staff',
        institutionPermissions: const ['karya_siswa', 'dokumen_institusi'],
      );

      final dests = RoleNavigationHelper.getMobileBottomNavDestinations(schoolStaff);

      expect(dests.map((d) => d.routeKey).toList(), [
        'beranda',
        'karya_siswa',
        'dokumen_instansi',
        'pesan',
        'menu',
      ]);
      expect(dests.any((d) => d.routeKey == 'program_magang'), isFalse);
      expect(dests.any((d) => d.routeKey == 'proyek_saya'), isFalse);
    });

    test('Corporate user gets Beranda, Lowongan, Proyek, Pesan, Menu (no Jelajahi)', () {
      final corporate = makeUser(
        name: 'PT Kreavana Studio',
        username: 'corp_demo',
        role: 'user',
        subRole: 'company',
      );

      final dests = RoleNavigationHelper.getMobileBottomNavDestinations(corporate);

      expect(dests.map((d) => d.routeKey).toList(), [
        'beranda',
        'lowongan_magang',
        'proyek_saya',
        'pesan',
        'menu',
      ]);
      expect(dests.any((d) => d.routeKey == 'explore'), isFalse);
    });

    test('Government user gets Beranda, Program, Tender, Pesan, Menu', () {
      final gov = makeUser(
        name: 'Dinas Pariwisata',
        username: 'dispar_id',
        role: 'government',
        subRole: 'government',
      );

      final dests = RoleNavigationHelper.getMobileBottomNavDestinations(gov);

      expect(dests.map((d) => d.routeKey).toList(), [
        'beranda',
        'proyek_saya',
        'tender_kolaborasi',
        'pesan',
        'menu',
      ]);
    });

    test('Admin user gets 5 admin tabs including unread notifications badge', () {
      final admin = makeUser(
        name: 'Admin Kreavana',
        username: 'admin',
        role: 'admin',
      );

      final dests = RoleNavigationHelper.getMobileBottomNavDestinations(
        admin,
        unreadNotifications: 7,
      );

      expect(dests.length, 5);
      expect(dests.map((d) => d.routeKey).toList(), [
        'admin_dashboard',
        'admin_verification',
        'admin_resolution',
        'admin_notifications',
        'menu',
      ]);
      expect(dests[3].mainNavIndex, 4);
      expect(dests[3].badgeCount, 7);
    });

    test('Creator, Client, and Guest each receive their role-appropriate bottom tabs', () {
      final creator = makeUser(role: 'creator', subRole: 'fotografer');
      final client = makeUser(role: 'user', subRole: 'personal');
      final guest = makeUser(id: 'guest', role: 'guest');

      expect(
        RoleNavigationHelper.getMobileBottomNavDestinations(creator)
            .map((d) => d.routeKey)
            .toList(),
        ['beranda', 'explore', 'proyek_saya', 'pesan', 'menu'],
      );
      expect(
        RoleNavigationHelper.getMobileBottomNavDestinations(client)
            .map((d) => d.routeKey)
            .toList(),
        ['beranda', 'marketplace', 'proyek_saya', 'pesan', 'menu'],
      );
      expect(
        RoleNavigationHelper.getMobileBottomNavDestinations(guest)
            .map((d) => d.routeKey)
            .toList(),
        ['beranda', 'explore', 'marketplace', 'peluang_proyek', 'menu'],
      );
    });

    test('Falls back cleanly when Direct Message module is disabled', () {
      SystemSettingsService.moduleStatuses.value = {
        ...SystemSettingsService.moduleStatuses.value,
        'direct_message_enabled': false,
      };

      final schoolAdmin = makeUser(role: 'institution', subRole: 'school');
      final corporate = makeUser(role: 'user', subRole: 'corporate');

      expect(
        RoleNavigationHelper.getMobileBottomNavDestinations(schoolAdmin)
            .map((d) => d.routeKey)
            .toList(),
        ['beranda', 'program_magang', 'proyek_saya', 'profil_instansi', 'menu'],
      );
      expect(
        RoleNavigationHelper.getMobileBottomNavDestinations(corporate)
            .map((d) => d.routeKey)
            .toList(),
        ['beranda', 'lowongan_magang', 'proyek_saya', 'tender_kolaborasi', 'menu'],
      );
    });
  });

  group('RoleNavigationHelper.resolveActiveBottomNavIndex & FAB rules', () {
    test('Returns matching index via routeKey, alias, or mainNavIndex, and -1 for Drawer-only routes', () {
      final school = makeUser(role: 'institution', subRole: 'school');
      final schoolDests = RoleNavigationHelper.getMobileBottomNavDestinations(school);

      expect(
        RoleNavigationHelper.resolveActiveBottomNavIndex(schoolDests, 'program-magang'),
        1,
      );
      expect(
        RoleNavigationHelper.resolveActiveBottomNavIndex(schoolDests, 'proyek_saya'),
        2,
      );
      expect(
        RoleNavigationHelper.resolveActiveBottomNavIndex(schoolDests, 'profil_instansi'),
        -1,
      );
      expect(
        RoleNavigationHelper.resolveActiveBottomNavIndex(schoolDests, 'tim_hak_akses'),
        -1,
      );
      expect(
        RoleNavigationHelper.resolveActiveBottomNavIndex(
          schoolDests,
          'anything',
          mainNavIndex: 8,
        ),
        -1,
      );

      final admin = makeUser(role: 'admin');
      final adminDests = RoleNavigationHelper.getMobileBottomNavDestinations(admin);
      expect(
        RoleNavigationHelper.resolveActiveBottomNavIndex(
          adminDests,
          'notifications',
          mainNavIndex: 4,
        ),
        3,
      );
    });

    test('routeHasPageFab identifies mobile FAB routes accurately per role', () {
      final creator = makeUser(role: 'creator', subRole: 'videografer');
      final client = makeUser(role: 'user', subRole: 'personal');

      expect(RoleNavigationHelper.routeHasPageFab(client, 'proyek_saya'), isTrue);
      expect(RoleNavigationHelper.routeHasPageFab(client, 'program_magang'), isTrue);
      expect(RoleNavigationHelper.routeHasPageFab(client, 'pesan'), isTrue);
      expect(RoleNavigationHelper.routeHasPageFab(creator, 'kolaborasi'), isTrue);
      expect(RoleNavigationHelper.routeHasPageFab(client, 'kolaborasi'), isFalse);
      expect(RoleNavigationHelper.routeHasPageFab(client, 'tim_hak_akses'), isFalse);
    });
  });

  group('RoleNavigationHelper.getRoleMenuSections Desktop parity', () {
    test('Institution admin Drawer matches full desktop sections without explore', () {
      final schoolAdmin = makeUser(
        role: 'institution',
        subRole: 'school',
        institutionRole: 'admin',
      );

      final sections = RoleNavigationHelper.getRoleMenuSections(schoolAdmin);
      final titles = sections.map((s) => s.title).toList();
      final allRouteKeys = sections.expand((s) => s.items).map((e) => e.routeKey).toList();

      expect(titles, [null, 'PENGELOLAAN INSTITUSI', 'DATA & DOKUMEN', 'PENGATURAN']);
      expect(allRouteKeys, contains('program_magang'));
      expect(allRouteKeys, contains('mitra_komunitas'));
      expect(allRouteKeys, contains('karya_siswa'));
      final labels = sections.expand((s) => s.items).map((e) => e.label).toList();
      expect(labels, contains('Karya & Portofolio Peserta'));
      expect(labels, isNot(contains('Karya & Portofolio Siswa')));
      expect(allRouteKeys, contains('dokumen_instansi'));
      expect(allRouteKeys, contains('profil_instansi'));
      expect(allRouteKeys, contains('profil_akun'));
      expect(allRouteKeys, contains('tim_hak_akses'));
      expect(allRouteKeys, contains('pembayaran'));
      expect(allRouteKeys, isNot(contains('explore')));
    });

    test('Institution staff Drawer enforces granular RBAC permissions', () {
      final staff = makeUser(
        role: 'institution',
        subRole: 'school',
        institutionRole: 'staff',
        institutionPermissions: const ['program_magang'],
      );

      final sections = RoleNavigationHelper.getRoleMenuSections(staff);
      final titles = sections.map((s) => s.title).toList();
      final allRouteKeys = sections.expand((s) => s.items).map((e) => e.routeKey).toList();

      expect(titles, [null, 'PENGELOLAAN INSTITUSI', 'PENGATURAN']);
      expect(allRouteKeys, contains('program_magang'));
      expect(allRouteKeys, contains('profil_akun'));
      expect(allRouteKeys, contains('pengaturan'));
      expect(allRouteKeys, isNot(contains('karya_siswa')));
      expect(allRouteKeys, isNot(contains('dokumen_instansi')));
      expect(allRouteKeys, isNot(contains('profil_instansi')));
      expect(allRouteKeys, isNot(contains('tim_hak_akses')));
    });

    test('Corporate Drawer includes B2B section and excludes Rekomendasi Peluang', () {
      final corporate = makeUser(role: 'user', subRole: 'corporate');

      final sections = RoleNavigationHelper.getRoleMenuSections(corporate);
      final titles = sections.map((s) => s.title).toList();
      final allRouteKeys = sections.expand((s) => s.items).map((e) => e.routeKey).toList();

      expect(titles, [null, 'MANAJEMEN BISNIS B2B']);
      expect(allRouteKeys, containsAll(['lowongan_magang', 'tender_kolaborasi', 'mitra_komunitas']));
      expect(allRouteKeys, isNot(contains('explore')));
    });
  });

  group('Mobile shell & Drawer widget layout at 390x844', () {
    testWidgets(
      'DesktopSidebarLayout renders mobile bottom nav, cleared AI widget above FAB, and opens Role Drawer',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final schoolAdmin = makeUser(
          name: 'SMK Telesandi Bekasi',
          username: 'smk_telesandi',
          role: 'institution',
          subRole: 'school',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: DesktopSidebarLayout(
              user: schoolAdmin,
              activeRoute: 'proyek_saya',
              child: Scaffold(
                body: const Center(child: Text('Konten Proyek Saya')),
                floatingActionButton: FloatingActionButton.extended(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text('Buat Kebutuhan'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(CustomBottomNavBar), findsOneWidget);
        expect(find.byType(KreavanaAiFloatingWidget), findsOneWidget);

        // Institution bottom nav shows desktop-aligned items instead of Jelajahi
        expect(find.text('Beranda'), findsOneWidget);
        expect(find.text('Magang'), findsOneWidget);
        expect(find.text('Proyek'), findsOneWidget);
        expect(find.text('Pesan'), findsOneWidget);
        expect(find.text('Menu'), findsOneWidget);
        expect(find.text('Jelajahi'), findsNothing);

        // Kreavana AI floating pill sits clear above the FAB & bottom nav bar
        final aiRect = tester.getRect(find.byType(KreavanaAiFloatingWidget));
        final fabRect = tester.getRect(find.byType(FloatingActionButton));
        final navRect = tester.getRect(find.byType(CustomBottomNavBar));

        expect(aiRect.overlaps(fabRect), isFalse);
        expect(aiRect.overlaps(navRect), isFalse);
        expect(aiRect.bottom <= fabRect.top, isTrue);

        // Tapping 'Menu' opens full desktop-parity Drawer
        await tester.tap(find.text('Menu'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(Drawer), findsOneWidget);
        expect(find.text('Institusi Pendidikan'), findsOneWidget);
        expect(find.text('Dompet & Pembayaran'), findsOneWidget);
        expect(find.text('PENGELOLAAN INSTITUSI'), findsOneWidget);
        expect(find.text('Karya & Portofolio Peserta'), findsOneWidget);
        expect(find.text('Program & Magang'), findsOneWidget);

        await tester.drag(find.byType(ListView).first, const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(find.text('Tim & Hak Akses'), findsOneWidget);
      },
    );

    testWidgets(
      'RoleNavigationHelper.buildMobileDrawer and CustomBottomNavBar render cleanly with currentIndex: -1',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final corporate = makeUser(
          name: 'PT Kreavana Maju',
          username: 'kreavana_corp',
          role: 'user',
          subRole: 'company',
        );
        final dests = RoleNavigationHelper.getMobileBottomNavDestinations(corporate);

        final scaffoldKey = GlobalKey<ScaffoldState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                key: scaffoldKey,
                body: const SizedBox.shrink(),
                drawer: RoleNavigationHelper.buildMobileDrawer(
                  context: ctx,
                  user: corporate,
                  activeRoute: 'pengaturan',
                  unreadMessages: 2,
                  onSelectEntry: (_) {},
                  onOpenUpgrade: () {},
                  onOpenProfile: () {},
                  onLogout: () {},
                ),
                bottomNavigationBar: CustomBottomNavBar(
                  currentIndex: -1,
                  onTap: (_) {},
                  items: dests.map((d) => d.toBottomNavItem()).toList(),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(CustomBottomNavBar), findsOneWidget);

        scaffoldKey.currentState?.openDrawer();
        await tester.pumpAndSettle();

        expect(find.text('Corporate / B2B'), findsOneWidget);
        expect(find.text('MANAJEMEN BISNIS B2B'), findsOneWidget);
        expect(find.text('Lowongan Kerja & Magang'), findsOneWidget);
        expect(find.text('Rekomendasi Peluang'), findsNothing);
      },
    );
  });
}
