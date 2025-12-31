import Cocoa
import Sentry

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusBarController: StatusBarController!
  private let areaManager = AreaManager.shared
  private var restorationRetryCount = 0
  private let maxRetryAttempts = 2
  
  func applicationDidFinishLaunching(_ notification: Notification) {
    if let dsn = Bundle.main.infoDictionary?["SentryDSN"] as? String,
       !dsn.isEmpty,
       !dsn.hasPrefix("$(") {
      SentrySDK.start { options in
        options.dsn = dsn
        #if DEBUG
        options.enabled = false
        #endif
      }
    }

    NSApplication.shared.setActivationPolicy(.accessory)
    
    Task { @MainActor in
      await NotificationManager.shared.requestPermissions()
      
      try? await Task.sleep(nanoseconds: 100_000_000)
      
      await restoreBlurAreas()
      
      if shouldRetryRestoration() && restorationRetryCount < maxRetryAttempts {
        restorationRetryCount += 1
        AppLogger.shared.info("Retrying restoration (attempt \(restorationRetryCount))")
        try? await Task.sleep(nanoseconds: 500_000_000)
        await restoreBlurAreas()
      }
      
      statusBarController = StatusBarController(areaManager: areaManager)
      HotkeyManager.shared.registerHotkey()
      setupDisplayMonitoring()
    }
  }
  
  func applicationWillTerminate(_ notification: Notification) {
    HotkeyManager.shared.cleanup()
    DisplayManager.shared.cleanup()
    MouseTracker.shared.cleanup()
#if DIRECT
    ScreenCaptureMonitor.shared.cleanup()
#endif
  }
  
  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  private func setupDisplayMonitoring() {
    DisplayManager.shared.onScreenConfigurationChanged = { [weak self] in
      Task { await self?.handleScreenConfigurationChange() }
    }
    DisplayManager.shared.startMonitoring()
  }
  
  private func handleScreenConfigurationChange() async {
    let availableDisplayIDs = Set(DisplayManager.shared.getAvailableDisplayIDs())
    var disabledCount = 0
    var enabledCount = 0
    var areasToEnable: [BlurArea] = []
    
    areaManager.beginBatchUpdate()
    
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
        if let screen = DisplayManager.shared.getScreen(for: displayID),
           let restoredFrame = calculateRestoredFrame(for: area, screen: screen) {
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
    
    areaManager.endBatchUpdate()
    
    if disabledCount > 0 {
      await NotificationManager.shared.send(
        title: String(localized: "Display Disconnected"),
        body: disabledCount == 1
        ? String(localized: "1 area has been disabled.")
        : String(localized: "\(disabledCount) areas have been disabled."),
        identifier: "display-disconnected",
        debounce: true
      )
    }
    
    if enabledCount > 0 {
      await NotificationManager.shared.send(
        title: String(localized: "Display Reconnected"),
        body: enabledCount == 1
        ? String(localized: "1 area has been automatically re-enabled.")
        : String(localized: "\(enabledCount) areas have been automatically re-enabled."),
        identifier: "display-reconnected",
        debounce: true
      )
    }
  }
  
  private func restoreBlurAreas() async {
    let logger = AppLogger.shared
    let areasToRestore = areaManager.areas.filter { $0.isEnabled }
    
    logger.logRestorationStart(areaCount: areasToRestore.count)
    logger.info("Available displays: \(DisplayManager.shared.getAvailableDisplayIDs())")
    logger.info("NSScreen count: \(NSScreen.screens.count)")
    
    var unavailableDisplayAreas: [String] = []
    var successCount = 0
    
    areaManager.beginBatchUpdate()
    
    for area in areasToRestore {
      var screen: NSScreen? = nil
      var displayID: CGDirectDisplayID? = area.displayID
      var displayUUID: String? = area.displayUUID
      
      if let uuid = displayUUID, let foundScreen = DisplayManager.shared.getScreen(for: uuid) {
        screen = foundScreen
        if let foundID = DisplayManager.shared.getDisplayID(for: uuid) {
          displayID = foundID
          logger.info("Matched area '\(area.name)' by UUID, updated displayID: \(foundID)")
        }
      } else if let id = displayID, DisplayManager.shared.isDisplayAvailable(id),
                let foundScreen = DisplayManager.shared.getScreen(for: id) {
        screen = foundScreen
        displayUUID = DisplayManager.shared.getDisplayUUID(for: id)
        logger.info("Matched area '\(area.name)' by displayID, captured UUID: \(displayUUID ?? "none")")
      }
      
      guard let screen = screen, let displayID = displayID else {
        logger.logRestorationFailure(
          areaID: area.id,
          areaName: area.name,
          reason: "Display not found (UUID: \(area.displayUUID ?? "none"), ID: \(area.displayID.map(String.init) ?? "none"))"
        )
        unavailableDisplayAreas.append(area.name)
        var updatedArea = area
        updatedArea.isEnabled = false
        areaManager.update(updatedArea)
        continue
      }
      
      var updatedArea = area
      updatedArea.displayID = displayID
      updatedArea.displayUUID = displayUUID
      
      if updatedArea.displayRelativeFrame.width == 0 || updatedArea.displayRelativeFrame.height == 0 {
        updatedArea.displayRelativeFrame = updatedArea.makeDisplayRelative(screen: screen)
      }
      
      guard let restoredFrame = calculateRestoredFrame(for: updatedArea, screen: screen) else {
        logger.logRestorationFailure(
          areaID: area.id,
          areaName: area.name,
          reason: "Frame validation failed - frame outside display bounds"
        )
        unavailableDisplayAreas.append("\(updatedArea.name) (invalid position)")
        updatedArea.isEnabled = false
        areaManager.update(updatedArea)
        continue
      }
      
      updatedArea.frame = restoredFrame
      areaManager.update(updatedArea)
      
      let windowCreated = createWindowForArea(updatedArea)
      if windowCreated {
        logger.logRestorationSuccess(areaID: area.id, areaName: area.name)
        successCount += 1
      } else {
        logger.logWindowCreationFailure(
          areaID: area.id,
          areaName: area.name,
          reason: "Window or effect view creation returned nil"
        )
      }
    }
    
    areaManager.endBatchUpdate()
    
    logger.info("Restoration complete: \(successCount)/\(areasToRestore.count) successful")
    
    if !unavailableDisplayAreas.isEmpty {
      await NotificationManager.shared.send(
        title: String(localized: "Some Areas Could Not Be Restored"),
        body: unavailableDisplayAreas.count == 1
        ? String(localized: "1 area was disabled because its display is not available.")
        : String(localized: "\(unavailableDisplayAreas.count) areas were disabled because their displays are not available."),
        identifier: "areas-unavailable"
      )
    }
  }
  
  private func calculateRestoredFrame(for area: BlurArea, screen: NSScreen) -> CGRect? {
    let globalFrame = BlurArea.makeGlobal(relativeFrame: area.displayRelativeFrame, screen: screen)
    
    if screen.frame.contains(globalFrame) {
      return globalFrame
    }
    
    return globalFrame.intersection(screen.frame)
  }
  
  @discardableResult
  private func createWindowForArea(_ area: BlurArea) -> Bool {
    let logger = AppLogger.shared
    
    guard let window = OverlayWindowManager.shared.createWindow(for: area) else {
      logger.error("OverlayWindowManager.createWindow returned nil for area: \(area.name)")
      return false
    }
    
    let localBounds = CGRect(origin: .zero, size: area.frame.size)
    guard let effectView = EffectViewFactory.createView(for: area, in: localBounds) else {
      logger.error("EffectViewFactory.createView returned nil for area: \(area.name)")
      OverlayWindowManager.shared.removeWindow(for: area.id)
      return false
    }
    
    window.contentView?.addSubview(effectView)
    window.orderFront(nil)
    
    logger.info("Successfully created window and effect view for area: \(area.name)")
    return true
  }
  
  private func shouldRetryRestoration() -> Bool {
    let enabledAreas = areaManager.areas.filter { $0.isEnabled }
    for area in enabledAreas {
      if OverlayWindowManager.shared.getWindow(for: area.id) == nil {
        return true
      }
    }
    return false
  }
}
