import XCTest
@testable import Blurry

@MainActor
final class OverlayWindowManagerTests: XCTestCase {
  var mockDisplayManager: MockDisplayManager!
  var sut: OverlayWindowManager!

  override func setUp() async throws {
    try await super.setUp()
    mockDisplayManager = MockDisplayManager()
    sut = OverlayWindowManager(displayManager: mockDisplayManager)
  }

  override func tearDown() async throws {
    sut.removeAllWindows()
    sut = nil
    mockDisplayManager = nil
    try await super.tearDown()
  }

  func testCreateWindowWithValidArea() {
    let area = TestHelpers.makeBlurArea(
      frame: CGRect(x: 100, y: 100, width: 200, height: 200)
    )
    mockDisplayManager.stubbedIsFrameValid = true

    let window = sut.createWindow(for: area)

    XCTAssertNotNil(window)
  }

  func testCreateWindowFailsWithZeroWidth() {
    let area = TestHelpers.makeBlurArea(
      frame: CGRect(x: 100, y: 100, width: 0, height: 200)
    )

    let window = sut.createWindow(for: area)

    XCTAssertNil(window)
  }

  func testCreateWindowFailsWithZeroHeight() {
    let area = TestHelpers.makeBlurArea(
      frame: CGRect(x: 100, y: 100, width: 200, height: 0)
    )

    let window = sut.createWindow(for: area)

    XCTAssertNil(window)
  }

  func testCreateWindowValidatesFrameWithDisplayID() {
    let area = TestHelpers.makeBlurArea(
      frame: CGRect(x: 100, y: 100, width: 200, height: 200),
      displayID: 1
    )
    mockDisplayManager.stubbedIsFrameValid = true

    _ = sut.createWindow(for: area)

    XCTAssertEqual(mockDisplayManager.isFrameValidCallCount, 1)
  }

  func testCreateWindowFailsWithInvalidFrame() {
    let area = TestHelpers.makeBlurArea(
      frame: CGRect(x: 100, y: 100, width: 200, height: 200),
      displayID: 1
    )
    mockDisplayManager.stubbedIsFrameValid = false

    let window = sut.createWindow(for: area)

    XCTAssertNil(window)
  }

  func testCreateWindowWithoutDisplayID() {
    let area = TestHelpers.makeBlurArea(
      frame: CGRect(x: 100, y: 100, width: 200, height: 200),
      displayID: nil
    )

    let window = sut.createWindow(for: area)

    XCTAssertNotNil(window)
    XCTAssertEqual(mockDisplayManager.isFrameValidCallCount, 0)
  }

  func testGetWindowReturnsCreatedWindow() {
    let area = TestHelpers.makeBlurArea()
    mockDisplayManager.stubbedIsFrameValid = true
    let createdWindow = sut.createWindow(for: area)

    let retrievedWindow = sut.getWindow(for: area.id)

    XCTAssertNotNil(retrievedWindow)
    XCTAssertEqual(retrievedWindow, createdWindow)
  }

  func testGetWindowReturnsNilForUnknownID() {
    let window = sut.getWindow(for: UUID())

    XCTAssertNil(window)
  }

  func testRemoveWindow() {
    let area = TestHelpers.makeBlurArea()
    mockDisplayManager.stubbedIsFrameValid = true
    _ = sut.createWindow(for: area)

    sut.removeWindow(for: area.id)

    XCTAssertNil(sut.getWindow(for: area.id))
  }

  func testRemoveWindowForUnknownID() {
    sut.removeWindow(for: UUID())
  }

  func testRemoveAllWindows() {
    let area1 = TestHelpers.makeBlurArea()
    let area2 = TestHelpers.makeBlurArea()
    mockDisplayManager.stubbedIsFrameValid = true
    _ = sut.createWindow(for: area1)
    _ = sut.createWindow(for: area2)

    sut.removeAllWindows()

    XCTAssertNil(sut.getWindow(for: area1.id))
    XCTAssertNil(sut.getWindow(for: area2.id))
  }

  func testEnableResizeMode() {
    let area = TestHelpers.makeBlurArea()
    mockDisplayManager.stubbedIsFrameValid = true
    _ = sut.createWindow(for: area)

    sut.enableResizeMode(for: area.id, delegate: MockResizeDelegate())

    XCTAssertTrue(sut.isInResizeMode(areaID: area.id))
  }

  func testDisableResizeMode() {
    let area = TestHelpers.makeBlurArea()
    mockDisplayManager.stubbedIsFrameValid = true
    _ = sut.createWindow(for: area)
    sut.enableResizeMode(for: area.id, delegate: MockResizeDelegate())

    sut.disableResizeMode(for: area.id)

    XCTAssertFalse(sut.isInResizeMode(areaID: area.id))
  }

  func testIsInResizeModeReturnsFalseByDefault() {
    let area = TestHelpers.makeBlurArea()
    mockDisplayManager.stubbedIsFrameValid = true
    _ = sut.createWindow(for: area)

    XCTAssertFalse(sut.isInResizeMode(areaID: area.id))
  }

  func testDisableAllResizeModes() {
    let area1 = TestHelpers.makeBlurArea()
    let area2 = TestHelpers.makeBlurArea()
    mockDisplayManager.stubbedIsFrameValid = true
    _ = sut.createWindow(for: area1)
    _ = sut.createWindow(for: area2)
    sut.enableResizeMode(for: area1.id, delegate: MockResizeDelegate())
    sut.enableResizeMode(for: area2.id, delegate: MockResizeDelegate())

    sut.disableAllResizeModes()

    XCTAssertFalse(sut.isInResizeMode(areaID: area1.id))
    XCTAssertFalse(sut.isInResizeMode(areaID: area2.id))
  }

  func testMultipleWindowsTrackedIndependently() {
    let area1 = TestHelpers.makeBlurArea(name: "Area 1")
    let area2 = TestHelpers.makeBlurArea(name: "Area 2")
    mockDisplayManager.stubbedIsFrameValid = true

    let window1 = sut.createWindow(for: area1)
    let window2 = sut.createWindow(for: area2)

    XCTAssertNotNil(window1)
    XCTAssertNotNil(window2)
    XCTAssertNotEqual(sut.getWindow(for: area1.id), sut.getWindow(for: area2.id))
  }
}

private class MockResizeDelegate: ResizeHandleDelegate {
  func resizeHandleView(_ view: ResizeHandleView, didUpdateFrame frame: CGRect) {}
  func resizeHandleView(_ view: ResizeHandleView, didExitResizeMode frame: CGRect) {}
}
