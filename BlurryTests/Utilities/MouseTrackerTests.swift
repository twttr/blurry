import XCTest
@testable import Blurry

@MainActor
final class MouseTrackerTests: XCTestCase {
  var mockProvider: MockMouseEventMonitorProvider!
  var sut: MouseTracker!

  override func setUp() async throws {
    try await super.setUp()
    mockProvider = MockMouseEventMonitorProvider()
    sut = MouseTracker(eventMonitorProvider: mockProvider)
  }

  override func tearDown() async throws {
    sut.cleanup()
    sut = nil
    mockProvider = nil
    try await super.tearDown()
  }

  func testStartTrackingWithDisableOnHover() {
    let area = TestHelpers.makeBlurArea(disableOnHover: true)

    sut.startTracking(area: area)

    XCTAssertTrue(sut.isTracking(areaID: area.id))
    XCTAssertEqual(mockProvider.addGlobalMonitorCallCount, 1)
  }

  func testStartTrackingWithoutDisableOnHover() {
    let area = TestHelpers.makeBlurArea(disableOnHover: false)

    sut.startTracking(area: area)

    XCTAssertFalse(sut.isTracking(areaID: area.id))
    XCTAssertEqual(mockProvider.addGlobalMonitorCallCount, 0)
  }

  func testFirstAreaStartsMonitoring() {
    let area = TestHelpers.makeBlurArea(disableOnHover: true)

    sut.startTracking(area: area)

    XCTAssertEqual(mockProvider.addGlobalMonitorCallCount, 1)
  }

  func testSecondAreaDoesNotStartNewMonitor() {
    let area1 = TestHelpers.makeBlurArea(disableOnHover: true)
    let area2 = TestHelpers.makeBlurArea(disableOnHover: true)

    sut.startTracking(area: area1)
    sut.startTracking(area: area2)

    XCTAssertEqual(mockProvider.addGlobalMonitorCallCount, 1)
  }

  func testStopTrackingRemovesArea() {
    let area = TestHelpers.makeBlurArea(disableOnHover: true)
    sut.startTracking(area: area)

    sut.stopTracking(areaID: area.id)

    XCTAssertFalse(sut.isTracking(areaID: area.id))
  }

  func testLastAreaStopsMonitoring() {
    let area = TestHelpers.makeBlurArea(disableOnHover: true)
    sut.startTracking(area: area)

    sut.stopTracking(areaID: area.id)

    XCTAssertEqual(mockProvider.removeMonitorCallCount, 1)
  }

  func testStopAllTracking() {
    let area1 = TestHelpers.makeBlurArea(disableOnHover: true)
    let area2 = TestHelpers.makeBlurArea(disableOnHover: true)
    sut.startTracking(area: area1)
    sut.startTracking(area: area2)

    sut.stopAllTracking()

    XCTAssertFalse(sut.isTracking(areaID: area1.id))
    XCTAssertFalse(sut.isTracking(areaID: area2.id))
    XCTAssertEqual(mockProvider.removeMonitorCallCount, 1)
  }

  func testUpdateFrame() {
    let area = TestHelpers.makeBlurArea(
      frame: CGRect(x: 0, y: 0, width: 100, height: 100),
      disableOnHover: true
    )
    sut.startTracking(area: area)

    let newFrame = CGRect(x: 50, y: 50, width: 200, height: 200)
    sut.updateFrame(for: area.id, frame: newFrame)

    XCTAssertTrue(sut.isTracking(areaID: area.id))
  }

  func testUpdateFrameForUntrackedArea() {
    let area = TestHelpers.makeBlurArea(disableOnHover: false)
    let newFrame = CGRect(x: 50, y: 50, width: 200, height: 200)

    sut.updateFrame(for: area.id, frame: newFrame)

    XCTAssertFalse(sut.isTracking(areaID: area.id))
  }

  func testCleanupRemovesAllState() {
    let area = TestHelpers.makeBlurArea(disableOnHover: true)
    sut.startTracking(area: area)
    sut.onMouseEnter = { _ in }
    sut.onMouseExit = { _ in }

    sut.cleanup()

    XCTAssertFalse(sut.isTracking(areaID: area.id))
    XCTAssertNil(sut.onMouseEnter)
    XCTAssertNil(sut.onMouseExit)
  }

  func testIsTrackingReturnsFalseForUnknownID() {
    XCTAssertFalse(sut.isTracking(areaID: UUID()))
  }

  func testMouseEnterCallbackFires() {
    let area = TestHelpers.makeBlurArea(
      frame: CGRect(x: 0, y: 0, width: 100, height: 100),
      disableOnHover: true
    )
    var enteredAreaID: UUID?
    sut.onMouseEnter = { id in enteredAreaID = id }
    sut.startTracking(area: area)

    mockProvider.stubbedMouseLocation = CGPoint(x: 50, y: 50)
    mockProvider.capturedHandler?(NSEvent())

    let expectation = XCTestExpectation(description: "Callback fires")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      if enteredAreaID == area.id {
        expectation.fulfill()
      }
    }
    wait(for: [expectation], timeout: 1.0)
  }

  func testMouseExitCallbackFires() {
    let area = TestHelpers.makeBlurArea(
      frame: CGRect(x: 0, y: 0, width: 100, height: 100),
      disableOnHover: true
    )
    var exitedAreaID: UUID?
    sut.onMouseExit = { id in exitedAreaID = id }
    sut.startTracking(area: area)

    mockProvider.stubbedMouseLocation = CGPoint(x: 50, y: 50)
    mockProvider.capturedHandler?(NSEvent())

    let expectation = XCTestExpectation(description: "Enter first")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      self.mockProvider.stubbedMouseLocation = CGPoint(x: 200, y: 200)
      self.mockProvider.capturedHandler?(NSEvent())
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1.0)

    let exitExpectation = XCTestExpectation(description: "Exit callback fires")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      if exitedAreaID == area.id {
        exitExpectation.fulfill()
      }
    }
    wait(for: [exitExpectation], timeout: 1.0)
  }

  func testStopTrackingFiresExitCallback() {
    let area = TestHelpers.makeBlurArea(
      frame: CGRect(x: 0, y: 0, width: 100, height: 100),
      disableOnHover: true
    )
    var exitedAreaID: UUID?
    sut.onMouseExit = { id in exitedAreaID = id }
    sut.startTracking(area: area)

    mockProvider.stubbedMouseLocation = CGPoint(x: 50, y: 50)
    mockProvider.capturedHandler?(NSEvent())

    let expectation = XCTestExpectation(description: "Enter first")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      self.sut.stopTracking(areaID: area.id)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1.0)

    XCTAssertEqual(exitedAreaID, area.id)
  }
}
