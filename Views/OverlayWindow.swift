import Cocoa

class OverlayWindow: NSWindow {
  init(frame: CGRect, cornerRadius: Double = 0.0) {
    super.init(
      contentRect: frame,
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )
    
    self.isOpaque = false
    self.backgroundColor = .clear
    self.level = .floating
    self.collectionBehavior = [.stationary, .fullScreenAuxiliary]
    self.ignoresMouseEvents = true
    self.hasShadow = false
    
    self.animationBehavior = .none
    
    setCornerRadius(cornerRadius)
  }
  
  func setCornerRadius(_ radius: Double) {
    if radius > 0 {
      self.contentView?.wantsLayer = true
      self.contentView?.layer?.cornerRadius = radius
      self.contentView?.layer?.masksToBounds = true
    } else {
      self.contentView?.layer?.cornerRadius = 0
      self.contentView?.layer?.masksToBounds = false
    }
  }
  
  override var isReleasedWhenClosed: Bool {
    get { false }
    set { }
  }
  
  override var canBecomeKey: Bool {
    return !ignoresMouseEvents
  }
  
  func setResizeMode(_ enabled: Bool, areaID: UUID, delegate: (any ResizeHandleDelegate)?) {
    if enabled {
      ignoresMouseEvents = false
      let handleView = ResizeHandleView(frame: contentView?.bounds ?? .zero, areaID: areaID)
      handleView.delegate = delegate
      handleView.autoresizingMask = [.width, .height]
      contentView?.addSubview(handleView, positioned: .above, relativeTo: nil)
      makeKeyAndOrderFront(nil)
      makeFirstResponder(handleView)
    } else {
      ignoresMouseEvents = true
      contentView?.subviews.forEach { subview in
        if subview is ResizeHandleView {
          subview.removeFromSuperview()
        }
      }
    }
  }
}
