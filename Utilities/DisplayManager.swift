import Cocoa

class DisplayManager {
  static let shared = DisplayManager()
  
  var onScreenConfigurationChanged: (() -> Void)?
  
  private var isMonitoring = false
  
  private init() {}
  
  // MARK: - Monitoring
  
  func startMonitoring() {
    guard !isMonitoring else { return }
    
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenConfigurationDidChange(_:)),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )
    
    isMonitoring = true
  }
  
  func stopMonitoring() {
    guard isMonitoring else { return }
    
    NotificationCenter.default.removeObserver(
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
    return NSScreen.screens.first { screen in
      guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
        return false
      }
      return screenNumber == displayID
    }
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

  func isFrameValid(_ frame: CGRect, for displayID: CGDirectDisplayID) -> Bool {
    guard let screen = getScreen(for: displayID) else { return false }
    return screen.frame.intersects(frame)
  }

  // MARK: - Notification Handler
  
  @objc private func screenConfigurationDidChange(_ notification: Notification) {
    onScreenConfigurationChanged?()
  }
  
  deinit {
    stopMonitoring()
  }
}
