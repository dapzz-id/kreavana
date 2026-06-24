import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/call_service.dart';
import '../screens/call_screen.dart';

class GlobalCallOverlay extends StatefulWidget {
  const GlobalCallOverlay({super.key});

  @override
  State<GlobalCallOverlay> createState() => _GlobalCallOverlayState();
}

class _GlobalCallOverlayState extends State<GlobalCallOverlay> {
  Offset _position = const Offset(20, 100);

  @override
  void initState() {
    super.initState();
    CallService().addListener(_onCallStateChanged);
  }

  @override
  void dispose() {
    CallService().removeListener(_onCallStateChanged);
    super.dispose();
  }

  void _onCallStateChanged() {
    if (mounted) setState(() {});
  }

  void _maximizeCall() {
    final callService = CallService();
    callService.maximizeCall();
    
    // Push the CallScreen again without destroying the service
    if (callService.currentCallId != null && callService.remoteUserId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CallScreen(
            callService: callService,
            remoteUserName: callService.incomingCallerName,
            remoteAvatarUrl: callService.incomingCallerAvatar,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final callService = CallService();

    // Only show In-App overlay if minimized, and we are NOT on Android
    // (Android uses Native PiP, so it doesn't need this overlay)
    bool useNativePip = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    
    if (!callService.isMinimized || !callService.isConnected || useNativePip) {
      return const SizedBox.shrink();
    }

    final isVideo = callService.isVideoCall;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
        },
        onTap: _maximizeCall,
        child: Material(
          color: Colors.transparent,
          elevation: 8,
          borderRadius: BorderRadius.circular(isVideo ? 12 : 30),
          child: Container(
            width: isVideo ? 120 : 180,
            height: isVideo ? 160 : 60,
            decoration: BoxDecoration(
              color: isVideo ? Colors.black : Colors.green.shade700,
              borderRadius: BorderRadius.circular(isVideo ? 12 : 30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: isVideo
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      RTCVideoView(
                        callService.remoteRenderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: const Icon(Icons.open_in_full, color: Colors.white, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _maximizeCall,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const Icon(Icons.call, color: Colors.white),
                      Text(
                        _formatDuration(callService.callDurationSeconds),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.call_end, color: Colors.redAccent),
                        onPressed: () {
                          callService.endCall();
                        },
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
