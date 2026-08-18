import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum LivenessChallenge { smile, blink, turnHeadLeft, turnHeadRight }

class LivenessDetectionResult {
  final bool isLive;
  final String? message;
  final bool blinkDetected;
  final bool smileDetected;

  LivenessDetectionResult({
    required this.isLive,
    this.message,
    required this.blinkDetected,
    required this.smileDetected,
  });
}

class LivenessDetectionService {
  late final FaceDetector _faceDetector;
  bool _isProcessing = false;

  // State for anti-spoofing
  bool _hasSmiled = false;
  bool _hasBlinked = false;

  final _random = Random();
  LivenessChallenge? currentChallenge;

  LivenessDetectionService() {
    // 12.2 Implement face detection using Google ML Kit
    final options = FaceDetectorOptions(
      enableClassification: true, // For smile and blink detection
      enableTracking: true,
      enableContours: false,
      enableLandmarks: true, // For head turns if needed
      performanceMode: FaceDetectorMode.fast,
    );
    _faceDetector = FaceDetector(options: options);
  }

  // 12.5 Add random challenge generation
  void generateNewChallenge() {
    _hasSmiled = false;
    _hasBlinked = false;
    // For simplicity, just alternate between smile and blink or pick random
    final challenges = [LivenessChallenge.smile, LivenessChallenge.blink];
    currentChallenge = challenges[_random.nextInt(challenges.length)];
  }

  Future<void> dispose() async {
    await _faceDetector.close();
  }

  Future<LivenessDetectionResult?> processCameraImage(
    InputImage inputImage,
  ) async {
    if (_isProcessing) return null;
    _isProcessing = true;

    try {
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        return LivenessDetectionResult(
          isLive: false,
          message: "No face detected",
          blinkDetected: _hasBlinked,
          smileDetected: _hasSmiled,
        );
      }

      if (faces.length > 1) {
        return LivenessDetectionResult(
          isLive: false,
          message: "Multiple faces detected",
          blinkDetected: _hasBlinked,
          smileDetected: _hasSmiled,
        );
      }

      final face = faces.first;

      // 12.3 Implement blink detection logic
      if (face.leftEyeOpenProbability != null &&
          face.rightEyeOpenProbability != null) {
        final leftEyeOpen = face.leftEyeOpenProbability!;
        final rightEyeOpen = face.rightEyeOpenProbability!;

        // If both eyes are closed (probability < 0.2), consider it a blink
        if (leftEyeOpen < 0.2 && rightEyeOpen < 0.2) {
          _hasBlinked = true;
        }
      }

      // 12.4 Implement smile detection logic
      if (face.smilingProbability != null) {
        final smileProb = face.smilingProbability!;
        // If smiling probability > 0.7, consider it a smile
        if (smileProb > 0.7) {
          _hasSmiled = true;
        }
      }

      // Check against current challenge
      if (currentChallenge == LivenessChallenge.smile && _hasSmiled) {
        return LivenessDetectionResult(
          isLive: true,
          message: "Challenge passed",
          blinkDetected: _hasBlinked,
          smileDetected: _hasSmiled,
        );
      } else if (currentChallenge == LivenessChallenge.blink && _hasBlinked) {
        return LivenessDetectionResult(
          isLive: true,
          message: "Challenge passed",
          blinkDetected: _hasBlinked,
          smileDetected: _hasSmiled,
        );
      }

      return LivenessDetectionResult(
        isLive: false,
        message: _getChallengeInstruction(),
        blinkDetected: _hasBlinked,
        smileDetected: _hasSmiled,
      );
    } catch (e) {
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  String _getChallengeInstruction() {
    switch (currentChallenge) {
      case LivenessChallenge.smile:
        return "Please smile";
      case LivenessChallenge.blink:
        return "Please blink";
      case LivenessChallenge.turnHeadLeft:
        return "Turn head left";
      case LivenessChallenge.turnHeadRight:
        return "Turn head right";
      default:
        return "Look at the camera";
    }
  }
}
