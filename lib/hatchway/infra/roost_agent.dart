import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../config/era_hatch_config.dart';

/// HTTP client whose every request is stamped with a forged Mobile Safari
/// User-Agent. The UA is derived from the real iOS release when possible
/// so ten different installs never collide on the same string.
///
/// GAME THEME CATEGORY: crash (no appid/appname suffix).
class RoostAgent extends http.BaseClient {
  RoostAgent();

  static const String _fallbackIos = '18.7.1';
  static const int _minMajor = 18;
  static const String _mobileToken = 'Mobile/15E148';

  final http.Client _wire = http.Client();
  String? _built;

  Future<void> prepare() async {
    _built = await _resolveUa();
  }

  String get userAgent => _built ?? _forge(_fallbackIos);

  Future<String> _resolveUa() async {
    if (!Platform.isIOS) return _forge(_fallbackIos);
    try {
      final info = await DeviceInfoPlugin().iosInfo;
      return _forge(_normalizeIos(info.systemVersion));
    } catch (_) {
      return _forge(_fallbackIos);
    }
  }

  String _normalizeIos(String raw) {
    final digits = <int>[];
    for (final chunk in raw.split('.')) {
      final parsed = int.tryParse(chunk);
      if (parsed != null) digits.add(parsed);
      if (digits.length >= 3) break;
    }
    if (digits.isEmpty || digits.first < _minMajor) return _fallbackIos;
    return digits.join('.');
  }

  String _forge(String iosVersion) {
    final cpu = iosVersion.replaceAll('.', '_');
    final buffer = StringBuffer('Mozilla/5.0 ')
      ..write('(iPhone; CPU iPhone OS ')
      ..write(cpu)
      ..write(' like Mac OS X) AppleWebKit/')
      ..write(EraHatchConfig.webKitVersion)
      ..write(' (KHTML, like Gecko) Version/')
      ..write(EraHatchConfig.safariVersion)
      ..write(' ')
      ..write(_mobileToken)
      ..write(' Safari/')
      ..write(EraHatchConfig.safariTail);
    return buffer.toString();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => userAgent);
    return _wire.send(request);
  }

  @override
  void close() => _wire.close();
}
