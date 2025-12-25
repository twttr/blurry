import XCTest
@testable import Blurry

@MainActor
final class CodableRectTests: XCTestCase {

  func testInitFromCGRect() {
    let rect = CGRect(x: 100, y: 200, width: 300, height: 400)
    let codable = CodableRect(from: rect)

    XCTAssertEqual(codable.x, 100, accuracy: 0.001)
    XCTAssertEqual(codable.y, 200, accuracy: 0.001)
    XCTAssertEqual(codable.width, 300, accuracy: 0.001)
    XCTAssertEqual(codable.height, 400, accuracy: 0.001)
  }

  func testCGRectProperty() {
    let rect = CGRect(x: 50, y: 75, width: 250, height: 350)
    let codable = CodableRect(from: rect)
    let result = codable.cgRect

    XCTAssertEqual(result.origin.x, 50, accuracy: 0.001)
    XCTAssertEqual(result.origin.y, 75, accuracy: 0.001)
    XCTAssertEqual(result.size.width, 250, accuracy: 0.001)
    XCTAssertEqual(result.size.height, 350, accuracy: 0.001)
  }

  func testRoundTripConversion() {
    let original = CGRect(x: 123.456, y: 789.012, width: 345.678, height: 901.234)
    let codable = CodableRect(from: original)
    let result = codable.cgRect

    XCTAssertEqual(result.origin.x, original.origin.x, accuracy: 0.001)
    XCTAssertEqual(result.origin.y, original.origin.y, accuracy: 0.001)
    XCTAssertEqual(result.size.width, original.size.width, accuracy: 0.001)
    XCTAssertEqual(result.size.height, original.size.height, accuracy: 0.001)
  }

  func testNegativeCoordinates() {
    let rect = CGRect(x: -500, y: -200, width: 300, height: 400)
    let codable = CodableRect(from: rect)
    let result = codable.cgRect

    XCTAssertEqual(result.origin.x, -500, accuracy: 0.001)
    XCTAssertEqual(result.origin.y, -200, accuracy: 0.001)
  }

  func testZeroRect() {
    let rect = CGRect.zero
    let codable = CodableRect(from: rect)
    let result = codable.cgRect

    XCTAssertEqual(result, CGRect.zero)
  }

  func testVeryLargeCoordinates() {
    let rect = CGRect(x: 10000, y: 20000, width: 5000, height: 6000)
    let codable = CodableRect(from: rect)
    let result = codable.cgRect

    XCTAssertEqual(result.origin.x, 10000, accuracy: 0.001)
    XCTAssertEqual(result.origin.y, 20000, accuracy: 0.001)
    XCTAssertEqual(result.size.width, 5000, accuracy: 0.001)
    XCTAssertEqual(result.size.height, 6000, accuracy: 0.001)
  }

  func testVerySmallDimensions() {
    let rect = CGRect(x: 0, y: 0, width: 0.001, height: 0.002)
    let codable = CodableRect(from: rect)
    let result = codable.cgRect

    XCTAssertEqual(result.size.width, 0.001, accuracy: 0.0001)
    XCTAssertEqual(result.size.height, 0.002, accuracy: 0.0001)
  }

  func testEncodeDecodeRoundTrip() throws {
    let original = CGRect(x: 100, y: 200, width: 300, height: 400)
    let codable = CodableRect(from: original)

    let data = try TestHelpers.encodeToJSON(codable)
    let decoded = try TestHelpers.decodeFromJSON(data, as: CodableRect.self)
    let result = decoded.cgRect

    XCTAssertEqual(result.origin.x, original.origin.x, accuracy: 0.001)
    XCTAssertEqual(result.origin.y, original.origin.y, accuracy: 0.001)
    XCTAssertEqual(result.size.width, original.size.width, accuracy: 0.001)
    XCTAssertEqual(result.size.height, original.size.height, accuracy: 0.001)
  }

  func testJSONStructure() throws {
    let rect = CGRect(x: 10, y: 20, width: 30, height: 40)
    let codable = CodableRect(from: rect)

    let data = try TestHelpers.encodeToJSON(codable)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    XCTAssertNotNil(json)
    XCTAssertEqual(json?["x"] as? Double, 10)
    XCTAssertEqual(json?["y"] as? Double, 20)
    XCTAssertEqual(json?["width"] as? Double, 30)
    XCTAssertEqual(json?["height"] as? Double, 40)
  }

  func testDecodingFromManualJSON() throws {
    let json = """
    {"x": 100, "y": 200, "width": 300, "height": 400}
    """
    let data = json.data(using: .utf8)!

    let decoded = try TestHelpers.decodeFromJSON(data, as: CodableRect.self)

    XCTAssertEqual(decoded.x, 100, accuracy: 0.001)
    XCTAssertEqual(decoded.y, 200, accuracy: 0.001)
    XCTAssertEqual(decoded.width, 300, accuracy: 0.001)
    XCTAssertEqual(decoded.height, 400, accuracy: 0.001)
  }

  func testFractionalCoordinates() throws {
    let rect = CGRect(x: 100.5, y: 200.75, width: 300.25, height: 400.125)
    let codable = CodableRect(from: rect)

    let data = try TestHelpers.encodeToJSON(codable)
    let decoded = try TestHelpers.decodeFromJSON(data, as: CodableRect.self)

    XCTAssertEqual(decoded.x, 100.5, accuracy: 0.001)
    XCTAssertEqual(decoded.y, 200.75, accuracy: 0.001)
    XCTAssertEqual(decoded.width, 300.25, accuracy: 0.001)
    XCTAssertEqual(decoded.height, 400.125, accuracy: 0.001)
  }
}
