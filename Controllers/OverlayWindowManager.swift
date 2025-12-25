import Cocoa

protocol OverlayWindowManaging: AnyObject {
  func createWindow(for area: BlurArea) -> OverlayWindow?
  func updateWindow(for area: BlurArea)
  func removeWindow(for areaID: UUID)
  func removeAllWindows()
  func getWindow(for areaID: UUID) -> OverlayWindow?
  func enableResizeMode(for areaID: UUID, delegate: any ResizeHandleDelegate)
  func disableResizeMode(for areaID: UUID)
  func isInResizeMode(areaID: UUID) -> Bool
  func disableAllResizeModes()
}

@MainActor
class OverlayWindowManager: OverlayWindowManaging {
  static let shared = OverlayWindowManager()

  private var windows: [UUID: OverlayWindow] = [:]
  private let defaultCornerRadius: Double = 20.0
  private var areasInResizeMode: Set<UUID> = []
  private let displayManager: DisplayManaging

  convenience init() {
    self.init(displayManager: DisplayManager.shared)
  }

  init(displayManager: DisplayManaging) {
    self.displayManager = displayManager
  }
  
  func createWindow(for area: BlurArea) -> OverlayWindow? {
    let logger = AppLogger.shared

    guard area.frame.width > 0 && area.frame.height > 0 else {
      logger.error("Cannot create window: invalid frame size (width: \(area.frame.width), height: \(area.frame.height)) for area: \(area.name)")
      return nil
    }

    if let displayID = area.displayID {
      guard displayManager.isFrameValid(area.frame, for: displayID) else {
        logger.error("Cannot create window: frame validation failed for display \(displayID), area: \(area.name)")
        logger.debug("Frame: \(area.frame), Display: \(displayID)")
        return nil
      }
    } else {
      logger.warning("Creating window without display ID for area: \(area.name)")
    }
    
    let window = OverlayWindow(frame: area.frame, cornerRadius: defaultCornerRadius)
    
    windows[area.id] = window
    
    logger.info("Created overlay window for area: \(area.name)")
    return window
  }
  
  func updateWindow(for area: BlurArea) {
    guard let window = windows[area.id] else { return }
    window.setFrame(area.frame, display: true)
    if area.isEnabled {
      window.orderFront(nil)
    } else {
      window.orderOut(nil)
    }
  }
  
  func removeWindow(for areaID: UUID) {
    guard let window = windows[areaID] else {
      return
    }
    
    windows.removeValue(forKey: areaID)
    
    window.orderOut(nil)
  }
  
  func removeAllWindows() {
    for (_, window) in windows {
      window.orderOut(nil)
    }
    windows.removeAll()
  }
  
  func getWindow(for areaID: UUID) -> OverlayWindow? {
    return windows[areaID]
  }
  
  func enableResizeMode(for areaID: UUID, delegate: any ResizeHandleDelegate) {
    guard let window = windows[areaID] else { return }
    window.setResizeMode(true, areaID: areaID, delegate: delegate)
    areasInResizeMode.insert(areaID)
  }
  
  func disableResizeMode(for areaID: UUID) {
    guard let window = windows[areaID] else { return }
    window.setResizeMode(false, areaID: areaID, delegate: nil)
    areasInResizeMode.remove(areaID)
  }
  
  func isInResizeMode(areaID: UUID) -> Bool {
    return areasInResizeMode.contains(areaID)
  }
  
  func disableAllResizeModes() {
    for areaID in areasInResizeMode {
      disableResizeMode(for: areaID)
    }
  }
}
