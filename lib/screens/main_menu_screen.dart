import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/chicken_data.dart';
import '../core/game_state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'achievements_screen.dart';
import 'coop_screen.dart';
import 'daily_reward_screen.dart';
import 'fusion_screen.dart';
import 'incubator_screen.dart';
import 'quests_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'upgrade_screen.dart';
import 'world_map_screen.dart';

/// Screen #2 — the hub the player returns to between runs.
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  void _go(BuildContext context, Widget screen) {
    Navigator.of(context).push(fadeThroughRoute(screen));
  }

  Color _rarityColor(Rarity r) => switch (r) {
        Rarity.common => AppColors.grassGreen,
        Rarity.rare => AppColors.skyTop,
        Rarity.epic => AppColors.crystalPurple,
        Rarity.legendary => AppColors.sunYellowDark,
      };

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final leader = ChickenRoster.byId(gs.selectedChicken);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MenuBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      _DailyBadge(
                        canClaim: gs.canClaimDaily,
                        onTap: () => _go(context, const DailyRewardScreen()),
                      ),
                      const Spacer(),
                      const CurrencyBar(),
                      const SizedBox(width: 8),
                      RoundIconButton(
                        icon: Icons.settings_rounded,
                        onTap: () => _go(context, const SettingsScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _leftPanel(context, leader),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 5,
                          child: _rightPanel(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leftPanel(BuildContext context, ChickenSpecies leader) {
    final gs = context.watch<GameState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title lockup.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xE6FFFFFF), Color(0xB3FFFFFF)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                  color: AppColors.panelShadow,
                  offset: Offset(0, 4),
                  blurRadius: 10),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                        text: 'CRAZY EGG ',
                        style: AppText.title(30, color: AppColors.skyTop)),
                    TextSpan(
                        text: 'DASH',
                        style:
                            AppText.title(30, color: AppColors.sunYellowDark)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text('Grow your flock. Dodge everything.',
              style: AppText.body(14, color: AppColors.textLight)),
        ),
        const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _LeaderCard(
              leader: leader,
              rarityColor: _rarityColor(leader.rarity),
              onTap: () => _go(context, const CoopScreen()),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: EggButton(
                height: 84,
                onTap: () => _go(context, const WorldMapScreen()),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 44),
                    Text('PLAY', style: AppText.title(34)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _statPill(Icons.emoji_events_rounded, 'Best  ${gs.bestDistance} m'),
            const SizedBox(width: 8),
            _statPill(Icons.pets_rounded,
                'Flock  ${gs.ownedCount}/${ChickenRoster.all.length}'),
          ],
        ),
      ],
    );
  }

  Widget _statPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, AppColors.paperDeep],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
              color: Color(0x335A3A12), offset: Offset(0, 3), blurRadius: 6),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.sunButton,
            ),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 7),
          Text(text, style: AppText.body(13, color: AppColors.textDark)),
        ],
      ),
    );
  }

  Widget _rightPanel(BuildContext context) {
    final rows = <List<_MenuData>>[
      [
        _MenuData('Coop', Icons.pets_rounded, const Color(0xFF6BBF3A),
            () => const CoopScreen()),
        _MenuData('Upgrade', Icons.trending_up_rounded,
            const Color(0xFF2FA8F7), () => const UpgradeScreen()),
      ],
      [
        _MenuData('Incubator', Icons.egg_rounded, const Color(0xFFF5A623),
            () => const IncubatorScreen()),
        _MenuData('Fusion', Icons.auto_awesome_rounded,
            const Color(0xFF9B6BF0), () => const FusionScreen()),
      ],
      [
        _MenuData('Shop', Icons.storefront_rounded, const Color(0xFFE8412E),
            () => const ShopScreen()),
        _MenuData('Quests', Icons.task_alt_rounded, const Color(0xFF37C7B8),
            () => const QuestsScreen()),
      ],
      [
        _MenuData('Awards', Icons.emoji_events_rounded,
            const Color(0xFFFFC627), () => const AchievementsScreen()),
        _MenuData('Daily', Icons.card_giftcard_rounded,
            const Color(0xFFE86AA6), () => const DailyRewardScreen()),
      ],
    ];
    return EggPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          for (int r = 0; r < rows.length; r++) ...[
            Expanded(
              child: Row(
                children: [
                  for (int c = 0; c < rows[r].length; c++) ...[
                    Expanded(
                      child: _MenuTile(
                        data: rows[r][c],
                        onTap: () => _go(context, rows[r][c].builder()),
                      ),
                    ),
                    if (c == 0) const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
            if (r < rows.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _MenuData {
  _MenuData(this.label, this.icon, this.color, this.builder);
  final String label;
  final IconData icon;
  final Color color;
  final Widget Function() builder;
}

class _MenuTile extends StatefulWidget {
  const _MenuTile({required this.data, required this.onTap});
  final _MenuData data;
  final VoidCallback onTap;

  @override
  State<_MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<_MenuTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final edge = Color.lerp(data.color, Colors.black, 0.34)!;
    final depth = _down ? 2.0 : 6.0;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _down ? 3 : 0, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(data.color, Colors.white, 0.18)!,
              Color.lerp(data.color, Colors.black, 0.12)!,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            // Candy 3D base edge.
            BoxShadow(color: edge, offset: Offset(0, depth), blurRadius: 0),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              offset: Offset(0, depth + 2),
              blurRadius: 9,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Stack(
          children: [
            // Glossy top highlight.
            Positioned(
              top: 5,
              left: 6,
              right: 6,
              child: IgnorePointer(
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.5),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                SizedBox(
                  width: 46,
                  height: 46,
                  child: Icon(data.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    data.label,
                    style: AppText.title(18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.8)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderCard extends StatelessWidget {
  const _LeaderCard({
    required this.leader,
    required this.rarityColor,
    required this.onTap,
  });
  final ChickenSpecies leader;
  final Color rarityColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 108,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: AppGradients.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: rarityColor, width: 3),
          boxShadow: const [
            BoxShadow(
                color: AppColors.panelShadow,
                offset: Offset(0, 4),
                blurRadius: 8),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(leader.idleAsset, width: 64, height: 64),
            Text(leader.name,
                style: AppText.body(14, color: AppColors.textDark),
                maxLines: 1),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: rarityColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('CHANGE',
                  style: AppText.body(10, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyBadge extends StatelessWidget {
  const _DailyBadge({required this.canClaim, required this.onTap});
  final bool canClaim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: canClaim
                ? [const Color(0xFFFF6B57), AppColors.combRed]
                : [Colors.white60, Colors.white38],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: (canClaim ? AppColors.combRed : Colors.black)
                  .withValues(alpha: 0.3),
              offset: const Offset(0, 3),
              blurRadius: 7,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.card_giftcard_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 6),
            Text(canClaim ? 'Daily Gift!' : 'Daily',
                style: AppText.body(14, color: Colors.white)),
            if (canClaim) ...[
              const SizedBox(width: 6),
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
