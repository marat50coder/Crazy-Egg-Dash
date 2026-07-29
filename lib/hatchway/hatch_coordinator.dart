import 'dart:async';
import 'dart:io';

import 'config/era_hatch_config.dart';
import 'core/hatch_models.dart';
import 'infra/airway_probe.dart';
import 'infra/egg_signal_hub.dart';
import 'infra/flight_attribution.dart';
import 'infra/hatch_exchange.dart';
import 'infra/launch_route_reader.dart';
import 'infra/nest_vault.dart';
import 'infra/roost_agent.dart';

class HatchCoordinator {
  HatchCoordinator({
    required this.vault,
    required this.probe,
    required this.attribution,
    required this.exchange,
    required this.notifications,
    required this.agent,
    required this.runtimeEnabled,
  });

  final NestVault vault;
  final AirwayProbe probe;
  final FlightAttribution attribution;
  final HatchExchange exchange;
  final EggSignalHub notifications;
  final RoostAgent agent;
  final bool runtimeEnabled;

  bool get enabled => runtimeEnabled && EraHatchConfig.grayCredentialsReady;

  Future<HatchDestination>? _decideFuture;

  /// De-duplicates only *concurrent* calls (the boot screen can build twice at
  /// startup → avoids a double attribution / config POST). The cache is
  /// cleared once the pipeline finishes, so a later call — e.g. Retry from the
  /// offline screen after Wi-Fi returns — runs the whole pipeline again
  /// instead of replaying the cached OfflineNest forever.
  Future<HatchDestination> decide({
    required void Function(double value) onProgress,
  }) =>
      _decideFuture ??= _decide(onProgress: onProgress)
          .whenComplete(() => _decideFuture = null);

  Future<HatchDestination> _decide({
    required void Function(double value) onProgress,
  }) async {
    if (!enabled) {
      assert(() {
        // ignore: avoid_print
        print(
          '[CED.HATCH] gate disabled '
          'runtime=$runtimeEnabled creds=${EraHatchConfig.grayCredentialsReady}',
        );
        return true;
      }());
      onProgress(1);
      return const NativeNest();
    }

    assert(() {
      // ignore: avoid_print
      print('[CED.HATCH] decide start route=${vault.route}');
      return true;
    }());

    notifications.onTokenChanged = _refreshForToken;
    final coldRoute = await LaunchRouteReader.consume();
    if (coldRoute != null) {
      await vault.saveRoute(NestRoute.portal);
      await vault.consumePushUrl();
      unawaited(_backgroundDispatch());
      onProgress(1);
      return PortalNest(coldRoute, coldLaunch: true);
    }

    onProgress(0.12);
    return switch (vault.route) {
      NestRoute.undecided => _firstDecision(onProgress),
      NestRoute.portal => _returningPortal(onProgress),
      NestRoute.native => _returningNative(onProgress),
    };
  }

  Future<HatchDestination> _firstDecision(
    void Function(double) progress,
  ) async {
    if (!await probe.hasInterface()) {
      assert(() {
        // ignore: avoid_print
        print('[CED.HATCH] first: no interface → offline');
        return true;
      }());
      return const OfflineNest(returnToNative: false);
    }
    progress(0.28);
    try {
      await notifications.boot();
    } catch (_) {}
    if (!await probe.canReachNetwork()) {
      assert(() {
        // ignore: avoid_print
        print('[CED.HATCH] first: DNS probe failed → offline');
        return true;
      }());
      return const OfflineNest(returnToNative: false);
    }
    progress(0.48);
    await attribution.awaitSignals();
    progress(0.72);
    final reply = await _requestConfig();
    progress(1);
    assert(() {
      // ignore: avoid_print
      print(
        '[CED.HATCH] first: config hasDest=${reply.hasDestination} '
        'url=${reply.url}',
      );
      return true;
    }());
    if (reply.hasDestination) {
      await vault.saveRoute(NestRoute.portal);
      return PortalNest(reply.url!);
    }
    await vault.saveRoute(NestRoute.native);
    return const NativeNest();
  }

  Future<HatchDestination> _returningPortal(
    void Function(double) progress,
  ) async {
    if (!await probe.hasInterface()) {
      return const OfflineNest(returnToNative: false);
    }
    final pending = await vault.consumePushUrl();
    if (pending != null && pending.isNotEmpty) {
      progress(1);
      return PortalNest(pending);
    }
    final cached = await vault.savedUrl();
    if (cached != null && !vault.cachedUrlExpired) {
      progress(1);
      return PortalNest(cached);
    }

    await Future.wait<void>(<Future<void>>[
      notifications.boot(),
      attribution.start(),
    ]);
    if (!await probe.canReachNetwork()) {
      return const OfflineNest(returnToNative: false);
    }
    progress(0.62);
    await attribution.awaitSignals(installTimeout: const Duration(seconds: 5));
    final reply = await _requestConfig();
    progress(1);
    if (reply.hasDestination) return PortalNest(reply.url!);
    if (cached != null) return PortalNest(cached);
    return const OfflineNest(returnToNative: false);
  }

  Future<HatchDestination> _returningNative(
    void Function(double) progress,
  ) async {
    if (!await probe.hasInterface()) {
      progress(1);
      return const NativeNest();
    }
    await Future.wait<void>(<Future<void>>[
      notifications.boot(),
      attribution.start(),
    ]);
    if (!await probe.canReachNetwork()) {
      progress(1);
      return const NativeNest();
    }
    progress(0.55);
    await attribution.awaitSignals();
    final reply = await _requestConfig();
    progress(1);
    if (!reply.hasDestination) return const NativeNest();
    await vault.saveRoute(NestRoute.portal);
    return PortalNest(reply.url!);
  }

  Future<HatchReply> _requestConfig({String? token}) async {
    final body = await attribution.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? notifications.token,
    );
    return exchange.request(body);
  }

  Future<void> _backgroundDispatch() async {
    try {
      await Future.wait<void>(<Future<void>>[
        notifications.boot(),
        attribution.awaitSignals(),
      ]);
      await _requestConfig();
    } catch (_) {}
  }

  Future<void> _refreshForToken(String token) async {
    try {
      await _requestConfig(token: token);
    } catch (_) {}
  }
}
