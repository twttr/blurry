import Cocoa

@MainActor
class AreaSelectionController {
  private var overlayWindows: [NSWindow] = []
  private var overlayViews: [OverlayView] = []
  private var keyMonitor = KeyMonitor()
  private var currentOnCancel: (() -> Void)?
  
  /// Begins interactive area selection with async/await
  /// - Returns: A tuple containing the selected rect and user-provided name, or nil if cancelled
  func beginSelection() async -> (rect: CGRect, name: String)? {
    return await withCheckedContinuation { continuation in
      showOverlay { rect, name in
        continuation.resume(returning: (rect, name))
      } onCancel: {
        continuation.resume(returning: nil)
      }
    }
  }
  
  /// Begins interactive area reselection with async/await
  /// - Parameter existingArea: The area being resized
  /// - Returns: The new rect, or nil if cancelled
  func beginReselection(existingArea: BlurArea) async -> CGRect? {
    return await withCheckedContinuation { continuation in
      showOverlay(existingArea: existingArea) { rect, _ in
        continuation.resume(returning: rect)
      } onCancel: {
        continuation.resume(returning: nil)
      }
    }
  }
  
  private func showOverlay(
    existingArea: BlurArea? = nil,
    onComplete: @escaping (CGRect, String) -> Void,
    onCancel: @escaping () -> Void
  ) {
    currentOnCancel = onCancel
    keyMonitor.start(keyCode: 53) { [weak self] in
      self?.handleEscPressed()
    }

    for screen in NSScreen.screens {
      let window = SelectionOverlayWindow(
        contentRect: screen.frame,
        styleMask: [.borderless, .fullSizeContentView],
        backing: .buffered,
        defer: false
      )
      
      window.backgroundColor = .clear
      window.isOpaque = false
      window.hasShadow = false
      window.level = .floating
      window.ignoresMouseEvents = false
      window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
      
      let view = OverlayView(
        frame: screen.frame,
        existingArea: existingArea,
        onComplete: onComplete,
        onCancel: onCancel
      )
      view.controller = self
      window.contentView = view
      
      overlayWindows.append(window)
      overlayViews.append(view)
      
      window.makeKeyAndOrderFront(nil)
      window.makeFirstResponder(view)
    }
    
    NSCursor.crosshair.set()
  }
  
  func closeOverlay() {
    keyMonitor.stop()
    NSCursor.arrow.set()

    for window in overlayWindows {
      window.orderOut(nil)
    }

    overlayWindows.removeAll()
    overlayViews.removeAll()
    currentOnCancel = nil
  }

  private func handleEscPressed() {
    if let onCancel = currentOnCancel {
      handleCancel(onCancel)
    }
  }
  
  func handleSelection(_ rect: CGRect, isReselection: Bool, onComplete: @escaping (CGRect, String) -> Void) {
    closeOverlay()
    
    if isReselection {
      onComplete(rect, "")
    } else {
      showNamingDialog(for: rect, onComplete: onComplete)
    }
  }
  
  func handleCancel(_ onCancel: @escaping () -> Void) {
    closeOverlay()
    onCancel()
  }
  
  private func showNamingDialog(for rect: CGRect, onComplete: @escaping (CGRect, String) -> Void) {
    let alert = NSAlert()
    alert.messageText = String(localized: "Name This Area")
    alert.informativeText = String(localized: "Enter a name for the selected area:")
    alert.alertStyle = .informational

    let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
    textField.placeholderString = String(localized: "e.g., Chat Window")
    let randomNumber = Int.random(in: 1...999)
    textField.stringValue = String(localized: "Area \(randomNumber)")
    alert.accessoryView = textField

    alert.addButton(withTitle: String(localized: "OK"))
    alert.addButton(withTitle: String(localized: "Cancel"))
    
    let response = alert.runModal()
    
    let shouldCallHandler = response == .alertFirstButtonReturn
    let name = shouldCallHandler ? textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) : ""
    
    DispatchQueue.main.async {
      if shouldCallHandler && !name.isEmpty {
        onComplete(rect, name)
      }
    }
  }
}

private class OverlayView: NSView {
  weak var controller: AreaSelectionController?
  private var startPoint: NSPoint?
  private var currentPoint: NSPoint?
  private var existingArea: BlurArea?
  private var onComplete: ((CGRect, String) -> Void)?
  private var onCancel: (() -> Void)?
  
  init(
    frame frameRect: NSRect,
    existingArea: BlurArea? = nil,
    onComplete: @escaping (CGRect, String) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.existingArea = existingArea
    self.onComplete = onComplete
    self.onCancel = onCancel
    super.init(frame: frameRect)
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override var acceptsFirstResponder: Bool {
    return true
  }
  
  override func resetCursorRects() {
    addCursorRect(bounds, cursor: .crosshair)
  }

  override func mouseDown(with event: NSEvent) {
    startPoint = convert(event.locationInWindow, from: nil)
    currentPoint = startPoint
    needsDisplay = true
  }
  
  override func mouseDragged(with event: NSEvent) {
    currentPoint = convert(event.locationInWindow, from: nil)
    needsDisplay = true
  }
  
  override func mouseUp(with event: NSEvent) {
    guard let start = startPoint, let end = currentPoint else {
      if let onCancel = onCancel {
        controller?.handleCancel(onCancel)
      }
      return
    }
    
    let minX = min(start.x, end.x)
    let minY = min(start.y, end.y)
    let width = abs(end.x - start.x)
    let height = abs(end.y - start.y)
    
    let windowLocalRect = CGRect(x: minX, y: minY, width: width, height: height)
    
    let screenRect: CGRect
    if let windowFrame = window?.frame {
      screenRect = CGRect(
        x: windowLocalRect.origin.x + windowFrame.origin.x,
        y: windowLocalRect.origin.y + windowFrame.origin.y,
        width: windowLocalRect.width,
        height: windowLocalRect.height
      )
    } else {
      screenRect = windowLocalRect
    }
    
    startPoint = nil
    currentPoint = nil
    
    if width > 10 && height > 10 {
      if let onComplete = onComplete {
        let isReselection = existingArea != nil
        controller?.handleSelection(screenRect, isReselection: isReselection, onComplete: onComplete)
      }
    } else {
      if let onCancel = onCancel {
        controller?.handleCancel(onCancel)
      }
    }
  }
  
  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    
    if let existingArea = existingArea {
      let existingRect = existingArea.frame
      NSColor.systemOrange.withAlphaComponent(0.3).setFill()
      existingRect.fill()
      
      NSColor.systemOrange.setStroke()
      let existingPath = NSBezierPath(rect: existingRect)
      existingPath.lineWidth = 2.0
      existingPath.stroke()
    }
    
    if let start = startPoint, let end = currentPoint {
      let minX = min(start.x, end.x)
      let minY = min(start.y, end.y)
      let width = abs(end.x - start.x)
      let height = abs(end.y - start.y)
      
      let rect = NSRect(x: minX, y: minY, width: width, height: height)
      
      NSColor.systemBlue.withAlphaComponent(0.3).setFill()
      rect.fill()
      
      NSColor.systemBlue.setStroke()
      let path = NSBezierPath(rect: rect)
      path.lineWidth = 2.0
      path.stroke()
    }
  }
}

private class SelectionOverlayWindow: NSWindow {
  override var canBecomeKey: Bool {
    return true
  }
  
  override var canBecomeMain: Bool {
    return true
  }
  
  override var animationBehavior: NSWindow.AnimationBehavior {
    get { .none }
    set { }
  }
  
  override var isReleasedWhenClosed: Bool {
    get { false }
    set { }
  }
}
