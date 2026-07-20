import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/assets.dart';
import '../core/game_state.dart';
import '../core/theme.dart';
import '../core/upgrades.dart';
import '../widgets/common.dart';

/// Screen #8 — spend coins on permanent upgrades that improve every run.
class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    return SkyScaffold(
      title: 'Upgrades',
      onBack: () => Navigator.of(context).pop(),
      showEggs: false,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.6,
          children: [
            for (final u in Upgrades.all)
              _UpgradeCard(
                def: u,
                level: gs.upgradeLevelOf(u.type),
                canBuy: gs.canBuyUpgrade(u.type),
                onBuy: () => gs.buyUpgrade(u.type),
              ),
          ],
        ),
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({
    required this.def,
    required this.level,
    required this.canBuy,
    required this.onBuy,
  });
  final UpgradeDef def;
  final int level;
  final bool canBuy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final maxed = level >= def.maxLevel;
    return EggPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Image.asset(def.icon, width: 46, height: 46),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(def.name,
                    style: AppText.title(16, color: AppColors.textDark)),
                Text(def.description,
                    style: AppText.body(11, color: AppColors.textDark),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                _levelBar(),
              ],
            ),
          ),
          const SizedBox(width: 8),
          maxed
              ? Text('MAX',
                  style: AppText.title(15, color: AppColors.grassGreen))
              : EggButton(
                  onTap: onBuy,
                  enabled: canBuy,
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(Assets.coin, width: 20, height: 20),
                      const SizedBox(width: 3),
                      Text('${def.costFor(level)}',
                          style: AppText.title(15)),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _levelBar() {
    return Row(
      children: [
        for (int i = 0; i < def.maxLevel; i++)
          Expanded(
            child: Container(
              height: 8,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: i < level ? AppColors.sunYellow : AppColors.locked,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
      ],
    );
  }
}
