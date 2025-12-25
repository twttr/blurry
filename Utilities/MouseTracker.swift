import Cocoa

protocol MouseTracking: AnyObject {
  var onMouseEnter: ((UUID) -> Void)? { get set }
  var onMouseExit: ((UUID) -> Void)? { get set }
  func startTracking(area: BlurArea)
  func stopTracking(areaID: UUID)
  func stopAllTracking()
  func cleanup()
  func updateFrame(for areaID: UUID, frame: CGRect)
  func isTracking(areaID: UUID) -> Bool
}

protocol MouseEventMonitorProvider {
  func addGlobalMonitor(for mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) -> Any?
  func removeMonitor(_ monitor: Any)
  var mouseLocation: NSPoint { get }
}

class DefaultMouseEventMonitorProvider: MouseEventMonitorProvider {
  func addGlobalMonitor(for mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) -> Any? {
    NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
  }

  func removeMonitor(_ monitor: Any) {
    NSEvent.removeMonitor(monitor)
  }

  var mouseLocation: NSPoint { NSEvent.mouseLocation }
}

@MainActor
class MouseTracker: MouseTracking {
  static let shared = MouseTracker()

  private var eventMonitor: Any?
  private var activeAreas: [UUID: CGRect] = [:]
  private var currentlyHoveredAreas: Set<UUID> = []
  private let eventMonitorProvider: MouseEventMonitorProvider

  var onMouseEnter: ((UUID) -> Void)?
  var onMouseExit: ((UUID) -> Void)?

  convenience init() {
    self.init(eventMonitorProvider: DefaultMouseEventMonitorProvider())
  }

  init(eventMonitorProvider: MouseEventMonitorProvider) {
    self.eventMonitorProvider = eventMonitorProvider
  }
  
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

    eventMonitor = eventMonitorProvider.addGlobalMonitor(for: .mouseMoved) { [weak self] _ in
      guard let self else { return }
      Task { @MainActor in
        self.handleMouseMoved(to: self.eventMonitorProvider.mouseLocation)
      }
    }
  }

  private func stopMonitoring() {
    if let monitor = eventMonitor {
      eventMonitorProvider.removeMonitor(monitor)
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
