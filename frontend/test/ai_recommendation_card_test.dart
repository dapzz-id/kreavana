import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kreavana/models/user_model.dart';
import 'package:kreavana/services/app_router.dart';
import 'package:kreavana/widgets/ai_recommendation_card.dart';

void main() {
  UserModel makeProUser() {
    return UserModel(
      id: 'user-pro-1',
      name: 'Budi Santoso',
      username: 'budi_pro',
      email: 'budi@kreavana.id',
      role: 'creator',
      subRole: 'videographer',
      subscriptionTier: 'pro',
    );
  }

  Widget wrapWithApp(Widget child, {Size surfaceSize = const Size(1280, 900)}) {
    return MediaQuery(
      data: MediaQueryData(size: surfaceSize),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets('Corporate tag chip renders between Semua and Photographer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrapWithApp(
        AiRecommendationCard(
          user: makeProUser(),
          role: 'creator',
          niche: 'Videografi',
        ),
      ),
    );
    await tester.pump();

    final semuaFinder = find.text('Semua');
    final corporateFinder = find.text('Corporate');
    final photographerFinder = find.text('Photographer');

    expect(semuaFinder, findsOneWidget);
    expect(corporateFinder, findsOneWidget);
    expect(photographerFinder, findsOneWidget);

    final semuaPos = tester.getTopLeft(semuaFinder);
    final corporatePos = tester.getTopLeft(corporateFinder);
    final photographerPos = tester.getTopLeft(photographerFinder);

    expect(corporatePos.dx, greaterThan(semuaPos.dx));
    expect(photographerPos.dx, greaterThan(corporatePos.dx));
  });

  testWidgets('Tapping Corporate updates CTA label and sends subRole corporate', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? sentSubRole;
    String? sentLocation;

    await tester.pumpWidget(
      wrapWithApp(
        AiRecommendationCard(
          user: makeProUser(),
          role: 'creator',
          niche: 'Kreatif',
          onFetchRecommendations: ({
            String? role,
            String? niche,
            String? subRole,
            String? location,
          }) async {
            sentSubRole = subRole;
            sentLocation = location;
            return {
              'status': true,
              'data': {
                'summary': 'Rekomendasi mitra Corporate berhasil dimuat.',
                'recommendations': [],
                'matched_items': [],
              },
            };
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Corporate'));
    await tester.pump();

    final ctaFinder = find.textContaining('Dapatkan Rekomendasi AI (Corporate');
    expect(ctaFinder, findsOneWidget);

    await tester.tap(ctaFinder);
    await tester.pumpAndSettle();

    expect(sentSubRole, equals('corporate'));
    expect(sentLocation, equals('Lokasi Sekarang'));
    expect(
      find.text('Rekomendasi mitra Corporate berhasil dimuat.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Clicking Dapatkan Rekomendasi AI renders summary, recommendations, and matched_items',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrapWithApp(
          AiRecommendationCard(
            user: makeProUser(),
            role: 'creator',
            niche: 'Fotografi',
            onFetchRecommendations: ({
              String? role,
              String? niche,
              String? subRole,
              String? location,
            }) async {
              return {
                'status': true,
                'data': {
                  'summary': 'Ditemukan mitra strategis di area Jakarta.',
                  'recommendations': [
                    {
                      'title': 'Penawaran Paket Company Profile Q4',
                      'category': 'Kemitraan Strategis',
                      'reason': 'Banyak perusahaan di Jakarta membutuhkan dokumentasi tahunan.',
                      'impact': 'Potensi Kontrak Rp 25 Juta',
                      'match_score': '97% Cocok',
                    },
                  ],
                  'matched_items': [
                    {
                      'id': 'corp-101',
                      'name': 'PT Kreasi Nusantara Tbk',
                      'type': 'user',
                      'sub_role': 'corporate',
                      'location': 'Jakarta Pusat, DKI Jakarta',
                    },
                    {
                      'id': 'opp-202',
                      'title': 'Kampanye Produk Q4 Corporate',
                      'type': 'opportunity',
                      'sub_role': 'corporate',
                      'location': 'Jakarta Selatan',
                    },
                  ],
                  'ai_provider': 'gemini',
                },
              };
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.textContaining('Dapatkan Rekomendasi AI'));
      await tester.pumpAndSettle();

      expect(
        find.text('Ditemukan mitra strategis di area Jakarta.'),
        findsOneWidget,
      );
      expect(find.text('Penawaran Paket Company Profile Q4'), findsOneWidget);
      expect(
        find.text(
          'Banyak perusahaan di Jakarta membutuhkan dokumentasi tahunan.',
        ),
        findsOneWidget,
      );
      expect(find.text('Kemitraan Strategis'), findsOneWidget);
      expect(find.text('Dampak: Potensi Kontrak Rp 25 Juta'), findsOneWidget);
      expect(find.text('PT Kreasi Nusantara Tbk'), findsOneWidget);
      expect(find.text('Jakarta Pusat, DKI Jakarta'), findsOneWidget);
      expect(find.text('Kampanye Produk Q4 Corporate'), findsOneWidget);
    },
  );

  testWidgets(
    'API failure or null response renders friendly error banner with Coba Lagi without raw SQL',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      int callCount = 0;

      await tester.pumpWidget(
        wrapWithApp(
          AiRecommendationCard(
            user: makeProUser(),
            role: 'creator',
            niche: 'Fotografi',
            onFetchRecommendations: ({
              String? role,
              String? niche,
              String? subRole,
              String? location,
            }) async {
              callCount++;
              if (callCount == 1) {
                return null;
              }
              if (callCount == 2) {
                return {
                  'status': false,
                  'message':
                      "SQLSTATE[42S22]: Column not found: 1054 Unknown column 'location'",
                };
              }
              return {
                'status': true,
                'data': {
                  'summary': 'Berhasil pulih setelah coba lagi.',
                  'recommendations': [],
                  'matched_items': [],
                },
              };
            },
          ),
        ),
      );
      await tester.pump();

      // Call 1: null response
      await tester.tap(find.textContaining('Dapatkan Rekomendasi AI'));
      await tester.pumpAndSettle();

      expect(find.text('Coba Lagi'), findsOneWidget);
      expect(find.textContaining('SQLSTATE'), findsNothing);

      // Call 2: retry yields raw SQLSTATE error message from backend -> must sanitize
      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();

      expect(callCount, equals(2));
      expect(find.text('Coba Lagi'), findsOneWidget);
      expect(find.textContaining('SQLSTATE'), findsNothing);

      // Call 3: retry succeeds
      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();

      expect(callCount, equals(3));
      expect(find.text('Berhasil pulih setelah coba lagi.'), findsOneWidget);
    },
  );

  testWidgets(
    'Selecting Seluruh Indonesia sends Seluruh Indonesia and Lihat navigates via GoRouter without crashing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? sentLocation;

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AiRecommendationCard(
                  user: makeProUser(),
                  role: 'creator',
                  niche: 'Kreatif',
                  onFetchRecommendations: ({
                    String? role,
                    String? niche,
                    String? subRole,
                    String? location,
                  }) async {
                    sentLocation = location;
                    return {
                      'status': true,
                      'data': {
                        'summary': 'Hasil nasional tersedia.',
                        'recommendations': [],
                        'matched_items': [
                          {
                            'id': 'corp-777',
                            'name': 'PT Media Nusantara',
                            'type': 'user',
                            'sub_role': 'corporate',
                            'location': 'Bandung',
                          },
                        ],
                      },
                    };
                  },
                ),
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.profil,
            builder: (context, state) => Scaffold(
              body: Text('Halaman Profil ${state.uri.queryParameters['id']}'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Open location menu from header selector and choose Seluruh Indonesia;
      // picking an option closes the modal and triggers _fetchRecommendations().
      await tester.tap(find.text('Lokasi Sekarang (GPS)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Seluruh Indonesia').last);
      await tester.pumpAndSettle();

      expect(sentLocation, equals('Seluruh Indonesia'));
      expect(find.text('Seluruh Indonesia'), findsOneWidget);
      expect(find.text('PT Media Nusantara'), findsOneWidget);

      await tester.tap(find.text('Lihat >').first);
      await tester.pumpAndSettle();

      expect(find.text('Halaman Profil corp-777'), findsOneWidget);
    },
  );
}
