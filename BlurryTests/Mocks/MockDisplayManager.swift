import Foundation
import Cocoa
@testable import Blurry

@MainActor
final class MockDisplayManager: DisplayManaging {
  var onScreenConfigurationChanged: (() -> Void)?

  var stubbedIsDisplayAvailable = true
  var stubbedIsFrameValid = true
  var stubbedScreen: NSScreen?
  var stubbedDisplayIDs: [CGDirectDisplayID] = [1]
  var stubbedDisplayUUID: String? = "mock-uuid"

  var isDisplayAvailableCallCount = 0
  var isFrameValidCallCount = 0
  var getScreenCallCount = 0

  func startMonitoring() {}
  func stopMonitoring() {}
  func cleanup() {}

  func getCurrentDisplayID(for point: CGPoint) -> CGDirectDisplayID? {
    return stubbedDisplayIDs.first
  }

  func isDisplayAvailable(_ displayID: CGDirectDisplayID) -> Bool {
    isDisplayAvailableCallCount += 1
    return stubbedIsDisplayAvailable
  }

  func getScreen(for displayID: CGDirectDisplayID) -> NSScreen? {
    getScreenCallCount += 1
    return stubbedScreen ?? NSScreen.main
  }

  func getAvailableDisplayIDs() -> [CGDirectDisplayID] {
    return stubbedDisplayIDs
  }

  func getDisplayUUID(for displayID: CGDirectDisplayID) -> String? {
    return stubbedDisplayUUID
  }

  func getDisplayID(for uuid: String) -> CGDirectDisplayID? {
    return uuid == stubbedDisplayUUID ? stubbedDisplayIDs.first : nil
  }

  func getScreen(for uuid: String) -> NSScreen? {
    return stubbedScreen ?? NSScreen.main
  }

  func isFrameValid(_ frame: CGRect, for displayID: CGDirectDisplayID) -> Bool {
    isFrameValidCallCount += 1
    return stubbedIsFrameValid
  }

  func reset() {
    stubbedIsDisplayAvailable = true
    stubbedIsFrameValid = true
    stubbedScreen = nil
    stubbedDisplayIDs = [1]
    stubbedDisplayUUID = "mock-uuid"
    isDisplayAvailableCallCount = 0
    isFrameValidCallCount = 0
    getScreenCallCount = 0
  }
}
