import XCTest
@testable import Blurry

@MainActor
final class EffectTypeTests: XCTestCase {

  func testBlurEncodeDecodeRoundTrip() throws {
    let original = EffectType.blur(intensity: .high)

    let data = try TestHelpers.encodeToJSON(original)
    let decoded = try TestHelpers.decodeFromJSON(data, as: EffectType.self)

    if case .blur(let intensity) = decoded {
      XCTAssertEqual(intensity, .high)
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
    let original = EffectType.picture(imageRef: "test-image.png")

    let data = try TestHelpers.encodeToJSON(original)
    let decoded = try TestHelpers.decodeFromJSON(data, as: EffectType.self)

    if case .picture(let decodedRef) = decoded {
      XCTAssertEqual(decodedRef, "test-image.png")
    } else {
      XCTFail("Expected picture effect")
    }
  }

  func testPictureLegacyDataMigration() throws {
    let legacyJSON = """
    {"type":"picture","imageData":"iVBORw0KGgo="}
    """
    let data = legacyJSON.data(using: .utf8)!
    let decoded = try TestHelpers.decodeFromJSON(data, as: EffectType.self)

    if case .picture(let imageRef) = decoded {
      XCTAssertFalse(imageRef.isEmpty)
      XCTAssertTrue(imageRef.hasSuffix(".png"))
    } else {
      XCTFail("Expected picture effect from legacy data")
    }
  }

  func testBlurLegacyRadiusMigration() throws {
    let legacyJSON = """
    {"type":"blur","radius":10.0}
    """
    let data = legacyJSON.data(using: .utf8)!
    let decoded = try TestHelpers.decodeFromJSON(data, as: EffectType.self)

    if case .blur(let intensity) = decoded {
      XCTAssertEqual(intensity, .low)
    } else {
      XCTFail("Expected blur effect from legacy radius")
    }
  }

  func testBlurLegacyRadiusMigrationHigh() throws {
    let legacyJSON = """
    {"type":"blur","radius":30.0}
    """
    let data = legacyJSON.data(using: .utf8)!
    let decoded = try TestHelpers.decodeFromJSON(data, as: EffectType.self)

    if case .blur(let intensity) = decoded {
      XCTAssertEqual(intensity, .high)
    } else {
      XCTFail("Expected blur effect from legacy radius")
    }
  }

  func testBlurLegacyRadiusMigrationDefault() throws {
    let legacyJSON = """
    {"type":"blur","radius":20.0}
    """
    let data = legacyJSON.data(using: .utf8)!
    let decoded = try TestHelpers.decodeFromJSON(data, as: EffectType.self)

    if case .blur(let intensity) = decoded {
      XCTAssertEqual(intensity, .medium)
    } else {
      XCTFail("Expected blur effect from legacy radius")
    }
  }

  func testIsBlur() {
    XCTAssertTrue(EffectType.blur(intensity: .medium).isBlur)
    XCTAssertFalse(EffectType.darken(amount: 0.5).isBlur)
    XCTAssertFalse(EffectType.picture(imageRef: "test.png").isBlur)
  }

  func testIsDarken() {
    XCTAssertFalse(EffectType.blur(intensity: .medium).isDarken)
    XCTAssertTrue(EffectType.darken(amount: 0.5).isDarken)
    XCTAssertFalse(EffectType.picture(imageRef: "test.png").isDarken)
  }

  func testIsPicture() {
    XCTAssertFalse(EffectType.blur(intensity: .medium).isPicture)
    XCTAssertFalse(EffectType.darken(amount: 0.5).isPicture)
    XCTAssertTrue(EffectType.picture(imageRef: "test.png").isPicture)
  }

  func testTypeName() {
    XCTAssertEqual(EffectType.blur(intensity: .medium).typeName, "blur")
    XCTAssertEqual(EffectType.darken(amount: 0.5).typeName, "darken")
    XCTAssertEqual(EffectType.picture(imageRef: "test.png").typeName, "picture")
  }

  func testIsSameKindBlur() {
    let blur1 = EffectType.blur(intensity: .low)
    let blur2 = EffectType.blur(intensity: .high)
    let darken = EffectType.darken(amount: 0.5)
    let picture = EffectType.picture(imageRef: "test.png")

    XCTAssertTrue(blur1.isSameKind(as: blur2))
    XCTAssertFalse(blur1.isSameKind(as: darken))
    XCTAssertFalse(blur1.isSameKind(as: picture))
  }

  func testIsSameKindDarken() {
    let darken1 = EffectType.darken(amount: 0.3)
    let darken2 = EffectType.darken(amount: 0.7)
    let blur = EffectType.blur(intensity: .medium)
    let picture = EffectType.picture(imageRef: "test.png")

    XCTAssertTrue(darken1.isSameKind(as: darken2))
    XCTAssertFalse(darken1.isSameKind(as: blur))
    XCTAssertFalse(darken1.isSameKind(as: picture))
  }

  func testIsSameKindPicture() {
    let picture1 = EffectType.picture(imageRef: "img1.png")
    let picture2 = EffectType.picture(imageRef: "img2.png")
    let blur = EffectType.blur(intensity: .medium)
    let darken = EffectType.darken(amount: 0.5)

    XCTAssertTrue(picture1.isSameKind(as: picture2))
    XCTAssertFalse(picture1.isSameKind(as: blur))
    XCTAssertFalse(picture1.isSameKind(as: darken))
  }

  func testBlurAllIntensities() throws {
    for intensity in BlurIntensity.allCases {
      let original = EffectType.blur(intensity: intensity)
      let data = try TestHelpers.encodeToJSON(original)
      let decoded = try TestHelpers.decodeFromJSON(data, as: EffectType.self)

      if case .blur(let decodedIntensity) = decoded {
        XCTAssertEqual(decodedIntensity, intensity)
      } else {
        XCTFail("Expected blur effect for intensity \(intensity)")
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

  func testPictureWithEmptyRef() throws {
    let original = EffectType.picture(imageRef: "")

    let data = try TestHelpers.encodeToJSON(original)
    let decoded = try TestHelpers.decodeFromJSON(data, as: EffectType.self)

    if case .picture(let decodedRef) = decoded {
      XCTAssertTrue(decodedRef.isEmpty)
    } else {
      XCTFail("Expected picture effect with empty ref")
    }
  }
}
