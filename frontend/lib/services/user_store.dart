import '../models/user_model.dart';
import 'package:flutter/foundation.dart';

/// Global store untuk user yang sedang login.
/// Dipakai oleh GoRouter sebagai refreshListenable agar redirect
/// otomatis dipicu saat login/logout.
final ValueNotifier<UserModel?> currentUserNotifier = ValueNotifier<UserModel?>(
  null,
);
