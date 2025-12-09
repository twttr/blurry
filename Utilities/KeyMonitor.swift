import Cocoa

class KeyMonitor {
  private var monitor: Any?

  func start(
    keyCode: UInt16,
    modifiers: NSEvent.ModifierFlags = [],
    handler: @escaping () -> Void
  ) {
    stop()

    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      guard event.keyCode == keyCode else { return event }
      if !modifiers.isEmpty {
        let eventMods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard eventMods == modifiers else { return event }
      }
      handler()
      return nil
    }
  }
  
  func stop() {
    if let monitor = monitor {
      NSEvent.removeMonitor(monitor)
      self.monitor = nil
    }
  }
}
