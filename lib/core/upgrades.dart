import 'assets.dart';

/// Permanent player upgrades bought with coins. Each upgrade improves a facet
/// of every run and has a capped number of levels with rising cost.
enum UpgradeType { speed, jump, magnet, shield, revive, coinValue }

class UpgradeDef {
  const UpgradeDef({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.maxLevel,
    required this.baseCost,
    required this.perLevel,
  });

  final UpgradeType type;
  final String name;
  final String description;
  final String icon;
  final int maxLevel;
  final int baseCost;

  /// Value gained per level (interpretation depends on the upgrade).
  final double perLevel;

  /// Cost of moving from [currentLevel] to the next level.
  int costFor(int currentLevel) =>
      (baseCost * (currentLevel + 1) * 2.1).round();
}

class Upgrades {
  Upgrades._();

  static const List<UpgradeDef> all = [
    UpgradeDef(
      type: UpgradeType.speed,
      name: 'Dash Speed',
      description: 'The whole flock runs a little faster.',
      icon: Assets.arrow,
      maxLevel: 8,
      baseCost: 220,
      perLevel: 0.05,
    ),
    UpgradeDef(
      type: UpgradeType.jump,
      name: 'Spring Legs',
      description: 'Jump higher to clear taller obstacles.',
      icon: Assets.feather,
      maxLevel: 8,
      baseCost: 220,
      perLevel: 0.05,
    ),
    UpgradeDef(
      type: UpgradeType.magnet,
      name: 'Coin Magnet',
      description: 'Pull nearby coins toward your flock.',
      icon: Assets.coin,
      maxLevel: 6,
      baseCost: 340,
      perLevel: 0.18,
    ),
    UpgradeDef(
      type: UpgradeType.shield,
      name: 'Egg Shell',
      description: 'Start each run with a protective shell.',
      icon: Assets.egg,
      maxLevel: 5,
      baseCost: 420,
      perLevel: 1,
    ),
    UpgradeDef(
      type: UpgradeType.revive,
      name: 'Second Wind',
      description: 'A chance to keep going after losing the flock.',
      icon: Assets.goldenEgg,
      maxLevel: 3,
      baseCost: 650,
      perLevel: 1,
    ),
    UpgradeDef(
      type: UpgradeType.coinValue,
      name: 'Golden Touch',
      description: 'Every coin you grab is worth more.',
      icon: Assets.crystal,
      maxLevel: 6,
      baseCost: 360,
      perLevel: 0.1,
    ),
  ];

  static UpgradeDef byType(UpgradeType t) =>
      all.firstWhere((u) => u.type == t);
}
