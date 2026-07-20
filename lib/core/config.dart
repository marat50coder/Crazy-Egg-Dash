/// App-wide configuration constants.
class AppConfig {
  AppConfig._();

  static const String appName = 'Crazy Egg Dash';
  static const String bundleId = 'com.crazyeggdash.crazyeggdashgame';

  /// Privacy Policy URL. Intentionally left empty for now — when a real URL is
  /// provided the WebView loads it; while empty, a bundled offline page shows.
  static const String privacyPolicyUrl = '';

  /// Support URL. Same behaviour as [privacyPolicyUrl].
  static const String supportUrl = '';
}
