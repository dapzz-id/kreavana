import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'api_service.dart';
import 'auth_service.dart';
import '../main.dart';
import '../screens/call_screen.dart';

class CallService extends ChangeNotifier {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  String? currentCallId;
  int? remoteUserId;
  bool isCaller = false;
  bool isVideoCall = false;

  // Call States
  bool isRinging = false;
  bool isConnected = false;
  bool isEnded = false;
  bool isMuted = false;
  bool isMinimized = false;
  bool isRemoteRinging = false;

  // Caller info for incoming calls
  String incomingCallerName = 'Panggilan Masuk';
  String incomingCallerAvatar = '';

  // Call duration timer
  Timer? _callTimer;
  Timer? _ringingTimeoutTimer;
  int callDurationSeconds = 0;
  String get callDurationFormatted {
    final minutes = (callDurationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (callDurationSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // ICE candidate buffer — stores candidates that arrive before peer connection is ready
  final List<dynamic> _pendingCandidates = [];
  bool _hasRemoteDescription = false;

  PusherChannelsClient? _pusher;
  final _uuid = const Uuid();

  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;
  bool _renderersInitialized = false;

  RTCVideoRenderer get localRenderer => _localRenderer!;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer!;

  /// Initialize Renderers (called automatically when call starts)
  Future<void> _initRenderers() async {
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();
    await _localRenderer!.initialize();
    await _remoteRenderer!.initialize();
    _renderersInitialized = true;
  }

  /// Dispose Renderers
  Future<void> disposeRenderers() async {
    if (_renderersInitialized) {
      await _localRenderer?.dispose();
      await _remoteRenderer?.dispose();
      _renderersInitialized = false;
    }
  }

  /// Initialize Pusher for Call Signaling
  Future<void> initPusher() async {
    final currentUser = await AuthService.getCurrentUser();
    if (currentUser == null) return;

    try {
      if (_pusher == null) {
        _pusher = PusherChannelsClient.websocket(
          options: PusherChannelsOptions.fromHost(
            scheme: 'ws',
            host: ApiService.hostIp,
            port: 8080,
            key: ApiService.keyPusher,
          ),
          connectionErrorHandler: (exception, trace, refresh) {
            debugPrint('Pusher call connection error: $exception');
            Future.delayed(const Duration(seconds: 5), refresh);
          },
        );
        _pusher!.onConnectionEstablished.listen((event) {
          debugPrint('Pusher Call Connection Event: Connected');
          
          // Subscribe to personal call channel (using public channel for prototyping)
          final channel = _pusher!.publicChannel('call.${currentUser.id}');
          channel.subscribe();
          
          channel.bind('call.signal').listen((callEvent) {
            if (callEvent.data != null) {
              _onSignalingEvent(callEvent.data!);
            }
          });
        });
        _pusher!.connect();
      }

      // Listen to CallKit Events (Android/iOS only)
      if (!kIsWeb) {
        FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
          if (event is CallEventActionCallAccept) {
            if (navigatorKey.currentState != null) {
              navigatorKey.currentState!.push(
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    callService: this,
                    remoteUserName: incomingCallerName,
                    remoteAvatarUrl: incomingCallerAvatar,
                  ),
                ),
              );
            }
            proceedAcceptingTempOffer();
          } else if (event is CallEventActionCallDecline) {
            endCall(rejected: true);
          }
        });
      }
    } catch (e) {
      debugPrint("Pusher Init Error for Calls: $e");
    }
  }

  /// Helper: mark the call as connected (called from onConnectionState, onIceConnectionState, or 'connected' signal)
  void _markConnected({bool sendSignal = false}) {
    if (!isConnected) {
      debugPrint('✅ Call connected!');
      isConnected = true;
      isRinging = false;
      _stopRingingTimeout();
      _startCallTimer();
      notifyListeners();
      // Both sides send 'connected' signal so the other side knows immediately
      if (sendSignal) {
        _sendSignalingMessage('connected', {});
      }
    }
  }

  /// Create WebRTC Peer Connection
  Future<void> _createPeerConnection() async {
    final Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        // Local Coturn TURN server (Docker)
        {'urls': 'stun:${ApiService.hostIp}:3478'},
        {
          'urls': [
            'turn:${ApiService.hostIp}:3478',
            'turn:${ApiService.hostIp}:3478?transport=tcp',
          ],
          'username': 'kreavana',
          'credential': 'kreavana2025',
        },
      ],
      'sdpSemantics': 'unified-plan',
      'iceCandidatePoolSize': 10,
    };

    _peerConnection = await createPeerConnection(configuration);

    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      debugPrint('📤 Sending ICE candidate: ${candidate.candidate}');
      _sendSignalingMessage('candidate', {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
      debugPrint('🔍 ICE Gathering State: $state');
    };

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      debugPrint('🔊 Received remote track: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        if (_renderersInitialized) {
          remoteRenderer.srcObject = _remoteStream;
        }
        notifyListeners();
      }
    };

    _peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('🔗 WebRTC Connection State: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _markConnected(sendSignal: true);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
                 state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        debugPrint('⚠️ WebRTC connection failed/disconnected');
      }
    };

    // Fallback: pada Android, onConnectionState kadang tidak terpicu.
    // onIceConnectionState lebih reliable sebagai pendeteksi koneksi.
    _peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('🧊 ICE Connection State: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _markConnected(sendSignal: true);
      }
    };

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        _peerConnection?.addTrack(track, _localStream!);
      }
    }

  }

  /// Flush buffered ICE candidates (call AFTER setRemoteDescription)
  Future<void> _flushPendingCandidates() async {
    if (_hasRemoteDescription && _pendingCandidates.isNotEmpty && _peerConnection != null) {
      debugPrint('📥 Flushing ${_pendingCandidates.length} buffered ICE candidates');
      for (var candidate in _pendingCandidates) {
        try {
          await _peerConnection!.addCandidate(candidate);
        } catch (e) {
          debugPrint('⚠️ Failed to add buffered candidate: $e');
        }
      }
      _pendingCandidates.clear();
    }
  }

  /// Start a Call
  Future<void> startCall(int receiverId, bool video, {String remoteUserName = 'User', String remoteAvatarUrl = ''}) async {
    isCaller = true;
    isVideoCall = video;
    remoteUserId = receiverId;
    currentCallId = _uuid.v4();
    isRinging = true;
    isConnected = false;
    isEnded = false;
    isMuted = false;
    isMinimized = false;
    isRemoteRinging = false;
    callDurationSeconds = 0;
    _hasRemoteDescription = false;
    _pendingCandidates.clear();
    incomingCallerName = remoteUserName;
    incomingCallerAvatar = remoteAvatarUrl;

    _startRingingTimeout();

    notifyListeners();

    await _initRenderers();
    await _openUserMedia(video);
    await _createPeerConnection();

    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    debugPrint('📞 Sending offer to user $receiverId');
    await _sendSignalingMessage('offer', {
      'sdp': offer.sdp,
      'type': offer.type,
      'video': video,
    });
  }

  /// Accept an incoming call (initializes WebRTC for receiver)
  Future<void> acceptCall(String callId, int callerId, bool video) async {
    isCaller = false;
    isVideoCall = video;
    currentCallId = callId;
    remoteUserId = callerId;
    isRinging = false;
    isEnded = false;
    isMuted = false;
    callDurationSeconds = 0;
    _hasRemoteDescription = false;
    
    notifyListeners();

    await _initRenderers();
    await _openUserMedia(video);
    await _createPeerConnection();
  }

  /// Hang up or Reject Call
  Future<void> endCall({bool rejected = false}) async {
    // Send signal before clearing state
    if (currentCallId != null && remoteUserId != null) {
      try {
        await _sendSignalingMessage(rejected ? 'reject' : 'end', {});
      } catch (e) {
        debugPrint('Error sending end signal: $e');
      }
    }

    _stopCallTimer();

    isRinging = false;
    isConnected = false;
    isEnded = true;
    isMuted = false;
    isMinimized = false;
    isRemoteRinging = false;
    currentCallId = null;
    remoteUserId = null;
    callDurationSeconds = 0;
    _hasRemoteDescription = false;
    _pendingCandidates.clear();

    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;

    if (_renderersInitialized) {
      _localRenderer?.srcObject = null;
      _remoteRenderer?.srcObject = null;
    }

    _peerConnection?.close();
    _peerConnection = null;

    notifyListeners();
  }

  /// Start call duration timer
  void _startCallTimer() {
    _stopRingingTimeout();
    _callTimer?.cancel();
    callDurationSeconds = 0;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      callDurationSeconds++;
      notifyListeners();
    });
  }

  /// Stop call duration timer
  void _stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
    _stopRingingTimeout();
  }

  void _startRingingTimeout() {
    _ringingTimeoutTimer?.cancel();
    _ringingTimeoutTimer = Timer(const Duration(seconds: 60), () {
      debugPrint('⏰ Call not answered within 60 seconds, ending call.');
      if (currentCallId != null && !isConnected) {
        endCall(rejected: !isCaller);
      }
    });
  }

  void _stopRingingTimeout() {
    _ringingTimeoutTimer?.cancel();
    _ringingTimeoutTimer = null;
  }

  // Fix SDP line endings for WebRTC strict parsing
  String _fixSdp(String sdp) {
    var fixed = sdp.replaceAll('\r\n', '\n').replaceAll('\n', '\r\n');
    if (!fixed.endsWith('\r\n')) {
      fixed += '\r\n';
    }
    return fixed;
  }

  /// Access Camera & Mic
  Future<void> _openUserMedia(bool video) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': video
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
              'frameRate': {'ideal': 30},
            }
          : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    if (_renderersInitialized) {
      localRenderer.srcObject = _localStream;
    }
    notifyListeners();
  }

  /// Handle incoming signaling messages from Laravel
  void _onSignalingEvent(dynamic eventData) async {
    final Map<String, dynamic> payloadData;
    try {
      if (eventData is String) {
        payloadData = Map<String, dynamic>.from(jsonDecode(eventData));
      } else if (eventData is Map) {
        payloadData = Map<String, dynamic>.from(eventData);
      } else {
        debugPrint('Unknown signaling eventData type: ${eventData.runtimeType}');
        return;
      }
    } catch (e) {
      debugPrint('Failed to decode signaling eventData: $e');
      return;
    }

    final type = payloadData['type'];
    final remoteId = payloadData['caller_id']; // For receiver, this is caller
    final callId = payloadData['call_id'];
    final signalData = payloadData['data'];

    debugPrint('📡 Received signaling: type=$type, callId=$callId, from=$remoteId');

    // If we're already in a call and receive signal for different call, ignore
    if (currentCallId != null && currentCallId != callId) return;

    switch (type) {
      case 'offer':
        // Show CallKit Incoming Screen
        isRinging = true;
        isCaller = false;
        currentCallId = callId;
        remoteUserId = remoteId;
        isVideoCall = signalData['video'] ?? false;
        incomingCallerName = signalData['callerName'] ?? 'Panggilan Masuk';
        incomingCallerAvatar = signalData['callerAvatar'] ?? '';
        notifyListeners();
        
        _tempOffer = RTCSessionDescription(_fixSdp(signalData['sdp']), signalData['type']);

        if (!kIsWeb) {
          final callKitParams = CallKitParams(
            id: callId,
            nameCaller: incomingCallerName,
            appName: 'Kreavana',
            avatar: incomingCallerAvatar.isNotEmpty ? incomingCallerAvatar : 'https://i.pravatar.cc/100',
            handle: isVideoCall ? 'Video Call' : 'Voice Call',
            type: isVideoCall ? 1 : 0,
            duration: 30000,
            android: AndroidParams(
              isCustomNotification: true,
              isShowLogo: false,
              ringtonePath: 'system_ringtone_default',
              backgroundColor: '#0955fa',
              actionColor: '#4CAF50',
            ),
            ios: IOSParams(
              iconName: 'CallKitLogo',
              handleType: '',
              supportsVideo: true,
              maximumCallGroups: 2,
              maximumCallsPerCallGroup: 1,
              audioSessionMode: 'default',
              audioSessionActive: true,
              audioSessionPreferredSampleRate: 44100.0,
              audioSessionPreferredIOBufferDuration: 0.005,
              supportsDTMF: true,
              supportsHolding: true,
              supportsGrouping: false,
              supportsUngrouping: false,
              ringtonePath: 'system_ringtone_default',
            ),
          );
          await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
        } else {
          _showIncomingCallDialogWeb();
        }

        // Send 'ringing' signal back to the caller
        _sendSignalingMessage('ringing', {'status': 'ringing'});

        _startRingingTimeout();

        break;
      case 'answer':
        debugPrint('✅ Call answered! Setting remote description...');
        await _peerConnection?.setRemoteDescription(
          RTCSessionDescription(_fixSdp(signalData['sdp']), signalData['type'])
        );
        _hasRemoteDescription = true;
        // Flush buffered ICE candidates now that remote description is set
        await _flushPendingCandidates();
        // Don't mark connected here — let onConnectionState/onIceConnectionState do it
        // so that 'connected' signal is also sent to receiver
        break;
      case 'connected':
        debugPrint('✅ Received connected signal from caller!');
        _markConnected();
        break;
      case 'candidate':
        debugPrint('📥 Received ICE candidate: ${signalData['candidate']}');
        final dynamic candidate = RTCIceCandidate(
          signalData['candidate'],
          signalData['sdpMid'],
          signalData['sdpMLineIndex'],
        );
        if (_hasRemoteDescription && _peerConnection != null) {
          debugPrint('📥 Adding ICE candidate directly');
          await _peerConnection!.addCandidate(candidate);
        } else {
          debugPrint('📥 Buffering ICE candidate (peer connection not ready)');
          _pendingCandidates.add(candidate);
        }
        break;
      case 'ringing':
        debugPrint('🔔 Remote user is ringing...');
        isRemoteRinging = true;
        notifyListeners();
        break;
      case 'end':
      case 'reject':
        if (currentCallId != null && !kIsWeb) {
          await FlutterCallkitIncoming.endCall(currentCallId!);
        }
        if (kIsWeb && isRinging && !isCaller && navigatorKey.currentState != null) {
          navigatorKey.currentState!.pop();
        }
        // Don't send signal back — the remote already sent this
        _stopCallTimer();
        isRinging = false;
        isConnected = false;
        isEnded = true;
        isMuted = false;
        isMinimized = false;
        isRemoteRinging = false;
        currentCallId = null;
        remoteUserId = null;
        callDurationSeconds = 0;
        _hasRemoteDescription = false;
        _pendingCandidates.clear();

        _localStream?.getTracks().forEach((track) => track.stop());
        _localStream?.dispose();
        _localStream = null;

        if (_renderersInitialized) {
          _localRenderer?.srcObject = null;
          _remoteRenderer?.srcObject = null;
        }

        _peerConnection?.close();
        _peerConnection = null;

        notifyListeners();
        break;
    }
  }

  dynamic _tempOffer;

  /// Called when user presses "Accept" — initializes WebRTC then sends answer
  Future<void> proceedAcceptingTempOffer() async {
    if (_tempOffer != null && currentCallId != null && remoteUserId != null) {
      debugPrint('📞 Accepting call, initializing WebRTC...');
      
      isRinging = false;
      _stopRingingTimeout();
      notifyListeners();

      // Initialize WebRTC (mic + peer connection)
      await acceptCall(currentCallId!, remoteUserId!, isVideoCall);

      // Set the remote offer description FIRST
      await _peerConnection?.setRemoteDescription(_tempOffer);
      _tempOffer = null;
      _hasRemoteDescription = true;

      // Now flush buffered ICE candidates (remote description is set)
      await _flushPendingCandidates();
      
      // Create and send answer
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      debugPrint('📤 Sending answer to caller');
      await _sendSignalingMessage('answer', {
        'sdp': answer.sdp,
        'type': answer.type,
      });
    }
  }

  Future<void> _sendSignalingMessage(String type, Map<String, dynamic> data) async {
    if (remoteUserId == null || currentCallId == null) return;
    debugPrint('📤 Sending signal: $type to user $remoteUserId');
    await ApiService.post('call/signal', {
      'receiver_id': remoteUserId,
      'call_id': currentCallId,
      'type': type,
      'data': data,
    });
  }

  void toggleMic() {
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      bool enabled = _localStream!.getAudioTracks()[0].enabled;
      _localStream!.getAudioTracks()[0].enabled = !enabled;
      isMuted = !isMuted;
      notifyListeners();
    }
  }

  void toggleCamera() {
    if (_localStream != null && isVideoCall && _localStream!.getVideoTracks().isNotEmpty) {
      bool enabled = _localStream!.getVideoTracks()[0].enabled;
      _localStream!.getVideoTracks()[0].enabled = !enabled;
      notifyListeners();
    }
  }

  /// Minimize the call (PiP / overlay mode)
  void minimizeCall() {
    isMinimized = true;
    notifyListeners();
  }

  /// Maximize the call (return to full screen)
  void maximizeCall() {
    isMinimized = false;
    notifyListeners();
  }

  /// Menampilkan dialog panggilan masuk khusus untuk platform Web
  void _showIncomingCallDialogWeb() {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isVideoCall
                ? '📹 Video Call dari $incomingCallerName'
                : '📞 Panggilan dari $incomingCallerName',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 45,
                backgroundImage: incomingCallerAvatar.isNotEmpty
                    ? NetworkImage(incomingCallerAvatar)
                    : null,
                child: incomingCallerAvatar.isEmpty
                    ? const Icon(Icons.person, size: 45, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                incomingCallerName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                isVideoCall ? 'Video Call Masuk...' : 'Panggilan Suara Masuk...',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FloatingActionButton(
              backgroundColor: Colors.red,
              heroTag: 'reject_web',
              onPressed: () {
                Navigator.of(dialogContext).pop();
                endCall(rejected: true);
              },
              child: const Icon(Icons.call_end, color: Colors.white),
            ),
            const SizedBox(width: 40),
            FloatingActionButton(
              backgroundColor: Colors.green,
              heroTag: 'accept_web',
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Navigate to CallScreen first, then accept
                navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (_) => CallScreen(
                      callService: this,
                      remoteUserName: incomingCallerName,
                      remoteAvatarUrl: incomingCallerAvatar,
                    ),
                  ),
                );
                proceedAcceptingTempOffer();
              },
              child: const Icon(Icons.call, color: Colors.white),
            ),
          ],
        );
      },
    );
  }
}
