import Foundation
import CoreGraphics
@testable import Blurry

@MainActor
enum TestHelpers {
  static func makeBlurArea(
    id: UUID = UUID(),
    name: String = "Test Area",
    frame: CGRect = CGRect(x: 100, y: 100, width: 200, height: 200),
    effectType: EffectType = .blur(radius: 20.0),
    isEnabled: Bool = true,
    disableOnHover: Bool = false,
    displayID: CGDirectDisplayID? = 1,
    displayUUID: String? = "test-uuid",
    displayRelativeFrame: CGRect = CGRect(x: 100, y: 100, width: 200, height: 200)
  ) -> BlurArea {
    BlurArea(
      id: id,
      name: name,
      frame: frame,
      effectType: effectType,
      isEnabled: isEnabled,
      disableOnHover: disableOnHover,
      displayID: displayID,
      displayUUID: displayUUID,
      displayRelativeFrame: displayRelativeFrame
    )
  }

  static func makeBlurEffect(radius: Double = 20.0) -> EffectType {
    .blur(radius: radius)
  }

  static func makeDarkenEffect(amount: Double = 0.5) -> EffectType {
    .darken(amount: amount)
  }

  static func makePictureEffect(data: Data = Data([0x89, 0x50, 0x4E, 0x47])) -> EffectType {
    .picture(imageData: data)
  }

  static func encodeToJSON<T: Encodable>(_ value: T) throws -> Data {
    try JSONEncoder().encode(value)
  }

  static func decodeFromJSON<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
    try JSONDecoder().decode(type, from: data)
  }
}
