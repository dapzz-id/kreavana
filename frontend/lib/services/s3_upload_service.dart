import 'dart:io';
import 'package:dio/dio.dart';
import 'package:kreavana/services/kyc_dio_client.dart';

/// Result of an S3 upload operation, including the S3 key for later reference.
class S3UploadResult {
  final bool success;
  final String? ktpKey;
  final String? selfieKey;
  final String? errorMessage;

  S3UploadResult({
    required this.success,
    this.ktpKey,
    this.selfieKey,
    this.errorMessage,
  });
}

class S3UploadService {
  final KycDioClient _kycDioClient = KycDioClient.instance;
  static const int _maxRetries = 3;

  // 13.9 — Stored S3 URIs after successful upload
  String? _lastKtpKey;
  String? _lastSelfieKey;

  String? get lastKtpKey => _lastKtpKey;
  String? get lastSelfieKey => _lastSelfieKey;

  // 13.2 Implement pre-signed URL retrieval from microservice
  Future<Map<String, String>?> getUploadUrls(String transactionId) async {
    try {
      final response = await _kycDioClient.dio.post(
        '/v1/kyc/upload-url',
        data: {'transaction_id': transactionId},
      );

      if (response.statusCode == 200) {
        return {
          'ktp_upload_url': response.data['ktp_upload_url'],
          'selfie_upload_url': response.data['selfie_upload_url'],
          'ktp_key': response.data['ktp_key'],
          'selfie_key': response.data['selfie_key'],
        };
      }
      return null;
    } on DioException catch (_) {
      return null;
    }
  }

  // 13.7 Implement URL expiration refresh logic
  Future<Map<String, String>?> refreshUploadUrls(String transactionId) async {
    // Pre-signed URLs expire after 15 minutes. Re-request from the API.
    return getUploadUrls(transactionId);
  }

  // 13.3 Implement direct S3 upload using pre-signed URLs
  // 13.6 Add error handling for upload failures
  // 13.8 Add retry mechanism for failed uploads
  Future<bool> uploadToS3(
    String url,
    File file,
    Function(int sent, int total)? onProgress,
  ) async {
    final bytes = await file.readAsBytes();

    // Separate Dio instance for S3 — no auth interceptors that AWS would reject.
    final s3Dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final response = await s3Dio.put(
          url,
          data: Stream.fromIterable([bytes]),
          options: Options(
            headers: {
              'Content-Type': 'image/jpeg',
              'Content-Length': bytes.length,
            },
          ),
          onSendProgress: onProgress,
        );

        if (response.statusCode == 200) return true;
      } on DioException catch (e) {
        final isTimeout = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout;
        final isServerError =
            e.response != null && e.response!.statusCode! >= 500;

        if ((isTimeout || isServerError) && attempt < _maxRetries) {
          // Exponential back-off before retry
          await Future.delayed(Duration(milliseconds: 500 * attempt));
          continue;
        }

        // URL expired (403) — caller should refresh and retry
        if (e.response?.statusCode == 403) {
          return false;
        }

        return false;
      }
    }
    return false;
  }

  // 13.4 Implement parallel upload for KTP and Selfie images
  // 13.5 Add upload progress tracking UI (callback-driven)
  // 13.9 Store S3 URIs after successful upload
  Future<S3UploadResult> uploadImagesParallel({
    required String transactionId,
    required String ktpUrl,
    required File ktpFile,
    required String ktpKey,
    required String selfieUrl,
    required File selfieFile,
    required String selfieKey,
    Function(double overallProgress)? onOverallProgress,
  }) async {
    final totalBytes = ktpFile.lengthSync() + selfieFile.lengthSync();
    int ktpSent = 0;
    int selfieSent = 0;

    void updateProgress() {
      if (onOverallProgress != null && totalBytes > 0) {
        onOverallProgress((ktpSent + selfieSent) / totalBytes);
      }
    }

    // First attempt
    var results = await Future.wait([
      uploadToS3(ktpUrl, ktpFile, (sent, total) {
        ktpSent = sent;
        updateProgress();
      }),
      uploadToS3(selfieUrl, selfieFile, (sent, total) {
        selfieSent = sent;
        updateProgress();
      }),
    ]);

    // 13.7 — If either upload failed with a possible 403 (expired URL), refresh and retry once
    if (!results.every((r) => r)) {
      final refreshedUrls = await refreshUploadUrls(transactionId);
      if (refreshedUrls != null) {
        ktpSent = 0;
        selfieSent = 0;

        results = await Future.wait([
          if (!results[0])
            uploadToS3(
              refreshedUrls['ktp_upload_url']!,
              ktpFile,
              (sent, total) {
                ktpSent = sent;
                updateProgress();
              },
            )
          else
            Future.value(true),
          if (!results[1])
            uploadToS3(
              refreshedUrls['selfie_upload_url']!,
              selfieFile,
              (sent, total) {
                selfieSent = sent;
                updateProgress();
              },
            )
          else
            Future.value(true),
        ]);
      }
    }

    final allSuccess = results.every((r) => r);

    if (allSuccess) {
      // 13.9 Store S3 URIs after successful upload
      _lastKtpKey = ktpKey;
      _lastSelfieKey = selfieKey;
    }

    return S3UploadResult(
      success: allSuccess,
      ktpKey: allSuccess ? ktpKey : null,
      selfieKey: allSuccess ? selfieKey : null,
      errorMessage: allSuccess ? null : 'One or more uploads failed',
    );
  }
}
