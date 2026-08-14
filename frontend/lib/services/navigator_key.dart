import 'package:flutter/material.dart';

/// NavigatorKey global — dipakai bersama oleh GoRouter dan CallService
/// untuk navigasi dari luar widget tree (misal: incoming call overlay).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
