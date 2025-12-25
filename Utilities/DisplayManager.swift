import Cocoa

protocol DisplayManaging: AnyObject {
  var onScreenConfigurationChanged: (() -> Void)? { get set }
  func startMonitoring()
  func stopMonitoring()
  func cleanup()
  func getCurrentDisplayID(for point: CGPoint) -> CGDirectDisplayID?
  func isDisplayAvailable(_ displayID: CGDirectDisplayID) -> Bool
  func getScreen(for displayID: CGDirectDisplayID) -> NSScreen?
  func getAvailableDisplayIDs() -> [CGDirectDisplayID]
  func getDisplayUUID(for displayID: CGDirectDisplayID) -> String?
  func getDisplayID(for uuid: String) -> CGDirectDisplayID?
  func getScreen(for uuid: String) -> NSScreen?
  func isFrameValid(_ frame: CGRect, for displayID: CGDirectDisplayID) -> Bool
}

protocol ScreenProvider {
  var screens: [NSScreen] { get }
}

class NSScreenProvider: ScreenProvider {
  var screens: [NSScreen] { NSScreen.screens }
}

@MainActor
class DisplayManager: DisplayManaging {
  static let shared = DisplayManager()

  var onScreenConfigurationChanged: (() -> Void)?

  private var isMonitoring = false
  private let notificationCenter: NotificationCenter
  private let screenProvider: ScreenProvider

  convenience init() {
    self.init(notificationCenter: .default, screenProvider: NSScreenProvider())
  }

  init(notificationCenter: NotificationCenter, screenProvider: ScreenProvider) {
    self.notificationCenter = notificationCenter
    self.screenProvider = screenProvider
  }
  
  // MARK: - Monitoring
  
  func startMonitoring() {
    guard !isMonitoring else { return }

    notificationCenter.addObserver(
      self,
      selector: #selector(screenConfigurationDidChange(_:)),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )

    isMonitoring = true
  }

  func stopMonitoring() {
    guard isMonitoring else { return }

    notificationCenter.removeObserver(
      self,
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )

    isMonitoring = false
  }
  
  /// Cleanup all resources - should be called on app termination
  func cleanup() {
    stopMonitoring()
    onScreenConfigurationChanged = nil
  }
  
  // MARK: - Display Queries
  
  func getCurrentDisplayID(for point: CGPoint) -> CGDirectDisplayID? {
    var displayID: CGDirectDisplayID = 0
    var displayCount: UInt32 = 0
    
    let result = CGGetDisplaysWithPoint(point, 1, &displayID, &displayCount)
    
    if result == .success && displayCount > 0 {
      return displayID
    }
    
    return nil
  }
  
  func isDisplayAvailable(_ displayID: CGDirectDisplayID) -> Bool {
    let maxDisplays: UInt32 = 16
    var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
    var displayCount: UInt32 = 0
    
    let result = CGGetOnlineDisplayList(maxDisplays, &onlineDisplays, &displayCount)
    
    if result == .success {
      for i in 0..<Int(displayCount) {
        if onlineDisplays[i] == displayID {
          return true
        }
      }
    }
    
    return false
  }
  
  func getScreen(for displayID: CGDirectDisplayID) -> NSScreen? {
    let screens = screenProvider.screens

    let screen = screens.first { screen in
      guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
        return false
      }
      return screenNumber == displayID
    }

    if screen == nil {
      AppLogger.shared.warning("Could not find NSScreen for display ID \(displayID)")
    }

    return screen
  }
  
  func getAvailableDisplayIDs() -> [CGDirectDisplayID] {
    let maxDisplays: UInt32 = 16
    var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
    var displayCount: UInt32 = 0
    
    let result = CGGetOnlineDisplayList(maxDisplays, &onlineDisplays, &displayCount)
    
    if result == .success {
      return Array(onlineDisplays.prefix(Int(displayCount)))
    }
    return []
  }
  
  func getDisplayUUID(for displayID: CGDirectDisplayID) -> String? {
    guard let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else {
      return nil
    }
    return CFUUIDCreateString(nil, uuid) as String
  }
  
  func getDisplayID(for uuid: String) -> CGDirectDisplayID? {
    let availableIDs = getAvailableDisplayIDs()
    for displayID in availableIDs {
      if let displayUUID = getDisplayUUID(for: displayID), displayUUID == uuid {
        return displayID
      }
    }
    return nil
  }
  
  func getScreen(for uuid: String) -> NSScreen? {
    guard let displayID = getDisplayID(for: uuid) else {
      return nil
    }
    return getScreen(for: displayID)
  }
  
  func isFrameValid(_ frame: CGRect, for displayID: CGDirectDisplayID) -> Bool {
    guard let screen = getScreen(for: displayID) else {
      AppLogger.shared.error("Frame validation failed: no screen for display \(displayID)")
      return false
    }
    
    return screen.frame.intersects(frame)
  }
  
  // MARK: - Notification Handler
  
  @objc private func screenConfigurationDidChange(_ notification: Notification) {
    onScreenConfigurationChanged?()
  }
}
