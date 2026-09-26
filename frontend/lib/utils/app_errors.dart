import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../widgets/app_sweet_alert.dart';

import 'package:dio/dio.dart';

/// Standar error helper: maps any exception/result-map to a friendly message.
class AppErrors {
  AppErrors._();

  /// Masking logic to prevent raw backend errors from leaking
  static String _sanitizeMessage(
    String rawMsg, {
    String fallback = 'Terjadi kesalahan internal pada server.',
  }) {
    final lowerMsg = rawMsg.toLowerCase();
    if (lowerMsg.contains('sqlstate') ||
        lowerMsg.contains('exception') ||
        lowerMsg.contains('stack trace:') ||
        lowerMsg.contains('mysql') ||
        lowerMsg.contains('connection refused') ||
        lowerMsg.contains('syntax error')) {
      return fallback;
    }
    return rawMsg;
  }

  /// Extracts a user-friendly message from a result map (service pattern).
  static String messageFromResult(
    Map<String, dynamic> result, {
    String fallback = 'Terjadi kesalahan. Silakan coba lagi.',
    int? statusCode,
  }) {
    // HTTP Status overrides
    if (statusCode == 401) {
      return 'Email atau kata sandi yang Anda masukkan salah.';
    }
    if (statusCode == 403) {
      return 'Anda tidak memiliki izin untuk mengakses sumber ini.';
    }
    if (statusCode == 404) {
      return 'Sumber data tidak ditemukan.';
    }
    if (statusCode == 422) {
      return 'Data yang dikirimkan tidak valid. Periksa kembali form Anda.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'Terjadi kesalahan internal pada server. Coba lagi nanti.';
    }

    final raw = result['message'] ?? result['error'] ?? result['msg'];
    if (raw is String && raw.trim().isNotEmpty) {
      return _sanitizeMessage(raw.trim(), fallback: fallback);
    }
    return fallback;
  }

  /// Extracts a friendly message from any caught [error] object.
  static String friendly(
    Object? error, {
    String fallback = 'Terjadi kesalahan. Silakan coba lagi.',
  }) {
    if (error == null) return fallback;

    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) {
        return 'Autentikasi gagal. Silakan masuk kembali.';
      }
      if (statusCode == 403) {
        return 'Anda tidak memiliki izin untuk mengakses sumber ini.';
      }
      if (statusCode == 404) {
        return 'Sumber data tidak ditemukan.';
      }
      if (statusCode == 422) {
        return 'Validasi data gagal. Periksa masukan Anda.';
      }
      if (statusCode != null && statusCode >= 500) {
        return 'Terjadi kesalahan internal pada server.';
      }

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'Koneksi terputus (Timeout). Periksa internet Anda.';
      }

      if (error.response?.data is Map<String, dynamic>) {
        return messageFromResult(
          error.response!.data as Map<String, dynamic>,
          fallback: fallback,
          statusCode: statusCode,
        );
      }
    }

    if (error is SocketException || error is HttpException) {
      return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
    }
    if (error is FormatException) {
      return 'Data yang diterima tidak valid dari server.';
    }
    if (error is String) {
      return error.isNotEmpty
          ? _sanitizeMessage(error, fallback: fallback)
          : fallback;
    }
    if (error is Map) {
      return messageFromResult(
        Map<String, dynamic>.from(error),
        fallback: fallback,
      );
    }

    final msg = error
        .toString()
        .replaceAll('Exception: ', '')
        .replaceAll('DioException:', '');
    if (msg.isEmpty) return fallback;
    if (msg.length > 200) return fallback;

    return _sanitizeMessage(msg, fallback: fallback);
  }
}

/// Konsisten alert feedback untuk sukses/error/info.
/// Di Web & Desktop, otomatis menampilkan SweetAlert Toast di pojok kanan atas.
class AppSnackbar {
  AppSnackbar._();

  static void success(BuildContext context, String message, {String? title}) {
    if (kIsWeb || MediaQuery.of(context).size.width >= 600) {
      AppSweetAlert.success(context, message, title: title);
      return;
    }
    _show(context, message, AppTheme.success, title: title);
  }

  static void error(BuildContext context, String message, {String? title}) {
    if (kIsWeb || MediaQuery.of(context).size.width >= 600) {
      AppSweetAlert.error(context, message, title: title);
      return;
    }
    _show(context, message, AppTheme.error, title: title);
  }

  static void info(BuildContext context, String message, {String? title}) {
    if (kIsWeb || MediaQuery.of(context).size.width >= 600) {
      AppSweetAlert.info(context, message, title: title);
      return;
    }
    _show(context, message, AppTheme.info, title: title);
  }

  static void warning(BuildContext context, String message, {String? title}) {
    if (kIsWeb || MediaQuery.of(context).size.width >= 600) {
      AppSweetAlert.warning(context, message, title: title);
      return;
    }
    _show(context, message, const Color(0xFFF59E0B), title: title);
  }

  static void _show(BuildContext context, String message, Color color, {String? title}) {
    try {
      AppSweetAlert.show(
        context: context,
        message: message,
        title: title,
        type: color == AppTheme.success
            ? SweetAlertType.success
            : color == AppTheme.error
                ? SweetAlertType.error
                : color == const Color(0xFFF59E0B)
                    ? SweetAlertType.warning
                    : SweetAlertType.info,
      );
    } catch (_) {
      // Fallback to standard ScaffoldMessenger if overlay is unavailable
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  color == AppTheme.success
                      ? Icons.check_circle_rounded
                      : color == AppTheme.error
                          ? Icons.error_rounded
                          : Icons.info_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: color,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
    }
  }
}
