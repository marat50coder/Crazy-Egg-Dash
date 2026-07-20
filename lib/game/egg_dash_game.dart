import 'dart:math';
import 'dart:ui';

import '../core/assets.dart';
import '../core/audio.dart';

enum GamePhase { ready, running, paused, dead }

enum EggKind { normal, golden, speckled }

/// One chicken in the trailing flock. Followers echo the leader's jump with a
/// spatial delay (they jump when they reach the spot the leader jumped from),
/// plus a little per-chicken jitter so the flock moves loosely, not in lockstep.
class FlockMember {
  FlockMember(this.speciesId, this.slot, Random rng)
      : bob = rng.nextDouble() * pi * 2,
        bobSpeed = 9 + rng.nextDouble() * 6,
        xJitter = (rng.nextDouble() - 0.5) * 0.5,
        yJitter = (rng.nextDouble() - 0.5) * 0.5,
        lag = rng.nextDouble();
  final int speciesId;
  final int slot; // formation index (0 = leader)
  double bob; // bobbing phase
  final double bobSpeed;
  final double xJitter; // -0.25..0.25 (fraction of spacing)
  final double yJitter; // small vertical wobble factor
  final double lag; // 0..1 extra follow lag for looseness
}

/// A chicken that just got hit: it pops up, reddens and falls away while the
/// rest of the flock keeps running (Zombie-Tsunami style).
class DyingChicken {
  DyingChicken({
    required this.x,
    required this.y,
    required this.speciesId,
    required this.rotSpeed,
    required this.vy,
  });
  double x;
  double y; // height above ground
  double vy;
  double rot = 0;
  final double rotSpeed;
  final int speciesId;
  double life = 0; // seconds elapsed
  static const double maxLife = 1.1;
  bool get dead => life >= maxLife;
}

class Obstacle {
  Obstacle({
    required this.x,
    required this.w,
    required this.h,
    required this.asset,
    required this.damage,
  });
  double x;
  final double w;
  final double h;
  final String asset;
  final int damage;
  bool hit = false;
}

class EggItem {
  EggItem({required this.x, required this.y, required this.kind});
  double x;
  double y; // height above ground
  final EggKind kind;
  bool collected = false;

  String get asset => switch (kind) {
        EggKind.normal => Assets.egg,
        EggKind.golden => Assets.goldenEgg,
        EggKind.speckled => Assets.speckledEgg,
      };
}

class CoinItem {
  CoinItem({required this.x, required this.y});
  double x;
  double y; // height above ground
  bool collected = false;
}

/// A gap in the ground. If the flock runs over it without jumping, chickens
/// fall in and die (Zombie-Tsunami style pit).
class Pit {
  Pit({required this.x, required this.w});
  double x;
  final double w;
}

/// Power-ups that can be triggered by grabbing a floating crate (Zombie-Tsunami
/// style super-abilities).
enum PowerUp {
  none,

  /// The flock takes flight — it cruises above the ground, ignoring obstacles,
  /// pits and traps, while hoovering up nearby coins and eggs.
  fly,

  /// Invincible rush — obstacles are smashed through instead of stopping the
  /// flock, and pits/traps can't hurt anyone.
  shield,

  /// Super magnet — coins and eggs are pulled in from across the screen.
  magnet,
}

/// A floating crate that grants a [PowerUp] when the leader touches it.
class PowerCrate {
  PowerCrate({required this.x, required this.y, required this.type, Random? rng})
      : bob = (rng?.nextDouble() ?? 0) * pi * 2;
  double x;
  double y; // height above ground
  final PowerUp type;
  double bob;
  bool collected = false;
}

/// A trap that drops from the sky. It telegraphs with a ground shadow, then
/// falls; if the flock is underneath (and not jumping clear) it costs chickens.
class FallingTrap {
  FallingTrap.spawn({required this.x, required this.size, required double top})
      : landY = 0,
        y = top;

  double x;
  final double landY; // ground height reference (0)
  final double size;
  double y; // current height above ground; starts high
  double vy = 0;
  bool landed = false;
  bool resolved = false;
}

/// Pure gameplay simulation. Holds no Flutter widgets — it is advanced by
/// [update] each frame and rendered by the painter. Communicates outward via
/// callbacks so the hosting screen can update the HUD and react to death.
class EggDashGame {
  EggDashGame({
    required this.speedMultiplier,
    required this.jumpMultiplier,
    required this.coinMultiplier,
    required this.magnetRadius,
    required this.startingShields,
    required this.leaderSpecies,
    this.spriteAspects = const {},
    this.onGameOver,
    this.onStatsChanged,
  });

  /// Natural width/height ratio per obstacle asset, so props are drawn and
  /// collided at their true proportions (never squashed or stretched).
  final Map<String, double> spriteAspects;

  double _aspect(String asset, double fallback) =>
      spriteAspects[asset] ?? fallback;

  // ---- External tuning coming from GameState upgrades / chickens ----------
  final double speedMultiplier;
  final double jumpMultiplier;
  final double coinMultiplier;
  final double magnetRadius;
  final int startingShields;
  final int leaderSpecies;

  final void Function()? onGameOver;
  final void Function()? onStatsChanged;

  final Random _rng = Random();

  // ---- World size ----------------------------------------------------------
  Size size = Size.zero;
  double get groundY => size.height * 0.80;
  double get leaderX => size.width * 0.24;
  double get chickenSize => size.height * 0.23;

  // ---- Phase & stats -------------------------------------------------------
  GamePhase phase = GamePhase.ready;
  double traveled = 0; // px
  double get pxPerMeter => 28;
  int get distance => (traveled / pxPerMeter).floor();
  int coins = 0;
  int eggsCollected = 0;
  int jumps = 0;
  int shields = 0;
  int maxFlock = 1;

  // ---- Player / flock ------------------------------------------------------
  double yOff = 0; // height above ground (px)
  double vy = 0;
  bool _holding = false;
  double _holdTime = 0;
  final List<FlockMember> flock = [];
  int get flockSize => flock.length;

  bool get grounded => yOff <= 0.5;

  // Falling into a pit: the whole flock drops down the hole and the run only
  // ends once it has fallen off the bottom of the screen.
  bool falling = false;
  double fallOff = 0; // how far below the ground the flock has dropped (px)
  double _fallVy = 0;

  // ---- Entities ------------------------------------------------------------
  final List<Obstacle> obstacles = [];
  final List<Pit> pits = [];
  final List<EggItem> eggs = [];
  final List<CoinItem> coinItems = [];
  final List<FallingTrap> traps = [];
  final List<PowerCrate> crates = [];
  final List<DyingChicken> dying = [];
  final List<double> clouds = []; // x positions

  // ---- Active power-up ------------------------------------------------------
  PowerUp activePower = PowerUp.none;
  double powerTime = 0; // seconds remaining
  double powerTotal = 0; // full duration (for the HUD bar)
  double get powerFraction => powerTotal <= 0 ? 0 : powerTime / powerTotal;
  bool get flying => activePower == PowerUp.fly;
  bool get invincible =>
      activePower == PowerUp.fly || activePower == PowerUp.shield;
  double get _flyAltitude => size.height * 0.42;

  double _durationFor(PowerUp p) => switch (p) {
        PowerUp.fly => 6.5,
        PowerUp.shield => 7.0,
        PowerUp.magnet => 8.0,
        PowerUp.none => 0,
      };

  // Continuous attrition: while the flock is jammed against an obstacle or
  // standing over a pit, chickens die as the hazard scrolls past — one per
  // [_attritionStep] pixels of contact, so wide hazards cost more (and it is
  // speed-independent, so a slow start doesn't wipe the flock instantly).
  double _threatDist = 0;
  double get _attritionStep => chickenSize * 0.45;

  // Leader vertical history keyed by distance travelled, so trailing chickens
  // can replay the leader's jump when they reach the same spot.
  final List<double> _histT = [];
  final List<double> _histY = [];

  // ---- Background / zones --------------------------------------------------
  // Crossfade between backgrounds instead of hard-cutting: [zone] is the one
  // currently shown, [nextZone] fades in on top with opacity [zoneFade].
  int zone = 0;
  int nextZone = 0;
  double zoneFade = 0; // 0 = only current, 1 = next fully shown
  bool _zoneFading = false;
  double bgScroll = 0;
  double _zoneTimer = 0;
  static const double _zoneInterval = 26; // seconds between transitions
  static const double _zoneFadeDur = 1.8; // seconds for the crossfade

  // ---- Spawn bookkeeping ---------------------------------------------------
  // A single scheduler drives obstacles / pits / eggs / coins so features are
  // always spaced apart (never overlapping) and their mix stays balanced.
  double _nextFeature = 0;
  double _nextTrap = 0;
  double _nextCrate = 0;
  bool _lastFeatureHazard = false; // was the last spawned feature a pit/obstacle?

  void resize(Size s) {
    size = s;
  }

  void start() {
    phase = GamePhase.running;
    traveled = 0;
    coins = 0;
    eggsCollected = 0;
    jumps = 0;
    shields = startingShields;
    yOff = 0;
    vy = 0;
    flock
      ..clear()
      ..add(FlockMember(leaderSpecies, 0, _rng));
    maxFlock = 1;
    obstacles.clear();
    pits.clear();
    eggs.clear();
    coinItems.clear();
    traps.clear();
    crates.clear();
    dying.clear();
    activePower = PowerUp.none;
    powerTime = 0;
    powerTotal = 0;
    _histT.clear();
    _histY.clear();
    _threatDist = 0;
    falling = false;
    fallOff = 0;
    _fallVy = 0;
    clouds
      ..clear()
      ..addAll([size.width * 0.3, size.width * 0.8, size.width * 1.4]);
    zone = 0;
    nextZone = 0;
    zoneFade = 0;
    _zoneFading = false;
    bgScroll = 0;
    _zoneTimer = 0;
    // Long empty runway at the start so the player eases in.
    _nextFeature = size.width * 1.2;
    _nextTrap = size.width * 4.0;
    _nextCrate = size.width * 3.2;
    _lastFeatureHazard = false;
  }

  // ---- Input ---------------------------------------------------------------
  void onTapDown() {
    if (phase != GamePhase.running || falling || flying) return;
    if (grounded) {
      vy = _jumpInitial;
      _holding = true;
      _holdTime = 0;
      jumps += 1;
      AudioManager.instance.play(Sfx.jump);
    }
  }

  void onTapUp() {
    _holding = false;
  }

  double get _jumpInitial => size.height * 1.15 * jumpMultiplier;
  double get _holdAccel => size.height * 4.6 * jumpMultiplier;
  double get _gravity => size.height * 3.7;
  static const double _maxHold = 0.22;

  double get _speed {
    // A touch quicker jog at the start (so wide obstacles can be cleared), then
    // a steady, noticeable ramp over distance — the flock keeps getting faster.
    final base = size.width * 0.23 * speedMultiplier;
    final ramp = 1 + (traveled / (pxPerMeter * 1700)).clamp(0.0, 2.5);
    return base * ramp;
  }

  // ---- Frame update --------------------------------------------------------
  void update(double dt) {
    if (phase != GamePhase.running) return;
    if (dt > 0.05) dt = 0.05; // clamp big frame gaps (e.g. after resume)

    // While falling into a pit the world freezes and the flock drops down the
    // hole; the run ends only once it has cleared the bottom of the screen.
    if (falling) {
      _fallVy += _gravity * dt;
      fallOff += _fallVy * dt;
      _updateDying(dt);
      if (fallOff > size.height * 1.3) {
        _die();
      }
      onStatsChanged?.call();
      return;
    }

    // Tick the active power-up down; it ends automatically when it runs out.
    if (activePower != PowerUp.none) {
      powerTime -= dt;
      if (powerTime <= 0) {
        activePower = PowerUp.none;
        powerTime = 0;
        powerTotal = 0;
      }
    }

    final dx = _speed * dt;
    traveled += dx;
    bgScroll += dx;

    _updatePlayer(dt);
    _recordHistory();
    _updateDying(dt);
    _moveEntities(dx);
    _spawn();
    _updateTraps(dt);
    _collisions(dt);
    _updateClouds(dx);
    _updateZone(dt);

    onStatsChanged?.call();
  }

  void _updatePlayer(double dt) {
    // While flying, the flock eases up to a cruising altitude and holds there,
    // gliding above every hazard. Followers replay this via the height history.
    if (flying) {
      yOff += (_flyAltitude - yOff) * (dt * 6).clamp(0.0, 1.0);
      vy = 0;
      _holding = false;
      for (final m in flock) {
        m.bob += dt * m.bobSpeed;
      }
      return;
    }
    if (_holding && _holdTime < _maxHold && vy > 0) {
      vy += _holdAccel * dt;
      _holdTime += dt;
    }
    vy -= _gravity * dt;
    yOff += vy * dt;
    if (yOff <= 0) {
      yOff = 0;
      vy = 0;
      _holding = false;
    }
    for (final m in flock) {
      m.bob += dt * m.bobSpeed;
    }
  }

  void _recordHistory() {
    _histT.add(traveled);
    _histY.add(yOff);
    // Keep enough history to cover the longest trailing chicken.
    if (_histT.length > 600) {
      _histT.removeRange(0, _histT.length - 600);
      _histY.removeRange(0, _histY.length - 600);
    }
  }

  /// The leader's vertical offset when it was [behind] pixels back — i.e. the
  /// height a trailing chicken should currently be at.
  double yOffBehind(double behind) {
    final target = traveled - behind;
    if (_histT.isEmpty || target <= _histT.first) return 0;
    // Scan from the end (most trailing chickens are near the recent past).
    for (int i = _histT.length - 1; i > 0; i--) {
      if (_histT[i - 1] <= target && target <= _histT[i]) {
        final span = _histT[i] - _histT[i - 1];
        final f = span <= 0 ? 0.0 : (target - _histT[i - 1]) / span;
        return _histY[i - 1] + (_histY[i] - _histY[i - 1]) * f;
      }
    }
    return _histY.last;
  }

  void _updateDying(double dt) {
    for (final d in dying) {
      d.vy -= _gravity * dt;
      d.y += d.vy * dt;
      d.rot += d.rotSpeed * dt;
      d.life += dt;
      d.x -= _speed * dt; // drift back with the world
    }
    dying.removeWhere((d) => d.dead);
  }

  void _moveEntities(double dx) {
    for (final o in obstacles) {
      o.x -= dx;
    }
    for (final p in pits) {
      p.x -= dx;
    }
    for (final e in eggs) {
      e.x -= dx;
    }
    for (final c in coinItems) {
      c.x -= dx;
    }
    for (final t in traps) {
      t.x -= dx;
    }
    for (final cr in crates) {
      cr.x -= dx;
      cr.bob += dx * 0.02;
    }
    obstacles.removeWhere((o) => o.x + o.w < -40);
    pits.removeWhere((p) => p.x + p.w < -40);
    eggs.removeWhere((e) => e.collected || e.x < -60);
    coinItems.removeWhere((c) => c.collected || c.x < -60);
    traps.removeWhere((t) => t.resolved || t.x < -80);
    crates.removeWhere((cr) => cr.collected || cr.x < -80);
  }

  void _updateClouds(double dx) {
    for (int i = 0; i < clouds.length; i++) {
      clouds[i] -= dx * 0.12;
      if (clouds[i] < -size.width * 0.2) {
        clouds[i] = size.width * (1.1 + _rng.nextDouble() * 0.5);
      }
    }
  }

  void _updateZone(double dt) {
    if (_zoneFading) {
      // Fade the next background in over the current one, then commit.
      zoneFade += dt / _zoneFadeDur;
      if (zoneFade >= 1) {
        zone = nextZone;
        zoneFade = 0;
        _zoneFading = false;
        _zoneTimer = 0;
      }
      return;
    }
    _zoneTimer += dt;
    if (_zoneTimer > _zoneInterval && Assets.backgrounds.length > 1) {
      nextZone = (zone + 1) % Assets.backgrounds.length;
      zoneFade = 0;
      _zoneFading = true;
    }
  }

  // ---- Spawning ------------------------------------------------------------
  void _spawn() {
    final w = size.width;
    final spawnX = w + 60;

    if (traveled >= _nextFeature) {
      final footprint = _spawnFeature(spawnX);
      // Gap after the feature guarantees the next thing can't overlap this one.
      // Threats get a bit denser with distance; eggs stay sparse so the flock
      // cannot outgrow the hazards.
      final density = 1 + (traveled / (pxPerMeter * 2000)).clamp(0.0, 0.7);
      double gap = (footprint + w * (0.36 + _rng.nextDouble() * 0.30)) / density;
      // After an obstacle or pit, guarantee a landing runway so you never get
      // two hazards back-to-back with no room to recover.
      if (_lastFeatureHazard) gap += w * 0.5;
      // Absolute floor on spacing regardless of density.
      final floor = w * (_lastFeatureHazard ? 0.62 : 0.38);
      if (gap < floor) gap = floor;
      _nextFeature = traveled + gap;
    }
    if (traveled >= _nextTrap) {
      _spawnTrap();
      _nextTrap = traveled + w * (2.4 + _rng.nextDouble() * 1.8);
    }
    // Power-up crates appear occasionally and only when no power is running, so
    // abilities feel like a treat rather than being permanently stacked.
    if (traveled >= _nextCrate) {
      if (activePower == PowerUp.none) {
        _spawnCrate(spawnX);
        _nextCrate = traveled + w * (5.5 + _rng.nextDouble() * 3.5);
      } else {
        // Wait until the current power ends before scheduling the next crate.
        _nextCrate = traveled + w * 1.5;
      }
    }
  }

  /// Spawns one world feature and returns the horizontal footprint it consumes
  /// (used to space the next feature so nothing overlaps).
  double _spawnFeature(double x) {
    // Weighted pick. Coins are common, threats (obstacle/pit) frequent, eggs
    // rare — so the army grows slowly and running out is possible.
    final roll = _rng.nextDouble();
    // No pits during the opening stretch so a new player can learn the jump,
    // and never a pit right after another hazard (needs a landing runway).
    final pitsAllowed = traveled > size.width * 2.5 && !_lastFeatureHazard;
    if (roll < 0.28) {
      _lastFeatureHazard = false;
      return _spawnCoinArc(x);
    }
    if (roll < 0.62) {
      _lastFeatureHazard = true;
      return _spawnObstacle(x);
    }
    if (roll < 0.80 && pitsAllowed) {
      _lastFeatureHazard = true;
      return _spawnPit(x);
    }
    if (roll < 0.80) {
      _lastFeatureHazard = false;
      return _spawnCoinArc(x);
    }
    _lastFeatureHazard = false;
    return _spawnEggCluster(x);
  }

  double _spawnObstacle(double x) {
    // Big obstacles: the whole flock jams against them and every chicken that
    // fails to jump over keeps dying until it clears (Zombie-Tsunami style).
    // Each is sized by a target HEIGHT; the width follows the sprite's true
    // aspect so nothing is squashed or stretched.
    final h = size.height;
    final roll = _rng.nextInt(4);
    late final String asset;
    late final double targetH;
    late final double fallbackAspect;
    switch (roll) {
      case 0:
        asset = Assets.rock;
        targetH = h * 0.17;
        fallbackAspect = 1.15;
        break;
      case 1:
        asset = Assets.treeStump;
        targetH = h * 0.26;
        fallbackAspect = 0.95;
        break;
      case 2:
        asset = Assets.log;
        targetH = h * 0.22;
        fallbackAspect = 1.6;
        break;
      default:
        asset = Assets.bush;
        targetH = h * 0.23;
        fallbackAspect = 1.15;
    }
    final w = targetH * _aspect(asset, fallbackAspect);
    obstacles.add(Obstacle(x: x, w: w, h: targetH, asset: asset, damage: 1));
    return w;
  }

  double _spawnPit(double x) {
    // Narrow enough that a well-timed hold-jump clears it.
    final w = size.height * (0.20 + _rng.nextDouble() * 0.14);
    pits.add(Pit(x: x, w: w));
    return w;
  }

  double _spawnEggCluster(double x) {
    // Sparse: usually a single egg, occasionally two, so the flock grows slowly.
    final count = _rng.nextDouble() < 0.28 ? 2 : 1;
    for (int i = 0; i < count; i++) {
      final r = _rng.nextDouble();
      final kind = r > 0.9
          ? EggKind.golden
          : (r > 0.65 ? EggKind.speckled : EggKind.normal);
      final y = _rng.nextBool() ? 0.0 : size.height * (0.12 + _rng.nextDouble() * 0.2);
      eggs.add(EggItem(x: x + i * chickenSize * 0.9, y: y, kind: kind));
    }
    return count * chickenSize * 0.9;
  }

  double _spawnCoinArc(double x) {
    final count = 5 + _rng.nextInt(5);
    final peak = size.height * (0.12 + _rng.nextDouble() * 0.22);
    final step = size.height * 0.13;
    for (int i = 0; i < count; i++) {
      final t = i / (count - 1);
      final y = sin(t * pi) * peak; // gentle arc
      coinItems.add(CoinItem(x: x + i * step, y: y));
    }
    return count * step;
  }

  void _spawnTrap() {
    // Big rock arcs down well ahead of the leader, giving a long telegraph so a
    // timed jump avoids it; if it lands untouched it becomes a ground obstacle.
    final x = size.width * 0.98;
    traps.add(FallingTrap.spawn(
      x: x,
      size: size.height * 0.24,
      top: size.height * 1.35,
    ));
  }

  void _spawnCrate(double x) {
    const types = [PowerUp.fly, PowerUp.shield, PowerUp.magnet];
    final type = types[_rng.nextInt(types.length)];
    // Float at a grabbable jump height so the player reaches up for it.
    final y = size.height * (0.16 + _rng.nextDouble() * 0.16);
    crates.add(PowerCrate(x: x, y: y, type: type, rng: _rng));
  }

  void _activatePower(PowerUp p) {
    activePower = p;
    powerTotal = _durationFor(p);
    powerTime = powerTotal;
    if (p == PowerUp.fly) vy = 0;
    AudioManager.instance.play(Sfx.egg);
  }

  // ---- Collisions ----------------------------------------------------------
  void _collisions(double dt) {
    final lx0 = leaderX - chickenSize * 0.32;
    final lx1 = leaderX + chickenSize * 0.32;

    // ---- Power-up crates: touching one triggers its ability -----------------
    for (final cr in crates) {
      if (cr.collected) continue;
      if (_overlapItem(cr.x, cr.y, chickenSize * 0.75)) {
        cr.collected = true;
        _activatePower(cr.type);
      }
    }

    // ---- Pits: stepping onto empty ground makes the whole flock fall in -----
    // Flying or shielded, the flock passes safely over every gap.
    if (!invincible) {
      for (final p in pits) {
        final overlapX = p.x < leaderX && (p.x + p.w) > leaderX;
        if (!overlapX) continue;
        if (yOff <= chickenSize * 0.2) {
          _startFalling();
          return;
        }
      }
    }

    // ---- Ground obstacles ---------------------------------------------------
    // Flying: glide over everything. Shield: smash obstacles on contact.
    // Otherwise the flock jams and suffers continuous attrition until it clears.
    bool jammed = false;
    if (activePower == PowerUp.shield) {
      final smashed = <Obstacle>[];
      for (final o in obstacles) {
        final overlapX = o.x < lx1 && (o.x + o.w) > lx0;
        if (overlapX) smashed.add(o);
      }
      if (smashed.isNotEmpty) {
        obstacles.removeWhere(smashed.contains);
        AudioManager.instance.play(Sfx.hit);
      }
    } else if (!flying) {
      for (final o in obstacles) {
        final overlapX = o.x < lx1 && (o.x + o.w) > lx0;
        if (!overlapX) continue;
        final cleared = yOff >= o.h * 0.85;
        if (!cleared) jammed = true;
      }
    }

    if (jammed) {
      _threatDist += _speed * dt;
      while (_threatDist >= _attritionStep && flock.isNotEmpty) {
        _threatDist -= _attritionStep;
        final lost = flock.removeLast();
        _spawnDying(lost.speciesId);
        if (flock.isEmpty) {
          _die();
          return;
        }
        AudioManager.instance.play(Sfx.hit);
      }
    } else {
      _threatDist = 0;
    }

    // Magnet strength: hugely boosted by the magnet power, and wide while flying
    // so airborne coins/eggs are swept up too.
    final magnet = switch (activePower) {
      PowerUp.magnet => size.width * 1.5,
      PowerUp.fly => size.width * 0.9,
      _ => magnetRadius,
    };
    final pullStrong = activePower == PowerUp.magnet || flying;

    // Eggs (pulled in while a magnet/fly power is active).
    for (final e in eggs) {
      if (e.collected) continue;
      if (pullStrong) {
        final dxp = e.x - leaderX;
        final dyp = e.y - yOff;
        if (sqrt(dxp * dxp + dyp * dyp) < magnet) {
          e.x -= dxp * 0.3;
          e.y -= dyp * 0.3;
        }
      }
      if (_overlapItem(e.x, e.y, chickenSize * 0.6)) {
        e.collected = true;
        eggsCollected += 1;
        _addChicken();
        AudioManager.instance.play(Sfx.egg);
        if (e.kind == EggKind.golden) {
          coins += (12 * coinMultiplier).round();
        }
      }
    }

    // Coins (with magnet pull, boosted by the magnet/fly powers).
    for (final c in coinItems) {
      if (c.collected) continue;
      final dxp = c.x - leaderX;
      final dyp = c.y - yOff;
      final dist = sqrt(dxp * dxp + dyp * dyp);
      if (dist < magnet) {
        final k = pullStrong ? 0.32 : 0.18;
        c.x -= dxp * k;
        c.y -= dyp * k;
      }
      if (_overlapItem(c.x, c.y, chickenSize * 0.55)) {
        c.collected = true;
        coins += (1 * coinMultiplier).round().clamp(1, 999);
        AudioManager.instance.play(Sfx.coin);
      }
    }

    // Falling traps: only dangerous mid-air (a rock dropping on the flock);
    // flying or shielded, the flock is immune.
    for (final t in traps) {
      if (t.resolved || t.landed || invincible) continue;
      final overlapX =
          t.x < lx1 + t.size * 0.4 && (t.x + t.size) > lx0 - t.size * 0.4;
      if (overlapX) {
        final band = (yOff - t.y).abs() < chickenSize * 0.55;
        if (band) {
          t.resolved = true;
          _takeHit(1);
        }
      }
    }
  }

  void _updateTraps(double dt) {
    for (final t in traps) {
      if (t.resolved || t.landed) continue;
      // Falls immediately from far ahead, giving a long telegraph.
      t.vy += size.height * 4.6 * dt;
      t.y -= t.vy * dt;
      if (t.y <= 0) {
        t.y = 0;
        t.landed = true;
        t.resolved = true;
        // The fallen rock becomes a ground obstacle the flock must jump — but
        // only if it wouldn't stack next to a pit or another obstacle (which
        // would create an unclearable double hazard).
        final clear = size.width * 0.6;
        final nearHazard =
            pits.any((p) => (p.x - t.x).abs() < clear + p.w) ||
                obstacles.any((o) => (o.x - t.x).abs() < clear + o.w);
        if (!nearHazard) {
          final oh = t.size * 0.85;
          obstacles.add(Obstacle(
            x: t.x,
            w: oh * _aspect(Assets.rock, 1.15),
            h: oh,
            asset: Assets.rock,
            damage: 1,
          ));
        }
      }
    }
  }

  bool _overlapItem(double x, double y, double radius) {
    final dxp = (x - leaderX).abs();
    final dyp = (y - yOff).abs();
    return dxp < radius && dyp < radius + chickenSize * 0.3;
  }

  void _takeHit(int damage) {
    if (shields > 0) {
      shields -= 1;
      AudioManager.instance.play(Sfx.hit);
      return;
    }
    for (int i = 0; i < damage && flock.isNotEmpty; i++) {
      final lost = flock.removeLast();
      _spawnDying(lost.speciesId);
    }
    if (flock.isEmpty) {
      _die(); // game-over SFX handled by the screen
    } else {
      AudioManager.instance.play(Sfx.hit);
    }
  }

  void _spawnDying(int speciesId, {bool intoPit = false}) {
    // Hit at an obstacle: pop up and tumble away. Falling into a pit: drop
    // straight down out of view.
    dying.add(DyingChicken(
      x: leaderX + chickenSize * 0.1,
      y: yOff + chickenSize * 0.15,
      speciesId: speciesId,
      vy: intoPit ? -size.height * 0.5 : size.height * 0.7,
      rotSpeed: (_rng.nextBool() ? 1 : -1) * (4 + _rng.nextDouble() * 4),
    ));
  }

  void _addChicken() {
    // New members take a random owned-looking species for visual variety; the
    // leader keeps its slot 0. Species just drives which sprite is drawn.
    final speciesId = _rng.nextInt(Assets.chickenIdle.length);
    flock.add(FlockMember(speciesId, flock.length, _rng));
    if (flock.length > maxFlock) maxFlock = flock.length;
  }

  void _startFalling() {
    if (falling) return;
    falling = true;
    _fallVy = size.height * 0.25; // start dropping straight down the hole
    fallOff = 0;
    yOff = 0;
    vy = 0;
    AudioManager.instance.play(Sfx.hit);
  }

  void _die() {
    phase = GamePhase.dead;
    onGameOver?.call();
  }

  void pause() {
    if (phase == GamePhase.running) phase = GamePhase.paused;
  }

  void resume() {
    if (phase == GamePhase.paused) phase = GamePhase.running;
  }

  /// Revive: restore a small flock and a shield, continue running.
  void revive() {
    if (phase != GamePhase.dead) return;
    phase = GamePhase.running;
    for (int i = flock.length; i < 5; i++) {
      flock.add(FlockMember(leaderSpecies, i, _rng));
    }
    shields = 1;
    yOff = 0;
    vy = 0;
    _threatDist = 0;
    falling = false;
    fallOff = 0;
    _fallVy = 0;
    activePower = PowerUp.none;
    powerTime = 0;
    powerTotal = 0;
    // Clear nearby threats so the player doesn't instantly die again.
    obstacles.removeWhere((o) => o.x < size.width);
    pits.removeWhere((p) => p.x < size.width);
    traps.clear();
  }
}
