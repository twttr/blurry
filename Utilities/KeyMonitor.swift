import Cocoa

class KeyMonitor {
  enum Scope {
    case local
    case global
  }

  private var monitor: Any?

  func start(
    keyCode: UInt16,
    modifiers: NSEvent.ModifierFlags = [],
    scope: Scope = .local,
    handler: @escaping () -> Void
  ) {
    stop()

    let matcher: (NSEvent) -> Bool = { event in
      guard event.keyCode == keyCode else { return false }
      if modifiers.isEmpty { return true }
      let eventMods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
      return eventMods == modifiers
    }

    switch scope {
    case .local:
      monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
        if matcher(event) {
          handler()
          return nil
        }
        return event
      }
    case .global:
      monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
        if matcher(event) {
          handler()
        }
      }
    }
  }

  func stop() {
    if let monitor = monitor {
      NSEvent.removeMonitor(monitor)
      self.monitor = nil
    }
  }
}
