import Cocoa

class PictureEffectView: NSView {
  private let imageView = NSImageView()
  
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setupImageView()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupImageView()
  }
  
  private func setupImageView() {
    imageView.imageScaling = .scaleProportionallyUpOrDown
    imageView.autoresizingMask = [.width, .height]
    addSubview(imageView)
  }
  
  override func layout() {
    super.layout()
    imageView.frame = bounds
  }
  
  func setImage(_ image: NSImage) {
    imageView.image = image
  }
}
