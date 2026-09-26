import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class KtpCameraView extends StatefulWidget {
  final Function(String imagePath) onImageCaptured;
  final VoidCallback onCancel;
  final String? title;
  final bool isFrontCamera;

  const KtpCameraView({
    super.key,
    required this.onImageCaptured,
    required this.onCancel,
    this.title,
    this.isFrontCamera = false,
  });

  @override
  State<KtpCameraView> createState() => _KtpCameraViewState();
}

class _KtpCameraViewState extends State<KtpCameraView> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // Request camera permission on native platforms
    if (!kIsWeb) {
      try {
        final status = await Permission.camera.request();
        if (!status.isGranted) {
          setState(() {
            _errorMessage = 'Izin kamera diperlukan untuk mengambil foto';
          });
          return;
        }
      } catch (e) {
        debugPrint('Camera permission check skipped: $e');
      }
    }

    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _errorMessage = 'Tidak ada kamera yang tersedia';
        });
        return;
      }

      // Choose camera based on direction
      final targetDirection = widget.isFrontCamera
          ? CameraLensDirection.front
          : CameraLensDirection.back;

      final selectedCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == targetDirection,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      // Set focus mode to auto if supported (camera_web throws UnimplementedError)
      try {
        await _controller!.setFocusMode(FocusMode.auto);
      } catch (e) {
        debugPrint('setFocusMode not supported on this platform: $e');
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal menginisialisasi kamera: $e';
        });
      }
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final image = await _controller!.takePicture();
      if (mounted) {
        widget.onImageCaptured(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengambil foto: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageTitle = widget.title ?? (widget.isFrontCamera ? 'Ambil Foto Selfie' : 'Ambil Foto KTP');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(pageTitle),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.close), onPressed: widget.onCancel),
        ],
      ),
      body: _errorMessage != null
          ? _buildErrorView()
          : !_isInitialized
          ? _buildLoadingView()
          : _buildCameraView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: widget.onCancel,
              child: const Text('Kembali'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }

  Widget _buildCameraView() {
    final size = MediaQuery.of(context).size;
    const scale = 1.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        Center(
          child: Transform.scale(
            scale: scale,
            child: CameraPreview(_controller!),
          ),
        ),
        // Frame overlay (KTP frame for back camera, oval/guide for selfie)
        if (!widget.isFrontCamera)
          _buildKtpFrameOverlay(size)
        else
          _buildSelfieFrameOverlay(size),
        // Guidance text
        _buildGuidanceText(size),
        // Capture button
        _buildCaptureButton(size),
      ],
    );
  }

  Widget _buildSelfieFrameOverlay(Size size) {
    final frameWidth = size.width * 0.75;
    final frameHeight = frameWidth * 1.3;
    final frameTop = size.height * 0.20;

    return Stack(
      children: [
        Column(
          children: [
            Container(
              height: frameTop,
              color: Colors.black.withValues(alpha: 0.35),
            ),
            SizedBox(
              height: frameHeight,
              child: Row(
                children: [
                  Container(
                    width: (size.width - frameWidth) / 2,
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                  Container(
                    width: frameWidth,
                    height: frameHeight,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  Container(
                    width: (size.width - frameWidth) / 2,
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(color: Colors.black.withValues(alpha: 0.35)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKtpFrameOverlay(Size size) {
    final frameWidth = size.width * 0.85;
    final frameHeight = frameWidth / 1.585; // KTP aspect ratio
    final frameTop = size.height * 0.25;

    return Stack(
      children: [
        Column(
          children: [
            // 1. Top overlay
            Container(
              height: frameTop,
              color: Colors.black.withValues(alpha: 0.3),
            ),

            // 2. Middle section
            SizedBox(
              height: frameHeight,
              child: Row(
                children: [
                  // Left overlay
                  Container(
                    width: (size.width - frameWidth) / 2,
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                  // Clear area for KTP
                  Container(
                    width: frameWidth,
                    height: frameHeight,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _buildCornerMarker(-2, -2, 0),
                        _buildCornerMarker(frameWidth - 28, -2, 90),
                        _buildCornerMarker(
                          frameWidth - 28,
                          frameHeight - 28,
                          180,
                        ),
                        _buildCornerMarker(-2, frameHeight - 28, 270),
                      ],
                    ),
                  ),
                  // Right overlay
                  Container(
                    width: (size.width - frameWidth) / 2,
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),

            // 3. Bottom overlay
            Expanded(
              child: Container(color: Colors.black.withValues(alpha: 0.3)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCornerMarker(double x, double y, double rotation) {
    return Positioned(
      left: x,
      top: y,
      child: Transform.rotate(
        angle: rotation * 3.14159 / 180,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue, width: 4),
          ),
        ),
      ),
    );
  }

  Widget _buildGuidanceText(Size size) {
    final titleText = widget.isFrontCamera
        ? 'Posisikan wajah & KTP terlihat jelas'
        : 'Posisikan KTP dalam bingkai';
    final subText = widget.isFrontCamera
        ? 'Pegang KTP Anda dan pastikan wajah tidak tertutup'
        : 'Pastikan semua teks terbaca jelas';

    return Positioned(
      top: size.height * 0.12,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Text(
            titleText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subText,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureButton(Size size) {
    return Positioned(
      bottom: size.height * 0.1,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: _isProcessing ? null : _takePicture,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              color: _isProcessing ? Colors.grey : Colors.transparent,
            ),
            child: _isProcessing
                ? const Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : Container(
                    margin: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
