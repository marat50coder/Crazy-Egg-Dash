import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/assets.dart';
import '../core/audio.dart';
import '../core/chicken_data.dart';
import '../core/game_state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Screen #9 — spend eggs to hatch chickens. New breeds join the Coop;
/// duplicates become shards for Fusion.
class IncubatorScreen extends StatefulWidget {
  const IncubatorScreen({super.key});

  @override
  State<IncubatorScreen> createState() => _IncubatorScreenState();
}

class _IncubatorScreenState extends State<IncubatorScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wiggle;

  @override
  void initState() {
    super.initState();
    _wiggle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  Future<void> _hatch(GameState gs) async {
    final result = gs.hatchEgg();
    if (result == null) return;
    AudioManager.instance.play(Sfx.hatch);
    if (!mounted) return;
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'hatch',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (_, anim, _, _) {
        return Transform.scale(
          scale: Curves.elasticOut.transform(anim.value.clamp(0, 1)),
          child: Center(
            child: EggPanel(
              margin: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(result.isNew ? 'New Chicken!' : 'Duplicate!',
                      style: AppText.title(24, color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  Image.asset(result.species.idleAsset,
                      width: 130, height: 130),
                  Text(result.species.name,
                      style: AppText.title(22, color: AppColors.textDark)),
                  Text(result.species.rarity.label,
                      style: AppText.body(14, color: AppColors.sunYellowDark)),
                  const SizedBox(height: 6),
                  Text(
                    result.isNew
                        ? 'Joined your flock!'
                        : '+1 shard for Fusion',
                    style: AppText.body(14, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 14),
                  EggButton(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text('Nice!', style: AppText.title(18)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final canHatch = gs.eggs >= gs.hatchCost;
    return SkyScaffold(
      title: 'Incubator',
      onBack: () => Navigator.of(context).pop(),
      child: Center(
        child: SingleChildScrollView(
          child: EggPanel(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Hatch an egg to grow your collection',
                    style: AppText.body(15, color: AppColors.textDark)),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _wiggle,
                  builder: (context, child) {
                    final t = (_wiggle.value - 0.5) * 2; // -1..1
                    return Transform.rotate(angle: t * 0.12, child: child);
                  },
                  child: Image.asset(Assets.egg, width: 96, height: 96),
                ),
                const SizedBox(height: 8),
                Text('Odds: Common 55% • Rare 28% • Epic 13% • Legendary 4%',
                    style: AppText.body(12, color: AppColors.textDark),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                EggButton(
                  onTap: () => _hatch(gs),
                  enabled: canHatch,
                  width: 260,
                  height: 56,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Hatch  ', style: AppText.title(20)),
                      Image.asset(Assets.egg, width: 26, height: 26),
                      Text(' ${gs.hatchCost}', style: AppText.title(20)),
                    ],
                  ),
                ),
                if (!canHatch) ...[
                  const SizedBox(height: 6),
                  Text('Collect more eggs by dashing!',
                      style: AppText.body(13, color: AppColors.combRed)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
