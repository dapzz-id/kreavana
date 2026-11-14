import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../widgets/app_sweet_alert.dart';

import 'package:dio/dio.dart';

/// Standar error helper: maps any exception/result-map to a friendly message.
class AppErrors {
  AppErrors._();

  static String _friendlyFieldName(String field) {
    switch (field.toLowerCase().trim()) {
      case 'email':
        return 'Alamat email';
      case 'username':
        return 'Username';
      case 'name':
      case 'full_name':
        return 'Nama lengkap';
      case 'password':
        return 'Kata sandi';
      case 'password_confirmation':
        return 'Konfirmasi kata sandi';
      case 'phone':
        return 'Nomor telepon';
      default:
        return field;
    }
  }

  /// Convert raw validation keys or English validation errors into clear Indonesian descriptions.
  static String _humanizeValidationString(String raw, [String? field]) {
    final lower = raw.toLowerCase().trim();
    final fLabel = field != null ? _friendlyFieldName(field) : null;

    if (lower.contains('validation.unique') ||
        lower.contains('already been taken') ||
        lower.contains('has already been taken')) {
      if (field == 'email' || lower.contains('email')) {
        return 'Alamat email ini sudah terdaftar. Silakan gunakan email lain atau masuk ke akun Anda.';
      }
      if (field == 'username' || lower.contains('username')) {
        return 'Username ini sudah digunakan. Silakan pilih username lain.';
      }
      if (field == 'phone' || lower.contains('phone') || lower.contains('telepon')) {
        return 'Nomor telepon ini sudah terdaftar.';
      }
      return fLabel != null
          ? '$fLabel ini sudah digunakan. Silakan gunakan data lain.'
          : 'Data ini sudah terdaftar. Silakan gunakan data lain atau masuk.';
    }

    if (lower.contains('validation.required')) {
      return fLabel != null ? '$fLabel wajib diisi.' : 'Mohon lengkapi semua kolom yang wajib diisi.';
    }

    if (lower.contains('validation.email')) {
      return 'Format alamat email tidak valid.';
    }

    if (lower.contains('validation.min') || lower.contains('too short')) {
      return fLabel != null ? '$fLabel terlalu pendek.' : 'Isian terlalu pendek.';
    }

    if (lower.contains('validation.confirmed') ||
        lower.contains('confirmation does not match')) {
      return 'Konfirmasi kata sandi tidak cocok.';
    }

    if (lower == 'the given data was invalid.') {
      return 'Data yang dimasukkan tidak valid. Periksa kembali form Anda.';
    }

    return _sanitizeMessage(raw);
  }

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
    // 1. First, check detailed validation errors map
    final errors = result['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final List<String> errorList = [];
      errors.forEach((key, val) {
        final fieldName = key.toString();
        if (val is List && val.isNotEmpty) {
          for (final item in val) {
            if (item != null && item.toString().trim().isNotEmpty) {
              errorList.add(_humanizeValidationString(item.toString().trim(), fieldName));
            }
          }
        } else if (val is String && val.trim().isNotEmpty) {
          errorList.add(_humanizeValidationString(val.trim(), fieldName));
        }
      });

      if (errorList.isNotEmpty) {
        return errorList.first;
      }
    }

    // 2. HTTP Status overrides (when no specific validation errors map was found)
    if (statusCode == 401) {
      return 'Email atau kata sandi yang Anda masukkan salah.';
    }
    if (statusCode == 403) {
      return 'Anda tidak memiliki izin untuk mengakses sumber ini.';
    }
    if (statusCode == 404) {
      return 'Sumber data tidak ditemukan.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'Terjadi kesalahan internal pada server. Coba lagi nanti.';
    }

    // 3. Fall back to message/error/msg
    final raw = result['message'] ?? result['error'] ?? result['msg'];
    if (raw is String && raw.trim().isNotEmpty) {
      final humanized = _humanizeValidationString(raw.trim());
      if (humanized.isNotEmpty && humanized != 'Terjadi kesalahan internal pada server.') {
        return humanized;
      }
    }

    if (statusCode == 422) {
      return 'Data yang dikirimkan tidak valid. Periksa kembali form Anda.';
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
