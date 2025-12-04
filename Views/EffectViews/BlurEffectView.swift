import Cocoa

class BlurEffectView: NSView {
  private let visualEffectView: NSVisualEffectView
  
  override init(frame frameRect: NSRect) {
    visualEffectView = NSVisualEffectView(frame: frameRect)
    super.init(frame: frameRect)
    setupVisualEffectView()
  }
  
  required init?(coder: NSCoder) {
    visualEffectView = NSVisualEffectView()
    super.init(coder: coder)
    setupVisualEffectView()
  }
  
  private func setupVisualEffectView() {
    visualEffectView.material = .hudWindow
    visualEffectView.blendingMode = .behindWindow
    visualEffectView.state = .active
    visualEffectView.autoresizingMask = [.width, .height]
    
    addSubview(visualEffectView)
  }
  
  override func layout() {
    super.layout()
    visualEffectView.frame = bounds
  }
  
  func setMaterial(_ material: NSVisualEffectView.Material) {
    visualEffectView.material = material
  }
}
