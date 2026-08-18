import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:kreavana/services/liveness_detection_service.dart';

class KycLivenessScreen extends StatefulWidget {
  final Function(bool isLive) onVerificationComplete;

  const KycLivenessScreen({super.key, required this.onVerificationComplete});

  @override
  State<KycLivenessScreen> createState() => _KycLivenessScreenState();
}

class _KycLivenessScreenState extends State<KycLivenessScreen> {
  CameraController? _cameraController;
  final LivenessDetectionService _livenessService = LivenessDetectionService();
  bool _isProcessing = false;
  String _instructionMessage = "Please position your face in the frame";
  bool _hasCameraPermissionError = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _livenessService.generateNewChallenge();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21, // Better for Android ML Kit
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {});
        _startImageStream();
      }
    } catch (e) {
      setState(() {
        _hasCameraPermissionError = true;
      });
    }
  }

  void _startImageStream() {
    _cameraController?.startImageStream((CameraImage image) async {
      if (_isProcessing) return;
      _isProcessing = true;

      try {
        final WriteBuffer allBytes = WriteBuffer();
        for (final Plane plane in image.planes) {
          allBytes.putUint8List(plane.bytes);
        }
        final bytes = allBytes.done().buffer.asUint8List();

        final Size imageSize = Size(
          image.width.toDouble(),
          image.height.toDouble(),
        );

        final camera = _cameraController!.description;
        final imageRotation =
            InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
            InputImageRotation.rotation0deg;

        final inputImageFormat =
            InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.nv21;

        final inputImageData = InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes[0].bytesPerRow,
        );

        final inputImage = InputImage.fromBytes(
          bytes: bytes,
          metadata: inputImageData,
        );

        final result = await _livenessService.processCameraImage(inputImage);

        if (result != null) {
          if (mounted) {
            setState(() {
              _instructionMessage = result.message ?? "";
            });

            if (result.isLive) {
              _cameraController?.stopImageStream();
              widget.onVerificationComplete(true);
            }
          }
        }
      } catch (_) {
        // Silently swallow frame processing error
      } finally {
        _isProcessing = false;
      }
    });
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _livenessService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasCameraPermissionError) {
      return const Center(
        child: Text("Camera permission denied or camera not available."),
      );
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          // Overlay for face outline
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 4),
                shape: BoxShape.circle,
              ),
              margin: const EdgeInsets.all(40),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _instructionMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
