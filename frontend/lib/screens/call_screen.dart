import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/call_service.dart';
import '../services/pip_factory.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallScreen extends StatefulWidget {
  final CallService callService;
  final String remoteUserName;
  final String remoteAvatarUrl;

  const CallScreen({
    Key? key,
    required this.callService,
    required this.remoteUserName,
    required this.remoteAvatarUrl,
  }) : super(key: key);

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    widget.callService.addListener(_onCallStateChanged);

    // On Android, enable auto-PiP when in a connected call
    _setupAutoPip();

    // Pulse animation for ringing state
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _setupAutoPip() async {
    final pip = getPipHandler();
    final isAvailable = await pip.isPipAvailable;
    if (isAvailable) {
      await pip.setAutoPipMode(
        aspectRatio: widget.callService.isVideoCall 
            ? (9, 16) // portrait video
            : (16, 9), // landscape for audio
      );
    }
  }

  Future<void> _disableAutoPip() async {
    final pip = getPipHandler();
    final isAvailable = await pip.isPipAvailable;
    if (isAvailable) {
      await pip.setAutoPipMode(autoEnter: false);
    }
  }

  void _onCallStateChanged() {
    if (mounted) {
      setState(() {});
      if (widget.callService.isEnded) {
        _disableAutoPip();
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
      // Stop pulse animation when connected
      if (widget.callService.isConnected && _pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
        // Re-enable auto PiP now that we're connected
        _setupAutoPip();
      }
    }
  }

  @override
  void dispose() {
    widget.callService.removeListener(_onCallStateChanged);
    widget.callService.disposeRenderers();
    _pulseController.dispose();
    super.dispose();
  }

  /// Minimize the call — on Android uses native PiP, on Web/iOS uses in-app overlay
  Future<void> _minimizeCall() async {
    final pip = getPipHandler();
    final isAvailable = await pip.isPipAvailable;
    if (isAvailable) {
      await pip.enterPipMode(
        aspectRatio: widget.callService.isVideoCall 
            ? (9, 16)
            : (16, 9),
      );
      return; // Don't pop — Android PiP keeps the Activity alive
    }

    // Web / iOS fallback: use in-app overlay
    widget.callService.minimizeCall();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  String _getStatusText() {
    final cs = widget.callService;
    if (cs.isConnected) {
      return cs.callDurationFormatted;
    } else if (cs.isCaller) {
      return cs.isRemoteRinging ? 'Berdering...' : 'Memanggil...';
    } else {
      return cs.isRinging ? 'Panggilan Masuk...' : 'Menghubungkan...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.callService;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // Back button minimizes instead of ending the call
          _minimizeCall();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1a1a2e),
        body: SafeArea(
          child: Stack(
            children: [
              // Background gradient
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1a1a2e),
                      Color(0xFF16213e),
                      Color(0xFF0f3460),
                    ],
                  ),
                ),
              ),

              // Remote Video (fullscreen, only for video calls when connected)
              if (cs.isConnected && cs.isVideoCall)
                Positioned.fill(
                  child: RTCVideoView(
                    cs.remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                  ),
                ),

              // Local Video (floating, only for video calls)
              if (cs.isVideoCall)
                Positioned(
                  right: 20,
                  top: 20,
                  width: 100,
                  height: 150,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: RTCVideoView(
                        cs.localRenderer,
                        mirror: true,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                ),

              // Minimize button (top-left)
              if (cs.isConnected)
                Positioned(
                  top: 12,
                  left: 12,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    onPressed: _minimizeCall,
                  ),
                ),

              // Caller Info & Status overlay (always visible for audio, visible when not connected for video)
              if (!cs.isConnected || !cs.isVideoCall)
                Positioned.fill(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Pulsating avatar during ringing
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          final scale = cs.isConnected ? 1.0 : _pulseAnimation.value;
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: cs.isConnected
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: Colors.green.withValues(alpha: 0.3),
                                          blurRadius: 30,
                                          spreadRadius: 10,
                                        ),
                                      ],
                              ),
                              child: CircleAvatar(
                                radius: 55,
                                backgroundColor: const Color(0xFF6c63ff),
                                backgroundImage: widget.remoteAvatarUrl.isNotEmpty
                                    ? NetworkImage(widget.remoteAvatarUrl)
                                    : null,
                                child: widget.remoteAvatarUrl.isEmpty
                                    ? const Icon(Icons.person, size: 55, color: Colors.white)
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.remoteUserName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Status / Duration
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.isConnected
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (cs.isConnected)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Text(
                              _getStatusText(),
                              style: TextStyle(
                                color: cs.isConnected ? Colors.greenAccent : Colors.white70,
                                fontSize: 16,
                                fontWeight: cs.isConnected ? FontWeight.w600 : FontWeight.normal,
                                fontFeatures: cs.isConnected
                                    ? const [FontFeature.tabularFigures()]
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Call type indicator
                      if (!cs.isConnected) ...[
                        const SizedBox(height: 12),
                        Icon(
                          cs.isVideoCall ? Icons.videocam : Icons.phone_in_talk,
                          color: Colors.white38,
                          size: 20,
                        ),
                      ],
                    ],
                  ),
                ),

              // Controls bar at bottom
              Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Audio Toggle
                    _buildControlButton(
                      icon: cs.isMuted ? Icons.mic_off : Icons.mic,
                      label: cs.isMuted ? 'Unmute' : 'Mute',
                      backgroundColor: cs.isMuted ? Colors.red.shade700 : Colors.white24,
                      onPressed: () => cs.toggleMic(),
                    ),
                    const SizedBox(width: 24),
                    
                    // End / Reject Call (bigger red button)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: FloatingActionButton(
                            heroTag: 'end_call',
                            backgroundColor: Colors.red,
                            onPressed: () {
                              _disableAutoPip();
                              cs.endCall(rejected: !cs.isCaller && !cs.isConnected);
                            },
                            child: const Icon(Icons.call_end, color: Colors.white, size: 30),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cs.isConnected ? 'Tutup' : (cs.isCaller ? 'Batal' : 'Tolak'),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    
                    // Accept Call (if ringing and receiver)
                    if (!cs.isCaller && !cs.isConnected && cs.isRinging) ...[
                      const SizedBox(width: 24),
                      _buildControlButton(
                        icon: Icons.call,
                        label: 'Angkat',
                        backgroundColor: Colors.green,
                        onPressed: () => cs.proceedAcceptingTempOffer(),
                      ),
                    ],

                    // Video Toggle
                    if (cs.isVideoCall) ...[
                      const SizedBox(width: 24),
                      _buildControlButton(
                        icon: Icons.videocam_off,
                        label: 'Kamera',
                        backgroundColor: Colors.white24,
                        onPressed: () => cs.toggleCamera(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: label,
          backgroundColor: backgroundColor,
          onPressed: onPressed,
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
