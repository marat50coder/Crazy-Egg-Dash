import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/assets.dart';
import '../core/chicken_data.dart';
import '../core/game_state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Screen #10 — level chickens up by spending duplicate shards plus coins.
/// Higher levels contribute stronger passive bonuses to every run.
class FusionScreen extends StatelessWidget {
  const FusionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final owned =
        ChickenRoster.all.where((s) => gs.isOwned(s.id)).toList();
    return SkyScaffold(
      title: 'Fusion',
      onBack: () => Navigator.of(context).pop(),
      showEggs: false,
      child: owned.isEmpty
          ? Center(
              child: Text('Hatch chickens first!',
                  style: AppText.title(20)),
            )
          : Padding(
              padding: const EdgeInsets.all(14),
              child: ListView.separated(
                itemCount: owned.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final s = owned[i];
                  return _FusionRow(
                    species: s,
                    level: gs.levelOf(s.id),
                    shards: gs.shardsOf(s.id),
                    needShards: gs.shardsToLevel(gs.levelOf(s.id)),
                    cost: gs.fuseCost(s.id),
                    canFuse: gs.canFuse(s.id),
                    maxed: gs.levelOf(s.id) >= GameState.maxChickenLevel,
                    onFuse: () => gs.fuse(s.id),
                  );
                },
              ),
            ),
    );
  }
}

class _FusionRow extends StatelessWidget {
  const _FusionRow({
    required this.species,
    required this.level,
    required this.shards,
    required this.needShards,
    required this.cost,
    required this.canFuse,
    required this.maxed,
    required this.onFuse,
  });
  final ChickenSpecies species;
  final int level;
  final int shards;
  final int needShards;
  final int cost;
  final bool canFuse;
  final bool maxed;
  final VoidCallback onFuse;

  @override
  Widget build(BuildContext context) {
    return EggPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Image.asset(species.idleAsset, width: 64, height: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${species.name}  •  Lv $level',
                    style: AppText.title(18, color: AppColors.textDark)),
                const SizedBox(height: 4),
                if (maxed)
                  Text('Fully evolved',
                      style: AppText.body(13, color: AppColors.grassGreen))
                else
                  Row(
                    children: [
                      Image.asset(species.idleAsset, width: 20, height: 20),
                      Text(' $shards/$needShards copies   ',
                          style: AppText.body(13, color: AppColors.textDark)),
                      Image.asset(Assets.coin, width: 20, height: 20),
                      Text(' $cost',
                          style: AppText.body(13, color: AppColors.textDark)),
                    ],
                  ),
              ],
            ),
          ),
          if (!maxed)
            EggButton(
              onTap: onFuse,
              enabled: canFuse,
              height: 50,
              child: Text('Fuse', style: AppText.title(16)),
            ),
        ],
      ),
    );
  }
}
