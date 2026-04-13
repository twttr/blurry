import Cocoa

enum EffectViewFactory {
  static func createView(for area: BlurArea, in bounds: NSRect) -> NSView? {
    let view: NSView

    switch area.effectType {
    case .blur(let intensity):
      let blurEffectView = BlurEffectView(frame: bounds)
      blurEffectView.setMaterial(intensity.material)
      view = blurEffectView

    case .darken(let amount):
      let darkenEffectView = DarkenEffectView(
        frame: bounds,
        darkenAmount: amount
      )
      view = darkenEffectView

    case .picture(let imageRef):
      guard let imageData = ImageStorageManager.shared.loadImage(filename: imageRef),
            let image = NSImage(data: imageData) else {
        return nil
      }
      let pictureEffectView = PictureEffectView(frame: bounds)
      pictureEffectView.setImage(image)
      view = pictureEffectView
    }

    view.autoresizingMask = [.width, .height]

    return view
  }
}
