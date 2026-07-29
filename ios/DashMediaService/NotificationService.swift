import UserNotifications

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

final class NotificationService: UNNotificationServiceExtension {
  private var deliver: ((UNNotificationContent) -> Void)?
  private var draft: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    deliver = contentHandler
    draft = request.content.mutableCopy() as? UNMutableNotificationContent

    guard let draft else {
      contentHandler(request.content)
      return
    }

    #if canImport(FirebaseMessaging)
    Messaging.serviceExtension().populateNotificationContent(
      draft,
      withContentHandler: contentHandler
    )
    #else
    contentHandler(draft)
    #endif
  }

  override func serviceExtensionTimeWillExpire() {
    guard let deliver, let draft else { return }
    deliver(draft)
  }
}
