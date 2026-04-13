import Cocoa
import UserNotifications
import os.log

actor NotificationManager {
  static let shared = NotificationManager()

  private var lastNotificationTimes: [String: Date] = [:]
  private let debounceInterval: TimeInterval = 2.0
  private let logger = Logger(subsystem: "io.twttr.Blurry", category: "notifications")

  func requestPermissions() async {
    do {
      let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
      if !granted {
        logger.warning("User denied notification permissions")
      }
    } catch {
      logger.error("Failed to request notification permissions: \(error.localizedDescription)")
    }
  }

  func send(
    title: String,
    body: String,
    identifier: String = UUID().uuidString,
    debounce: Bool = false
  ) async {
    if debounce && !shouldSend(identifier: identifier) {
      return
    }

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body

    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
    do {
      try await UNUserNotificationCenter.current().add(request)
    } catch {
      logger.error("Failed to send notification: \(error.localizedDescription)")
    }
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
