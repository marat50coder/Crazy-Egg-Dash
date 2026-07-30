import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/hatch_models.dart';

class NestVault {
  NestVault();

  static const String _routeSlot = 'dash.nest.route';
  static const String _expirySlot = 'dash.nest.expiry';
  static const String _inviteAfterSlot = 'dash.nest.invite.after';
  static const String _pushGrantSlot = 'dash.nest.push.granted';
  static const String _pushOsDeniedSlot = 'dash.nest.push.os_denied';
  static const String _savedUrlSlot = 'dash.nest.secure.destination';
  static const String _pendingUrlSlot = 'dash.nest.secure.pending';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  late SharedPreferences _preferences;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
  }

  NestRoute get route => NestRoute.parse(_preferences.getString(_routeSlot));

  Future<void> saveRoute(NestRoute route) =>
      _preferences.setString(_routeSlot, route.storageValue);

  Future<String?> savedUrl() async {
    try {
      return await _secure.read(key: _savedUrlSlot);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheUrl(String url, int? expiresAt) async {
    try {
      await _secure.write(key: _savedUrlSlot, value: url);
      if (expiresAt != null) {
        await _preferences.setInt(_expirySlot, expiresAt);
      }
    } catch (_) {}
  }

  bool get cachedUrlExpired {
    final expiry = _preferences.getInt(_expirySlot);
    if (expiry == null) return true;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return nowSeconds >= expiry;
  }

  Future<void> stashPushUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    try {
      await _secure.write(key: _pendingUrlSlot, value: trimmed);
    } catch (_) {}
  }

  Future<String?> consumePushUrl() async {
    try {
      final value = await _secure.read(key: _pendingUrlSlot);
      if (value != null) await _secure.delete(key: _pendingUrlSlot);
      return value;
    } catch (_) {
      return null;
    }
  }

  bool get pushAllowed => _preferences.getBool(_pushGrantSlot) ?? false;
  bool get pushDeniedByOs => _preferences.getBool(_pushOsDeniedSlot) ?? false;

  Future<void> setPushAllowed(bool value) =>
      _preferences.setBool(_pushGrantSlot, value);

  Future<void> markPushDeniedByOs() =>
      _preferences.setBool(_pushOsDeniedSlot, true);

  bool get shouldShowPushInvite {
    if (pushAllowed || pushDeniedByOs) return false;
    final after = _preferences.getInt(_inviteAfterSlot);
    if (after == null) return true;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return nowSeconds >= after;
  }

  Future<void> snoozePushInvite(int epochSeconds) =>
      _preferences.setInt(_inviteAfterSlot, epochSeconds);
}
