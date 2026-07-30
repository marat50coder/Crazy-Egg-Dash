import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

class AirwayProbe {
  AirwayProbe();

  final Connectivity _bearer = Connectivity();

  // Well-known hosts we probe when the OS reports "connected" but the
  // WebView cannot load the offer. Deliberately not our own domain — a VPN
  // or a not-yet-propagated app domain would otherwise produce a false
  // "offline". Two independent registrars so a single AS outage never
  // classifies the whole install as offline.
  static const List<String> _sentinelHosts = <String>[
    'apple.com',
    'microsoft.com',
  ];
  static const Duration _lookupBudget = Duration(milliseconds: 3200);

  Future<bool> hasInterface() async {
    try {
      final report = await _bearer.checkConnectivity();
      for (final entry in report) {
        if (entry != ConnectivityResult.none) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Reliable reachability check. Each lookup is time-boxed so the retry
  /// button can never hang forever, and every host is tried once before
  /// declaring the network unreachable.
  Future<bool> canReachNetwork() async {
    if (!await hasInterface()) return false;
    var attempt = 0;
    while (attempt < _sentinelHosts.length) {
      final host = _sentinelHosts[attempt];
      if (await _probeHost(host)) return true;
      attempt++;
    }
    return false;
  }

  Future<bool> _probeHost(String host) async {
    try {
      final answers = await InternetAddress.lookup(host).timeout(_lookupBudget);
      for (final record in answers) {
        if (record.rawAddress.isNotEmpty) return true;
      }
    } catch (_) {
      // fall through to next host
    }
    return false;
  }

  Stream<List<ConnectivityResult>> get changes => _bearer.onConnectivityChanged;
}
