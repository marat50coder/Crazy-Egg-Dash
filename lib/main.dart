import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/audio.dart';
import 'core/game_state.dart';
import 'core/theme.dart';
import 'hatchway/config/era_hatch_config.dart';
import 'hatchway/core/hatch_models.dart';
import 'hatchway/hatch_coordinator.dart';
import 'hatchway/infra/airway_probe.dart';
import 'hatchway/infra/egg_signal_hub.dart';
import 'hatchway/infra/flight_attribution.dart';
import 'hatchway/infra/hatch_exchange.dart';
import 'hatchway/infra/nest_vault.dart';
import 'hatchway/infra/roost_agent.dart';
import 'hatchway/pages/empty_air_page.dart';
import 'hatchway/pages/feather_invitation.dart';
import 'hatchway/pages/roost_portal.dart';
import 'screens/loading_screen.dart';
import 'screens/main_menu_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Both orientations while the gray flow decides (the WebView + gray screens
  // rotate). The game proper locks to landscape once the white part starts.
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // --- Gray-flow services (assembled before the game so the boot gate can
  // decide gray vs white). Attribution + config must run even if Firebase
  // fails; only push/FCM depends on productionServicesReady. ---
  final vault = NestVault();
  final agent = RoostAgent();
  await Future.wait<void>(<Future<void>>[
    vault.initialize(),
    agent.prepare(),
  ]);

  assert(() {
    debugPrint(
      '[DASH.BOOT] credentialsReady=${EraHatchConfig.grayCredentialsReady} '
      'endpoint=${EraHatchConfig.endpoint} '
      'afKeyLen=${EraHatchConfig.appsFlyerKey.length} '
      'fbNum=${EraHatchConfig.firebaseProjectNumber}',
    );
    return true;
  }());

  var productionServicesReady = false;
  if (EraHatchConfig.grayCredentialsReady) {
    try {
      await Firebase.initializeApp();
      productionServicesReady = true;
      assert(() {
        debugPrint('[DASH.BOOT] Firebase.initializeApp OK');
        return true;
      }());
    } catch (error) {
      assert(() {
        debugPrint('[DASH.BOOT] Firebase.initializeApp failed: $error');
        return true;
      }());
    }
    if (productionServicesReady) {
      try {
        await FirebaseAppCheck.instance.activate(
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        );
      } catch (error) {
        // App Check must never block FCM / gray routing.
        assert(() {
          debugPrint('[DASH.BOOT] AppCheck skipped: $error');
          return true;
        }());
      }
    }
  } else {
    assert(() {
      debugPrint(
        '[DASH.BOOT] gray gate DISABLED — missing credentials. Game only.',
      );
      return true;
    }());
  }

  final probe = AirwayProbe();
  final notifications = EggSignalHub(vault, enabled: productionServicesReady);
  final attribution = FlightAttribution(agent);
  final coordinator = HatchCoordinator(
    vault: vault,
    probe: probe,
    attribution: attribution,
    exchange: HatchExchange(agent, vault),
    notifications: notifications,
    agent: agent,
    runtimeEnabled: EraHatchConfig.grayCredentialsReady,
  );

  // --- Game services ---
  final gameState = GameState();
  await gameState.load();
  await AudioManager.instance.init(
    music: gameState.musicOn,
    sound: gameState.soundOn,
    musicVol: gameState.musicVolume,
    soundVol: gameState.soundVolume,
  );

  runApp(
    ChangeNotifierProvider.value(
      value: gameState,
      child: CrazyEggDashApp(coordinator: coordinator),
    ),
  );
}

class CrazyEggDashApp extends StatelessWidget {
  const CrazyEggDashApp({super.key, required this.coordinator});

  final HatchCoordinator coordinator;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crazy Egg Dash',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: BootGate(coordinator: coordinator),
    );
  }
}

/// Shows the game's loading screen while the gray-flow decision runs, then
/// routes to the WebView (gray), the offline screen, or the game (white).
class BootGate extends StatefulWidget {
  const BootGate({super.key, required this.coordinator});

  final HatchCoordinator coordinator;

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  HatchDestination? _destination;
  bool _loadingDone = false;
  bool _navigated = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    HatchDestination destination;
    try {
      destination = await widget.coordinator.decide(onProgress: (_) {});
    } catch (_) {
      destination = const NativeNest();
    }
    if (!mounted) return;
    _destination = destination;
    _tryRoute();
  }

  void _tryRoute() {
    if (_navigated || !_loadingDone || _destination == null || !mounted) return;
    _navigated = true;
    _open(_destination!);
  }

  void _open(HatchDestination destination) {
    final coordinator = widget.coordinator;

    // Organic / gate disabled → the white game.
    if (destination is NativeNest) {
      _replace((_) => const GameHome());
      return;
    }

    if (destination is OfflineNest) {
      _replace(
        (_) => EmptyAirPage(
          probe: coordinator.probe,
          retryBuilder: (_) => BootGate(coordinator: coordinator),
        ),
      );
      return;
    }

    if (destination is PortalNest) {
      Widget portalBuilder(BuildContext _) => RoostPortal(
            url: destination.url,
            coldLaunch: destination.coldLaunch,
            vault: coordinator.vault,
            probe: coordinator.probe,
            notifications: coordinator.notifications,
            agent: coordinator.agent,
          );

      () async {
        if (coordinator.vault.shouldShowPushInvite &&
            await coordinator.notifications.canOfferPermission()) {
          if (!mounted) return;
          _replace(
            (_) => FeatherInvitation(
              vault: coordinator.vault,
              notifications: coordinator.notifications,
              nextBuilder: portalBuilder,
            ),
          );
        } else {
          _replace(portalBuilder);
        }
      }();
    }
  }

  void _replace(WidgetBuilder builder) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: builder),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoadingScreen(
      onDone: () {
        _loadingDone = true;
        _tryRoute();
      },
    );
  }
}

/// The white part: the actual Crazy Egg Dash game. Locks landscape, starts the
/// menu music and manages audio across app-lifecycle changes.
class GameHome extends StatefulWidget {
  const GameHome({super.key});

  @override
  State<GameHome> createState() => _GameHomeState();
}

class _GameHomeState extends State<GameHome> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The game and all menus are strictly horizontal.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    AudioManager.instance.playMusic(MusicTrack.menu);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        AudioManager.instance.resumeFromBackground();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        AudioManager.instance.pauseForBackground();
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const MainMenuScreen();
  }
}
