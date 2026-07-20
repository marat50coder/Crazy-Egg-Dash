import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/assets.dart';
import '../core/game_state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'game_screen.dart';

/// Screen #3 — pick a zone to dash through. Zones unlock as the player pushes
/// their distance further; the run itself cycles scenery automatically.
class WorldMapScreen extends StatelessWidget {
  const WorldMapScreen({super.key});

  static const List<String> zoneNames = [
    'Sunny Farm',
    'Green Forest',
    'Rocky Hills',
    'Old Factory',
    'Egg Moon',
  ];

  void _play(BuildContext context) {
    Navigator.of(context).push(
      fadeThroughRoute(const GameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    return SkyScaffold(
      title: 'Choose a Zone',
      onBack: () => Navigator.of(context).pop(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: GameState.totalZones,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (context, i) {
            final unlocked = i < gs.zonesUnlocked;
            return _ZoneCard(
              index: i,
              name: zoneNames[i],
              unlocked: unlocked,
              onPlay: () => _play(context),
            );
          },
        ),
      ),
    );
  }
}

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({
    required this.index,
    required this.name,
    required this.unlocked,
    required this.onPlay,
  });
  final int index;
  final String name;
  final bool unlocked;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: EggPanel(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(Assets.backgrounds[index], fit: BoxFit.cover),
                    if (!unlocked)
                      Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        alignment: Alignment.center,
                        child: const Icon(Icons.lock_rounded,
                            color: Colors.white, size: 44),
                      ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(name, style: AppText.title(16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (unlocked)
              EggButton(
                onTap: onPlay,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow_rounded, color: Colors.white),
                    Text('Start', style: AppText.title(18)),
                  ],
                ),
              )
            else
              Text('Reach ${index * 600} m to unlock',
                  style: AppText.body(13, color: AppColors.textDark),
                  textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
