import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kreavana/services/kyc_dio_client.dart';
import 'package:kreavana/services/s3_upload_service.dart';

/// Represents the current step in the KYC flow.
enum KycFlowStep {
  idle,
  initializingSession,
  livenessDetection,
  uploadingImages,
  matchingFaces,
  pollingResult,
  completed,
  failed,
}

/// Holds the full state of an in-progress KYC verification.
class KycFlowState {
  final KycFlowStep step;
  final String? transactionId;
  final String? errorMessage;
  final double uploadProgress;
  final String? status; // pending / processing / approved / rejected / failed
  final double? similarityScore;
  final String? completedAt;

  KycFlowState({
    this.step = KycFlowStep.idle,
    this.transactionId,
    this.errorMessage,
    this.uploadProgress = 0,
    this.status,
    this.similarityScore,
    this.completedAt,
  });

  KycFlowState copyWith({
    KycFlowStep? step,
    String? transactionId,
    String? errorMessage,
    double? uploadProgress,
    String? status,
    double? similarityScore,
    String? completedAt,
  }) {
    return KycFlowState(
      step: step ?? this.step,
      transactionId: transactionId ?? this.transactionId,
      errorMessage: errorMessage,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      status: status ?? this.status,
      similarityScore: similarityScore ?? this.similarityScore,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

/// Orchestrates the entire KYC verification flow using the dedicated KYC
/// Dio client and S3 upload service.
class KycService {
  final KycDioClient _kycDio = KycDioClient.instance;
  final S3UploadService _s3UploadService = S3UploadService();

  final ValueNotifier<KycFlowState> stateNotifier =
      ValueNotifier(KycFlowState());

  KycFlowState get state => stateNotifier.value;

  void _emit(KycFlowState newState) {
    stateNotifier.value = newState;
  }

  // --- 14.2 Session initialisation ----------------------------------------

  Future<bool> initSession() async {
    _emit(state.copyWith(step: KycFlowStep.initializingSession));
    try {
      final response = await _kycDio.dio.post('/v1/kyc/session');

      if (response.statusCode == 201) {
        final txId = response.data['transaction_id'] as String;
        _emit(state.copyWith(
          step: KycFlowStep.livenessDetection,
          transactionId: txId,
          status: 'pending',
        ));
        return true;
      }

      _emit(state.copyWith(
        step: KycFlowStep.failed,
        errorMessage: response.data['error'] ?? 'Session initialization failed',
      ));
      return false;
    } catch (e) {
      _emit(state.copyWith(
        step: KycFlowStep.failed,
        errorMessage: _friendlyError(e),
      ));
      return false;
    }
  }

  // --- 14.3 Liveness verification -----------------------------------------

  Future<bool> submitLivenessResult({
    required bool blinkDetected,
    required bool smileDetected,
  }) async {
    try {
      final response = await _kycDio.dio.post('/v1/kyc/liveness/verify', data: {
        'transaction_id': state.transactionId,
        'blink_detected': blinkDetected,
        'smile_detected': smileDetected,
      });

      if (response.statusCode == 200) {
        final passed = response.data['liveness_passed'] == true;
        if (passed) {
          _emit(state.copyWith(step: KycFlowStep.uploadingImages));
        } else {
          _emit(state.copyWith(
            step: KycFlowStep.failed,
            errorMessage: 'Liveness check failed — please try again',
          ));
        }
        return passed;
      }

      _emit(state.copyWith(
        step: KycFlowStep.failed,
        errorMessage: 'Liveness verification request failed',
      ));
      return false;
    } catch (e) {
      _emit(state.copyWith(
        step: KycFlowStep.failed,
        errorMessage: _friendlyError(e),
      ));
      return false;
    }
  }

  // --- 14.4 Direct S3 upload ----------------------------------------------

  Future<bool> uploadImages({
    required File ktpFile,
    required File selfieFile,
  }) async {
    _emit(state.copyWith(step: KycFlowStep.uploadingImages, uploadProgress: 0));

    final urls = await _s3UploadService.getUploadUrls(state.transactionId!);
    if (urls == null) {
      _emit(state.copyWith(
        step: KycFlowStep.failed,
        errorMessage: 'Failed to get upload URLs',
      ));
      return false;
    }

    final result = await _s3UploadService.uploadImagesParallel(
      transactionId: state.transactionId!,
      ktpUrl: urls['ktp_upload_url']!,
      ktpFile: ktpFile,
      ktpKey: urls['ktp_key']!,
      selfieUrl: urls['selfie_upload_url']!,
      selfieFile: selfieFile,
      selfieKey: urls['selfie_key']!,
      onOverallProgress: (progress) {
        _emit(state.copyWith(uploadProgress: progress));
      },
    );

    if (result.success) {
      _emit(state.copyWith(step: KycFlowStep.matchingFaces));
      return true;
    }

    _emit(state.copyWith(
      step: KycFlowStep.failed,
      errorMessage: result.errorMessage ?? 'Image upload failed',
    ));
    return false;
  }

  // --- 14.5 Face match job initiation -------------------------------------

  Future<bool> initiateFaceMatch() async {
    _emit(state.copyWith(step: KycFlowStep.matchingFaces));

    try {
      final response = await _kycDio.dio.post('/v1/kyc/face-match', data: {
        'transaction_id': state.transactionId,
        's3_ktp_uri': _s3UploadService.lastKtpKey,
        's3_selfie_uri': _s3UploadService.lastSelfieKey,
      });

      if (response.statusCode == 202 || response.statusCode == 200) {
        _emit(state.copyWith(step: KycFlowStep.pollingResult, status: 'processing'));
        return true;
      }

      _emit(state.copyWith(
        step: KycFlowStep.failed,
        errorMessage: response.data['error'] ?? 'Face match initiation failed',
      ));
      return false;
    } catch (e) {
      _emit(state.copyWith(
        step: KycFlowStep.failed,
        errorMessage: _friendlyError(e),
      ));
      return false;
    }
  }

  // --- 14.6 Status polling ------------------------------------------------

  Future<void> pollUntilComplete({
    Duration interval = const Duration(seconds: 2),
    int maxAttempts = 30,
  }) async {
    _emit(state.copyWith(step: KycFlowStep.pollingResult));

    for (int i = 0; i < maxAttempts; i++) {
      try {
        final response = await _kycDio.dio.get(
          '/v1/kyc/status/${state.transactionId}',
        );

        if (response.statusCode == 200) {
          final status = response.data['status'] as String?;

          if (status == 'approved' || status == 'rejected' || status == 'failed') {
            _emit(state.copyWith(
              step: KycFlowStep.completed,
              status: status,
              similarityScore: (response.data['similarity_score'] as num?)?.toDouble(),
              completedAt: response.data['completed_at'] as String?,
            ));
            return;
          }
        }
      } catch (_) {
        // Silently handle polling error
      }

      await Future.delayed(interval);
    }

    // Timed out
    _emit(state.copyWith(
      step: KycFlowStep.failed,
      errorMessage: 'Verification timed out — please check back later',
    ));
  }

  // --- Helpers ------------------------------------------------------------

  void reset() {
    _emit(KycFlowState());
  }

  String _friendlyError(Object e) {
    if (e is DioException) {
      if (e.response?.statusCode == 429) {
        return 'Daily KYC attempt limit exceeded';
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Request timed out — please try again';
      }
      return e.response?.data?['error'] ?? 'Network error';
    }
    return 'An unexpected error occurred';
  }
}
