import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/assets.dart';
import '../core/game_state.dart';
import '../core/progression_defs.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Screen #13 — three daily quests that refresh every day.
class QuestsScreen extends StatelessWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    gs.ensureDailyQuests();
    return SkyScaffold(
      title: 'Daily Quests',
      onBack: () => Navigator.of(context).pop(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('New quests every day. Complete them for rewards!',
                style: AppText.body(14, color: AppColors.textLight)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: gs.dailyQuestIds.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final id = gs.dailyQuestIds[i];
                  final def = Quests.byId(id);
                  final progress = (gs.questProgress[id] ?? 0)
                      .clamp(0, def.target);
                  return _QuestRow(
                    def: def,
                    progress: progress,
                    complete: gs.isQuestComplete(id),
                    claimed: gs.isQuestClaimed(id),
                    onClaim: () => gs.claimQuest(id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({
    required this.def,
    required this.progress,
    required this.complete,
    required this.claimed,
    required this.onClaim,
  });
  final QuestDef def;
  final int progress;
  final bool complete;
  final bool claimed;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return EggPanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.description,
                    style: AppText.title(16, color: AppColors.textDark)),
                const SizedBox(height: 8),
                EggProgressBar(
                  value: def.target == 0 ? 0 : progress / def.target,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('$progress/${def.target}',
                        style: AppText.body(12, color: AppColors.textDark)),
                    const Spacer(),
                    Image.asset(Assets.coin, width: 16, height: 16),
                    Text(' ${def.rewardCoins}  ',
                        style: AppText.body(12, color: AppColors.textDark)),
                    Image.asset(Assets.feather, width: 16, height: 16),
                    Text(' ${def.rewardFeathers}',
                        style: AppText.body(12, color: AppColors.textDark)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          claimed
              ? const Icon(Icons.check_circle,
                  color: AppColors.grassGreen, size: 36)
              : EggButton(
                  onTap: onClaim,
                  enabled: complete,
                  height: 46,
                  child: Text('Claim', style: AppText.title(15)),
                ),
        ],
      ),
    );
  }
}
