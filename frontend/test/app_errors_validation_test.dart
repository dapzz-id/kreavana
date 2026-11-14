import 'package:flutter_test/flutter_test.dart';
import 'package:kreavana/utils/app_errors.dart';

void main() {
  test('AppErrors formats raw validation.unique correctly for email and username', () {
    final res1 = {
      'status': false,
      'message': 'validation.unique',
      'errors': {
        'email': ['validation.unique'],
      },
    };
    expect(
      AppErrors.messageFromResult(res1),
      'Alamat email ini sudah terdaftar. Silakan gunakan email lain atau masuk ke akun Anda.',
    );

    final res2 = {
      'status': false,
      'message': 'validation.unique',
      'errors': {
        'username': ['validation.unique'],
      },
    };
    expect(
      AppErrors.messageFromResult(res2),
      'Username ini sudah digunakan. Silakan pilih username lain.',
    );

    final res3 = {
      'status': false,
      'message': 'validation.unique',
    };
    expect(
      AppErrors.messageFromResult(res3),
      'Data ini sudah terdaftar. Silakan gunakan data lain atau masuk.',
    );

    final res4 = {
      'message': 'The given data was invalid.',
      'errors': {
        'email': ['The email has already been taken.'],
      },
    };
    expect(
      AppErrors.messageFromResult(res4),
      'Alamat email ini sudah terdaftar. Silakan gunakan email lain atau masuk ke akun Anda.',
    );
  });
}
