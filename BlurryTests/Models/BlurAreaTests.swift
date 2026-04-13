import XCTest
@testable import Blurry

@MainActor
final class BlurAreaTests: XCTestCase {

  func testInitialization() {
    let id = UUID()
    let frame = CGRect(x: 100, y: 200, width: 300, height: 400)
    let area = BlurArea(
      id: id,
      name: "Test Area",
      frame: frame,
      effectType: .blur(intensity: .medium),
      isEnabled: true,
      disableOnHover: false,
      displayID: 1,
      displayUUID: "test-uuid",
      displayRelativeFrame: frame
    )

    XCTAssertEqual(area.id, id)
    XCTAssertEqual(area.name, "Test Area")
    XCTAssertEqual(area.frame, frame)
    XCTAssertTrue(area.isEnabled)
    XCTAssertFalse(area.disableOnHover)
    XCTAssertEqual(area.displayID, 1)
    XCTAssertEqual(area.displayUUID, "test-uuid")
  }

  func testDefaultValues() {
    let area = BlurArea(
      name: "Test",
      frame: CGRect(x: 0, y: 0, width: 100, height: 100),
      effectType: .blur(intensity: .low)
    )

    XCTAssertTrue(area.isEnabled)
    XCTAssertFalse(area.disableOnHover)
    XCTAssertNil(area.displayID)
    XCTAssertNil(area.displayUUID)
    XCTAssertEqual(area.displayRelativeFrame, .zero)
  }

  func testEncodeDecodeRoundTrip() throws {
    let original = TestHelpers.makeBlurArea(
      name: "Round Trip Test",
      frame: CGRect(x: 50, y: 75, width: 250, height: 350),
      effectType: .darken(amount: 0.7),
      isEnabled: false,
      disableOnHover: true,
      displayID: 42,
      displayUUID: "uuid-123",
      displayRelativeFrame: CGRect(x: 10, y: 20, width: 250, height: 350)
    )

    let data = try TestHelpers.encodeToJSON(original)
    let decoded = try TestHelpers.decodeFromJSON(data, as: BlurArea.self)

    XCTAssertEqual(decoded.id, original.id)
    XCTAssertEqual(decoded.name, original.name)
    XCTAssertEqual(decoded.frame.origin.x, original.frame.origin.x, accuracy: 0.001)
    XCTAssertEqual(decoded.frame.origin.y, original.frame.origin.y, accuracy: 0.001)
    XCTAssertEqual(decoded.frame.size.width, original.frame.size.width, accuracy: 0.001)
    XCTAssertEqual(decoded.frame.size.height, original.frame.size.height, accuracy: 0.001)
    XCTAssertEqual(decoded.isEnabled, original.isEnabled)
    XCTAssertEqual(decoded.disableOnHover, original.disableOnHover)
    XCTAssertEqual(decoded.displayID, original.displayID)
    XCTAssertEqual(decoded.displayUUID, original.displayUUID)
  }

  func testEncodeDecodeBlurEffect() throws {
    let original = TestHelpers.makeBlurArea(effectType: .blur(intensity: .high))

    let data = try TestHelpers.encodeToJSON(original)
    let decoded = try TestHelpers.decodeFromJSON(data, as: BlurArea.self)

    if case .blur(let intensity) = decoded.effectType {
      XCTAssertEqual(intensity, .high)
    } else {
      XCTFail("Expected blur effect type")
    }
  }

  func testEncodeDecodeDarkenEffect() throws {
    let original = TestHelpers.makeBlurArea(effectType: .darken(amount: 0.65))

    let data = try TestHelpers.encodeToJSON(original)
    let decoded = try TestHelpers.decodeFromJSON(data, as: BlurArea.self)

    if case .darken(let amount) = decoded.effectType {
      XCTAssertEqual(amount, 0.65, accuracy: 0.001)
    } else {
      XCTFail("Expected darken effect type")
    }
  }

  func testEncodeDecodePictureEffect() throws {
    let original = TestHelpers.makeBlurArea(effectType: .picture(imageRef: "test-image.png"))

    let data = try TestHelpers.encodeToJSON(original)
    let decoded = try TestHelpers.decodeFromJSON(data, as: BlurArea.self)

    if case .picture(let decodedRef) = decoded.effectType {
      XCTAssertEqual(decodedRef, "test-image.png")
    } else {
      XCTFail("Expected picture effect type")
    }
  }

  func testNegativeCoordinates() throws {
    let frame = CGRect(x: -500, y: -200, width: 300, height: 400)
    let original = TestHelpers.makeBlurArea(frame: frame)

    let data = try TestHelpers.encodeToJSON(original)
    let decoded = try TestHelpers.decodeFromJSON(data, as: BlurArea.self)

    XCTAssertEqual(decoded.frame.origin.x, -500, accuracy: 0.001)
    XCTAssertEqual(decoded.frame.origin.y, -200, accuracy: 0.001)
  }

  func testFractionalCoordinates() throws {
    let frame = CGRect(x: 100.5, y: 200.75, width: 300.25, height: 400.125)
    let original = TestHelpers.makeBlurArea(frame: frame)

    let data = try TestHelpers.encodeToJSON(original)
    let decoded = try TestHelpers.decodeFromJSON(data, as: BlurArea.self)

    XCTAssertEqual(decoded.frame.origin.x, 100.5, accuracy: 0.001)
    XCTAssertEqual(decoded.frame.origin.y, 200.75, accuracy: 0.001)
    XCTAssertEqual(decoded.frame.size.width, 300.25, accuracy: 0.001)
    XCTAssertEqual(decoded.frame.size.height, 400.125, accuracy: 0.001)
  }

  func testUUIDUniqueness() {
    let area1 = TestHelpers.makeBlurArea()
    let area2 = TestHelpers.makeBlurArea()

    XCTAssertNotEqual(area1.id, area2.id)
  }

  func testIdentifiable() {
    let id = UUID()
    let area = TestHelpers.makeBlurArea(id: id)

    XCTAssertEqual(area.id, id)
  }

  func testMakeDisplayRelative() {
    let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let areaFrame = CGRect(x: 100, y: 200, width: 300, height: 400)
    let area = TestHelpers.makeBlurArea(frame: areaFrame)

    let mockScreen = MockNSScreen(frame: screenFrame)
    let relativeFrame = area.makeDisplayRelative(screen: mockScreen)

    XCTAssertEqual(relativeFrame.origin.x, 100, accuracy: 0.001)
    XCTAssertEqual(relativeFrame.origin.y, 200, accuracy: 0.001)
  }

  func testMakeDisplayRelativeWithOffset() {
    let screenFrame = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
    let areaFrame = CGRect(x: 2020, y: 200, width: 300, height: 400)
    let area = TestHelpers.makeBlurArea(frame: areaFrame)

    let mockScreen = MockNSScreen(frame: screenFrame)
    let relativeFrame = area.makeDisplayRelative(screen: mockScreen)

    XCTAssertEqual(relativeFrame.origin.x, 100, accuracy: 0.001)
    XCTAssertEqual(relativeFrame.origin.y, 200, accuracy: 0.001)
  }

  func testMakeGlobal() {
    let screenFrame = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
    let relativeFrame = CGRect(x: 100, y: 200, width: 300, height: 400)

    let mockScreen = MockNSScreen(frame: screenFrame)
    let globalFrame = BlurArea.makeGlobal(relativeFrame: relativeFrame, screen: mockScreen)

    XCTAssertEqual(globalFrame.origin.x, 2020, accuracy: 0.001)
    XCTAssertEqual(globalFrame.origin.y, 200, accuracy: 0.001)
  }

  func testMakeGlobalPreservesSize() {
    let screenFrame = CGRect(x: 500, y: 300, width: 1920, height: 1080)
    let relativeFrame = CGRect(x: 100, y: 200, width: 300, height: 400)

    let mockScreen = MockNSScreen(frame: screenFrame)
    let globalFrame = BlurArea.makeGlobal(relativeFrame: relativeFrame, screen: mockScreen)

    XCTAssertEqual(globalFrame.size.width, 300, accuracy: 0.001)
    XCTAssertEqual(globalFrame.size.height, 400, accuracy: 0.001)
  }
}

private class MockNSScreen: NSScreen {
  private let mockFrame: CGRect

  init(frame: CGRect) {
    self.mockFrame = frame
    super.init()
  }

  override var frame: CGRect {
    mockFrame
  }
}
