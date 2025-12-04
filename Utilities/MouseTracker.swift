import Cocoa

/// Singleton class that tracks mouse movement and triggers callbacks when
/// the mouse enters or exits registered disable areas.
/// Only monitors mouse events when at least one disable area is being tracked.
class MouseTracker {
  static let shared = MouseTracker()
  
  private var eventMonitor: Any?
  private var activeAreas: [UUID: CGRect] = [:]
  private var currentlyHoveredAreas: Set<UUID> = []
  
  /// Called when the mouse enters a tracked area
  var onMouseEnter: ((UUID) -> Void)?
  
  /// Called when the mouse exits a tracked area
  var onMouseExit: ((UUID) -> Void)?
  
  private init() {}
  
  /// Starts tracking mouse movement for a disable area.
  /// Only adds the area if disableOnHover is enabled.
  /// Automatically starts the global event monitor when the first area is added.
  func startTracking(area: BlurArea) {
    guard area.disableOnHover else { return }
    
    activeAreas[area.id] = area.frame
    
    if activeAreas.count == 1 {
      startMonitoring()
    }
  }
  
  /// Stops tracking mouse movement for a specific area.
  /// Automatically stops the global event monitor when the last area is removed.
  func stopTracking(areaID: UUID) {
    if currentlyHoveredAreas.contains(areaID) {
      currentlyHoveredAreas.remove(areaID)
      onMouseExit?(areaID)
    }
    
    activeAreas.removeValue(forKey: areaID)
    
    if activeAreas.isEmpty {
      stopMonitoring()
    }
  }
  
  /// Stops tracking all areas and removes the event monitor.
  func stopAllTracking() {
    for areaID in currentlyHoveredAreas {
      onMouseExit?(areaID)
    }
    currentlyHoveredAreas.removeAll()
    activeAreas.removeAll()
    stopMonitoring()
  }
  
  /// Cleanup all resources - should be called on app termination
  func cleanup() {
    stopAllTracking()
    onMouseEnter = nil
    onMouseExit = nil
  }
  
  /// Updates the frame for a tracked area (e.g., if the area is moved or resized).
  func updateFrame(for areaID: UUID, frame: CGRect) {
    if activeAreas[areaID] != nil {
      activeAreas[areaID] = frame
    }
  }
  
  /// Checks if an area is currently being tracked.
  func isTracking(areaID: UUID) -> Bool {
    return activeAreas[areaID] != nil
  }
  
  // MARK: - Private Methods
  
  private func startMonitoring() {
    guard eventMonitor == nil else { return }
    
    eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
      self?.handleMouseMoved(to: NSEvent.mouseLocation)
    }
  }
  
  private func stopMonitoring() {
    if let monitor = eventMonitor {
      NSEvent.removeMonitor(monitor)
      eventMonitor = nil
    }
  }
  
  private func handleMouseMoved(to location: NSPoint) {
    for (areaID, frame) in activeAreas {
      let isInside = frame.contains(location)
      let wasInside = currentlyHoveredAreas.contains(areaID)
      
      if isInside && !wasInside {
        currentlyHoveredAreas.insert(areaID)
        onMouseEnter?(areaID)
      } else if !isInside && wasInside {
        currentlyHoveredAreas.remove(areaID)
        onMouseExit?(areaID)
      }
    }
  }
}
