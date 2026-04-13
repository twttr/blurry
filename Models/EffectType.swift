import Foundation
import Cocoa

enum BlurIntensity: String, Codable, CaseIterable {
  case low
  case medium
  case high

  var material: NSVisualEffectView.Material {
    switch self {
    case .low: return .sidebar
    case .medium: return .hudWindow
    case .high: return .menu
    }
  }

  init(fromLegacyRadius radius: Double) {
    switch radius {
    case 10.0: self = .low
    case 30.0: self = .high
    default: self = .medium
    }
  }
}

enum EffectType: Codable {
  case blur(intensity: BlurIntensity)
  case darken(amount: Double)
  case picture(imageRef: String)

  enum CodingKeys: String, CodingKey {
    case type
    case intensity
    case radius
    case amount
    case imageRef
    case imageData
  }

  enum TypeValue: String, Codable {
    case blur
    case darken
    case picture
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case .blur(let intensity):
      try container.encode(TypeValue.blur, forKey: .type)
      try container.encode(intensity, forKey: .intensity)
    case .darken(let amount):
      try container.encode(TypeValue.darken, forKey: .type)
      try container.encode(amount, forKey: .amount)
    case .picture(let imageRef):
      try container.encode(TypeValue.picture, forKey: .type)
      try container.encode(imageRef, forKey: .imageRef)
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(TypeValue.self, forKey: .type)

    switch type {
    case .blur:
      if let intensity = try? container.decode(BlurIntensity.self, forKey: .intensity) {
        self = .blur(intensity: intensity)
      } else if let radius = try? container.decode(Double.self, forKey: .radius) {
        self = .blur(intensity: BlurIntensity(fromLegacyRadius: radius))
      } else {
        self = .blur(intensity: .medium)
      }
    case .darken:
      let amount = try container.decode(Double.self, forKey: .amount)
      self = .darken(amount: amount)
    case .picture:
      if let imageRef = try? container.decode(String.self, forKey: .imageRef) {
        self = .picture(imageRef: imageRef)
      } else if let imageData = try? container.decode(Data.self, forKey: .imageData) {
        let filename = ImageStorageManager.shared.saveImage(imageData, id: UUID())
        self = .picture(imageRef: filename)
      } else {
        throw DecodingError.dataCorruptedError(forKey: .imageRef, in: container, debugDescription: "Missing image reference or data")
      }
    }
  }

  var typeName: String {
    switch self {
    case .blur: return "blur"
    case .darken: return "darken"
    case .picture: return "picture"
    }
  }

  var isBlur: Bool {
    if case .blur = self { return true }
    return false
  }

  var isDarken: Bool {
    if case .darken = self { return true }
    return false
  }

  var isPicture: Bool {
    if case .picture = self { return true }
    return false
  }

  func isSameKind(as other: EffectType) -> Bool {
    switch (self, other) {
    case (.blur, .blur), (.darken, .darken), (.picture, .picture):
      return true
    default:
      return false
    }
  }
}
