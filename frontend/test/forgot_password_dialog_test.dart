import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kreavana/features/auth/screens/login_screen.dart';
import 'package:kreavana/services/dio_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_secure_storage.dart';

class _MockAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;
  _MockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}

void main() {
  late HttpClientAdapter originalAdapter;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    DioClient.instance.setStorageForTesting(FakeSecureStorage());
    originalAdapter = DioClient.instance.dio.httpClientAdapter;
  });

  tearDown(() {
    DioClient.instance.dio.httpClientAdapter = originalAdapter;
  });

  testWidgets(
    'Forgot password dialog sends real API requests, surfaces API error instead of fake success, and resets password',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool shouldFailRequest = true;
      Map<String, dynamic>? resetPayload;

      DioClient.instance.dio.httpClientAdapter = _MockAdapter((options) async {
        final path = options.uri.path;
        if (path.endsWith('/auth/forgot-password')) {
          if (shouldFailRequest) {
            return _jsonResponse({
              'status': false,
              'message': 'Layanan autentikasi sedang sibuk.',
            }, statusCode: 503);
          }
          return _jsonResponse({
            'status': true,
            'message': 'Kode reset 6 digit dikirim ke email Anda.',
          });
        }
        if (path.endsWith('/auth/reset-password')) {
          resetPayload = Map<String, dynamic>.from(options.data as Map);
          return _jsonResponse({
            'status': true,
            'message': 'Kata sandi berhasil diperbarui.',
          });
        }
        return _jsonResponse({'status': true, 'data': []});
      });

      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lupa kata sandi?'));
      await tester.pumpAndSettle();

      expect(find.text('Reset Kata Sandi'), findsOneWidget);

      // Submit while server returns 503 -> must stay open and show real error
      await tester.enterText(
        find.widgetWithText(TextField, 'Alamat Email'),
        'user@kreavana.id',
      );
      await tester.tap(find.text('Kirim Kode'));
      await tester.pumpAndSettle();

      expect(find.text('Reset Kata Sandi'), findsOneWidget);
      expect(find.textContaining('sibuk'), findsOneWidget);

      // Retry with working backend -> moves to Step 2 (OTP + Password)
      shouldFailRequest = false;
      await tester.tap(find.text('Kirim Kode'));
      await tester.pumpAndSettle();

      expect(find.text('Verifikasi Kode & Sandi Baru'), findsOneWidget);
      expect(find.text('Simpan Kata Sandi'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Kode Verifikasi (6 Digit)'),
        '482910',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Kata Sandi Baru (Min. 8 karakter)'),
        'NewPass123!',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Konfirmasi Kata Sandi Baru'),
        'NewPass123!',
      );
      await tester.tap(find.text('Simpan Kata Sandi'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 350));

      expect(resetPayload?['email'], 'user@kreavana.id');
      expect(resetPayload?['code'], '482910');
      expect(resetPayload?['password'], 'NewPass123!');
      expect(resetPayload?['password_confirmation'], 'NewPass123!');
      expect(find.text('Verifikasi Kode & Sandi Baru'), findsNothing);
      expect(find.text('Kata Sandi Diperbarui'), findsOneWidget);

      await tester.pumpAndSettle();
    },
  );
}
