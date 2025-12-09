import Foundation

enum EffectType: Codable {
  case blur(radius: Double)
  case darken(amount: Double)
  case picture(imageData: Data)

  enum CodingKeys: String, CodingKey {
    case type
    case radius
    case amount
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
    case .blur(let radius):
      try container.encode(TypeValue.blur, forKey: .type)
      try container.encode(radius, forKey: .radius)
    case .darken(let amount):
      try container.encode(TypeValue.darken, forKey: .type)
      try container.encode(amount, forKey: .amount)
    case .picture(let imageData):
      try container.encode(TypeValue.picture, forKey: .type)
      try container.encode(imageData, forKey: .imageData)
    }
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(TypeValue.self, forKey: .type)
    
    switch type {
    case .blur:
      let radius = try container.decode(Double.self, forKey: .radius)
      self = .blur(radius: radius)
    case .darken:
      let amount = try container.decode(Double.self, forKey: .amount)
      self = .darken(amount: amount)
    case .picture:
      let imageData = try container.decode(Data.self, forKey: .imageData)
      self = .picture(imageData: imageData)
    }
  }
  
  // MARK: - Convenience Properties
  
  /// Returns the type name for display purposes
  var typeName: String {
    switch self {
    case .blur: return "blur"
    case .darken: return "darken"
    case .picture: return "picture"
    }
  }
  
  /// Returns true if this is a blur effect
  var isBlur: Bool {
    if case .blur = self { return true }
    return false
  }
  
  /// Returns true if this is a darken effect
  var isDarken: Bool {
    if case .darken = self { return true }
    return false
  }
  
  /// Returns true if this is a picture effect
  var isPicture: Bool {
    if case .picture = self { return true }
    return false
  }
  
  /// Checks if two effect types are of the same kind (ignoring associated values)
  func isSameKind(as other: EffectType) -> Bool {
    switch (self, other) {
    case (.blur, .blur), (.darken, .darken), (.picture, .picture):
      return true
    default:
      return false
    }
  }
}
