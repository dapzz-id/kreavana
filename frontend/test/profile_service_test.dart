import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:kreavana/services/dio_client.dart';
import 'package:kreavana/services/profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'fake_secure_storage.dart';

class MockAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onRequest;
  MockAdapter(this.onRequest);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      onRequest(options);

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Dio dio;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = FakeSecureStorage();
    await storage.saveToken('test_token');
    DioClient.instance.setStorageForTesting(storage);

    dio = DioClient.instance.dio;
    dio.httpClientAdapter = MockAdapter((options) async {
      if (options.path.contains('profile/identity')) {
        return ResponseBody.fromString(
          jsonEncode({
            'status': true,
            'data': {
              'id': 'user-123',
              'name': 'Test User',
              'username': 'testuser',
              'email': 'test@test.com',
              'role': 'creator',
              'sub_role': 'photographer',
              'avatar_url': null,
              'is_creator_approved': true,
              'balance': 50000.0,
              'followers_count': 10,
              'following_count': 5,
            }
          }),
          200,
          headers: {Headers.contentTypeHeader: ['application/json']},
        );
      }

      if (options.path.contains('profile/application')) {
        return ResponseBody.fromString(
          jsonEncode({
            'status': true,
            'data': {
              'id': 'app-123',
              'user_id': 'user-123',
              'status': 'approved',
              'sub_role_category': 'photographer',
              'skill_description': 'Expert photographer',
              'portfolio_link': null,
            }
          }),
          200,
          headers: {Headers.contentTypeHeader: ['application/json']},
        );
      }

      return ResponseBody.fromString('{"status":false}', 404);
    });
  });

  test('getProfile fetches identity and application concurrently, returns typed result', () async {
    final result = await ProfileService.getProfile('user-123');

    expect(result.success, true, reason: 'should succeed when both endpoints succeed');

    final user = result.user;
    expect(user, isNotNull);
    expect(user!.id, 'user-123');
    expect(user.name, 'Test User');
    expect(user.role, 'creator');
    expect(user.balance, 50000.0);
    expect(user.followersCount, 10);
    expect(user.followingCount, 5);
    expect(user.isCreatorApproved, true);

    final app = result.application;
    expect(app, isNotNull);
    expect(app!.status, 'approved');
  });

  test('getProfile fails gracefully when identity endpoint returns error', () async {
    dio.httpClientAdapter = MockAdapter((options) async {
      if (options.path.contains('profile/identity')) {
        return ResponseBody.fromString(
          '{"status":false,"message":"Token not valid"}',
          401,
          headers: {Headers.contentTypeHeader: ['application/json']},
        );
      }
      return ResponseBody.fromString('{}', 404);
    });

    final result = await ProfileService.getProfile('user-123');

    expect(result.success, false);
    expect(result.user, isNull);
    expect(result.message, isNotNull);
  });
}
