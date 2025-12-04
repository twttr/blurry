import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusBarController: StatusBarController!
  private let areaManager = AreaManager.shared
  
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.accessory)
    
    restoreBlurAreas()
    statusBarController = StatusBarController(areaManager: areaManager)
    
    HotkeyManager.shared.registerHotkey()
    
    setupDisplayMonitoring()
  }
  
  func applicationWillTerminate(_ notification: Notification) {
    HotkeyManager.shared.cleanup()
    DisplayManager.shared.cleanup()
    MouseTracker.shared.cleanup()
  }
  
  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  private func setupDisplayMonitoring() {
    DisplayManager.shared.onScreenConfigurationChanged = { [weak self] in
      self?.handleScreenConfigurationChange()
    }
    DisplayManager.shared.startMonitoring()
  }
  
  private func handleScreenConfigurationChange() {
    let availableDisplayIDs = Set(DisplayManager.shared.getAvailableDisplayIDs())
    var disabledCount = 0
    var enabledCount = 0
    var areasToEnable: [BlurArea] = []

    for area in areaManager.areas {
      guard let displayID = area.displayID else { continue }

      let isDisplayAvailable = availableDisplayIDs.contains(displayID)

      if !isDisplayAvailable && area.isEnabled {
        areaManager.toggleEnabled(for: area.id)
        OverlayWindowManager.shared.removeWindow(for: area.id)

        if area.disableOnHover {
          MouseTracker.shared.stopTracking(areaID: area.id)
        }
        disabledCount += 1

      } else if isDisplayAvailable && !area.isEnabled {
        if let restoredFrame = calculateRestoredFrame(for: area, displayID: displayID) {
          var updatedArea = area
          updatedArea.frame = restoredFrame
          updatedArea.isEnabled = true
          areasToEnable.append(updatedArea)
          enabledCount += 1
        }
      }
    }

    for area in areasToEnable {
      areaManager.update(area)
      createWindowForArea(area)

      if area.disableOnHover {
        MouseTracker.shared.startTracking(area: area)
      }
    }

    if disabledCount > 0 {
      showDisplayDisconnectedNotification(count: disabledCount)
    }

    if enabledCount > 0 {
      showDisplayReconnectedNotification(count: enabledCount)
    }
  }

  private func showDisplayReconnectedNotification(count: Int) {
    let alert = NSAlert()
    alert.messageText = String(localized: "Display Reconnected")
    alert.informativeText = count == 1
      ? String(localized: "1 area has been automatically re-enabled.")
      : String(localized: "\(count) areas have been automatically re-enabled.")
    alert.alertStyle = .informational
    alert.addButton(withTitle: String(localized: "OK"))
    alert.runModal()
  }
  
  private func showDisplayDisconnectedNotification(count: Int) {
    let alert = NSAlert()
    alert.messageText = String(localized: "Display Disconnected")
    if count == 1 {
      alert.informativeText = String(localized: "Display disconnected. Some areas have been disabled.")
    } else {
      alert.informativeText = String(localized: "Display disconnected. \(count) areas have been disabled.")
    }
    alert.alertStyle = .informational
    alert.addButton(withTitle: String(localized: "OK"))
    alert.runModal()
  }
  
  private func restoreBlurAreas() {
    var unavailableDisplayAreas: [String] = []

    for area in areaManager.areas where area.isEnabled {
      guard let displayID = area.displayID,
            DisplayManager.shared.isDisplayAvailable(displayID) else {
        unavailableDisplayAreas.append(area.name)
        var updatedArea = area
        updatedArea.isEnabled = false
        areaManager.update(updatedArea)
        continue
      }

      guard let screen = DisplayManager.shared.getScreen(for: displayID) else {
        unavailableDisplayAreas.append(area.name)
        var updatedArea = area
        updatedArea.isEnabled = false
        areaManager.update(updatedArea)
        continue
      }

      var updatedArea = area

      if updatedArea.displayRelativeFrame.width == 0 || updatedArea.displayRelativeFrame.height == 0 {
        updatedArea.displayRelativeFrame = updatedArea.makeDisplayRelative(screen: screen)
      }

      if let restoredFrame = calculateRestoredFrame(for: updatedArea, displayID: displayID) {
        updatedArea.frame = restoredFrame
        areaManager.update(updatedArea)
        createWindowForArea(updatedArea)
      } else {
        unavailableDisplayAreas.append("\(updatedArea.name) (invalid position)")
        updatedArea.isEnabled = false
        areaManager.update(updatedArea)
      }
    }

    if !unavailableDisplayAreas.isEmpty {
      showUnavailableDisplaysNotification(areas: unavailableDisplayAreas)
    }
  }

  private func calculateRestoredFrame(for area: BlurArea, displayID: CGDirectDisplayID) -> CGRect? {
    guard let screen = DisplayManager.shared.getScreen(for: displayID) else {
      return nil
    }

    let globalFrame = BlurArea.makeGlobal(relativeFrame: area.displayRelativeFrame, screen: screen)

    if screen.frame.contains(globalFrame) {
      return globalFrame
    }

    return globalFrame.intersection(screen.frame)
  }

  private func createWindowForArea(_ area: BlurArea) {
    guard let window = OverlayWindowManager.shared.createWindow(for: area) else { return }
    let localBounds = CGRect(origin: .zero, size: area.frame.size)
    if let effectView = EffectViewFactory.createView(for: area, in: localBounds) {
      window.contentView?.addSubview(effectView)
    }
  }

  private func showUnavailableDisplaysNotification(areas: [String]) {
    let alert = NSAlert()
    alert.messageText = String(localized: "Some Areas Could Not Be Restored")

    let areaList = areas.prefix(5).joined(separator: "\n• ")
    let remainingCount = areas.count - 5
    let suffix = areas.count > 5 ? String(localized: "\n• ... and \(remainingCount) more") : ""

    alert.informativeText = String(localized: """
      The following areas were disabled because their displays are not available:

      • \(areaList)\(suffix)

      These areas will automatically re-enable when their displays reconnect.
      """)

    alert.alertStyle = .informational
    alert.addButton(withTitle: String(localized: "OK"))
    alert.runModal()
  }
}
