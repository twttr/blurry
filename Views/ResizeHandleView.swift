import Cocoa

enum ResizeHandle {
  case topLeft, topRight, bottomLeft, bottomRight
  case top, bottom, left, right

  var cursor: NSCursor {
    switch self {
    case .topLeft, .bottomRight:
      return NSCursor(
        image: NSImage(
          systemSymbolName: "arrow.up.left.and.arrow.down.right",
          accessibilityDescription: nil
        ) ?? NSImage(),
        hotSpot: NSPoint(x: 8, y: 8)
      )
    case .topRight, .bottomLeft:
      return NSCursor(
        image: NSImage(
          systemSymbolName: "arrow.up.right.and.arrow.down.left",
          accessibilityDescription: nil
        ) ?? NSImage(),
        hotSpot: NSPoint(x: 8, y: 8)
      )
    case .top, .bottom:
      return NSCursor.resizeUpDown
    case .left, .right:
      return NSCursor.resizeLeftRight
    }
  }
}

protocol ResizeHandleDelegate: AnyObject {
  func resizeHandleView(_ view: ResizeHandleView, didUpdateFrame frame: CGRect)
  func resizeHandleView(_ view: ResizeHandleView, didExitResizeMode frame: CGRect)
}

class ResizeHandleView: NSView {
  let areaID: UUID
  weak var delegate: ResizeHandleDelegate?

  private let handleSize: CGFloat = 12.0
  private let hitZoneSize: CGFloat = 15.0
  private var activeHandle: ResizeHandle?
  private var dragStartPoint: NSPoint?
  private var initialWindowFrame: CGRect?

  init(frame: NSRect, areaID: UUID) {
    self.areaID = areaID
    super.init(frame: frame)
  }

  required init?(coder: NSCoder) {
    fatalError()
  }

  override var acceptsFirstResponder: Bool {
    return true
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    let borderColor = NSColor.systemBlue.withAlphaComponent(0.6)
    let handleColor = NSColor.systemBlue.withAlphaComponent(0.8)

    borderColor.setStroke()
    let borderPath = NSBezierPath(rect: bounds)
    borderPath.lineWidth = 2.0
    borderPath.stroke()

    for handle in allHandles() {
      let rect = handleRect(for: handle)
      handleColor.setFill()
      let path = NSBezierPath(ovalIn: rect)
      path.fill()

      NSColor.white.setStroke()
      path.lineWidth = 1.0
      path.stroke()
    }
  }

  override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)

    if let handle = detectHandle(at: point) {
      activeHandle = handle
      dragStartPoint = event.locationInWindow
      initialWindowFrame = window?.frame
      handle.cursor.set()
    }
  }

  override func mouseDragged(with event: NSEvent) {
    guard let handle = activeHandle,
          let startPoint = dragStartPoint,
          let initialFrame = initialWindowFrame else { return }

    let currentPoint = event.locationInWindow
    let delta = NSSize(width: currentPoint.x - startPoint.x, height: currentPoint.y - startPoint.y)

    let newFrame = calculateNewFrame(initialFrame: initialFrame, handle: handle, delta: delta)

    delegate?.resizeHandleView(self, didUpdateFrame: newFrame)
  }

  override func mouseUp(with event: NSEvent) {
    guard let handle = activeHandle,
          let startPoint = dragStartPoint,
          let initialFrame = initialWindowFrame else {
      activeHandle = nil
      dragStartPoint = nil
      initialWindowFrame = nil
      return
    }

    let currentPoint = event.locationInWindow
    let delta = NSSize(width: currentPoint.x - startPoint.x, height: currentPoint.y - startPoint.y)

    let finalFrame = calculateNewFrame(initialFrame: initialFrame, handle: handle, delta: delta)

    activeHandle = nil
    dragStartPoint = nil
    initialWindowFrame = nil

    NSCursor.arrow.set()

    delegate?.resizeHandleView(self, didUpdateFrame: finalFrame)
  }

  override func keyDown(with event: NSEvent) {
    let commandShift: NSEvent.ModifierFlags = [.command, .shift]
    let hasCommandShift = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(commandShift)
    let keyCodeB: UInt16 = 11
    let isHotkey = hasCommandShift && event.keyCode == keyCodeB

    if event.keyCode == 53 || isHotkey {
      guard let currentFrame = window?.frame else { return }
      delegate?.resizeHandleView(self, didExitResizeMode: currentFrame)
      if isHotkey {
        DispatchQueue.main.async {
          HotkeyManager.shared.onHotkeyPressed?()
        }
      }
    } else {
      super.keyDown(with: event)
    }
  }

  override func resetCursorRects() {
    super.resetCursorRects()

    for handle in allHandles() {
      let hitZone = hitZoneRect(for: handle)
      addCursorRect(hitZone, cursor: handle.cursor)
    }

    addCursorRect(bounds, cursor: .arrow)
  }

  private func allHandles() -> [ResizeHandle] {
    return [.topLeft, .topRight, .bottomLeft, .bottomRight, .top, .bottom, .left, .right]
  }

  private func handleRect(for handle: ResizeHandle) -> CGRect {
    let center = handleCenter(for: handle)
    return CGRect(
      x: center.x - handleSize / 2,
      y: center.y - handleSize / 2,
      width: handleSize,
      height: handleSize
    )
  }

  private func hitZoneRect(for handle: ResizeHandle) -> CGRect {
    let center = handleCenter(for: handle)
    return CGRect(
      x: center.x - hitZoneSize / 2,
      y: center.y - hitZoneSize / 2,
      width: hitZoneSize,
      height: hitZoneSize
    )
  }

  private func handleCenter(for handle: ResizeHandle) -> CGPoint {
    let w = bounds.width
    let h = bounds.height

    switch handle {
    case .topLeft: return CGPoint(x: 0, y: h)
    case .topRight: return CGPoint(x: w, y: h)
    case .bottomLeft: return CGPoint(x: 0, y: 0)
    case .bottomRight: return CGPoint(x: w, y: 0)
    case .top: return CGPoint(x: w / 2, y: h)
    case .bottom: return CGPoint(x: w / 2, y: 0)
    case .left: return CGPoint(x: 0, y: h / 2)
    case .right: return CGPoint(x: w, y: h / 2)
    }
  }

  private func detectHandle(at point: NSPoint) -> ResizeHandle? {
    for handle in allHandles() {
      let hitZone = hitZoneRect(for: handle)
      if hitZone.contains(point) {
        return handle
      }
    }
    return nil
  }

  private func calculateNewFrame(initialFrame: CGRect, handle: ResizeHandle, delta: NSSize) -> CGRect {
    var newFrame = initialFrame
    let minSize: CGFloat = 50.0

    switch handle {
    case .topLeft:
      newFrame.origin.x += delta.width
      newFrame.size.width -= delta.width
      newFrame.size.height += delta.height

    case .topRight:
      newFrame.size.width += delta.width
      newFrame.size.height += delta.height

    case .bottomLeft:
      newFrame.origin.x += delta.width
      newFrame.origin.y += delta.height
      newFrame.size.width -= delta.width
      newFrame.size.height -= delta.height

    case .bottomRight:
      newFrame.origin.y += delta.height
      newFrame.size.width += delta.width
      newFrame.size.height -= delta.height

    case .top:
      newFrame.size.height += delta.height

    case .bottom:
      newFrame.origin.y += delta.height
      newFrame.size.height -= delta.height

    case .left:
      newFrame.origin.x += delta.width
      newFrame.size.width -= delta.width

    case .right:
      newFrame.size.width += delta.width
    }

    if newFrame.size.width < minSize {
      if handle == .left || handle == .topLeft || handle == .bottomLeft {
        newFrame.origin.x = initialFrame.origin.x + initialFrame.size.width - minSize
      }
      newFrame.size.width = minSize
    }

    if newFrame.size.height < minSize {
      if handle == .bottom || handle == .bottomLeft || handle == .bottomRight {
        newFrame.origin.y = initialFrame.origin.y + initialFrame.size.height - minSize
      }
      newFrame.size.height = minSize
    }

    return newFrame
  }
}
