import 'dart:io';
import 'package:flutter/material.dart';
import '../app/theme.dart';

/// Standar error helper: maps any exception/result-map to a friendly message.
class AppErrors {
  AppErrors._();

  /// Extracts a user-friendly message from a result map (service pattern).
  /// Falls back to a generic message.
  static String messageFromResult(Map<String, dynamic> result,
      {String fallback = 'Terjadi kesalahan. Silakan coba lagi.'}) {
    final raw = result['message'] ?? result['error'] ?? result['msg'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return fallback;
  }

  /// Extracts a friendly message from any caught [error] object.
  static String friendly(Object? error,
      {String fallback = 'Terjadi kesalahan. Silakan coba lagi.'}) {
    if (error == null) return fallback;
    if (error is String) return error.isNotEmpty ? error : fallback;
    if (error is SocketException || error is HttpException) {
      return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
    }
    if (error is FormatException) {
      return 'Data yang diterima tidak valid. Silakan coba lagi.';
    }
    if (error is Map) {
      return messageFromResult(Map<String, dynamic>.from(error), fallback: fallback);
    }
    final msg = error.toString().replaceAll('Exception: ', '').replaceAll('DioException:', '');
    if (msg.isEmpty) return fallback;
    return msg.length > 200 ? fallback : msg;
  }
}

/// Konsisten snackbar feedback untuk sukses/error/info.
class AppSnackbar {
  AppSnackbar._();

  static void success(BuildContext context, String message) {
    _show(context, message, AppTheme.success);
  }

  static void error(BuildContext context, String message) {
    _show(context, message, AppTheme.error);
  }

  static void info(BuildContext context, String message) {
    _show(context, message, AppTheme.info);
  }

  static void _show(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context)
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
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
  }
}
