import 'assets.dart';

/// The kind of statistic a quest / achievement tracks.
enum StatMetric {
  distance, // meters in a single run
  totalDistance, // meters accumulated across all runs
  flockSize, // largest flock in a single run
  coins, // coins collected in a single run
  totalCoins, // coins accumulated across all runs
  eggs, // eggs collected in a single run
  totalEggs, // eggs accumulated across all runs
  runs, // number of runs played
  jumps, // number of jumps performed (accumulated)
}

class QuestDef {
  const QuestDef({
    required this.id,
    required this.description,
    required this.metric,
    required this.target,
    required this.rewardCoins,
    required this.rewardFeathers,
  });

  final String id;
  final String description;
  final StatMetric metric;
  final int target;
  final int rewardCoins;
  final int rewardFeathers;
}

/// Pool of daily quests; three are picked each day.
class Quests {
  Quests._();

  static const List<QuestDef> pool = [
    QuestDef(
      id: 'run_400',
      description: 'Dash 400m in a single run',
      metric: StatMetric.distance,
      target: 400,
      rewardCoins: 150,
      rewardFeathers: 2,
    ),
    QuestDef(
      id: 'flock_12',
      description: 'Grow a flock of 12 chickens',
      metric: StatMetric.flockSize,
      target: 12,
      rewardCoins: 200,
      rewardFeathers: 3,
    ),
    QuestDef(
      id: 'coins_120',
      description: 'Collect 120 coins in one run',
      metric: StatMetric.coins,
      target: 120,
      rewardCoins: 180,
      rewardFeathers: 2,
    ),
    QuestDef(
      id: 'eggs_15',
      description: 'Grab 15 eggs in one run',
      metric: StatMetric.eggs,
      target: 15,
      rewardCoins: 160,
      rewardFeathers: 2,
    ),
    QuestDef(
      id: 'runs_3',
      description: 'Play 3 runs today',
      metric: StatMetric.runs,
      target: 3,
      rewardCoins: 120,
      rewardFeathers: 1,
    ),
    QuestDef(
      id: 'jumps_40',
      description: 'Perform 40 jumps',
      metric: StatMetric.jumps,
      target: 40,
      rewardCoins: 100,
      rewardFeathers: 1,
    ),
    QuestDef(
      id: 'run_800',
      description: 'Dash 800m in a single run',
      metric: StatMetric.distance,
      target: 800,
      rewardCoins: 260,
      rewardFeathers: 4,
    ),
  ];

  static QuestDef byId(String id) => pool.firstWhere((q) => q.id == id);
}

class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.name,
    required this.description,
    required this.metric,
    required this.target,
    required this.rewardCrystals,
    required this.icon,
  });

  final String id;
  final String name;
  final String description;
  final StatMetric metric;
  final int target;
  final int rewardCrystals;
  final String icon;
}

class Achievements {
  Achievements._();

  static const List<AchievementDef> all = [
    AchievementDef(
      id: 'first_steps',
      name: 'First Steps',
      description: 'Finish your first run.',
      metric: StatMetric.runs,
      target: 1,
      rewardCrystals: 1,
      icon: Assets.egg,
    ),
    AchievementDef(
      id: 'marathon',
      name: 'Marathon Hen',
      description: 'Reach 1000m in one run.',
      metric: StatMetric.distance,
      target: 1000,
      rewardCrystals: 3,
      icon: Assets.arrow,
    ),
    AchievementDef(
      id: 'big_flock',
      name: 'Feathered Army',
      description: 'Lead a flock of 25 chickens.',
      metric: StatMetric.flockSize,
      target: 25,
      rewardCrystals: 4,
      icon: Assets.chickenIdle3,
    ),
    AchievementDef(
      id: 'egg_hoarder',
      name: 'Egg Hoarder',
      description: 'Collect 500 eggs in total.',
      metric: StatMetric.totalEggs,
      target: 500,
      rewardCrystals: 3,
      icon: Assets.eggs,
    ),
    AchievementDef(
      id: 'rich_hen',
      name: 'Rich Hen',
      description: 'Earn 5000 coins in total.',
      metric: StatMetric.totalCoins,
      target: 5000,
      rewardCrystals: 4,
      icon: Assets.coin,
    ),
    AchievementDef(
      id: 'globetrotter',
      name: 'Globetrotter',
      description: 'Run 10,000m across all your dashes.',
      metric: StatMetric.totalDistance,
      target: 10000,
      rewardCrystals: 5,
      icon: Assets.finish,
    ),
    AchievementDef(
      id: 'jumper',
      name: 'Sky Hopper',
      description: 'Perform 500 jumps.',
      metric: StatMetric.jumps,
      target: 500,
      rewardCrystals: 3,
      icon: Assets.feather,
    ),
    AchievementDef(
      id: 'veteran',
      name: 'Coop Veteran',
      description: 'Play 50 runs.',
      metric: StatMetric.runs,
      target: 50,
      rewardCrystals: 5,
      icon: Assets.crystal,
    ),
  ];
}
