import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../core/game_state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'webview_screen.dart';

/// Screen #15 — audio/haptics toggles, legal pages and progress reset.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _openLegal(BuildContext context, LegalPage page) {
    Navigator.of(context).push(
      fadeThroughRoute(WebViewScreen(page: page)),
    );
  }

  void _confirmReset(BuildContext context, GameState gs) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: EggPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Reset Progress?',
                  style: AppText.title(22, color: AppColors.textDark)),
              const SizedBox(height: 8),
              Text('This erases all coins, chickens and upgrades.',
                  style: AppText.body(14, color: AppColors.textDark),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  EggButton(
                    onTap: () => Navigator.of(context).pop(),
                    color: AppColors.locked,
                    width: 120,
                    child: Text('Cancel', style: AppText.title(16)),
                  ),
                  const SizedBox(width: 12),
                  EggButton(
                    onTap: () {
                      gs.resetProgress();
                      Navigator.of(context).pop();
                    },
                    color: AppColors.danger,
                    width: 120,
                    child: Text('Reset', style: AppText.title(16)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    return SkyScaffold(
      title: 'Settings',
      onBack: () => Navigator.of(context).pop(),
      showCurrency: false,
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: EggPanel(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _toggle('Music', gs.musicOn, gs.setMusic),
                  if (gs.musicOn)
                    _volume('Music Volume', Icons.music_note_rounded,
                        gs.musicVolume, gs.setMusicVolume),
                  _toggle('Sound Effects', gs.soundOn, gs.setSound),
                  if (gs.soundOn)
                    _volume('Sound Volume', Icons.volume_up_rounded,
                        gs.soundVolume, gs.setSoundVolume),
                  _toggle('Vibration', gs.vibrationOn, gs.setVibration),
                  const Divider(height: 28),
                  _link(context, 'Privacy Policy', Icons.privacy_tip_rounded,
                      () => _openLegal(context, LegalPage.privacy)),
                  const SizedBox(height: 10),
                  _link(context, 'Support', Icons.help_center_rounded,
                      () => _openLegal(context, LegalPage.support)),
                  const Divider(height: 28),
                  EggButton(
                    onTap: () => _confirmReset(context, gs),
                    color: AppColors.danger,
                    width: double.infinity,
                    child: Text('Reset Progress', style: AppText.title(16)),
                  ),
                  const SizedBox(height: 14),
                  Text('${AppConfig.appName}  •  v1.0.0',
                      style: AppText.body(12, color: AppColors.textDark)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: AppText.title(17, color: AppColors.textDark)),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.grassGreen,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _volume(
      String label, IconData icon, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 4, bottom: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.sunYellowDark, size: 20),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: Text(label,
                style: AppText.body(14, color: AppColors.textDark)),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(0.0, 1.0),
              activeColor: AppColors.grassGreen,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text('${(value * 100).round()}%',
                textAlign: TextAlign.right,
                style: AppText.body(13, color: AppColors.textDark)),
          ),
        ],
      ),
    );
  }

  Widget _link(
      BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.skyBottom.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.sunYellowDark),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: AppText.title(16, color: AppColors.textDark)),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textDark),
          ],
        ),
      ),
    );
  }
}
