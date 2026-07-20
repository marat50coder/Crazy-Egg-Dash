import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

import '../core/assets.dart';

/// Loads and holds decoded [ui.Image]s so the game's [CustomPainter] can draw
/// them directly onto the canvas (much cheaper per-frame than widgets).
class GameImages {
  final Map<String, ui.Image> _cache = {};

  ui.Image? operator [](String key) => _cache[key];

  ui.Image get(String key) => _cache[key]!;

  bool get isReady => _cache.isNotEmpty;

  /// Natural width/height ratio for each loaded key (skips any that failed).
  Map<String, double> aspectRatios(List<String> keys) {
    final out = <String, double>{};
    for (final k in keys) {
      final img = _cache[k];
      if (img != null && img.height > 0) {
        out[k] = img.width / img.height;
      }
    }
    return out;
  }

  Future<void> loadAll() async {
    final paths = <String>{
      ...Assets.chickenIdle,
      ...Assets.chickenRun,
      ...Assets.chickenJump,
      ...Assets.backgrounds,
      Assets.magicBox,
      Assets.cloud,
      Assets.egg,
      Assets.goldenEgg,
      Assets.speckledEgg,
      Assets.brokenEggs,
      Assets.rock,
      Assets.treeStump,
      Assets.log,
      Assets.bush,
      Assets.tree,
      Assets.platform,
      Assets.floatingPlatform,
      Assets.finish,
      Assets.coin,
      Assets.feather,
    };

    for (final p in paths) {
      if (_cache.containsKey(p)) continue;
      try {
        final data = await rootBundle.load(p);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
        );
        final frame = await codec.getNextFrame();
        _cache[p] = frame.image;
      } catch (_) {
        // Skip a broken asset rather than aborting the whole load.
      }
    }
  }

  void dispose() {
    for (final img in _cache.values) {
      img.dispose();
    }
    _cache.clear();
  }
}
