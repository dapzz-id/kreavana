import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class KtpCameraView extends StatefulWidget {
  final Function(String imagePath) onImageCaptured;
  final VoidCallback onCancel;

  const KtpCameraView({
    super.key,
    required this.onImageCaptured,
    required this.onCancel,
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
    // Request camera permission
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _errorMessage = 'Izin kamera diperlukan untuk mengambil foto KTP';
      });
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _errorMessage = 'Tidak ada kamera yang tersedia';
        });
        return;
      }

      // Use back camera
      final backCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      // Set focus mode to auto
      await _controller!.setFocusMode(FocusMode.auto);
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal menginisialisasi kamera: $e';
      });
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Ambil Foto KTP'),
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
    final scale = 1.0;

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
        // KTP frame overlay
        _buildKtpFrameOverlay(size),
        // Guidance text
        _buildGuidanceText(size),
        // Capture button
        _buildCaptureButton(size),
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

            // 2. Middle section (Kunci tinggi total section ini sebesar frameHeight)
            SizedBox(
              height: frameHeight,
              child: Row(
                children: [
                  // Left overlay
                  Container(
                    width: (size.width - frameWidth) / 2,
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                  // Clear area for KTP (Sekarang tingginya akan pas!)
                  Container(
                    width: frameWidth,
                    height: frameHeight,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      clipBehavior:
                          Clip.none, // Agar marker corner tidak terpotong
                      children: [
                        // Corner markers (Menggunakan penyesuaian posisi agar pas di sudut)
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

            // 3. Bottom overlay (Sisanya otomatis menutup ke bawah)
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
    return Positioned(
      top: size.height * 0.15,
      left: 0,
      right: 0,
      child: const Column(
        children: [
          Text(
            'Posisikan KTP dalam bingkai',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Pastikan semua teks terbaca jelas',
            style: TextStyle(color: Colors.white70, fontSize: 14),
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
