import 'package:flutter_test/flutter_test.dart';
import 'package:kreavana/models/user_model.dart';

void main() {
  group('UserModel Corporate & KTP Verification Tests', () {
    test('corporate subrole is recognized as isCorporate', () {
      final user = UserModel(
        id: 'corp-1',
        name: 'PT Kreavana Nusantara Korporat',
        username: 'corporate_demo',
        email: 'corporate@kreavana.id',
        role: 'user',
        subRole: 'corporate',
      );

      expect(user.isCorporate, isTrue);
      // Corporate is automatically considered verified for client features without KTP
      expect(user.isClientVerified, isTrue);
    });

    test('regular client without verification is not verified and not corporate', () {
      final client = UserModel(
        id: 'client-1',
        name: 'Regular Client',
        username: 'regular_client',
        email: 'client@example.com',
        role: 'user',
        subRole: null,
        isVerified: false,
      );

      expect(client.isCorporate, isFalse);
      expect(client.isClientVerified, isFalse);
    });

    test('regular client with isVerified = true is verified', () {
      final client = UserModel(
        id: 'client-2',
        name: 'Verified Client',
        username: 'verified_client',
        email: 'client2@example.com',
        role: 'user',
        subRole: null,
        isVerified: true,
      );

      expect(client.isCorporate, isFalse);
      expect(client.isClientVerified, isTrue);
    });

    test('various company sub roles are recognized as corporate', () {
      for (final sub in ['corporate', 'company', 'business', 'perusahaan', 'bisnis', 'enterprise', 'b2b']) {
        final u = UserModel(
          id: 'test-$sub',
          name: 'Test Corp',
          username: 'test_$sub',
          email: 'test_$sub@corp.com',
          role: 'user',
          subRole: sub,
        );
        expect(u.isCorporate, isTrue, reason: 'Expected $sub to be corporate');
        expect(u.isClientVerified, isTrue);
      }
    });

    test('UserModel.fromJson automatically marks corporate accounts as isVerified', () {
      final json = {
        'id': 'corp-demo',
        'name': 'PT Kreavana Nusantara Korporat',
        'username': 'corporate_demo',
        'email': 'corporate@kreavana.id',
        'role': 'user',
        'sub_role': 'corporate',
        'is_verified': false,
      };

      final user = UserModel.fromJson(json);
      expect(user.isCorporate, isTrue);
      expect(user.isVerified, isTrue);
      expect(user.isClientVerified, isTrue);
      expect(user.verificationType, equals('corporate'));
    });
  });
}
