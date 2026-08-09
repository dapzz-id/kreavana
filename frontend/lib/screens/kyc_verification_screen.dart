import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:kreavana/app/theme.dart';
import 'package:kreavana/screens/kyc_liveness_screen.dart';
import 'package:kreavana/services/kyc_service.dart';

/// Full-screen KYC verification flow.
///
/// Steps: 1) Session init → 2) Liveness detection → 3) Capture KTP & Selfie
/// → 4) Upload → 5) Face match → 6) Poll & show result.
class KycVerificationScreen extends StatefulWidget {
  const KycVerificationScreen({super.key});

  @override
  State<KycVerificationScreen> createState() => _KycVerificationScreenState();
}

class _KycVerificationScreenState extends State<KycVerificationScreen> {
  final KycService _kycService = KycService();

  bool _livenessBlinkDetected = false;
  bool _livenessSmileDetected = false;
  File? _ktpFile;
  File? _selfieFile;

  @override
  void initState() {
    super.initState();
    _startFlow();
  }

  @override
  void dispose() {
    _kycService.stateNotifier.dispose();
    super.dispose();
  }

  // --- Flow orchestration -------------------------------------------------

  Future<void> _startFlow() async {
    // 14.2 — Session initialisation
    final sessionOk = await _kycService.initSession();
    if (!sessionOk) return;
    // Now waiting in livenessDetection step — UI will show liveness screen.
  }

  void _onLivenessComplete(bool isLive) async {
    if (!isLive) {
      _kycService.stateNotifier.value = _kycService.state.copyWith(
        step: KycFlowStep.failed,
        errorMessage: 'Liveness check failed',
      );
      return;
    }

    // 14.3 — Submit liveness result to backend
    await _kycService.submitLivenessResult(
      blinkDetected: _livenessBlinkDetected,
      smileDetected: _livenessSmileDetected,
    );
  }

  Future<void> _captureKtp() async {
    final cameras = await availableCameras();
    if (!mounted) return;

    final result = await Navigator.push<XFile>(
      context,
      MaterialPageRoute(
        builder: (_) => _CaptureImageScreen(
          cameras: cameras,
          title: 'Foto KTP',
          instruction: 'Posisikan KTP di dalam bingkai',
          useFrontCamera: false,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() => _ktpFile = File(result.path));
      // If selfie also captured, start upload
      if (_selfieFile != null) {
        _startUploadAndMatch();
      }
    }
  }

  Future<void> _captureSelfie() async {
    final cameras = await availableCameras();
    if (!mounted) return;

    final result = await Navigator.push<XFile>(
      context,
      MaterialPageRoute(
        builder: (_) => _CaptureImageScreen(
          cameras: cameras,
          title: 'Foto Selfie',
          instruction: 'Posisikan wajah Anda di dalam bingkai',
          useFrontCamera: true,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() => _selfieFile = File(result.path));
      if (_ktpFile != null) {
        _startUploadAndMatch();
      }
    }
  }

  // 15.7 — Compress image before upload
  Future<File> _compressImage(File file) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return file;

    // Resize to max 1024px on the longest side
    final resized = img.copyResize(decoded,
        width: decoded.width > decoded.height ? 1024 : null,
        height: decoded.height >= decoded.width ? 1024 : null);

    final compressed = img.encodeJpg(resized, quality: 80);
    final compressedFile = File('${file.path}_compressed.jpg');
    await compressedFile.writeAsBytes(compressed);
    return compressedFile;
  }

  Future<void> _startUploadAndMatch() async {
    if (_ktpFile == null || _selfieFile == null) return;

    // 14.4 — Upload (with compression first)
    final compressedKtp = await _compressImage(_ktpFile!);
    final compressedSelfie = await _compressImage(_selfieFile!);

    final uploadOk = await _kycService.uploadImages(
      ktpFile: compressedKtp,
      selfieFile: compressedSelfie,
    );
    if (!uploadOk) return;

    // 14.5 — Face match
    final matchOk = await _kycService.initiateFaceMatch();
    if (!matchOk) return;

    // 14.6 — Poll for result
    await _kycService.pollUntilComplete();
  }

  // --- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifikasi KYC'),
        centerTitle: true,
      ),
      body: ValueListenableBuilder<KycFlowState>(
        valueListenable: _kycService.stateNotifier,
        builder: (context, flowState, _) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildStepContent(flowState, isDark),
          );
        },
      ),
    );
  }

  Widget _buildStepContent(KycFlowState flowState, bool isDark) {
    switch (flowState.step) {
      case KycFlowStep.idle:
      case KycFlowStep.initializingSession:
        return _buildLoading('Memulai sesi verifikasi…');

      case KycFlowStep.livenessDetection:
        return KycLivenessScreen(
          onVerificationComplete: (isLive) {
            _livenessBlinkDetected = true;
            _livenessSmileDetected = true;
            _onLivenessComplete(isLive);
          },
        );

      case KycFlowStep.uploadingImages:
        if (_ktpFile == null || _selfieFile == null) {
          return _buildImageCaptureStep(isDark);
        }
        return _buildUploadProgress(flowState);

      case KycFlowStep.matchingFaces:
        return _buildLoading('Memulai pencocokan wajah…');

      case KycFlowStep.pollingResult:
        return _buildLoading('Menunggu hasil verifikasi…');

      case KycFlowStep.completed:
        return _buildResult(flowState, isDark);

      case KycFlowStep.failed:
        return _buildError(flowState, isDark);
    }
  }

  // 14.9 — Loading indicators
  Widget _buildLoading(String message) {
    return Center(
      key: ValueKey(message),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text(message, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildImageCaptureStep(bool isDark) {
    return Padding(
      key: const ValueKey('capture'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ambil Foto',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ambil foto KTP dan selfie Anda untuk verifikasi.',
            style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight),
          ),
          const SizedBox(height: 32),

          // KTP card
          _buildCaptureCard(
            icon: Icons.credit_card,
            label: 'Foto KTP',
            file: _ktpFile,
            onTap: _captureKtp,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Selfie card
          _buildCaptureCard(
            icon: Icons.face,
            label: 'Foto Selfie',
            file: _selfieFile,
            onTap: _captureSelfie,
            isDark: isDark,
          ),
          const Spacer(),

          if (_ktpFile != null && _selfieFile != null)
            FilledButton.icon(
              onPressed: _startUploadAndMatch,
              icon: const Icon(Icons.upload),
              label: const Text('Mulai Verifikasi'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.primaryPurple,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCaptureCard({
    required IconData icon,
    required String label,
    required File? file,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: file != null
                ? Colors.green.shade400
                : (isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: file != null ? Colors.green : AppTheme.primaryPurple),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                file != null ? '$label ✓' : label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: file != null ? Colors.green : null,
                ),
              ),
            ),
            Icon(
              file != null ? Icons.check_circle : Icons.camera_alt,
              color: file != null ? Colors.green : AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  // 13.5 / 14.9 — Upload progress
  Widget _buildUploadProgress(KycFlowState flowState) {
    final pct = (flowState.uploadProgress * 100).toStringAsFixed(0);
    return Center(
      key: const ValueKey('upload'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: flowState.uploadProgress,
              strokeWidth: 6,
              color: AppTheme.primaryPurple,
              backgroundColor: AppTheme.inputBorder,
            ),
          ),
          const SizedBox(height: 24),
          Text('Mengunggah gambar… $pct%', style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  // 14.7 — Similarity score & verification status
  Widget _buildResult(KycFlowState flowState, bool isDark) {
    final isApproved = flowState.status == 'approved';
    return Padding(
      key: const ValueKey('result'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isApproved ? Icons.verified : Icons.cancel,
            size: 80,
            color: isApproved ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 24),
          Text(
            isApproved ? 'Verifikasi Berhasil' : 'Verifikasi Gagal',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isApproved ? Colors.green : Colors.red,
                ),
          ),
          if (flowState.similarityScore != null) ...[
            const SizedBox(height: 12),
            Text(
              'Skor Kecocokan: ${flowState.similarityScore!.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
              ),
            ),
          ],
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(isApproved),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              backgroundColor: AppTheme.primaryPurple,
            ),
            child: const Text('Kembali'),
          ),
        ],
      ),
    );
  }

  // 14.8 / 14.10 — Error handling & error UI
  Widget _buildError(KycFlowState flowState, bool isDark) {
    return Padding(
      key: const ValueKey('error'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            'Terjadi Kesalahan',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            flowState.errorMessage ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Batal'),
              ),
              const SizedBox(width: 16),
              FilledButton(
                onPressed: () {
                  _kycService.reset();
                  setState(() {
                    _ktpFile = null;
                    _selfieFile = null;
                  });
                  _startFlow();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                ),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Simple camera capture screen used for KTP / Selfie
// ---------------------------------------------------------------------------

class _CaptureImageScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String title;
  final String instruction;
  final bool useFrontCamera;

  const _CaptureImageScreen({
    required this.cameras,
    required this.title,
    required this.instruction,
    this.useFrontCamera = false,
  });

  @override
  State<_CaptureImageScreen> createState() => _CaptureImageScreenState();
}

class _CaptureImageScreenState extends State<_CaptureImageScreen> {
  CameraController? _controller;
  bool _isTaking = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final camera = widget.cameras.firstWhere(
      (c) => c.lensDirection ==
          (widget.useFrontCamera
              ? CameraLensDirection.front
              : CameraLensDirection.back),
      orElse: () => widget.cameras.first,
    );

    _controller = CameraController(camera, ResolutionPreset.high, enableAudio: false);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_isTaking || _controller == null || !_controller!.value.isInitialized) return;
    _isTaking = true;

    final xFile = await _controller!.takePicture();
    if (mounted) Navigator.pop(context, xFile);
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Text(
              widget.instruction,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _takePicture,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: Colors.white24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
