import Cocoa

class VisualWindowPicker: NSObject {
  private var overlayWindow: NSWindow?
  private var highlightWindow: NSWindow?
  private var trackingArea: NSTrackingArea?
  private var currentWindows: [WindowInfo] = []
  
  /// Interactively pick a window with visual feedback
  /// - Returns: The selected WindowInfo, or nil if cancelled
  func pickWindow() async -> WindowInfo? {
    self.currentWindows = getAvailableWindows()
    
    if currentWindows.isEmpty {
      let alert = NSAlert()
      alert.messageText = String(localized: "No Windows Available")
      alert.informativeText = String(localized: "No selectable windows were found.")
      alert.alertStyle = .informational
      alert.addButton(withTitle: String(localized: "OK"))
      alert.runModal()
      return nil
    }
    
    return await withCheckedContinuation { continuation in
      showOverlay { windowInfo in
        continuation.resume(returning: windowInfo)
      }
    }
  }
  
  private func showOverlay(completion: @escaping (WindowInfo?) -> Void) {
    guard let screen = NSScreen.main else {
      completion(nil)
      return
    }
    
    let window = NSWindow(
      contentRect: screen.frame,
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )
    window.backgroundColor = .clear
    window.isOpaque = false
    window.level = .screenSaver
    window.ignoresMouseEvents = false
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    
    let view = PickerOverlayView(frame: screen.frame, completion: completion)
    view.picker = self
    window.contentView = view
    
    overlayWindow = window
    window.makeKeyAndOrderFront(nil)
    
    NSCursor.pointingHand.set()
  }
  
  func handleMouseMove(at location: NSPoint) {
    if let windowInfo = findWindowAt(location) {
      showHighlight(for: windowInfo)
    } else {
      hideHighlight()
    }
  }
  
  func handleClick(at location: NSPoint, completion: @escaping (WindowInfo?) -> Void) {
    if let windowInfo = findWindowAt(location) {
      cleanup()
      completion(windowInfo)
    }
  }
  
  func handleRightClick(completion: @escaping (WindowInfo?) -> Void) {
    cleanup()
    completion(nil)
  }
  
  private func findWindowAt(_ point: NSPoint) -> WindowInfo? {
    for window in currentWindows {
      if window.bounds.contains(point) {
        return window
      }
    }
    return nil
  }
  
  private func showHighlight(for windowInfo: WindowInfo) {
    if highlightWindow == nil {
      let window = NSWindow(
        contentRect: windowInfo.bounds,
        styleMask: .borderless,
        backing: .buffered,
        defer: false
      )
      window.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.2)
      window.isOpaque = false
      window.level = .screenSaver - 1
      window.ignoresMouseEvents = true
      window.hasShadow = false
      
      window.contentView?.wantsLayer = true
      window.contentView?.layer?.borderColor = NSColor.systemBlue.cgColor
      window.contentView?.layer?.borderWidth = 3
      window.contentView?.layer?.cornerRadius = 8
      
      highlightWindow = window
      window.orderFront(nil)
    } else {
      highlightWindow?.setFrame(windowInfo.bounds, display: true, animate: false)
    }
  }
  
  private func hideHighlight() {
    highlightWindow?.orderOut(nil)
    highlightWindow = nil
  }
  
  private func cleanup() {
    NSCursor.arrow.set()
    overlayWindow?.orderOut(nil)
    overlayWindow = nil
    hideHighlight()
  }
  
  private func getAvailableWindows() -> [WindowInfo] {
    return WindowEnumerator.getAvailableWindows(filterLevel: .strict)
  }
}

class PickerOverlayView: NSView {
  weak var picker: VisualWindowPicker?
  private var completion: ((WindowInfo?) -> Void)?
  
  init(frame frameRect: NSRect, completion: @escaping (WindowInfo?) -> Void) {
    self.completion = completion
    super.init(frame: frameRect)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    
    if let existing = trackingAreas.first {
      removeTrackingArea(existing)
    }
    
    let trackingArea = NSTrackingArea(
      rect: bounds,
      options: [.activeAlways, .mouseMoved, .inVisibleRect],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(trackingArea)
  }
  
  override func mouseMoved(with event: NSEvent) {
    let location = event.locationInWindow
    picker?.handleMouseMove(at: location)
  }
  
  override func mouseDown(with event: NSEvent) {
    let location = event.locationInWindow
    if let completion = completion {
      picker?.handleClick(at: location, completion: completion)
    }
  }
  
  override func rightMouseDown(with event: NSEvent) {
    if let completion = completion {
      picker?.handleRightClick(completion: completion)
    }
  }
  
  override var acceptsFirstResponder: Bool { true }
  
  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 {
      if let completion = completion {
        picker?.handleRightClick(completion: completion)
      }
    }
  }
}
