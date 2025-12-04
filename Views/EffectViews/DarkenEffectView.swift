import Cocoa

class DarkenEffectView: NSView {
  private let darkLayer = CALayer()
  private var darkenAmount: Double = 0.5
  
  init(frame frameRect: NSRect, darkenAmount: Double = 0.5) {
    self.darkenAmount = darkenAmount
    super.init(frame: frameRect)
    setupDarkLayer()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupDarkLayer()
  }
  
  private func setupDarkLayer() {
    wantsLayer = true
    darkLayer.backgroundColor = NSColor.black.cgColor
    darkLayer.opacity = Float(darkenAmount)
    layer?.addSublayer(darkLayer)
  }
  
  override func layout() {
    super.layout()
    darkLayer.frame = bounds
  }
  
  func setDarkenAmount(_ amount: Double) {
    let clampedAmount = max(0.0, min(1.0, amount))
    darkenAmount = clampedAmount
    darkLayer.opacity = Float(clampedAmount)
  }
}
