import 'dart:async';

import 'package:flutter/material.dart';

import '../core/assets.dart';
import '../core/theme.dart';

/// The very first screen. Shows the branded loading art (portrait or landscape
/// depending on device orientation) with a horizontal progress bar that fills
/// left-to-right, a "Loading..." label and a synced percentage.
///
/// Guarantees:
///  * The bar and the percentage always stay in sync (they read the same value).
///  * The bar only reaches a full 100% right before we hand off to the app.
///  * Loading always completes in well under 10 seconds even if asset
///    pre-caching stalls (a hard deadline forces completion).
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  static const Duration _tick = Duration(milliseconds: 30);

  // Hard ceiling: no matter what, we finish before this and never get stuck.
  static const Duration _hardDeadline = Duration(milliseconds: 5500);

  double _progress = 0; // 0..1, the single source of truth for bar + percent.
  bool _preloadDone = false;
  bool _finished = false;
  bool _precacheStarted = false;
  Timer? _timer;
  final Stopwatch _watch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _watch.start();
    _timer = Timer.periodic(_tick, _onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-cache once we have a context capable of resolving image configs.
    if (!_precacheStarted) {
      _precacheStarted = true;
      _preload();
    }
  }

  Future<void> _preload() async {
    for (final path in Assets.preloadList) {
      try {
        await precacheImage(AssetImage(path), context);
      } catch (_) {
        // Ignore a single asset failing; keep the loader moving.
      }
      if (!mounted) return;
    }
    _preloadDone = true;
  }

  void _onTick(Timer _) {
    if (!mounted) return;
    final elapsedMs = _watch.elapsedMilliseconds;

    // Force completion if the pre-cache hangs so we never stall (e.g. at 97%).
    if (elapsedMs >= _hardDeadline.inMilliseconds) {
      _preloadDone = true;
    }

    // Phase 1: climb steadily toward 90% over ~2.6s in visible increments.
    // Phase 2: once assets are ready (or the deadline hit), rush to 100%.
    final double target = _preloadDone ? 1.0 : 0.9;
    final double step = _preloadDone ? 0.06 : 0.9 / (2600 / _tick.inMilliseconds);
    var next = _progress + step;
    if (next > target) next = target;

    if (next != _progress) {
      setState(() => _progress = next);
    }

    if (_progress >= 1.0 && !_finished) {
      _finished = true;
      _timer?.cancel();
      // Brief beat on a full bar so 100% is actually seen before we leave.
      Future.delayed(const Duration(milliseconds: 280), () {
        if (mounted) widget.onDone();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final bg = isPortrait ? Assets.loadingVertical : Assets.loadingHorizontal;

    return Scaffold(
      backgroundColor: AppColors.skyTop,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(bg, fit: BoxFit.cover),
          isPortrait ? _portraitOverlay() : _landscapeOverlay(),
        ],
      ),
    );
  }

  /// Portrait: a wide bar sitting in the lower area, label above, percent below.
  Widget _portraitOverlay() {
    final width = MediaQuery.of(context).size.width;
    return Align(
      alignment: const Alignment(0, 0.62),
      child: _progressGroup(
        barWidth: width * 0.72,
        barHeight: 26,
        labelSize: 24,
        percentSize: 22,
      ),
    );
  }

  /// Landscape: a smaller bar pinned near the bottom of the screen, with the
  /// label and percentage centered around it.
  Widget _landscapeOverlay() {
    final width = MediaQuery.of(context).size.width;
    return Align(
      alignment: const Alignment(0, 0.9),
      child: _progressGroup(
        barWidth: width * 0.44,
        barHeight: 20,
        labelSize: 20,
        percentSize: 18,
      ),
    );
  }

  Widget _progressGroup({
    required double barWidth,
    required double barHeight,
    required double labelSize,
    required double percentSize,
  }) {
    final percent = (_progress * 100).round();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LoadingLabel(fontSize: labelSize),
        const SizedBox(height: 10),
        _ProgressBar(
          value: _progress,
          width: barWidth,
          height: barHeight,
        ),
        const SizedBox(height: 8),
        Text(
          '$percent%',
          style: AppText.title(percentSize),
        ),
      ],
    );
  }
}

/// "Loading" with cycling dots (. .. ...), kept steady in width so it doesn't
/// shift the layout as the dots change.
class _LoadingLabel extends StatefulWidget {
  const _LoadingLabel({required this.fontSize});
  final double fontSize;

  @override
  State<_LoadingLabel> createState() => _LoadingLabelState();
}

class _LoadingLabelState extends State<_LoadingLabel> {
  Timer? _timer;
  int _dots = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (mounted) setState(() => _dots = (_dots + 1) % 4);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Loading', style: AppText.title(widget.fontSize)),
        SizedBox(
          width: widget.fontSize * 1.3,
          child: Text(
            '.' * _dots,
            style: AppText.title(widget.fontSize),
          ),
        ),
      ],
    );
  }
}

/// The horizontal fill bar. Fills left → right based on [value] (0..1).
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.value,
    required this.width,
    required this.height,
  });

  final double value;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(height),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: AppColors.panelShadow,
            offset: Offset(0, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.sunYellowDark, AppColors.sunYellow],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
