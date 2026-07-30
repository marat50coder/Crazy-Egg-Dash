import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// One-shot reader for the cold-launch push destination that the native
/// SceneDelegate hands off through NSUserDefaults. The Swift side writes
/// under `flutter.dash_push_dest`; shared_preferences exposes it here
/// without the `flutter.` prefix.
class LaunchRouteReader {
  const LaunchRouteReader._();

  static const String _handoffKey = 'dash_push_dest';

  static Future<String?> consume() async {
    if (!Platform.isIOS) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_handoffKey)?.trim();
      if (raw == null || raw.isEmpty) return null;
      await prefs.remove(_handoffKey);
      return raw;
    } catch (_) {
      return null;
    }
  }
}
