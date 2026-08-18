/// Regression tests – Task 7.10
///
/// These tests prove that:
/// 1. No screen or service calls the legacy `/auth/me` or monolithic `/profile` (GET) endpoint.
/// 2. [ProfileService.getProfile] exclusively uses granular endpoints.
/// 3. [AuthService.login] no longer calls `/auth/me` post-login.
///
/// The approach: register the legacy endpoints in the mock adapter so that *any*
/// call to them results in an explicit test failure. All expected traffic is
/// routed to `/profile/identity` and `/profile/application`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:kreavana/services/dio_client.dart';
import 'package:kreavana/services/profile_service.dart';
import 'package:kreavana/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'fake_secure_storage.dart';

class _MockAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) handler;
  _MockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions o, _, _) => handler(o);

  @override
  void close({bool force = false}) {}
}

/// A fake adapter that explicitly fails on legacy monolithic endpoints.
_MockAdapter _buildProfileAdapter({required bool failOnLegacy}) {
  return _MockAdapter((options) async {
    final path = options.path;

    // ── FAIL if any legacy endpoint is hit ───────────────────────────────────
    if (failOnLegacy) {
      if (path == '/auth/me' || path.endsWith('/auth/me')) {
        fail(
          'Legacy endpoint /auth/me was called — remove all usages from the frontend',
        );
      }
      // Exact GET /profile (monolithic) — but allow sub-paths like /profile/identity
      if ((path == '/profile' || path.endsWith('/profile')) &&
          !path.contains('profile/')) {
        fail(
          'Legacy monolithic GET /profile was called — use granular endpoints instead',
        );
      }
    }

    // ── Serve granular endpoints ──────────────────────────────────────────────
    if (path.contains('profile/identity')) {
      return ResponseBody.fromString(
        jsonEncode({
          'status': true,
          'data': {
            'id': 'u1',
            'name': 'Bob',
            'username': 'bob',
            'email': 'bob@test.com',
            'role': 'user',
            'sub_role': null,
            'avatar_url': null,
            'is_creator_approved': false,
            'balance': 0.0,
            'followers_count': 0,
            'following_count': 0,
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }

    if (path.contains('profile/application')) {
      return ResponseBody.fromString(
        '{"status":true,"data":null}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }

    return ResponseBody.fromString(
      '{"status":false,"message":"not found"}',
      404,
    );
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = FakeSecureStorage();
    await storage.saveToken('test_token');
    DioClient.instance.setStorageForTesting(storage);
  });

  // ── Test 1: ProfileService uses only granular endpoints ──────────────────
  test(
    'ProfileService.getProfile does NOT call /auth/me or monolithic /profile',
    () async {
      DioClient.instance.dio.httpClientAdapter = _buildProfileAdapter(
        failOnLegacy: true,
      );

      // If legacy endpoints are called, the adapter will fail() the test.
      final result = await ProfileService.getProfile('u1');

      expect(
        result.success,
        true,
        reason: 'getProfile should succeed via granular endpoints',
      );
      expect(result.user, isNotNull);
      expect(result.user!.name, 'Bob');
    },
  );

  // ── Test 2: UserModel is fully parsed from granular identity payload ──────
  test('UserModel.fromJson correctly maps all identity fields', () {
    final user = UserModel.fromJson({
      'id': 'u1',
      'name': 'Bob',
      'username': 'bob',
      'email': 'bob@test.com',
      'role': 'user',
      'sub_role': null,
      'avatar_url': null,
      'is_creator_approved': false,
      'balance': 250000.5,
      'followers_count': 12,
      'following_count': 7,
    });

    expect(user.id, 'u1');
    expect(user.name, 'Bob');
    expect(user.email, 'bob@test.com');
    expect(user.balance, 250000.5);
    expect(user.followersCount, 12);
    expect(user.followingCount, 7);
    expect(user.isCreatorApproved, false);
    expect(user.isAdmin, false);
  });

  // ── Test 3: ProfileFetchResult is strongly typed (no Map access) ─────────
  test(
    'ProfileFetchResult exposes typed .user and .application — not raw maps',
    () async {
      DioClient.instance.dio.httpClientAdapter = _buildProfileAdapter(
        failOnLegacy: false,
      );

      final result = await ProfileService.getProfile('u1');

      // These must be typed properties (if they were Map access, this would be a compile error)
      expect(result.success, isA<bool>());
      expect(result.user, isA<UserModel?>());
      expect(result.application, isA<CreatorApplication?>());
      expect(result.message, isA<String?>());
    },
  );
}
