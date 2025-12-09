import Cocoa

@MainActor
class OverlayWindowManager {
  static let shared = OverlayWindowManager()
  
  private var windows: [UUID: OverlayWindow] = [:]
  private let defaultCornerRadius: Double = 20.0
  private var areasInResizeMode: Set<UUID> = []
  
  private init() {}
  
  func createWindow(for area: BlurArea) -> OverlayWindow? {
    guard area.frame.width > 0 && area.frame.height > 0 else {
      return nil
    }
    
    if let displayID = area.displayID {
      guard DisplayManager.shared.isFrameValid(area.frame, for: displayID) else {
        return nil
      }
    }
    
    let window = OverlayWindow(frame: area.frame, cornerRadius: defaultCornerRadius)
    
    windows[area.id] = window
    window.orderFront(nil)
    
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
