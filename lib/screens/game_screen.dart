import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../core/assets.dart';
import '../core/audio.dart';
import '../core/game_state.dart';
import '../core/progression_defs.dart';
import '../core/theme.dart';
import '../game/egg_dash_game.dart';
import '../game/game_images.dart';
import '../game/game_painter.dart';
import '../widgets/common.dart';
import 'settings_screen.dart';

/// Screen #4 (Gameplay) — hosts the runner, the in-run HUD and the Pause (#5)
/// and Game Over / Result (#6) overlays.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  final GameImages _images = GameImages();
  final ValueNotifier<int> _frame = ValueNotifier(0);
  late final Ticker _ticker;
  EggDashGame? _game;
  bool _assetsReady = false;
  Duration _lastElapsed = Duration.zero;

  bool _showPause = false;
  bool _showGameOver = false;
  bool _showReviveOffer = false;
  int _revivesUsed = 0;
  bool _recorded = false;
  List<String> _newAchievements = [];

  GameState get _gs => context.read<GameState>();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    AudioManager.instance.playMusic(MusicTrack.game);
    _init();
  }

  Future<void> _init() async {
    await _images.loadAll();
    if (!mounted) return;
    setState(() => _assetsReady = true);
  }

  void _ensureGame(Size size) {
    if (_game == null) {
      final gs = _gs;
      _game = EggDashGame(
        speedMultiplier: gs.speedMultiplier,
        jumpMultiplier: gs.jumpMultiplier,
        coinMultiplier: gs.coinMultiplier,
        magnetRadius: gs.magnetRadius,
        startingShields: gs.startingShields,
        leaderSpecies: gs.selectedChicken,
        spriteAspects: _images.aspectRatios([
          Assets.rock,
          Assets.treeStump,
          Assets.log,
          Assets.bush,
        ]),
        onGameOver: _handleGameOver,
      );
      _game!.resize(size);
      _game!.start();
      _lastElapsed = Duration.zero;
      _ticker.start();
    } else if (_game!.size != size) {
      _game!.resize(size);
    }
  }

  void _onTick(Duration elapsed) {
    final g = _game;
    if (g == null) return;
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (g.phase == GamePhase.running) {
      g.update(dt.clamp(0.0, 0.05));
      _frame.value++;
    }
  }

  void _handleGameOver() {
    if (!mounted) return;
    AudioManager.instance.play(Sfx.gameOver);
    final canRevive = _gs.reviveCharges > _revivesUsed;
    setState(() {
      if (canRevive) {
        _showReviveOffer = true;
      } else {
        _finishRun();
      }
    });
  }

  void _finishRun() {
    if (_recorded) {
      _showGameOver = true;
      return;
    }
    _recorded = true;
    final g = _game!;
    _newAchievements = _gs.recordRun(RunResult(
      distance: g.distance,
      maxFlock: g.maxFlock,
      coins: g.coins,
      eggs: g.eggsCollected,
      jumps: g.jumps,
      zone: g.zone,
    ));
    _showGameOver = true;
  }

  void _revive() {
    _revivesUsed++;
    setState(() => _showReviveOffer = false);
    _game!.revive();
  }

  void _declineRevive() {
    setState(() {
      _showReviveOffer = false;
      _finishRun();
    });
  }

  void _pause() {
    _game?.pause();
    setState(() => _showPause = true);
  }

  void _resume() {
    setState(() => _showPause = false);
    _lastElapsed = Duration.zero;
    _game?.resume();
  }

  void _openSettings() {
    // Opens on top of the paused game; volume changes apply live and the run
    // stays paused until the player taps Resume.
    Navigator.of(context).push(fadeThroughRoute(const SettingsScreen()));
  }

  void _restart() {
    setState(() {
      _showPause = false;
      _showGameOver = false;
      _showReviveOffer = false;
      _revivesUsed = 0;
      _recorded = false;
      _newAchievements = [];
    });
    _lastElapsed = Duration.zero;
    _game?.start();
  }

  void _goHome() {
    if (!_recorded && _game != null && _game!.phase != GamePhase.ready) {
      // Bank progress from an abandoned run too.
      _finishRun();
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _images.dispose();
    _frame.dispose();
    // Back to the calmer menu track when leaving gameplay.
    AudioManager.instance.playMusic(MusicTrack.menu);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_assetsReady) {
      return const Scaffold(
        backgroundColor: AppColors.skyTop,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          _ensureGame(size);
          final g = _game!;
          final interactive = !_showPause && !_showGameOver && !_showReviveOffer;
          return Stack(
            children: [
              // Input layer only covers the game itself, so taps on HUD
              // buttons (e.g. Pause) don't also trigger a jump.
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: interactive ? (_) => g.onTapDown() : null,
                  onPointerUp: interactive ? (_) => g.onTapUp() : null,
                  child: CustomPaint(
                    painter: GamePainter(
                      game: g,
                      images: _images,
                      repaint: _frame,
                    ),
                  ),
                ),
              ),
              _buildHud(g),
              if (_showPause)
                _PauseOverlay(
                  onResume: _resume,
                  onRestart: _restart,
                  onHome: _goHome,
                  onSettings: _openSettings,
                ),
              if (_showReviveOffer)
                _ReviveOverlay(onRevive: _revive, onDecline: _declineRevive),
              if (_showGameOver)
                _GameOverOverlay(
                  game: g,
                  newAchievements: _newAchievements,
                  onRetry: _restart,
                  onHome: _goHome,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHud(EggDashGame g) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: _frame,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RoundIconButton(icon: Icons.pause_rounded, onTap: _pause),
                const SizedBox(width: 10),
                Flexible(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _HudChip(
                        icon: Assets.chickenIdle[_gs.selectedChicken],
                        label: '${g.flockSize}',
                        tint: AppColors.grassGreen,
                      ),
                      _HudChip(
                        icon: Assets.coin,
                        label: '${g.coins}',
                        tint: AppColors.coinGold,
                      ),
                      _HudChip(
                        icon: Assets.egg,
                        label: '${g.eggsCollected}',
                        tint: AppColors.skyTop,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _DistanceBanner(distance: g.distance),
                    if (g.activePower != PowerUp.none) ...[
                      const SizedBox(height: 6),
                      _PowerIndicator(
                        power: g.activePower,
                        fraction: g.powerFraction,
                      ),
                    ],
                    if (g.shields > 0) ...[
                      const SizedBox(height: 6),
                      _ShieldPill(count: g.shields),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PowerIndicator extends StatelessWidget {
  const _PowerIndicator({required this.power, required this.fraction});
  final PowerUp power;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final color = GamePainter.powerColor(power);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(GamePainter.powerIcon(power), color: color, size: 20),
          const SizedBox(width: 6),
          SizedBox(
            width: 72,
            height: 8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                backgroundColor: color.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({
    required this.icon,
    required this.label,
    this.tint = AppColors.sunYellow,
  });
  final String icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, AppColors.paperDeep],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            offset: const Offset(0, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tint.withValues(alpha: 0.18),
              border: Border.all(color: tint.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Image.asset(icon, width: 20, height: 20),
          ),
          const SizedBox(width: 6),
          Text(label, style: AppText.body(16, color: AppColors.textDark)),
        ],
      ),
    );
  }
}

class _DistanceBanner extends StatelessWidget {
  const _DistanceBanner({required this.distance});
  final int distance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 5, 16, 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xF2223A52), Color(0xF20E1C2B)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            offset: const Offset(0, 4),
            blurRadius: 9,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.straighten_rounded,
              color: AppColors.sunYellow, size: 20),
          const SizedBox(width: 7),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: '$distance', style: AppText.title(28)),
                TextSpan(
                    text: ' m',
                    style: AppText.title(15, color: AppColors.sunYellow)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShieldPill extends StatelessWidget {
  const _ShieldPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF66C2FF), Color(0xFF2FA8F7)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            offset: const Offset(0, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 4),
          Text('x$count', style: AppText.body(15, color: Colors.white)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overlays
// ---------------------------------------------------------------------------
class _OverlayScrim extends StatelessWidget {
  const _OverlayScrim({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        alignment: Alignment.center,
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({
    required this.onResume,
    required this.onRestart,
    required this.onHome,
    required this.onSettings,
  });
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onHome;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return _OverlayScrim(
      child: EggPanel(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Paused', style: AppText.title(30, color: AppColors.textDark)),
            const SizedBox(height: 18),
            EggButton(onTap: onResume, width: 240, height: 52, child: Text('Resume', style: AppText.title(20))),
            const SizedBox(height: 10),
            EggButton(
              onTap: onSettings,
              width: 240,
              height: 52,
              gradient: AppGradients.sunButton,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.settings_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text('Settings', style: AppText.title(20)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            EggButton(
              onTap: onRestart,
              width: 240,
              height: 52,
              gradient: AppGradients.sky,
              child: Text('Restart', style: AppText.title(20)),
            ),
            const SizedBox(height: 10),
            EggButton(
              onTap: onHome,
              width: 240,
              height: 52,
              color: AppColors.locked,
              child: Text('Home', style: AppText.title(20)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviveOverlay extends StatelessWidget {
  const _ReviveOverlay({required this.onRevive, required this.onDecline});
  final VoidCallback onRevive;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return _OverlayScrim(
      child: EggPanel(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(Assets.goldenEgg, width: 70, height: 70),
            const SizedBox(height: 8),
            Text('Second Wind!',
                style: AppText.title(26, color: AppColors.textDark)),
            const SizedBox(height: 6),
            Text('Revive your flock and keep dashing?',
                style: AppText.body(15), textAlign: TextAlign.center),
            const SizedBox(height: 18),
            EggButton(
                onTap: onRevive,
                width: 240,
                child: Text('Revive', style: AppText.title(20))),
            const SizedBox(height: 12),
            EggButton(
              onTap: onDecline,
              width: 240,
              color: AppColors.locked,
              child: Text('No thanks', style: AppText.title(18)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({
    required this.game,
    required this.newAchievements,
    required this.onRetry,
    required this.onHome,
  });
  final EggDashGame game;
  final List<String> newAchievements;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final isBest = game.distance >= gs.bestDistance && game.distance > 0;
    return _OverlayScrim(
      child: EggPanel(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Run Complete',
                      style: AppText.title(24, color: AppColors.textDark)),
                  if (isBest) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.combRed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('BEST',
                          style: AppText.body(12, color: Colors.white)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              // All earnings on a single compact line.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _stat(Assets.finish, '${game.distance}m'),
                  _stat(Assets.chickenIdle[gs.selectedChicken],
                      'x${game.maxFlock}'),
                  _stat(Assets.coin, '+${game.coins}'),
                  _stat(Assets.egg, '+${game.eggsCollected}'),
                ],
              ),
              if (newAchievements.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Unlocked: ${newAchievements.map((id) => Achievements.all.firstWhere((e) => e.id == id).name).join(', ')}',
                  style: AppText.body(13, color: AppColors.sunYellowDark),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  EggButton(
                    onTap: onHome,
                    width: 150,
                    height: 50,
                    color: AppColors.locked,
                    child: Text('Home', style: AppText.title(18)),
                  ),
                  const SizedBox(width: 14),
                  EggButton(
                    onTap: onRetry,
                    width: 150,
                    height: 50,
                    child: Text('Retry', style: AppText.title(18)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(icon, width: 30, height: 30),
        const SizedBox(width: 4),
        Text(value, style: AppText.title(19, color: AppColors.textDark)),
      ],
    );
  }
}
