import Flutter
import UIKit
import UserNotifications

/// Captures the deep-link URL from a cold-start notification tap and hands
/// it to the Dart side over the shared_preferences NSUserDefaults surface.
/// The Dart-visible key drops the "flutter." prefix.
class SceneDelegate: FlutterSceneDelegate {
  static let handoffKey = "flutter.dash_push_dest"

  private static let candidateKeys = [
    "deep_link", "target", "url", "deeplink", "link",
  ]
  private static let nestedContainers = ["payload", "data"]

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard let response = connectionOptions.notificationResponse else {
      return
    }
    let payload = response.notification.request.content.userInfo
    guard let destination = Self.resolveDestination(from: payload) else {
      return
    }

    let defaults = UserDefaults.standard
    defaults.set(destination, forKey: Self.handoffKey)
    defaults.synchronize()

    #if DEBUG
    NSLog("[DASH.ROUTE] captured notification destination")
    #endif
  }

  private static func resolveDestination(
    from payload: [AnyHashable: Any]
  ) -> String? {
    if let hit = pickString(from: payload) { return hit }
    for container in nestedContainers {
      if let nested = payload[container] as? [AnyHashable: Any],
         let hit = pickString(from: nested) {
        return hit
      }
    }
    return nil
  }

  private static func pickString(
    from dictionary: [AnyHashable: Any]
  ) -> String? {
    for key in candidateKeys {
      guard let raw = dictionary[key] as? String else { continue }
      let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty { return trimmed }
    }
    return nil
  }
}
