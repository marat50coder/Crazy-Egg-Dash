import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/assets.dart';
import '../core/game_state.dart';
import '../core/progression_defs.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Screen #14 — long-term achievements that reward crystals.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    return SkyScaffold(
      title: 'Achievements',
      onBack: () => Navigator.of(context).pop(),
      showEggs: false,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.5,
          children: [
            for (final a in Achievements.all)
              _AchievementCard(
                def: a,
                value: gs.achievementValue(a.metric),
                complete: gs.isAchievementComplete(a),
                canClaim: gs.canClaimAchievement(a),
                claimed: gs.achievementClaimed.contains(a.id),
                onClaim: () => gs.claimAchievement(a),
              ),
          ],
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.def,
    required this.value,
    required this.complete,
    required this.canClaim,
    required this.claimed,
    required this.onClaim,
  });
  final AchievementDef def;
  final int value;
  final bool complete;
  final bool canClaim;
  final bool claimed;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final progress = (value / def.target).clamp(0.0, 1.0);
    return EggPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Opacity(
            opacity: complete ? 1 : 0.5,
            child: Image.asset(def.icon, width: 46, height: 46),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(def.name,
                    style: AppText.title(15, color: AppColors.textDark)),
                Text(def.description,
                    style: AppText.body(11, color: AppColors.textDark),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.locked,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.grassGreen),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _trailing(),
        ],
      ),
    );
  }

  Widget _trailing() {
    if (claimed) {
      return const Icon(Icons.verified,
          color: AppColors.grassGreen, size: 32);
    }
    if (canClaim) {
      return EggButton(
        onTap: onClaim,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(Assets.crystal, width: 18, height: 18),
            Text(' ${def.rewardCrystals}', style: AppText.title(14)),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(Assets.crystal, width: 20, height: 20),
        Text('${def.rewardCrystals}',
            style: AppText.body(12, color: AppColors.textDark)),
      ],
    );
  }
}
