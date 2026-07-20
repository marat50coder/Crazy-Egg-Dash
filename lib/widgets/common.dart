import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/assets.dart';
import '../core/audio.dart';
import '../core/game_state.dart';
import '../core/theme.dart';

/// A smooth fade + gentle scale page transition, used for all menu navigation
/// so screens cross-dissolve instead of hard-cutting.
Route<T> fadeThroughRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 340),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// A chunky, cartoon-styled button with a drop shadow and press animation.
class EggButton extends StatefulWidget {
  const EggButton({
    super.key,
    required this.onTap,
    required this.child,
    this.gradient,
    this.color,
    this.height = 58,
    this.width,
    this.padding,
    this.enabled = true,
  });

  final VoidCallback onTap;
  final Widget child;
  final Gradient? gradient;
  final Color? color;
  final double height;
  final double? width;
  final EdgeInsets? padding;
  final bool enabled;

  @override
  State<EggButton> createState() => _EggButtonState();
}

class _EggButtonState extends State<EggButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final Gradient? grad = widget.color == null
        ? (widget.gradient ?? AppGradients.sunButton)
        : null;
    // The bottom "3D" edge colour is a darker shade of the button face.
    final Color face = widget.color ??
        (grad is LinearGradient ? grad.colors.last : AppColors.sunYellowDark);
    final Color edge = Color.lerp(face, Colors.black, 0.32)!;
    final double depth = _down ? 2 : 6;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTap: enabled
          ? () {
              AudioManager.instance.play(Sfx.button);
              widget.onTap();
            }
          : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          curve: Curves.easeOut,
          height: widget.height,
          width: widget.width,
          transform: Matrix4.translationValues(0, _down ? 3 : 0, 0),
          decoration: BoxDecoration(
            gradient: grad,
            color: widget.color,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              // Solid darker edge underneath = candy 3D base.
              BoxShadow(color: edge, offset: Offset(0, depth), blurRadius: 0),
              // Soft drop shadow for lift.
              BoxShadow(
                color: AppColors.panelShadow,
                offset: Offset(0, depth + 2),
                blurRadius: 10,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glossy top highlight.
              Positioned(
                top: 3,
                left: 7,
                right: 7,
                child: IgnorePointer(
                  child: Container(
                    height: widget.height * 0.42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
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
              Padding(
                padding: widget.padding ??
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small circular icon button (used for back / settings / close).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = AppColors.sunYellow,
    this.size = 48,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
              color: AppColors.panelShadow,
              offset: Offset(0, 3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }
}

/// A rounded white panel used to frame screen content.
class EggPanel extends StatelessWidget {
  const EggPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: AppGradients.panel,
        borderRadius: BorderRadius.circular(24),
        // Warm inner rim + subtle white outline for a layered card look.
        border: Border.all(color: AppColors.paperEdge, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.white,
            offset: Offset(0, 0),
            blurRadius: 0,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Color(0x3A5A3A12),
            offset: Offset(0, 10),
            blurRadius: 20,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Soft glass sheen along the top edge for a polished, glossy card.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.55),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// A rounded, glossy progress bar (green fill on a recessed track) matching the
/// premium quest/journey style. [value] is clamped to 0..1.
class EggProgressBar extends StatelessWidget {
  const EggProgressBar({
    super.key,
    required this.value,
    this.height = 18,
    this.fillStart = const Color(0xFF7ED957),
    this.fillEnd = const Color(0xFF3FA62E),
  });

  final double value;
  final double height;
  final Color fillStart;
  final Color fillEnd;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    final radius = BorderRadius.circular(height);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth * v;
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFE3D6BC),
            borderRadius: radius,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ClipRRect(
              borderRadius: radius,
              child: Container(
                width: w,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [fillStart, fillEnd],
                  ),
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: FractionallySizedBox(
                    widthFactor: 0.9,
                    heightFactor: 0.42,
                    child: Container(
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(height),
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A single currency chip (icon + amount) as used in the top HUD.
class CurrencyChip extends StatelessWidget {
  const CurrencyChip({
    super.key,
    required this.asset,
    required this.amount,
    this.onTap,
  });

  final String asset;
  final int amount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 14, 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, AppColors.paperDeep],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x335A3A12),
              offset: Offset(0, 3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.85),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Image.asset(asset, width: 22, height: 22),
            ),
            const SizedBox(width: 5),
            Text(
              _fmt(amount),
              style: AppText.body(16, color: AppColors.textDark),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.add_circle,
                  color: AppColors.grassGreen, size: 18),
            ]
          ],
        ),
      ),
    );
  }

  static String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 10000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }
}

/// The top HUD row of currency chips, wired to [GameState].
class CurrencyBar extends StatelessWidget {
  const CurrencyBar({super.key, this.showEggs = true});

  final bool showEggs;

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        CurrencyChip(asset: Assets.coin, amount: gs.coins),
        CurrencyChip(asset: Assets.feather, amount: gs.feathers),
        CurrencyChip(asset: Assets.crystal, amount: gs.crystals),
        if (showEggs) CurrencyChip(asset: Assets.egg, amount: gs.eggs),
      ],
    );
  }
}

/// Standard scaffold with the sky gradient background and an optional header.
class SkyScaffold extends StatelessWidget {
  const SkyScaffold({
    super.key,
    required this.child,
    this.title,
    this.onBack,
    this.showCurrency = true,
    this.showEggs = true,
    this.actions,
  });

  final Widget child;
  final String? title;
  final VoidCallback? onBack;
  final bool showCurrency;
  final bool showEggs;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MenuBackground(),
          SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Row(
                  children: [
                    if (onBack != null)
                      RoundIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: onBack!,
                      ),
                    if (title != null) ...[
                      const SizedBox(width: 12),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 7, 18, 9),
                          decoration: BoxDecoration(
                            gradient: AppGradients.header,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x3A5A3A12),
                                offset: Offset(0, 4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Text(
                            title!,
                            style: AppText.title(22),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    ...?actions,
                    if (showCurrency) ...[
                      if (actions != null) const SizedBox(width: 8),
                      Flexible(
                        flex: 0,
                        child: CurrencyBar(showEggs: showEggs),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
          ),
        ],
      ),
    );
  }
}

/// Shared menu/UI backdrop: the painted menu art covered edge-to-edge with a
/// layered scrim (warm top glow + cool base + corner vignette) that adds depth
/// and keeps foreground panels and text crisp and readable.
class MenuBackground extends StatelessWidget {
  const MenuBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(Assets.menuBg, fit: BoxFit.cover),
        // Vertical tone: a gentle warm glow up top, cooler and slightly darker
        // toward the bottom so content reads clearly over any artwork.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFFFF3D6).withValues(alpha: 0.28),
                Colors.transparent,
                AppColors.skyTop.withValues(alpha: 0.18),
                const Color(0xFF16324A).withValues(alpha: 0.32),
              ],
              stops: const [0.0, 0.42, 0.78, 1.0],
            ),
          ),
        ),
        // Soft corner vignette to focus the eye on the centre content.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.1,
              colors: [
                Colors.transparent,
                const Color(0xFF0A1E30).withValues(alpha: 0.28),
              ],
              stops: const [0.62, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
