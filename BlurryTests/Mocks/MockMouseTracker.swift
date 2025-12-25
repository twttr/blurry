import Foundation
import Cocoa
@testable import Blurry

final class MockMouseEventMonitorProvider: MouseEventMonitorProvider {
  var addGlobalMonitorCallCount = 0
  var removeMonitorCallCount = 0
  var stubbedMouseLocation: NSPoint = .zero
  var capturedHandler: ((NSEvent) -> Void)?

  func addGlobalMonitor(for mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) -> Any? {
    addGlobalMonitorCallCount += 1
    capturedHandler = handler
    return "mock-monitor"
  }

  func removeMonitor(_ monitor: Any) {
    removeMonitorCallCount += 1
    capturedHandler = nil
  }

  var mouseLocation: NSPoint {
    stubbedMouseLocation
  }

  func reset() {
    addGlobalMonitorCallCount = 0
    removeMonitorCallCount = 0
    stubbedMouseLocation = .zero
    capturedHandler = nil
  }
}

@MainActor
final class MockMouseTracker: MouseTracking {
  var onMouseEnter: ((UUID) -> Void)?
  var onMouseExit: ((UUID) -> Void)?

  var trackedAreas: [UUID: CGRect] = [:]
  var startTrackingCallCount = 0
  var stopTrackingCallCount = 0
  var stopAllTrackingCallCount = 0

  func startTracking(area: BlurArea) {
    startTrackingCallCount += 1
    if area.disableOnHover {
      trackedAreas[area.id] = area.frame
    }
  }

  func stopTracking(areaID: UUID) {
    stopTrackingCallCount += 1
    trackedAreas.removeValue(forKey: areaID)
  }

  func stopAllTracking() {
    stopAllTrackingCallCount += 1
    trackedAreas.removeAll()
  }

  func cleanup() {
    stopAllTracking()
    onMouseEnter = nil
    onMouseExit = nil
  }

  func updateFrame(for areaID: UUID, frame: CGRect) {
    if trackedAreas[areaID] != nil {
      trackedAreas[areaID] = frame
    }
  }

  func isTracking(areaID: UUID) -> Bool {
    return trackedAreas[areaID] != nil
  }

  func reset() {
    trackedAreas.removeAll()
    startTrackingCallCount = 0
    stopTrackingCallCount = 0
    stopAllTrackingCallCount = 0
    onMouseEnter = nil
    onMouseExit = nil
  }
}
