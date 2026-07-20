import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/chicken_data.dart';
import '../core/game_state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Screen #7 — the collection of chicken breeds. Owned breeds show their level
/// and can be set as the flock leader; locked breeds are silhouetted.
class CoopScreen extends StatelessWidget {
  const CoopScreen({super.key});

  Color _rarityColor(Rarity r) => switch (r) {
        Rarity.common => AppColors.grassGreen,
        Rarity.rare => AppColors.skyTop,
        Rarity.epic => AppColors.crystalPurple,
        Rarity.legendary => AppColors.sunYellowDark,
      };

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    return SkyScaffold(
      title: 'Coop',
      onBack: () => Navigator.of(context).pop(),
      showEggs: false,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Collected ${gs.ownedCount}/${ChickenRoster.all.length}',
                style: AppText.title(18)),
            const SizedBox(height: 10),
            Expanded(
              child: GridView.count(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
                children: [
                  for (final s in ChickenRoster.all)
                    _ChickenCard(
                      species: s,
                      owned: gs.isOwned(s.id),
                      level: gs.levelOf(s.id),
                      shards: gs.shardsOf(s.id),
                      selected: gs.selectedChicken == s.id,
                      rarityColor: _rarityColor(s.rarity),
                      onSelect: () => gs.selectChicken(s.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChickenCard extends StatelessWidget {
  const _ChickenCard({
    required this.species,
    required this.owned,
    required this.level,
    required this.shards,
    required this.selected,
    required this.rarityColor,
    required this.onSelect,
  });
  final ChickenSpecies species;
  final bool owned;
  final int level;
  final int shards;
  final bool selected;
  final Color rarityColor;
  final VoidCallback onSelect;

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: EggPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(species.idleAsset, width: 110, height: 110),
              Text(species.name,
                  style: AppText.title(24, color: AppColors.textDark)),
              Text(species.title,
                  style: AppText.body(14, color: rarityColor)),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: rarityColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(species.rarity.label,
                    style: AppText.body(12, color: Colors.white)),
              ),
              const SizedBox(height: 10),
              Text(species.perk,
                  style: AppText.body(14), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              if (owned)
                Text('Level $level   •   Shards: $shards',
                    style: AppText.body(13, color: AppColors.textDark)),
              const SizedBox(height: 14),
              if (owned && !selected)
                EggButton(
                  onTap: () {
                    onSelect();
                    Navigator.of(context).pop();
                  },
                  child: Text('Set as Leader', style: AppText.title(16)),
                )
              else if (selected)
                Text('Current Leader',
                    style: AppText.body(15, color: AppColors.grassGreen)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppGradients.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.sunYellow : Colors.white,
            width: selected ? 4 : 3,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.panelShadow,
              offset: Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: ColorFiltered(
                colorFilter: owned
                    ? const ColorFilter.mode(
                        Colors.transparent, BlendMode.multiply)
                    : const ColorFilter.mode(
                        Color(0xFF3A2A16), BlendMode.srcATop),
                child: Image.asset(species.idleAsset),
              ),
            ),
            Text(owned ? species.name : '???',
                style: AppText.body(13), maxLines: 1),
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: owned ? rarityColor : AppColors.locked,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                owned ? 'Lv $level' : species.rarity.label,
                style: AppText.body(11, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
