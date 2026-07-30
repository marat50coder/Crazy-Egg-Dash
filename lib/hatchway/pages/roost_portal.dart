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
  static const List<int> _rotationReflowDelaysMs = <int>[45, 165, 330, 570, 860];

  late final WebViewController _controller;
  StreamSubscription<List<ConnectivityResult>>? _pipeSubscription;
  bool _viewportReady = false;
  bool _coldReloadIssued = false;
  bool _offlineShown = false;
  int _redirectAttempts = 0;
  String? _lastMainUrl;
  Timer? _viewportSettleTimer;
  Size? _previousMetricsSize;

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

    _controller = _forgeController();

    widget.notifications.onDestination = _routeIncomingUrl;
    _pipeSubscription = widget.probe.changes.listen(_onConnectivityChanged);

    if (widget.coldLaunch) {
      _settleColdViewport();
    } else {
      _viewportReady = true;
      _controller.loadRequest(Uri.parse(widget.url));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePending());
  }

  WebViewController _forgeController() {
    final PlatformWebViewControllerCreationParams params = Platform.isIOS
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();
    final controller = WebViewController.fromPlatformCreationParams(
      params,
      onPermissionRequest: (request) => request.grant(),
    );
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(widget.agent.userAgent)
      ..enableZoom(false)
      ..setNavigationDelegate(_navigation());
    final platform = controller.platform;
    if (platform is WebKitWebViewController) {
      platform.setAllowsBackForwardNavigationGestures(true);
    }
    return controller;
  }

  void _routeIncomingUrl(String url) {
    final uri = Uri.tryParse(url);
    if (!mounted || uri == null || !uri.hasScheme) return;
    _controller.loadRequest(uri);
  }

  void _onConnectivityChanged(List<ConnectivityResult> states) {
    // Connectivity is definitively gone → show offline immediately, no DNS
    // probe (a probe hangs for seconds while offline and lets WKWebView
    // render its built-in error page first).
    var allNone = true;
    for (final state in states) {
      if (state != ConnectivityResult.none) {
        allNone = false;
        break;
      }
    }
    if (allNone) _goOffline();
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
    final prev = _previousMetricsSize;
    _previousMetricsSize = size;
    if (prev == null) return;
    final wasPortrait = prev.width < prev.height;
    final isPortrait = size.width < size.height;
    if (wasPortrait == isPortrait) return;
    _enterImmersive();
    // WKWebView keeps the pre-rotation viewport width for a few hundred ms,
    // so the site renders at the wrong width right after the flip. Kick a
    // resize/orientationchange several times as the native frame settles so
    // the page reflows to the new width quickly instead of after ~1s.
    _viewportSettleTimer?.cancel();
    _pokeReflow(_rotationReflowDelaysMs);
  }

  void _pokeReflow(List<int> delaysMs) {
    var i = 0;
    while (i < delaysMs.length) {
      final ms = delaysMs[i];
      Timer(Duration(milliseconds: ms), () {
        if (!mounted) return;
        _controller.runJavaScript(
          'window.dispatchEvent(new Event("orientationchange"));'
          'window.dispatchEvent(new Event("resize"));'
          'if(window.visualViewport)'
          '  window.visualViewport.dispatchEvent(new Event("resize"));',
        ).catchError((_) {});
      });
      i++;
    }
    // Re-assert viewport lock once things have settled.
    _viewportSettleTimer = Timer(const Duration(milliseconds: 320), () {
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
      onWebResourceError: _translateResourceError,
      onNavigationRequest: _decideNavigation,
    );
  }

  void _translateResourceError(WebResourceError error) {
    // -999 = cancelled (a new navigation superseded this one).
    if (error.errorCode == -999) return;
    // WKWebView sometimes reports isForMainFrame as null for the main
    // navigation — treat null as main-frame so a real load failure is
    // never silently swallowed (that was leaving the app "frozen").
    final mainFrame = error.isForMainFrame ?? true;
    final lower = error.description.toLowerCase();
    final redirectLoop = error.errorCode == -1007 ||
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
  }

  NavigationDecision _decideNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    const inAppSchemes = <String>{'http', 'https', 'about', 'data', 'blob'};
    if (inAppSchemes.contains(uri.scheme)) {
      if (request.isMainFrame) _lastMainUrl = request.url;
      return NavigationDecision.navigate;
    }
    launchUrl(uri, mode: LaunchMode.externalApplication);
    return NavigationDecision.prevent;
  }

  /// Confirms the outage with a reachability probe (used for WebView load
  /// errors, which can be transient) before routing to the offline screen.
  Future<void> _showOfflineAfterProbe() async {
    if (_offlineShown) return;
    var online = true;
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
(function(){
  var W = window;
  if (W.__dashYolkGuard) { return; }
  W.__dashYolkGuard = 1;
  var SHEET_ID = 'dash-yolk-slab';
  var RULES = [
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
    'html,body{',
      'overscroll-behavior:none!important;',
      'overscroll-behavior-y:none!important;',
    '}'
  ].join('');
  function kbUp(){
    var vv = W.visualViewport;
    if (!vv) { return false; }
    return vv.height < (W.innerHeight * 0.75);
  }
  function paint(){
    if (kbUp()) { return; }
    var head = document.head || document.documentElement;
    if (!head) { return; }
    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.name = 'viewport';
      meta.content = 'width=device-width, initial-scale=1, viewport-fit=contain';
      head.appendChild(meta);
    } else {
      var clean = ('' + (meta.content || ''))
        .replace(/,?\s*viewport-fit\s*=\s*\w+/ig, '').trim();
      meta.content = clean + (clean ? ', ' : '') + 'viewport-fit=contain';
    }
    var css = document.getElementById(SHEET_ID);
    if (!css) {
      css = document.createElement('style');
      css.id = SHEET_ID;
      head.appendChild(css);
    }
    css.textContent = RULES;
  }
  function ping(){
    W.setTimeout(paint, 180);
    W.setTimeout(paint, 620);
  }
  var patch = ['pushState', 'replaceState'];
  for (var i = 0; i < patch.length; i++) {
    (function(name){
      var orig = history[name];
      history[name] = function(){
        var r = orig.apply(this, arguments);
        ping();
        return r;
      };
    })(patch[i]);
  }
  W.addEventListener('popstate', ping);
  paint();
  W.setInterval(paint, 3100);
})();
''');
  }

  /// Locks the page at 1:1 scale — no pinch / double-tap / gesture zoom, so
  /// the offer behaves like a native screen. Idempotent + re-asserts the
  /// viewport on SPA navigations.
  void _installZoomLock() {
    _controller.runJavaScript(r'''
(function(){
  if (window.__dashClampScale) { return; }
  window.__dashClampScale = true;
  var VIEWPORT = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, '
    + 'minimum-scale=1.0, user-scalable=no, viewport-fit=contain';
  function pinViewport(){
    var head = document.head || document.documentElement;
    if (!head) { return; }
    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.setAttribute('name', 'viewport');
      head.appendChild(meta);
    }
    meta.setAttribute('content', VIEWPORT);
  }
  pinViewport();
  function block(ev){ ev.preventDefault(); }
  var gestures = ['gesturestart', 'gesturechange', 'gestureend'];
  for (var g = 0; g < gestures.length; g++) {
    document.addEventListener(gestures[g], block, {passive: false});
  }
  document.addEventListener('touchmove', function(ev){
    if (ev.scale !== undefined && ev.scale !== 1) { ev.preventDefault(); }
  }, {passive: false});
  var lastTapAt = 0;
  document.addEventListener('touchend', function(ev){
    var now = Date.now();
    if ((now - lastTapAt) <= 300) { ev.preventDefault(); }
    lastTapAt = now;
  }, {passive: false});
  var patch = ['pushState', 'replaceState'];
  for (var i = 0; i < patch.length; i++) {
    (function(name){
      var orig = history[name];
      history[name] = function(){
        var r = orig.apply(this, arguments);
        setTimeout(pinViewport, 170);
        return r;
      };
    })(patch[i]);
  }
  window.addEventListener('popstate', function(){ setTimeout(pinViewport, 170); });
})();
''');
  }

  /// Kills the grey/black translucent box WKWebView paints on every tap
  /// (default `-webkit-tap-highlight-color`) and the long-press callout, so
  /// tapping elements feels native. Inputs stay selectable.
  void _installTapPolish() {
    _controller.runJavaScript(r'''
(function(){
  if (window.__dashRippleMute) { return; }
  window.__dashRippleMute = 1;
  var css = document.createElement('style');
  css.id = 'dash-tap-slab';
  var lines = [
    '*{-webkit-tap-highlight-color:transparent!important;}',
    '*:not(input):not(textarea):not([contenteditable="true"]){',
      '-webkit-touch-callout:none!important;',
    '}'
  ];
  css.textContent = lines.join('');
  (document.head || document.documentElement).appendChild(css);
})();
''');
  }

  void _installKeyboardLift() {
    _controller.runJavaScript(r'''
(function(){
  if (window.__dashLiftCaret) { return; }
  window.__dashLiftCaret = 1;
  var SEL = 'input, textarea, select, [contenteditable="true"]';
  function editable(node){
    if (!node || !node.matches) { return false; }
    try { return node.matches(SEL); } catch (e) { return false; }
  }
  function bringIntoView(){
    var el = document.activeElement;
    if (!editable(el)) { return; }
    el.scrollIntoView({behavior: 'auto', block: 'nearest'});
  }
  document.addEventListener('focusin', function(ev){
    if (editable(ev.target)) {
      window.setTimeout(bringIntoView, 360);
    }
  }, true);
})();
''');
  }

  void _installFocusScaleGuard() {
    if (!Platform.isIOS) return;
    _controller.runJavaScript(r'''
(function(){
  if (window.__dashLegibleForms) { return; }
  window.__dashLegibleForms = 1;
  var css = document.createElement('style');
  css.textContent = 'input,textarea,select,[contenteditable="true"]{'
    + 'font-size:max(16px,1em)!important;}';
  (document.head || document.documentElement).appendChild(css);
})();
''');
  }

  void _installInlinePlayback() {
    _controller.runJavaScript(r'''
(function(){
  if (window.__dashRestVideo) { return; }
  window.__dashRestVideo = 1;
  function warm(video){
    if (!(video instanceof HTMLVideoElement)) { return; }
    video.setAttribute('playsinline', '');
    video.setAttribute('webkit-playsinline', '');
    video.playsInline = true;
    video.autoplay = true;
    var p = null;
    try { p = video.play(); } catch (e) {}
    if (p && p.catch) { p.catch(function(){}); }
  }
  function walk(node){
    if (node instanceof HTMLVideoElement) { warm(node); }
    if (node.querySelectorAll) {
      var list = node.querySelectorAll('video');
      for (var i = 0; i < list.length; i++) { warm(list[i]); }
    }
  }
  walk(document);
  var mo = new MutationObserver(function(records){
    for (var r = 0; r < records.length; r++) {
      var added = records[r].addedNodes;
      for (var a = 0; a < added.length; a++) { walk(added[a]); }
    }
  });
  mo.observe(document.documentElement, {childList: true, subtree: true});
})();
''');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewportSettleTimer?.cancel();
    _pipeSubscription?.cancel();
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
