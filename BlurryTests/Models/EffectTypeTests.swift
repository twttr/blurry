import XCTest
@testable import Blurry

final class EffectTypeTests: XCTestCase {

  func testBlurEncodeDecodeRoundTrip() throws {
    let original = EffectType.blur(radius: 15.5)

    let data = try TestHelpers.encodeToJSON(original)
    let decoded = try TestHelpers.decodeFromJSON(data, as: EffectType.self)

    if case .blur(let radius) = decoded {
      XCTAssertEqual(radius, 15.5, accuracy: 0.001)
    } else {
      XCTFail("Expected blur effect")
    }
  }

  func testDarkenEncodeDecodeRoundTrip() throws {
    let original = EffectType.darken(amount: 0.75)

    let data = try TestHelpers.encodeToJSON(original)
    let decoded = try TestHelpers.decodeFromJSON(data, as: EffectType.self)

    if case .darken(let amount) = decoded {
      XCTAssertEqual(amount, 0.75, accuracy: 0.001)
    } else {
      XCTFail("Expected darken effect")
    }
  }

  func testPictureEncodeDecodeRoundTrip() throws {
    let imageData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])
    let original = EffectType.picture(imageData: imageData)

    let data = try TestHelpers.encodeToJSON(original)
    let decoded = try TestHelpers.decodeFromJSON(data, as: EffectType.self)

    if case .picture(let decodedData) = decoded {
      XCTAssertEqual(decodedData, imageData)
    } else {
      XCTFail("Expected picture effect")
    }
  }

  func testIsBlur() {
    XCTAssertTrue(EffectType.blur(radius: 10).isBlur)
    XCTAssertFalse(EffectType.darken(amount: 0.5).isBlur)
    XCTAssertFalse(EffectType.picture(imageData: Data()).isBlur)
  }

  func testIsDarken() {
    XCTAssertFalse(EffectType.blur(radius: 10).isDarken)
    XCTAssertTrue(EffectType.darken(amount: 0.5).isDarken)
    XCTAssertFalse(EffectType.picture(imageData: Data()).isDarken)
  }

  func testIsPicture() {
    XCTAssertFalse(EffectType.blur(radius: 10).isPicture)
    XCTAssertFalse(EffectType.darken(amount: 0.5).isPicture)
    XCTAssertTrue(EffectType.picture(imageData: Data()).isPicture)
  }

  func testTypeName() {
    XCTAssertEqual(EffectType.blur(radius: 10).typeName, "blur")
    XCTAssertEqual(EffectType.darken(amount: 0.5).typeName, "darken")
    XCTAssertEqual(EffectType.picture(imageData: Data()).typeName, "picture")
  }

  func testIsSameKindBlur() {
    let blur1 = EffectType.blur(radius: 10)
    let blur2 = EffectType.blur(radius: 30)
    let darken = EffectType.darken(amount: 0.5)
    let picture = EffectType.picture(imageData: Data())

    XCTAssertTrue(blur1.isSameKind(as: blur2))
    XCTAssertFalse(blur1.isSameKind(as: darken))
    XCTAssertFalse(blur1.isSameKind(as: picture))
  }

  func testIsSameKindDarken() {
    let darken1 = EffectType.darken(amount: 0.3)
    let darken2 = EffectType.darken(amount: 0.7)
    let blur = EffectType.blur(radius: 10)
    let picture = EffectType.picture(imageData: Data())

    XCTAssertTrue(darken1.isSameKind(as: darken2))
    XCTAssertFalse(darken1.isSameKind(as: blur))
    XCTAssertFalse(darken1.isSameKind(as: picture))
  }

  func testIsSameKindPicture() {
    let picture1 = EffectType.picture(imageData: Data([0x01]))
    let picture2 = EffectType.picture(imageData: Data([0x02, 0x03]))
    let blur = EffectType.blur(radius: 10)
    let darken = EffectType.darken(amount: 0.5)

    XCTAssertTrue(picture1.isSameKind(as: picture2))
    XCTAssertFalse(picture1.isSameKind(as: blur))
    XCTAssertFalse(picture1.isSameKind(as: darken))
  }

  func testBlurWithDifferentRadii() throws {
    let radii: [Double] = [10.0, 20.0, 30.0, 0.5, 100.0]

    for radius in radii {
      let original = EffectType.blur(radius: radius)
      let data = try TestHelpers.encodeToJSON(original)
      let decoded = try TestHelpers.decodeFromJSON(data, as: EffectType.self)

      if case .blur(let decodedRadius) = decoded {
        XCTAssertEqual(decodedRadius, radius, accuracy: 0.001)
      } else {
        XCTFail("Expected blur effect for radius \(radius)")
      }
    }
  }

  func testDarkenWithDifferentAmounts() throws {
    let amounts: [Double] = [0.0, 0.3, 0.5, 0.7, 1.0]

    for amount in amounts {
      let original = EffectType.darken(amount: amount)
      let data = try TestHelpers.encodeToJSON(original)
      let decoded = try TestHelpers.decodeFromJSON(data, as: EffectType.self)

      if case .darken(let decodedAmount) = decoded {
        XCTAssertEqual(decodedAmount, amount, accuracy: 0.001)
      } else {
        XCTFail("Expected darken effect for amount \(amount)")
      }
    }
  }

  func testPictureWithEmptyData() throws {
    let original = EffectType.picture(imageData: Data())

    let data = try TestHelpers.encodeToJSON(original)
    let decoded = try TestHelpers.decodeFromJSON(data, as: EffectType.self)

    if case .picture(let decodedData) = decoded {
      XCTAssertTrue(decodedData.isEmpty)
    } else {
      XCTFail("Expected picture effect with empty data")
    }
  }

  func testPictureWithLargeData() throws {
    let largeData = Data(repeating: 0xFF, count: 1024 * 10)
    let original = EffectType.picture(imageData: largeData)

    let data = try TestHelpers.encodeToJSON(original)
    let decoded = try TestHelpers.decodeFromJSON(data, as: EffectType.self)

    if case .picture(let decodedData) = decoded {
      XCTAssertEqual(decodedData.count, largeData.count)
      XCTAssertEqual(decodedData, largeData)
    } else {
      XCTFail("Expected picture effect with large data")
    }
  }
}
