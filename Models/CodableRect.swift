import Foundation
import CoreGraphics

/// A Codable wrapper for CGRect that encodes/decodes as separate x, y, width, height values
struct CodableRect: Codable {
  let x: Double
  let y: Double
  let width: Double
  let height: Double
  
  init(from rect: CGRect) {
    self.x = rect.origin.x
    self.y = rect.origin.y
    self.width = rect.size.width
    self.height = rect.size.height
  }
  
  var cgRect: CGRect {
    CGRect(x: x, y: y, width: width, height: height)
  }
}
