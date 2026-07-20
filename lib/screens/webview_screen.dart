import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/config.dart';
import '../core/theme.dart';

/// Which document to display.
enum LegalPage { privacy, support }

/// Displays Privacy Policy / Support inside a WebView.
///
/// The page is guaranteed to always be viewable — with or without internet:
///  * If a real URL is configured it is loaded from the web.
///  * If the URL is empty (current state) or the network request fails, a
///    bundled offline HTML document is shown instead (black text on white).
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key, required this.page});

  final LegalPage page;

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  String get _title =>
      widget.page == LegalPage.privacy ? 'Privacy Policy' : 'Support';

  String get _url => widget.page == LegalPage.privacy
      ? AppConfig.privacyPolicyUrl
      : AppConfig.supportUrl;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            // Any load failure (offline, empty URL, 404) falls back to the
            // bundled document so the page is always available.
            _loadFallback();
          },
        ),
      );

    if (_url.trim().isEmpty) {
      _loadFallback();
    } else {
      _controller.loadRequest(Uri.parse(_url));
    }
  }

  void _loadFallback() {
    _controller.loadHtmlString(
      widget.page == LegalPage.privacy ? _privacyHtml : _supportHtml,
    );
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.sunYellow,
        foregroundColor: Colors.white,
        title: Text(_title, style: AppText.title(20)),
        elevation: 2,
      ),
      body: Stack(
        children: [
          // WebView always renders on a white background with black text.
          Container(
            color: Colors.white,
            child: WebViewWidget(controller: _controller),
          ),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.sunYellow),
            ),
        ],
      ),
    );
  }

  // ---- Bundled offline documents (black text, white background) ----------
  static const String _style = '''
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      body { background:#FFFFFF; color:#000000; font-family:-apple-system,Roboto,Arial,sans-serif;
             margin:0; padding:20px; line-height:1.55; font-size:16px; }
      h1 { color:#000000; font-size:24px; margin-bottom:4px; }
      h2 { color:#000000; font-size:19px; margin-top:22px; }
      p, li { color:#000000; }
      .muted { color:#000000; opacity:0.7; font-size:13px; }
      a { color:#0a58ca; }
    </style>
  ''';

  static const String _privacyHtml = '''
    <!DOCTYPE html><html><head>$_style</head><body>
    <h1>Privacy Policy</h1>
    <p class="muted">Crazy Egg Dash</p>
    <p>Your privacy matters to us. This policy explains how Crazy Egg Dash
    ("the game") handles information.</p>
    <h2>Information We Collect</h2>
    <p>Crazy Egg Dash is a single-player game. Your progress (coins, chickens,
    upgrades and settings) is stored locally on your device only and is not
    transmitted to us.</p>
    <h2>Data Storage</h2>
    <p>All game data is saved on your device. Removing the app deletes this data.</p>
    <h2>Children's Privacy</h2>
    <p>The game does not knowingly collect personal information from children.</p>
    <h2>Contact</h2>
    <p>For any questions about this policy, please use the in-game Support page.</p>
    <p class="muted">This document is provided within the app and is available
    offline.</p>
    </body></html>
  ''';

  static const String _supportHtml = '''
    <!DOCTYPE html><html><head>$_style</head><body>
    <h1>Support</h1>
    <p class="muted">Crazy Egg Dash</p>
    <p>Need help? Here are answers to common questions.</p>
    <h2>How do I grow my flock?</h2>
    <p>Run and collect eggs — each egg hatches a chicken that joins your flock.
    The bigger the flock, the more hits you can survive.</p>
    <h2>How do I jump?</h2>
    <p>Tap for a small hop, or press and hold for a longer, higher jump to clear
    bigger obstacles.</p>
    <h2>How do I unlock new chickens?</h2>
    <p>Hatch eggs in the Incubator. Duplicate chickens become shards you can use
    in Fusion to level a chicken up.</p>
    <h2>My progress</h2>
    <p>Progress is stored locally on your device.</p>
    <h2>Contact</h2>
    <p>A contact channel will be available here soon.</p>
    <p class="muted">This document is provided within the app and is available
    offline.</p>
    </body></html>
  ''';
}
