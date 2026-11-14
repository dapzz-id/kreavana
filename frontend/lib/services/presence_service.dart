import 'dart:async';
import 'package:flutter/widgets.dart';
import 'chat_service.dart';

class PresenceService with WidgetsBindingObserver {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  Timer? _heartbeatTimer;
  bool _isRunning = false;
  bool _isObserverRegistered = false;

  /// Start global presence heartbeat. Pings every 15 seconds while app is in foreground.
  static void start() {
    instance._start();
  }

  /// Stop presence heartbeat (e.g. on logout or app exit).
  static void stop() {
    instance._stop();
  }

  /// Trigger an immediate presence ping.
  static Future<void> ping() async {
    await ChatService.pingPresence();
  }

  void _start() {
    if (_isRunning) return;
    _isRunning = true;

    if (!_isObserverRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _isObserverRegistered = true;
    }

    // Ping immediately upon start
    ping();

    // Start periodic heartbeat every 15 seconds
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      ping();
    });
  }

  void _stop() {
    _isRunning = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (_isObserverRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _isObserverRegistered = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isRunning) return;

    if (state == AppLifecycleState.resumed) {
      // User returned to app (foreground) -> ping immediately and resume timer
      ping();
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        ping();
      });
    } else if (state == AppLifecycleState.paused ||
               state == AppLifecycleState.hidden ||
               state == AppLifecycleState.detached) {
      // User minimized or closed app -> pause heartbeat so last_online expires accurately
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
    }
  }
}
