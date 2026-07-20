import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/audio.dart';
import 'core/game_state.dart';
import 'core/theme.dart';
import 'screens/loading_screen.dart';
import 'screens/main_menu_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The loading screen may be shown in either orientation; we lock to
  // landscape once the game proper starts (after loading finishes).
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

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
      child: const CrazyEggDashApp(),
    ),
  );
}

class CrazyEggDashApp extends StatelessWidget {
  const CrazyEggDashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crazy Egg Dash',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const _Root(),
    );
  }
}

/// Shows the loading screen first, then locks to landscape and reveals the
/// main menu.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> with WidgetsBindingObserver {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
        // Minimized / backgrounded / closing: stop music and SFX.
        AudioManager.instance.pauseForBackground();
        break;
      case AppLifecycleState.inactive:
        // Transient (e.g. notification shade) — leave audio running.
        break;
    }
  }

  Future<void> _onLoadingDone() async {
    // The game and all menus are strictly horizontal.
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    AudioManager.instance.playMusic(MusicTrack.menu);
    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _loaded
          ? const MainMenuScreen()
          : LoadingScreen(onDone: _onLoadingDone),
    );
  }
}
