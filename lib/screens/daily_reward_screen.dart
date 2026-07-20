import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/audio.dart';
import '../core/game_state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Screen #12 — spin the daily wheel once per day for a currency reward.
class DailyRewardScreen extends StatefulWidget {
  const DailyRewardScreen({super.key});

  @override
  State<DailyRewardScreen> createState() => _DailyRewardScreenState();
}

class _DailyRewardScreenState extends State<DailyRewardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  double _angle = 0;
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static const List<Color> _segColors = [
    AppColors.sunYellow,
    AppColors.skyTop,
    AppColors.featherTeal,
    AppColors.sunYellowDark,
    AppColors.crystalPurple,
    AppColors.grassGreen,
  ];

  Future<void> _spin(GameState gs) async {
    if (_spinning || !gs.canClaimDaily) return;
    final wheel = gs.dailyWheel;
    final n = wheel.length;
    final target = Random().nextInt(n);
    final seg = 2 * pi / n;
    // Land the chosen segment's centre under the top pointer.
    final base = _angle % (2 * pi);
    final desired = (3 * 2 * pi) + (2 * pi - (target * seg + seg / 2));
    final end = _angle - base + desired;

    setState(() => _spinning = true);
    final anim = Tween<double>(begin: _angle, end: end).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    void listener() => setState(() => _angle = anim.value);
    anim.addListener(listener);
    await _ctrl.forward(from: 0);
    anim.removeListener(listener);

    if (!mounted) return;
    final reward = wheel[target];
    gs.commitDaily(reward);
    AudioManager.instance.play(Sfx.reward);
    setState(() => _spinning = false);
    _showReward(reward);
  }

  void _showReward(DailyReward reward) {
    final label = switch (reward.type) {
      'coins' => '${reward.amount} Coins',
      'eggs' => '${reward.amount} Eggs',
      'feathers' => '${reward.amount} Feathers',
      _ => '${reward.amount} Crystals',
    };
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: EggPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('You won!',
                  style: AppText.title(24, color: AppColors.textDark)),
              const SizedBox(height: 8),
              Text(label,
                  style: AppText.title(22, color: AppColors.sunYellowDark)),
              const SizedBox(height: 14),
              EggButton(
                onTap: () => Navigator.of(context).pop(),
                child: Text('Collect', style: AppText.title(18)),
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
    final can = gs.canClaimDaily;
    return SkyScaffold(
      title: 'Daily Reward',
      onBack: () => Navigator.of(context).pop(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Size the wheel to whatever vertical room is available so the
          // layout never overflows on short landscape screens.
          final double wheel = (constraints.maxHeight - 130)
              .clamp(150.0, 260.0)
              .clamp(0.0, constraints.maxWidth - 24)
              .toDouble();
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Streak: ${gs.dailyStreak} days',
                        style: AppText.title(18)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: wheel,
                      height: wheel,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.rotate(
                            angle: _angle,
                            child: CustomPaint(
                              size: Size(wheel, wheel),
                              painter: _WheelPainter(
                                segments: gs.dailyWheel,
                                colors: _segColors,
                              ),
                            ),
                          ),
                          const Positioned(
                            top: -6,
                            child: Icon(Icons.arrow_drop_down,
                                size: 48, color: AppColors.combRed),
                          ),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.sunYellowDark, width: 3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    EggButton(
                      onTap: () => _spin(gs),
                      enabled: can && !_spinning,
                      width: 220,
                      height: 56,
                      child: Text(can ? 'SPIN' : 'Come back tomorrow',
                          style: AppText.title(can ? 22 : 15)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.segments, required this.colors});
  final List<DailyReward> segments;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final n = segments.length;
    final seg = 2 * pi / n;

    for (int i = 0; i < n; i++) {
      final paint = Paint()..color = colors[i % colors.length];
      final start = i * seg - pi / 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        seg,
        true,
        paint,
      );
      // Segment label.
      final mid = start + seg / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: _label(segments[i]),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
            shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final lr = radius * 0.6;
      final pos = Offset(
        center.dx + cos(mid) * lr - tp.width / 2,
        center.dy + sin(mid) * lr - tp.height / 2,
      );
      tp.paint(canvas, pos);
    }
    // Outer ring.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Colors.white,
    );
  }

  String _label(DailyReward r) {
    final t = switch (r.type) {
      'coins' => 'Coins',
      'eggs' => 'Eggs',
      'feathers' => 'Feath',
      _ => 'Gem',
    };
    return '${r.amount}\n$t';
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => false;
}
