import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio.dart';
import 'chicken_data.dart';
import 'progression_defs.dart';
import 'upgrades.dart';

/// Result of a single dash, handed to [GameState.recordRun].
class RunResult {
  RunResult({
    required this.distance,
    required this.maxFlock,
    required this.coins,
    required this.eggs,
    required this.jumps,
    required this.zone,
  });

  final int distance;
  final int maxFlock;
  final int coins;
  final int eggs;
  final int jumps;
  final int zone;
}

/// Outcome of spinning the daily reward wheel.
class DailyReward {
  DailyReward(this.type, this.amount);
  final String type; // 'coins' | 'feathers' | 'crystals' | 'eggs'
  final int amount;
}

/// The single source of truth for all persistent player progress. Screens
/// listen to this via [Provider]/[ChangeNotifier] and mutate it through the
/// intent methods below, which each persist automatically.
class GameState extends ChangeNotifier {
  static const String _prefsKey = 'crazy_egg_dash_save_v1';
  final Random _rng = Random();

  // ---- Currencies ----
  int coins = 150;
  int feathers = 5;
  int crystals = 1;
  int eggs = 10;

  // ---- Collection ----
  /// speciesId -> level (0 = not yet owned, otherwise 1..maxChickenLevel).
  final Map<int, int> chickenLevel = {0: 1};

  /// speciesId -> spare copies used to level a chicken up via fusion.
  final Map<int, int> chickenShards = {};

  int selectedChicken = 0;
  static const int maxChickenLevel = 10;

  // ---- Upgrades ----
  final Map<UpgradeType, int> upgradeLevel = {};

  // ---- Zones ----
  int zonesUnlocked = 1;
  static const int totalZones = 5;

  // ---- Lifetime stats ----
  int bestDistance = 0;
  int bestFlock = 0;
  int totalRuns = 0;
  int totalDistance = 0;
  int totalCoins = 0;
  int totalEggs = 0;
  int totalJumps = 0;

  // ---- Daily reward ----
  int dailyStreak = 0;
  int lastDailyClaimDay = -1;

  // ---- Quests ----
  List<String> dailyQuestIds = [];
  final Map<String, int> questProgress = {};
  final Set<String> questClaimed = {};
  int questsGeneratedDay = -1;

  // ---- Achievements ----
  final Set<String> achievementClaimed = {};

  // ---- Settings ----
  bool soundOn = true;
  bool musicOn = true;
  bool vibrationOn = true;
  double musicVolume = 0.5; // 0..1
  double soundVolume = 0.8; // 0..1

  bool _loaded = false;
  bool get isLoaded => _loaded;

  int get _today => DateTime.now().difference(DateTime(2024)).inDays;

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        _fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {
      // Corrupt save — start fresh rather than crash.
    }
    ensureDailyQuests();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_toJson()));
    } catch (_) {
      // Ignore persistence failures; the session still works in-memory.
    }
  }

  Map<String, dynamic> _toJson() => {
        'coins': coins,
        'feathers': feathers,
        'crystals': crystals,
        'eggs': eggs,
        'chickenLevel':
            chickenLevel.map((k, v) => MapEntry(k.toString(), v)),
        'chickenShards':
            chickenShards.map((k, v) => MapEntry(k.toString(), v)),
        'selectedChicken': selectedChicken,
        'upgradeLevel':
            upgradeLevel.map((k, v) => MapEntry(k.index.toString(), v)),
        'zonesUnlocked': zonesUnlocked,
        'bestDistance': bestDistance,
        'bestFlock': bestFlock,
        'totalRuns': totalRuns,
        'totalDistance': totalDistance,
        'totalCoins': totalCoins,
        'totalEggs': totalEggs,
        'totalJumps': totalJumps,
        'dailyStreak': dailyStreak,
        'lastDailyClaimDay': lastDailyClaimDay,
        'dailyQuestIds': dailyQuestIds,
        'questProgress': questProgress,
        'questClaimed': questClaimed.toList(),
        'questsGeneratedDay': questsGeneratedDay,
        'achievementClaimed': achievementClaimed.toList(),
        'soundOn': soundOn,
        'musicOn': musicOn,
        'vibrationOn': vibrationOn,
        'musicVolume': musicVolume,
        'soundVolume': soundVolume,
      };

  void _fromJson(Map<String, dynamic> j) {
    coins = j['coins'] ?? coins;
    feathers = j['feathers'] ?? feathers;
    crystals = j['crystals'] ?? crystals;
    eggs = j['eggs'] ?? eggs;

    chickenLevel.clear();
    (j['chickenLevel'] as Map?)?.forEach((k, v) {
      chickenLevel[int.parse(k as String)] = v as int;
    });
    if (chickenLevel.isEmpty) chickenLevel[0] = 1;

    chickenShards.clear();
    (j['chickenShards'] as Map?)?.forEach((k, v) {
      chickenShards[int.parse(k as String)] = v as int;
    });

    selectedChicken = j['selectedChicken'] ?? 0;

    upgradeLevel.clear();
    (j['upgradeLevel'] as Map?)?.forEach((k, v) {
      final idx = int.parse(k as String);
      if (idx >= 0 && idx < UpgradeType.values.length) {
        upgradeLevel[UpgradeType.values[idx]] = v as int;
      }
    });

    zonesUnlocked = j['zonesUnlocked'] ?? 1;
    bestDistance = j['bestDistance'] ?? 0;
    bestFlock = j['bestFlock'] ?? 0;
    totalRuns = j['totalRuns'] ?? 0;
    totalDistance = j['totalDistance'] ?? 0;
    totalCoins = j['totalCoins'] ?? 0;
    totalEggs = j['totalEggs'] ?? 0;
    totalJumps = j['totalJumps'] ?? 0;
    dailyStreak = j['dailyStreak'] ?? 0;
    lastDailyClaimDay = j['lastDailyClaimDay'] ?? -1;
    dailyQuestIds = (j['dailyQuestIds'] as List?)?.cast<String>() ?? [];
    questProgress.clear();
    (j['questProgress'] as Map?)?.forEach((k, v) {
      questProgress[k as String] = v as int;
    });
    questClaimed
      ..clear()
      ..addAll((j['questClaimed'] as List?)?.cast<String>() ?? const []);
    questsGeneratedDay = j['questsGeneratedDay'] ?? -1;
    achievementClaimed
      ..clear()
      ..addAll(
          (j['achievementClaimed'] as List?)?.cast<String>() ?? const []);
    soundOn = j['soundOn'] ?? true;
    musicOn = j['musicOn'] ?? true;
    vibrationOn = j['vibrationOn'] ?? true;
    musicVolume = (j['musicVolume'] as num?)?.toDouble() ?? 0.5;
    soundVolume = (j['soundVolume'] as num?)?.toDouble() ?? 0.8;
  }

  // ---------------------------------------------------------------------------
  // Collection helpers
  // ---------------------------------------------------------------------------
  bool isOwned(int speciesId) => (chickenLevel[speciesId] ?? 0) > 0;
  int levelOf(int speciesId) => chickenLevel[speciesId] ?? 0;
  int shardsOf(int speciesId) => chickenShards[speciesId] ?? 0;
  int get ownedCount =>
      chickenLevel.values.where((v) => v > 0).length;

  /// Shards required to move a chicken from [level] to [level] + 1.
  int shardsToLevel(int level) => level + 1;

  bool canFuse(int speciesId) {
    final lvl = levelOf(speciesId);
    if (lvl == 0 || lvl >= maxChickenLevel) return false;
    return shardsOf(speciesId) >= shardsToLevel(lvl) && coins >= _fuseCost(lvl);
  }

  int _fuseCost(int level) => 180 * (level + 1);
  int fuseCost(int speciesId) => _fuseCost(levelOf(speciesId));

  void fuse(int speciesId) {
    if (!canFuse(speciesId)) return;
    final lvl = levelOf(speciesId);
    chickenShards[speciesId] = shardsOf(speciesId) - shardsToLevel(lvl);
    coins -= _fuseCost(lvl);
    chickenLevel[speciesId] = lvl + 1;
    _save();
    notifyListeners();
  }

  /// Hatch one egg from the incubator. Returns the species obtained and whether
  /// it was newly unlocked.
  ({ChickenSpecies species, bool isNew})? hatchEgg() {
    // Weighted pick: common most likely, legendary rarest.
    const weights = [55, 28, 13, 4];
    final total = weights.reduce((a, b) => a + b);
    final cost = _hatchCost();
    if (eggs < cost) return null;
    eggs -= cost;
    var roll = _rng.nextInt(total);
    int picked = 0;
    for (int i = 0; i < weights.length; i++) {
      if (roll < weights[i]) {
        picked = i;
        break;
      }
      roll -= weights[i];
    }
    final species = ChickenRoster.all[picked];
    final wasOwned = isOwned(species.id);
    if (!wasOwned) {
      chickenLevel[species.id] = 1;
    } else {
      chickenShards[species.id] = shardsOf(species.id) + 1;
    }
    _save();
    notifyListeners();
    return (species: species, isNew: !wasOwned);
  }

  int _hatchCost() => 12;
  int get hatchCost => _hatchCost();

  void selectChicken(int speciesId) {
    if (!isOwned(speciesId)) return;
    selectedChicken = speciesId;
    _save();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Upgrades
  // ---------------------------------------------------------------------------
  int upgradeLevelOf(UpgradeType t) => upgradeLevel[t] ?? 0;

  bool canBuyUpgrade(UpgradeType t) {
    final def = Upgrades.byType(t);
    final lvl = upgradeLevelOf(t);
    return lvl < def.maxLevel && coins >= def.costFor(lvl);
  }

  void buyUpgrade(UpgradeType t) {
    if (!canBuyUpgrade(t)) return;
    final def = Upgrades.byType(t);
    final lvl = upgradeLevelOf(t);
    coins -= def.costFor(lvl);
    upgradeLevel[t] = lvl + 1;
    _save();
    notifyListeners();
  }

  // ---- Aggregate run modifiers -------------------------------------------
  double _chickenSum(double Function(ChickenSpecies) sel) {
    double sum = 0;
    for (final s in ChickenRoster.all) {
      final lvl = levelOf(s.id);
      if (lvl > 0) sum += sel(s) * lvl;
    }
    return sum;
  }

  /// Run speed multiplier from chickens + speed upgrade.
  double get speedMultiplier =>
      1.0 +
      _chickenSum((s) => s.baseSpeedBonus).clamp(0, 0.5) +
      upgradeLevelOf(UpgradeType.speed) * Upgrades.byType(UpgradeType.speed).perLevel;

  double get jumpMultiplier =>
      1.0 +
      _chickenSum((s) => s.baseJumpBonus).clamp(0, 0.5) +
      upgradeLevelOf(UpgradeType.jump) * Upgrades.byType(UpgradeType.jump).perLevel;

  double get coinMultiplier =>
      1.0 +
      _chickenSum((s) => s.baseCoinBonus).clamp(0, 1.0) +
      upgradeLevelOf(UpgradeType.coinValue) *
          Upgrades.byType(UpgradeType.coinValue).perLevel;

  /// Extra protective shells granted at the start of a run.
  int get startingShields =>
      upgradeLevelOf(UpgradeType.shield) +
      (_chickenSum((s) => s.baseShieldBonus) >= 0.1 ? 1 : 0);

  int get reviveCharges => upgradeLevelOf(UpgradeType.revive);

  double get magnetRadius =>
      60 + upgradeLevelOf(UpgradeType.magnet) * 40.0;

  // ---------------------------------------------------------------------------
  // Currency mutation
  // ---------------------------------------------------------------------------
  void addCoins(int v) {
    coins += v;
    _save();
    notifyListeners();
  }

  void addEggs(int v) {
    eggs += v;
    _save();
    notifyListeners();
  }

  bool spendCrystals(int v) {
    if (crystals < v) return false;
    crystals -= v;
    _save();
    notifyListeners();
    return true;
  }

  bool spendFeathers(int v) {
    if (feathers < v) return false;
    feathers -= v;
    _save();
    notifyListeners();
    return true;
  }

  bool spendCoins(int v) {
    if (coins < v) return false;
    coins -= v;
    _save();
    notifyListeners();
    return true;
  }

  void grantPack({int coins = 0, int feathers = 0, int crystals = 0, int eggs = 0}) {
    this.coins += coins;
    this.feathers += feathers;
    this.crystals += crystals;
    this.eggs += eggs;
    _save();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Run recording
  // ---------------------------------------------------------------------------
  /// Called at the end of a run. Awards currency, updates stats, quests and
  /// unlocks the next zone when the player is doing well. Returns the list of
  /// achievement ids newly completed so the UI can celebrate them.
  List<String> recordRun(RunResult r) {
    totalRuns += 1;
    totalDistance += r.distance;
    totalCoins += r.coins;
    totalEggs += r.eggs;
    totalJumps += r.jumps;
    if (r.distance > bestDistance) bestDistance = r.distance;
    if (r.maxFlock > bestFlock) bestFlock = r.maxFlock;

    coins += r.coins;
    eggs += r.eggs;

    // Unlock the next zone every time the player pushes past a distance gate.
    final gate = zonesUnlocked * 600;
    if (r.distance >= gate && zonesUnlocked < totalZones) {
      zonesUnlocked += 1;
    }

    _advanceQuests(r);
    final newAch = _checkAchievements(r);

    _save();
    notifyListeners();
    return newAch;
  }

  void _advanceQuests(RunResult r) {
    ensureDailyQuests();
    for (final id in dailyQuestIds) {
      final def = Quests.byId(id);
      final current = questProgress[id] ?? 0;
      int add = 0;
      switch (def.metric) {
        case StatMetric.distance:
          questProgress[id] = max(current, r.distance);
          continue;
        case StatMetric.flockSize:
          questProgress[id] = max(current, r.maxFlock);
          continue;
        case StatMetric.coins:
          questProgress[id] = max(current, r.coins);
          continue;
        case StatMetric.eggs:
          questProgress[id] = max(current, r.eggs);
          continue;
        case StatMetric.runs:
          add = 1;
          break;
        case StatMetric.jumps:
          add = r.jumps;
          break;
        default:
          add = 0;
      }
      questProgress[id] = current + add;
    }
  }

  List<String> _checkAchievements(RunResult r) {
    final newly = <String>[];
    for (final a in Achievements.all) {
      if (achievementClaimed.contains(a.id)) continue;
      if (achievementValue(a.metric, r) >= a.target) {
        newly.add(a.id);
      }
    }
    return newly;
  }

  int achievementValue(StatMetric m, [RunResult? r]) {
    switch (m) {
      case StatMetric.distance:
        return max(bestDistance, r?.distance ?? 0);
      case StatMetric.totalDistance:
        return totalDistance;
      case StatMetric.flockSize:
        return max(bestFlock, r?.maxFlock ?? 0);
      case StatMetric.coins:
        return r?.coins ?? 0;
      case StatMetric.totalCoins:
        return totalCoins;
      case StatMetric.eggs:
        return r?.eggs ?? 0;
      case StatMetric.totalEggs:
        return totalEggs;
      case StatMetric.runs:
        return totalRuns;
      case StatMetric.jumps:
        return totalJumps;
    }
  }

  bool isAchievementComplete(AchievementDef a) =>
      achievementClaimed.contains(a.id) ||
      achievementValue(a.metric) >= a.target;

  bool canClaimAchievement(AchievementDef a) =>
      !achievementClaimed.contains(a.id) &&
      achievementValue(a.metric) >= a.target;

  void claimAchievement(AchievementDef a) {
    if (!canClaimAchievement(a)) return;
    achievementClaimed.add(a.id);
    crystals += a.rewardCrystals;
    _save();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Quests
  // ---------------------------------------------------------------------------
  void ensureDailyQuests() {
    if (questsGeneratedDay == _today && dailyQuestIds.isNotEmpty) return;
    questsGeneratedDay = _today;
    final pool = List<QuestDef>.from(Quests.pool)..shuffle(_rng);
    dailyQuestIds = pool.take(3).map((q) => q.id).toList();
    questProgress.removeWhere((key, _) => !dailyQuestIds.contains(key));
    for (final id in dailyQuestIds) {
      questProgress[id] = 0;
    }
    questClaimed.removeWhere((id) => !dailyQuestIds.contains(id));
  }

  bool isQuestComplete(String id) =>
      (questProgress[id] ?? 0) >= Quests.byId(id).target;

  bool isQuestClaimed(String id) => questClaimed.contains(id);

  void claimQuest(String id) {
    if (!isQuestComplete(id) || isQuestClaimed(id)) return;
    final def = Quests.byId(id);
    questClaimed.add(id);
    coins += def.rewardCoins;
    feathers += def.rewardFeathers;
    _save();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Daily reward wheel
  // ---------------------------------------------------------------------------
  bool get canClaimDaily => lastDailyClaimDay != _today;

  /// The fixed set of segments shown on the daily wheel.
  List<DailyReward> get dailyWheel => [
        DailyReward('coins', 150),
        DailyReward('eggs', 8),
        DailyReward('feathers', 3),
        DailyReward('coins', 350),
        DailyReward('crystals', 1),
        DailyReward('eggs', 15),
      ];

  /// Grant a specific wheel segment (used by the animated wheel UI) and mark
  /// today's reward as claimed.
  void commitDaily(DailyReward reward) {
    if (!canClaimDaily) return;
    if (lastDailyClaimDay == _today - 1) {
      dailyStreak += 1;
    } else {
      dailyStreak = 1;
    }
    lastDailyClaimDay = _today;
    switch (reward.type) {
      case 'coins':
        coins += reward.amount;
        break;
      case 'eggs':
        eggs += reward.amount;
        break;
      case 'feathers':
        feathers += reward.amount;
        break;
      case 'crystals':
        crystals += reward.amount;
        break;
    }
    _save();
    notifyListeners();
  }

  DailyReward claimDaily() {
    // Streak bonus scales the reward slightly.
    if (lastDailyClaimDay == _today - 1) {
      dailyStreak += 1;
    } else {
      dailyStreak = 1;
    }
    lastDailyClaimDay = _today;

    final options = <DailyReward>[
      DailyReward('coins', 100 + dailyStreak * 20),
      DailyReward('eggs', 5 + dailyStreak),
      DailyReward('feathers', 2 + dailyStreak ~/ 2),
      DailyReward('coins', 250),
      DailyReward('crystals', 1),
      DailyReward('eggs', 12),
    ];
    final reward = options[_rng.nextInt(options.length)];
    switch (reward.type) {
      case 'coins':
        coins += reward.amount;
        break;
      case 'eggs':
        eggs += reward.amount;
        break;
      case 'feathers':
        feathers += reward.amount;
        break;
      case 'crystals':
        crystals += reward.amount;
        break;
    }
    _save();
    notifyListeners();
    return reward;
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------
  void setSound(bool v) {
    soundOn = v;
    AudioManager.instance.setSoundEnabled(v);
    _save();
    notifyListeners();
  }

  void setMusic(bool v) {
    musicOn = v;
    AudioManager.instance.setMusicEnabled(v);
    _save();
    notifyListeners();
  }

  void setVibration(bool v) {
    vibrationOn = v;
    _save();
    notifyListeners();
  }

  void setMusicVolume(double v) {
    musicVolume = v.clamp(0.0, 1.0);
    AudioManager.instance.setMusicVolume(musicVolume);
    _save();
    notifyListeners();
  }

  void setSoundVolume(double v) {
    soundVolume = v.clamp(0.0, 1.0);
    AudioManager.instance.setSoundVolume(soundVolume);
    _save();
    notifyListeners();
  }

  void resetProgress() {
    coins = 150;
    feathers = 5;
    crystals = 1;
    eggs = 10;
    chickenLevel
      ..clear()
      ..[0] = 1;
    chickenShards.clear();
    selectedChicken = 0;
    upgradeLevel.clear();
    zonesUnlocked = 1;
    bestDistance = 0;
    bestFlock = 0;
    totalRuns = 0;
    totalDistance = 0;
    totalCoins = 0;
    totalEggs = 0;
    totalJumps = 0;
    dailyStreak = 0;
    lastDailyClaimDay = -1;
    questClaimed.clear();
    achievementClaimed.clear();
    questsGeneratedDay = -1;
    ensureDailyQuests();
    _save();
    notifyListeners();
  }
}
