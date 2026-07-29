import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class LaunchRouteReader {
  static const String _dartKey = 'ced_tap_route';

  static Future<String?> consume() async {
    if (!Platform.isIOS) return null;
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(_dartKey)?.trim();
      if (value == null || value.isEmpty) return null;
      await preferences.remove(_dartKey);
      return value;
    } catch (_) {
      return null;
    }
  }
}
