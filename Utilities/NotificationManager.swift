import Cocoa
import UserNotifications

actor NotificationManager {
  static let shared = NotificationManager()

  private var lastNotificationTimes: [String: Date] = [:]
  private let debounceInterval: TimeInterval = 2.0

  func requestPermissions() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
  }

  func send(
    title: String,
    body: String,
    identifier: String = UUID().uuidString,
    debounce: Bool = false
  ) {
    if debounce && !shouldSend(identifier: identifier) {
      return
    }

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body

    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request)
  }

  private func shouldSend(identifier: String) -> Bool {
    let now = Date()
    if let lastTime = lastNotificationTimes[identifier],
       now.timeIntervalSince(lastTime) < debounceInterval {
      return false
    }
    lastNotificationTimes[identifier] = now
    return true
  }
}
