import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/assets.dart';
import '../core/theme.dart';
import 'egg_dash_game.dart';
import 'game_images.dart';

/// Draws the entire game world each frame from [EggDashGame] state.
class GamePainter extends CustomPainter {
  GamePainter({required this.game, required this.images, required this.repaint})
      : super(repaint: repaint);

  final EggDashGame game;
  final GameImages images;
  final Listenable repaint;

  static const int _maxRenderedFlock = 60;

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawGround(canvas, size);
    _drawPits(canvas, size);
    _drawClouds(canvas, size);
    _drawCoins(canvas);
    _drawEggs(canvas);
    _drawObstacles(canvas);
    _drawTraps(canvas);
    _drawCrates(canvas);
    _drawFlock(canvas);
    _drawPowerAura(canvas);
    _drawDying(canvas);
  }

  void _img(Canvas canvas, String key, Rect dst, {double opacity = 1}) {
    final image = images[key];
    if (image == null) return;
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (opacity < 1) paint.color = Colors.white.withValues(alpha: opacity);
    canvas.drawImageRect(image, src, dst, paint);
  }

  void _drawBackground(Canvas canvas, Size size) {
    // Sky fallback while an image is missing.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = AppGradients.sky.createShader(Offset.zero & size),
    );
    // Current background, then the next one faded in on top (crossfade).
    _drawBgLayer(canvas, size, game.zone, 1);
    if (game.zoneFade > 0 && game.nextZone != game.zone) {
      _drawBgLayer(canvas, size, game.nextZone, game.zoneFade.clamp(0.0, 1.0));
    }
  }

  void _drawBgLayer(Canvas canvas, Size size, int zoneIndex, double opacity) {
    final key = Assets.backgrounds[zoneIndex % Assets.backgrounds.length];
    final image = images[key];
    if (image == null) return;
    // Static, screen-filling background (cover fit) — no horizontal scroll, so
    // there's no visible seam. Motion is conveyed by the moving ground; zones
    // change via crossfade only.
    final imgAspect = image.width / image.height;
    final scrAspect = size.width / size.height;
    double sx, sy, sw, sh;
    if (imgAspect > scrAspect) {
      sh = image.height.toDouble();
      sw = sh * scrAspect;
      sx = (image.width - sw) / 2;
      sy = 0;
    } else {
      sw = image.width.toDouble();
      sh = sw / scrAspect;
      sx = 0;
      sy = (image.height - sh) / 2;
    }
    final src = Rect.fromLTWH(sx, sy, sw, sh);
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (opacity < 1) paint.color = Colors.white.withValues(alpha: opacity);
    canvas.drawImageRect(image, src, Offset.zero & size, paint);
  }

  void _drawPits(Canvas canvas, Size size) {
    if (game.pits.isEmpty) return;
    final gy = game.groundY;
    final bandH = size.height - gy;
    for (final p in game.pits) {
      final rect = Rect.fromLTWH(p.x, gy, p.w, bandH);
      // A rounded opening so it clearly reads as a hole cut into the ground.
      final rr = RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.circular(p.w * 0.16),
        topRight: Radius.circular(p.w * 0.16),
      );

      canvas.save();
      canvas.clipRRect(rr);

      // Abyss fill: dark earth fading to black at the bottom.
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3A2410), Color(0xFF070302)],
          ).createShader(rect),
      );

      // Earthen side walls give the hole depth/perspective.
      final wallW = p.w * 0.24;
      final leftWall = Rect.fromLTWH(p.x, gy, wallW, bandH);
      canvas.drawRect(
        leftWall,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xCC7A4A22), Color(0x00000000)],
          ).createShader(leftWall),
      );
      final rightWall = Rect.fromLTWH(p.x + p.w - wallW, gy, wallW, bandH);
      canvas.drawRect(
        rightWall,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [Color(0xCC7A4A22), Color(0x00000000)],
          ).createShader(rightWall),
      );

      // Strong shadow just under the front lip.
      final lipRect = Rect.fromLTWH(p.x, gy, p.w, bandH * 0.42);
      canvas.drawRect(
        lipRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.65), Colors.transparent],
          ).createShader(lipRect),
      );
      canvas.restore();

      // Overhanging grass edges curling into the hole (drawn over the ground).
      final lipDrop = bandH * 0.16;
      final lipReach = p.w * 0.20;
      final grass = Paint()..color = const Color(0xFF5FA22E);
      final grassEdge = Paint()..color = const Color(0xFF3E7A1E);
      final leftLip = Path()
        ..moveTo(p.x - 1, gy)
        ..lineTo(p.x + lipReach, gy)
        ..quadraticBezierTo(
            p.x + lipReach * 0.3, gy + lipDrop * 0.6, p.x - 1, gy + lipDrop)
        ..close();
      final rightLip = Path()
        ..moveTo(p.x + p.w + 1, gy)
        ..lineTo(p.x + p.w - lipReach, gy)
        ..quadraticBezierTo(p.x + p.w - lipReach * 0.3, gy + lipDrop * 0.6,
            p.x + p.w + 1, gy + lipDrop)
        ..close();
      canvas.drawPath(leftLip, grass);
      canvas.drawPath(rightLip, grass);
      // Thin darker grass edge line along the rim.
      canvas.drawRect(Rect.fromLTWH(p.x - 1, gy, lipReach, 3), grassEdge);
      canvas.drawRect(
          Rect.fromLTWH(p.x + p.w - lipReach, gy, lipReach + 1, 3), grassEdge);
    }
  }

  void _img2(Canvas canvas, ui.Image image, Rect src, Rect dst) {
    canvas.drawImageRect(
        image, src, dst, Paint()..filterQuality = FilterQuality.medium);
  }

  void _drawGround(Canvas canvas, Size size) {
    final gy = game.groundY;
    final bandH = size.height - gy;
    final grassH = bandH * 0.42;
    final soilTop = gy + grassH;

    // ---- Soil: fully procedural warm-brown earth (no asset) ------------------
    final soilRect =
        Rect.fromLTWH(0, soilTop, size.width, size.height - soilTop);
    canvas.drawRect(
      soilRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9A6531), Color(0xFF5E3A18)],
        ).createShader(soilRect),
    );
    // Subtle scrolling pebble/dirt speckle for texture.
    final specStep = size.height * 0.16;
    final specOff = game.traveled % specStep;
    final lightSpec = Paint()..color = const Color(0x22FFFFFF);
    final darkSpec = Paint()..color = const Color(0x22000000);
    for (double x = -specOff; x < size.width; x += specStep) {
      canvas.drawCircle(
          Offset(x + specStep * 0.30, soilTop + bandH * 0.30), 2.4, lightSpec);
      canvas.drawCircle(
          Offset(x + specStep * 0.68, soilTop + bandH * 0.52), 2.0, darkSpec);
      canvas.drawCircle(
          Offset(x + specStep * 0.50, soilTop + bandH * 0.74), 1.8, lightSpec);
    }

    // ---- Grass: procedural, scrolling surface on top (illusion of running) --
    final grassRect = Rect.fromLTWH(0, gy, size.width, grassH);
    canvas.drawRect(
      grassRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8BD24E), Color(0xFF5FA22E)],
        ).createShader(grassRect),
    );

    // Scalloped, slightly darker grass top edge, scrolling at world speed.
    final scallop = size.height * 0.022;
    final path = Path()..moveTo(0, gy);
    final step = scallop * 2;
    final offset = game.traveled % step;
    for (double x = -offset; x < size.width + step; x += step) {
      path.arcToPoint(
        Offset(x + step, gy),
        radius: Radius.circular(scallop),
        clockwise: true,
      );
    }
    path
      ..lineTo(size.width, gy + scallop)
      ..lineTo(0, gy + scallop)
      ..close();
    canvas.save();
    canvas.translate(0, -scallop * 0.5);
    canvas.drawPath(path, Paint()..color = const Color(0xFF6FB83A));
    canvas.restore();

    // Bright highlight line + a soft shadow where grass meets the dirt.
    canvas.drawRect(
      Rect.fromLTWH(0, gy + scallop * 0.5, size.width, 3),
      Paint()..color = const Color(0xFF3E7A1E),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, gy + grassH - 4, size.width, 6),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );
  }

  void _drawClouds(Canvas canvas, Size size) {
    final image = images[Assets.cloud];
    if (image == null) return;
    final w = size.width * 0.22;
    final h = w * (image.height / image.width);
    final src = Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());
    for (int i = 0; i < game.clouds.length; i++) {
      final x = game.clouds[i];
      final y = size.height * (0.08 + (i % 3) * 0.08);
      _img2(canvas, image, src, Rect.fromLTWH(x, y, w, h));
    }
  }

  void _drawObstacles(Canvas canvas) {
    final gy = game.groundY;
    for (final o in game.obstacles) {
      // Nestle each prop firmly into the grass so its visible art rests on the
      // ground (sprites carry transparent padding, so a generous sink keeps
      // them from appearing to hover above the surface).
      final sink = o.h * 0.18;
      // Soft contact shadow on the grass right at the ground line.
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(o.x + o.w / 2, gy + o.h * 0.02),
          width: o.w * 0.92,
          height: o.h * 0.18,
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.25),
      );
      final dst = Rect.fromLTWH(o.x, gy - o.h + sink, o.w, o.h);
      _img(canvas, o.asset, dst);
    }
  }

  void _drawEggs(Canvas canvas) {
    final gy = game.groundY;
    final s = game.chickenSize * 0.78;
    for (final e in game.eggs) {
      if (e.collected) continue;
      final dst = Rect.fromLTWH(e.x - s / 2, gy - e.y - s, s, s);
      _img(canvas, e.asset, dst);
    }
  }

  void _drawCoins(Canvas canvas) {
    final gy = game.groundY;
    final s = game.chickenSize * 0.62;
    for (final c in game.coinItems) {
      if (c.collected) continue;
      final dst = Rect.fromLTWH(c.x - s / 2, gy - c.y - s, s, s);
      _img(canvas, Assets.coin, dst);
    }
  }

  void _drawTraps(Canvas canvas) {
    final gy = game.groundY;
    for (final t in game.traps) {
      if (t.resolved) continue;
      // Ground shadow telegraph.
      final shadowW = t.size * (t.landed ? 1.0 : 0.8);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(t.x + t.size / 2, gy - 2),
          width: shadowW,
          height: shadowW * 0.3,
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.28),
      );
      if (!t.landed || t.y > 0) {
        final dst =
            Rect.fromLTWH(t.x, gy - t.y - t.size, t.size, t.size);
        _img(canvas, Assets.rock, dst);
      }
    }
  }

  void _drawFlock(Canvas canvas) {
    final gy = game.groundY;
    final s = game.chickenSize;
    final spacing = s * 0.42;
    // When the flock tips into a pit, the whole cluster drops down the hole.
    final fall = game.falling ? game.fallOff : 0.0;

    final count = min(game.flock.length, _maxRenderedFlock);

    // Ground shadows first (so no chicken is drawn under another's shadow).
    // They shrink and fade as a chicken jumps, and vanish while falling.
    if (!game.falling) {
      for (int i = count - 1; i >= 0; i--) {
        final m = game.flock[i];
        final row = i % 3;
        final col = i ~/ 3;
        final behind =
            col * spacing + row * spacing * 0.35 + m.xJitter * spacing;
        final x = game.leaderX - behind;
        final memberYoff = i == 0 ? game.yOff : game.yOffBehind(behind);
        final rowLift = row * s * 0.09;
        final air = (memberYoff / (s * 1.4)).clamp(0.0, 1.0);
        final sw = s * (0.52 - air * 0.22);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, gy - rowLift + s * 0.02),
            width: sw,
            height: sw * 0.34,
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.22 * (1 - air * 0.6)),
        );
      }
    }

    // Draw back-to-front so the leader sits on top. Chickens form a loose
    // diagonal cluster; each follower echoes the leader's jump with a spatial
    // delay (Zombie-Tsunami wave) plus a little personal jitter.
    for (int i = count - 1; i >= 0; i--) {
      final m = game.flock[i];
      final row = i % 3;
      final col = i ~/ 3;
      final behind =
          col * spacing + row * spacing * 0.35 + m.xJitter * spacing;
      final x = game.leaderX - behind;

      final memberYoff = i == 0 ? game.yOff : game.yOffBehind(behind);
      final grounded = memberYoff <= s * 0.04 && !game.falling;
      final bob = grounded ? sin(m.bob) * s * 0.035 : 0.0;
      final wobble = sin(m.bob * 0.5) * m.yJitter * s * 0.05;
      final rowLift = row * s * 0.09;
      // Front chickens tip into the hole first (bigger drop with less lag).
      final y = gy - memberYoff - s + bob + wobble - rowLift + fall;

      final asset = grounded
          ? Assets.chickenRun[m.speciesId % Assets.chickenRun.length]
          : Assets.chickenJump[m.speciesId % Assets.chickenJump.length];
      _img(canvas, asset, Rect.fromLTWH(x - s / 2, y, s, s));
    }
  }

  void _drawDying(Canvas canvas) {
    final gy = game.groundY;
    final s = game.chickenSize;
    for (final d in game.dying) {
      final op = (1 - d.life / DyingChicken.maxLife).clamp(0.0, 1.0);
      final asset = Assets.chickenIdle[d.speciesId % Assets.chickenIdle.length];
      final image = images[asset];
      if (image == null) continue;
      final src = Rect.fromLTWH(
          0, 0, image.width.toDouble(), image.height.toDouble());
      canvas.save();
      canvas.translate(d.x, gy - d.y - s / 2);
      canvas.rotate(d.rot);
      final paint = Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Colors.white.withValues(alpha: op)
        // Redden the hit chicken.
        ..colorFilter =
            const ColorFilter.mode(Color(0xFFFF4436), BlendMode.modulate);
      canvas.drawImageRect(
          image, src, Rect.fromLTWH(-s / 2, -s / 2, s, s), paint);
      canvas.restore();
    }
  }

  // ---- Power-ups -----------------------------------------------------------
  static Color powerColor(PowerUp p) => switch (p) {
        PowerUp.fly => const Color(0xFF4FC3F7),
        PowerUp.shield => const Color(0xFF66BB6A),
        PowerUp.magnet => const Color(0xFF9575CD),
        PowerUp.none => Colors.white,
      };

  static IconData powerIcon(PowerUp p) => switch (p) {
        PowerUp.fly => Icons.flight,
        PowerUp.shield => Icons.shield,
        PowerUp.magnet => Icons.adjust,
        PowerUp.none => Icons.star,
      };

  void _drawGlyph(
      Canvas canvas, IconData icon, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawCrates(Canvas canvas) {
    final gy = game.groundY;
    final img = images[Assets.magicBox];
    final baseS = game.chickenSize * 0.85;
    for (final cr in game.crates) {
      if (cr.collected) continue;
      final bobY = sin(cr.bob) * baseS * 0.09;
      final cx = cr.x;
      final cy = gy - cr.y - baseS / 2 + bobY;
      final color = powerColor(cr.type);

      // Coloured glow (tinted to the ability) so crates pop against the world.
      canvas.drawCircle(
        Offset(cx, cy),
        baseS * 0.66,
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );

      // The magic-box sprite, drawn at its natural aspect ratio.
      if (img != null && img.height > 0) {
        final aspect = img.width / img.height;
        final w = baseS * aspect;
        final h = baseS;
        final src =
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        _img2(canvas, img, src,
            Rect.fromLTWH(cx - w / 2, cy - h / 2, w, h));
      }

      // Small ability badge in the corner so each power is recognisable.
      final bx = cx + baseS * 0.28;
      final by = cy - baseS * 0.30;
      final br = baseS * 0.22;
      canvas.drawCircle(Offset(bx, by), br, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(bx, by), br,
          Paint()..color = color.withValues(alpha: 0.22));
      canvas.drawCircle(
        Offset(bx, by),
        br,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = br * 0.22
          ..color = color,
      );
      _drawGlyph(canvas, powerIcon(cr.type), Offset(bx, by), br * 1.15, color);
    }
  }

  void _drawPowerAura(Canvas canvas) {
    final p = game.activePower;
    if (p == PowerUp.none) return;
    final gy = game.groundY;
    final s = game.chickenSize;
    final fall = game.falling ? game.fallOff : 0.0;
    final cx = game.leaderX;
    final cy = gy - game.yOff - s * 0.5 + fall;
    final color = powerColor(p);
    if (p == PowerUp.shield) {
      // Protective bubble around the flock.
      canvas.drawCircle(
          Offset(cx, cy), s * 0.8, Paint()..color = color.withValues(alpha: 0.14));
      canvas.drawCircle(
        Offset(cx, cy),
        s * 0.8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = color.withValues(alpha: 0.55),
      );
    } else if (p == PowerUp.magnet) {
      // Pulsing attraction ring.
      final pulse = 0.7 + 0.15 * sin(game.traveled * 0.05);
      canvas.drawCircle(
        Offset(cx, cy),
        s * pulse,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = color.withValues(alpha: 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => false;
}
