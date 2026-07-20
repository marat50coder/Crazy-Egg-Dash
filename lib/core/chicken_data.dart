import 'assets.dart';

/// Rarity tiers, ordered from most common to rarest.
enum Rarity { common, rare, epic, legendary }

extension RarityInfo on Rarity {
  String get label => switch (this) {
        Rarity.common => 'Common',
        Rarity.rare => 'Rare',
        Rarity.epic => 'Epic',
        Rarity.legendary => 'Legendary',
      };

  int get eggCostToHatch => switch (this) {
        Rarity.common => 8,
        Rarity.rare => 20,
        Rarity.epic => 45,
        Rarity.legendary => 90,
      };
}

/// A playable chicken breed. There are four breeds, each with its own art set
/// (idle / running / jumping) and a passive perk that changes how a run feels.
class ChickenSpecies {
  const ChickenSpecies({
    required this.id,
    required this.name,
    required this.title,
    required this.rarity,
    required this.perk,
    required this.baseSpeedBonus,
    required this.baseJumpBonus,
    required this.baseCoinBonus,
    required this.baseShieldBonus,
  });

  final int id;
  final String name;
  final String title;
  final Rarity rarity;
  final String perk;

  /// Per-star contribution to the flock's aggregate stats (percent, 0..1).
  final double baseSpeedBonus;
  final double baseJumpBonus;
  final double baseCoinBonus;
  final double baseShieldBonus;

  String get idleAsset => Assets.chickenIdle[id];
  String get runAsset => Assets.chickenRun[id];
  String get jumpAsset => Assets.chickenJump[id];
}

class ChickenRoster {
  ChickenRoster._();

  static const List<ChickenSpecies> all = [
    ChickenSpecies(
      id: 0,
      name: 'Clucky',
      title: 'The Brave Leader',
      rarity: Rarity.common,
      perk: 'Balanced all-rounder. A dependable start to any flock.',
      baseSpeedBonus: 0.02,
      baseJumpBonus: 0.02,
      baseCoinBonus: 0.02,
      baseShieldBonus: 0.02,
    ),
    ChickenSpecies(
      id: 1,
      name: 'Rusty',
      title: 'The Speedster',
      rarity: Rarity.rare,
      perk: 'Boosts the whole flock\'s dash speed.',
      baseSpeedBonus: 0.06,
      baseJumpBonus: 0.01,
      baseCoinBonus: 0.01,
      baseShieldBonus: 0.0,
    ),
    ChickenSpecies(
      id: 2,
      name: 'Shellby',
      title: 'The Guardian',
      rarity: Rarity.epic,
      perk: 'Hard shell grants extra protection against hits.',
      baseSpeedBonus: 0.01,
      baseJumpBonus: 0.02,
      baseCoinBonus: 0.01,
      baseShieldBonus: 0.06,
    ),
    ChickenSpecies(
      id: 3,
      name: 'Goldie',
      title: 'The Lucky One',
      rarity: Rarity.legendary,
      perk: 'Golden feathers attract far more coins.',
      baseSpeedBonus: 0.02,
      baseJumpBonus: 0.03,
      baseCoinBonus: 0.08,
      baseShieldBonus: 0.01,
    ),
  ];

  static ChickenSpecies byId(int id) => all[id.clamp(0, all.length - 1)];
}
