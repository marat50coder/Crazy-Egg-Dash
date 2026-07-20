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
    <p class="muted">Effective Date: June 2026 &nbsp;|&nbsp; Crazy Egg Dash</p>
    <p>Developer ("we", "us", or "our") operates the <strong>Crazy Egg Dash</strong>
    mobile application ("Service"). This Privacy Policy explains how information is
    collected, used, and protected when you use the Service.</p>
    <h2>Information We Collect</h2>
    <p>The Service may collect limited technical information necessary for operation
    and improvement of the application, including: device type and model, operating
    system version, anonymous usage statistics, diagnostic and crash information, and
    IP address (when required for security and analytics purposes).</p>
    <p>We do not intentionally collect sensitive personal information such as
    financial account details, government-issued identification numbers, or biometric
    data.</p>
    <h2>How We Use Information</h2>
    <p>To provide and maintain the Service, improve app functionality, monitor
    performance, detect and resolve technical issues, and comply with legal
    obligations.</p>
    <h2>Data Storage and Security</h2>
    <p>We take reasonable measures to protect information from unauthorized access.
    No method of electronic transmission or storage is completely secure.</p>
    <h2>Third-Party Services</h2>
    <p>The Service may use third-party providers for analytics, crash reporting, or
    hosting. These providers process information solely to provide services on our
    behalf.</p>
    <h2>Data Deletion</h2>
    <p>Users have the right to request deletion of their personal data. Contact us
    at <a href="mailto:support@crazyeggdash.com">support@crazyeggdash.com</a>.
    Verified requests will be processed within a reasonable timeframe. You may also
    permanently delete all locally stored data by uninstalling the application.</p>
    <h2>Children's Privacy</h2>
    <p>The Service is not intended for children under the age of 18, and we do not
    knowingly collect personal information from children under that age.</p>
    <h2>Contact Us</h2>
    <p><strong>Email:</strong> <a href="mailto:support@crazyeggdash.com">support@crazyeggdash.com</a></p>
    <p class="muted">Full policy: https://crazyeggdash.com/privacy-policy.html<br>
    This offline copy is shown when the network is unavailable.</p>
    </body></html>
  ''';

  static const String _supportHtml = '''
    <!DOCTYPE html><html><head>$_style</head><body>
    <h1>Support</h1>
    <p class="muted">Crazy Egg Dash</p>
    <p>Need help? Here are answers to common questions. For anything else, email
    us at <a href="mailto:support@crazyeggdash.com">support@crazyeggdash.com</a>.</p>
    <h2>How do I grow my flock?</h2>
    <p>Run and collect eggs — each egg hatches a chicken that joins your flock.
    The bigger the flock, the more hits you can survive.</p>
    <h2>How do I jump?</h2>
    <p>Tap for a small hop, or press and hold for a longer, higher jump to clear
    bigger obstacles and pits.</p>
    <h2>How do I unlock new chickens?</h2>
    <p>Hatch eggs in the Incubator. Duplicate chickens become shards you can use
    in Fusion to level a chicken up.</p>
    <h2>Power-ups</h2>
    <p>Grab glowing magic boxes during a run to activate a temporary super-ability:
    Fly (glide over everything), Shield (smash obstacles), or Magnet (attract coins
    and eggs from afar).</p>
    <h2>My progress was lost</h2>
    <p>Progress is stored locally on your device. Reinstalling the app will reset it.
    Contact us if you believe this happened unexpectedly.</p>
    <h2>Contact</h2>
    <p><a href="mailto:support@crazyeggdash.com">support@crazyeggdash.com</a></p>
    <p class="muted">Full support page: https://crazyeggdash.com/support.html<br>
    This offline copy is shown when the network is unavailable.</p>
    </body></html>
  ''';
}
