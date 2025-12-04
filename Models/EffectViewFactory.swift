import Cocoa

enum EffectViewFactory {
  /// Creates and configures an effect view for the given blur area
  /// - Parameters:
  ///   - area: The BlurArea containing effect type and parameters
  ///   - bounds: The bounds for the view frame
  /// - Returns: A configured NSView subclass ready to be added to a window
  static func createView(for area: BlurArea, in bounds: NSRect) -> NSView? {
    let view: NSView
    
    switch area.effectType {
    case .blur(let radius):
      let blurEffectView = BlurEffectView(frame: bounds)
      let material = getMaterialForBlurRadius(radius)
      blurEffectView.setMaterial(material)
      view = blurEffectView
      
    case .darken(let amount):
      let darkenEffectView = DarkenEffectView(
        frame: bounds,
        darkenAmount: amount
      )
      view = darkenEffectView
      
    case .picture(let imagePath):
      guard let image = NSImage(contentsOfFile: imagePath) else {
        return nil
      }
      
      let pictureEffectView = PictureEffectView(frame: bounds)
      pictureEffectView.setImage(image)
      view = pictureEffectView
    }
    
    view.autoresizingMask = [.width, .height]
    
    return view
  }
  
  /// Maps blur radius values to NSVisualEffectView materials
  /// - Parameter radius: The blur radius (typically 10.0, 20.0, or 30.0)
  /// - Returns: The corresponding material for the blur effect
  private static func getMaterialForBlurRadius(_ radius: Double) -> NSVisualEffectView.Material {
    if radius == 10.0 {
      return .sidebar
    } else if radius == 30.0 {
      return .menu
    } else {
      return .hudWindow
    }
  }
}
