import Foundation
import CoreGraphics
import Cocoa

struct BlurArea: Identifiable, Codable {
  var id: UUID = UUID()
  var name: String
  var frame: CGRect
  var effectType: EffectType
  var isEnabled: Bool = true
  var disableOnHover: Bool = false
  var displayID: CGDirectDisplayID? = nil
  var displayUUID: String? = nil
  var displayRelativeFrame: CGRect = .zero
  
  enum CodingKeys: String, CodingKey {
    case id, name, frame, effectType, isEnabled, disableOnHover, displayID, displayUUID, displayRelativeFrame
  }
  
  init(
    id: UUID = UUID(),
    name: String,
    frame: CGRect,
    effectType: EffectType,
    isEnabled: Bool = true,
    disableOnHover: Bool = false,
    displayID: CGDirectDisplayID? = nil,
    displayUUID: String? = nil,
    displayRelativeFrame: CGRect = .zero
  ) {
    self.id = id
    self.name = name
    self.frame = frame
    self.effectType = effectType
    self.isEnabled = isEnabled
    self.disableOnHover = disableOnHover
    self.displayID = displayID
    self.displayUUID = displayUUID
    self.displayRelativeFrame = displayRelativeFrame
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(name, forKey: .name)
    
    let codableFrame = CodableRect(from: frame)
    try container.encode(codableFrame, forKey: .frame)
    
    try container.encode(effectType, forKey: .effectType)
    try container.encode(isEnabled, forKey: .isEnabled)
    try container.encode(disableOnHover, forKey: .disableOnHover)
    try container.encode(displayID, forKey: .displayID)
    try container.encodeIfPresent(displayUUID, forKey: .displayUUID)
    
    let codableRelativeFrame = CodableRect(from: displayRelativeFrame)
    try container.encode(codableRelativeFrame, forKey: .displayRelativeFrame)
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    
    if let codableFrame = try? container.decode(CodableRect.self, forKey: .frame) {
      frame = codableFrame.cgRect
    } else {
      enum LegacyKeys: String, CodingKey {
        case frameX, frameY, frameWidth, frameHeight
      }
      let legacyContainer = try decoder.container(keyedBy: LegacyKeys.self)
      let x = try legacyContainer.decode(Double.self, forKey: .frameX)
      let y = try legacyContainer.decode(Double.self, forKey: .frameY)
      let width = try legacyContainer.decode(Double.self, forKey: .frameWidth)
      let height = try legacyContainer.decode(Double.self, forKey: .frameHeight)
      frame = CGRect(x: x, y: y, width: width, height: height)
    }
    
    effectType = try container.decode(EffectType.self, forKey: .effectType)
    isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
    disableOnHover = try container.decode(Bool.self, forKey: .disableOnHover)
    displayID = try container.decodeIfPresent(CGDirectDisplayID.self, forKey: .displayID)
    displayUUID = try container.decodeIfPresent(String.self, forKey: .displayUUID)
    
    if let codableRelativeFrame = try? container.decode(CodableRect.self, forKey: .displayRelativeFrame) {
      displayRelativeFrame = codableRelativeFrame.cgRect
    } else {
      displayRelativeFrame = .zero
    }
  }
  
  func makeDisplayRelative(screen: NSScreen) -> CGRect {
    return CGRect(
      x: frame.origin.x - screen.frame.origin.x,
      y: frame.origin.y - screen.frame.origin.y,
      width: frame.width,
      height: frame.height
    )
  }
  
  static func makeGlobal(relativeFrame: CGRect, screen: NSScreen) -> CGRect {
    return CGRect(
      x: relativeFrame.origin.x + screen.frame.origin.x,
      y: relativeFrame.origin.y + screen.frame.origin.y,
      width: relativeFrame.width,
      height: relativeFrame.height
    )
  }
}
