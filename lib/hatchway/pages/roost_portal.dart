import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../infra/airway_probe.dart';
import '../infra/egg_signal_hub.dart';
import '../infra/nest_vault.dart';
import '../infra/roost_agent.dart';
import 'empty_air_page.dart';

class RoostPortal extends StatefulWidget {
  const RoostPortal({
    super.key,
    required this.url,
    required this.vault,
    required this.probe,
    required this.notifications,
    required this.agent,
    this.coldLaunch = false,
  });

  final String url;
  final NestVault vault;
  final AirwayProbe probe;
  final EggSignalHub notifications;
  final RoostAgent agent;
  final bool coldLaunch;

  @override
  State<RoostPortal> createState() => _RoostPortalState();
}

class _RoostPortalState extends State<RoostPortal> with WidgetsBindingObserver {
  late final WebViewController _controller;
  StreamSubscription<List<ConnectivityResult>>? _networkSubscription;
  bool _viewportReady = false;
  bool _coldReloadIssued = false;
  bool _offlineShown = false;
  int _redirectAttempts = 0;
  String? _lastMainUrl;
  Timer? _metricsDebounce;
  Size? _lastMetricsSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterImmersive();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    final params = Platform.isIOS
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();
    _controller =
        WebViewController.fromPlatformCreationParams(
            params,
            onPermissionRequest: (request) => request.grant(),
          )
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.black)
          ..setUserAgent(widget.agent.userAgent)
          ..enableZoom(false)
          ..setNavigationDelegate(_navigation());
    if (_controller.platform is WebKitWebViewController) {
      (_controller.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }

    widget.notifications.onDestination = (url) {
      final uri = Uri.tryParse(url);
      if (mounted && uri != null && uri.hasScheme) {
        _controller.loadRequest(uri);
      }
    };
    _networkSubscription = widget.probe.changes.listen((states) {
      if (states.every((state) => state == ConnectivityResult.none)) {
        // Connectivity is definitively gone — show offline immediately,
        // no DNS probe (a probe hangs for seconds while offline and lets
        // the WebView render its built-in error page first).
        _goOffline();
      }
    });

    if (widget.coldLaunch) {
      _settleColdViewport();
    } else {
      _viewportReady = true;
      _controller.loadRequest(Uri.parse(widget.url));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePending());
  }

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _settleColdViewport() async {
    _enterImmersive();
    // Let immersive mode settle in the phone's ACTUAL orientation before the
    // WebView mounts, so WKWebView measures the correct viewport. We do NOT
    // force a landscape nudge here — that made a cold-start push link open
    // sideways and then flip. Any residual stretch is corrected after load by
    // the resize + single reload in onPageFinished, in the current orientation.
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    setState(() => _viewportReady = true);
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    setState(() {});
    // On rotation the physical size flips. WKWebView can briefly render at
    // the pre-rotation viewport (stretched / "broken") until it recalcs.
    // Once metrics settle, force a single resize + re-assert the inset CSS
    // so the site reflows cleanly instead of jittering.
    final view = View.of(context);
    final size = view.physicalSize;
    final rotated = _lastMetricsSize != null &&
        ((_lastMetricsSize!.width < _lastMetricsSize!.height) !=
            (size.width < size.height));
    _lastMetricsSize = size;
    if (!rotated) return;
    _enterImmersive();
    // WKWebView keeps the pre-rotation viewport width for a few hundred ms,
    // so the site renders at the wrong width right after the flip. Kick a
    // resize/orientationchange several times as the native frame settles so
    // the page reflows to the new width quickly instead of after ~1s.
    _metricsDebounce?.cancel();
    _pokeReflow(const [40, 160, 320, 560, 850]);
  }

  void _pokeReflow(List<int> delaysMs) {
    for (final ms in delaysMs) {
      Timer(Duration(milliseconds: ms), () {
        if (!mounted) return;
        _controller.runJavaScript(
          'window.dispatchEvent(new Event("orientationchange"));'
          'window.dispatchEvent(new Event("resize"));'
          'if(window.visualViewport)'
          '  window.visualViewport.dispatchEvent(new Event("resize"));',
        ).catchError((_) {});
      });
    }
    // Re-assert viewport lock once things have settled.
    _metricsDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      _installInsetGuard();
      _installZoomLock();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enterImmersive();
      _consumePending();
    }
  }

  Future<void> _consumePending() async {
    final value = await widget.vault.consumePushUrl();
    final uri = value == null ? null : Uri.tryParse(value);
    if (mounted && uri != null && uri.hasScheme) {
      await _controller.loadRequest(uri);
    }
  }

  NavigationDelegate _navigation() {
    return NavigationDelegate(
      onPageStarted: (url) {
        _lastMainUrl = url;
      },
      onPageFinished: (_) {
        _redirectAttempts = 0;
        _installInsetGuard();
        _installZoomLock();
        _installTapPolish();
        _installKeyboardLift();
        _installFocusScaleGuard();
        _installInlinePlayback();
        Future<void>.delayed(const Duration(milliseconds: 800), () async {
          if (!mounted) return;
          setState(() {});
          await _controller.runJavaScript(
            'window.dispatchEvent(new Event("resize"));'
            'window.visualViewport?.dispatchEvent(new Event("resize"));',
          );
          _installInsetGuard();
          if (widget.coldLaunch && !_coldReloadIssued) {
            _coldReloadIssued = true;
            await _controller.reload();
          }
        });
      },
      onWebResourceError: (error) {
        // -999 = cancelled (a new navigation superseded this one).
        if (error.errorCode == -999) return;
        // WKWebView sometimes reports isForMainFrame as null for the main
        // navigation — treat null as main-frame so a real load failure is
        // never silently swallowed (that was leaving the app "frozen").
        final mainFrame = error.isForMainFrame ?? true;
        final lower = error.description.toLowerCase();
        final redirectLoop =
            error.errorCode == -1007 ||
            lower.contains('too_many_redirects') ||
            lower.contains('too many redirects');
        if (redirectLoop && _lastMainUrl != null && _redirectAttempts < 3) {
          _redirectAttempts++;
          _controller.loadRequest(Uri.parse(_lastMainUrl!));
          return;
        }
        if (!mainFrame) return;
        // Codes that mean the network is unreachable → confirm with a probe.
        _showOfflineAfterProbe();
      },
      onNavigationRequest: (request) {
        final uri = Uri.tryParse(request.url);
        if (uri == null) return NavigationDecision.prevent;
        if (<String>{
          'http',
          'https',
          'about',
          'data',
          'blob',
        }.contains(uri.scheme)) {
          if (request.isMainFrame) _lastMainUrl = request.url;
          return NavigationDecision.navigate;
        }
        launchUrl(uri, mode: LaunchMode.externalApplication);
        return NavigationDecision.prevent;
      },
    );
  }

  /// Confirms the outage with a reachability probe (used for WebView load
  /// errors, which can be transient) before routing to the offline screen.
  Future<void> _showOfflineAfterProbe() async {
    if (_offlineShown) return;
    bool online = true;
    try {
      online = await widget.probe.canReachNetwork();
    } catch (_) {
      online = false;
    }
    if (online) return;
    _goOffline();
  }

  /// Routes to the offline screen immediately (no probe). Safe to call from
  /// multiple triggers thanks to the [_offlineShown] guard.
  Future<void> _goOffline() async {
    if (_offlineShown || !mounted) return;
    _offlineShown = true;
    String current;
    try {
      current = await _controller.currentUrl() ?? widget.url;
    } catch (_) {
      current = widget.url;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => EmptyAirPage(
          probe: widget.probe,
          retryBuilder: (_) => RoostPortal(
            url: current,
            vault: widget.vault,
            probe: widget.probe,
            notifications: widget.notifications,
            agent: widget.agent,
          ),
        ),
      ),
    );
  }

  void _installInsetGuard() {
    _controller.runJavaScript(r'''
(() => {
  const root = window;
  if (root.__cedInsetKeeper) return;
  root.__cedInsetKeeper = true;
  const marker = 'ced-inset-sheet';
  const rules = [
    ':root{',
    '--safe-area-inset-top:0px!important;',
    '--safe-area-inset-right:0px!important;',
    '--safe-area-inset-bottom:0px!important;',
    '--safe-area-inset-left:0px!important;',
    '--sat:0px!important;--sar:0px!important;',
    '--sab:0px!important;--sal:0px!important;',
    '--safe-top:0px!important;--safe-right:0px!important;',
    '--safe-bottom:0px!important;--safe-left:0px!important;',
    '}',
    // Lock the document edges: no rubber-band overscroll that would
    // reveal the black scaffold above/below the site. Makes the page
    // feel static like a native app. Does not touch the site's layout.
    'html,body{overscroll-behavior:none!important;',
    'overscroll-behavior-y:none!important;}'
  ].join('');
  const keyboardVisible = () => {
    const visual = root.visualViewport;
    return !!visual && visual.height < root.innerHeight * 0.75;
  };
  const refresh = () => {
    if (keyboardVisible()) return;
    const host = document.head || document.documentElement;
    if (!host) return;
    let viewport = document.querySelector('meta[name="viewport"]');
    if (!viewport) {
      viewport = document.createElement('meta');
      viewport.name = 'viewport';
      viewport.content = 'width=device-width, initial-scale=1, viewport-fit=contain';
      host.appendChild(viewport);
    } else {
      const clean = (viewport.content || '')
        .replace(/,?\s*viewport-fit\s*=\s*\w+/ig, '').trim();
      viewport.content = `${clean}${clean ? ', ' : ''}viewport-fit=contain`;
    }
    let sheet = document.getElementById(marker);
    if (!sheet) {
      sheet = document.createElement('style');
      sheet.id = marker;
      host.appendChild(sheet);
    }
    sheet.textContent = rules;
  };
  const schedule = () => {
    root.setTimeout(refresh, 170);
    root.setTimeout(refresh, 640);
  };
  ['pushState', 'replaceState'].forEach((name) => {
    const original = history[name];
    history[name] = function(...args) {
      const result = original.apply(this, args);
      schedule();
      return result;
    };
  });
  root.addEventListener('popstate', schedule);
  refresh();
  root.setInterval(refresh, 2900);
})();
''');
  }

  /// Locks the page at 1:1 scale — no pinch / double-tap / gesture zoom, so
  /// the offer behaves like a native screen. Idempotent + re-asserts the
  /// viewport on SPA navigations.
  void _installZoomLock() {
    _controller.runJavaScript(r'''
(() => {
  if (window.__cedZoomLock) return;
  window.__cedZoomLock = true;
  const lockViewport = () => {
    const host = document.head || document.documentElement;
    if (!host) return;
    let vp = document.querySelector('meta[name="viewport"]');
    if (!vp) {
      vp = document.createElement('meta');
      vp.setAttribute('name', 'viewport');
      host.appendChild(vp);
    }
    vp.setAttribute('content',
      'width=device-width, initial-scale=1.0, maximum-scale=1.0, ' +
      'minimum-scale=1.0, user-scalable=no, viewport-fit=contain');
  };
  lockViewport();
  const stop = (e) => { e.preventDefault(); };
  ['gesturestart', 'gesturechange', 'gestureend'].forEach((t) =>
    document.addEventListener(t, stop, {passive: false}));
  document.addEventListener('touchmove', (e) => {
    if (e.scale !== undefined && e.scale !== 1) e.preventDefault();
  }, {passive: false});
  let lastTap = 0;
  document.addEventListener('touchend', (e) => {
    const now = Date.now();
    if (now - lastTap <= 300) e.preventDefault();
    lastTap = now;
  }, {passive: false});
  ['pushState', 'replaceState'].forEach((name) => {
    const original = history[name];
    history[name] = function(...args) {
      const result = original.apply(this, args);
      setTimeout(lockViewport, 150);
      return result;
    };
  });
  window.addEventListener('popstate', () => setTimeout(lockViewport, 150));
})();
''');
  }

  /// Kills the grey/black translucent box WKWebView paints on every tap
  /// (default `-webkit-tap-highlight-color`) and the long-press callout, so
  /// tapping elements feels native. Inputs stay selectable.
  void _installTapPolish() {
    _controller.runJavaScript(r'''
(() => {
  if (window.__cedTapPolish) return;
  window.__cedTapPolish = true;
  const style = document.createElement('style');
  style.id = 'ced-tap-polish';
  style.textContent =
    '*{-webkit-tap-highlight-color:transparent!important;}' +
    '*:not(input):not(textarea):not([contenteditable="true"]){' +
      '-webkit-touch-callout:none!important;}';
  (document.head || document.documentElement).appendChild(style);
})();
''');
  }

  void _installKeyboardLift() {
    _controller.runJavaScript(r'''
(() => {
  if (window.__cedInputLift) return;
  window.__cedInputLift = true;
  const editable = (node) => !!node && (
    node.matches?.('input, textarea, select, [contenteditable="true"]')
  );
  const reveal = () => {
    const active = document.activeElement;
    if (!editable(active)) return;
    active.scrollIntoView({behavior: 'auto', block: 'nearest'});
  };
  document.addEventListener('focusin', (event) => {
    if (editable(event.target)) window.setTimeout(reveal, 350);
  }, true);
})();
''');
  }

  void _installFocusScaleGuard() {
    if (!Platform.isIOS) return;
    _controller.runJavaScript(r'''
(() => {
  if (window.__cedFocusScale) return;
  window.__cedFocusScale = true;
  const style = document.createElement('style');
  style.textContent =
    'input,textarea,select,[contenteditable="true"]{' +
    'font-size:max(16px,1em)!important;}';
  (document.head || document.documentElement).appendChild(style);
})();
''');
  }

  void _installInlinePlayback() {
    _controller.runJavaScript(r'''
(() => {
  if (window.__cedInlineMedia) return;
  window.__cedInlineMedia = true;
  const awaken = (video) => {
    if (!(video instanceof HTMLVideoElement)) return;
    video.setAttribute('playsinline', '');
    video.setAttribute('webkit-playsinline', '');
    video.playsInline = true;
    video.autoplay = true;
    const attempt = video.play();
    if (attempt?.catch) attempt.catch(() => {});
  };
  const scan = (node) => {
    if (node instanceof HTMLVideoElement) awaken(node);
    node.querySelectorAll?.('video').forEach(awaken);
  };
  scan(document);
  new MutationObserver((records) => {
    records.forEach((record) => record.addedNodes.forEach(scan));
  }).observe(document.documentElement, {childList: true, subtree: true});
})();
''');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _metricsDebounce?.cancel();
    _networkSubscription?.cancel();
    widget.notifications.onDestination = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).viewPadding;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _controller.canGoBack()) {
          await _controller.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: _viewportReady
            ? Padding(
                // Respect notch/Dynamic Island (top + sides) AND the home
                // indicator (bottom) in BOTH orientations. Cold-start uses
                // viewPadding (never EdgeInsets.zero) so the bottom inset is
                // not lost while immersive mode settles.
                padding: EdgeInsets.only(
                  top: safe.top,
                  bottom: safe.bottom,
                  left: safe.left,
                  right: safe.right,
                ),
                child: WebViewWidget(controller: _controller),
              )
            : const ColoredBox(color: Colors.black),
      ),
    );
  }
}
