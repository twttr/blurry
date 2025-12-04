import Cocoa

class HotkeyManager {
  static let shared = HotkeyManager()

  private var globalMonitor: Any?
  private var localMonitor: Any?
  var onHotkeyPressed: (() -> Void)?

  private init() {}

  func registerHotkey() {
    let options: NSDictionary = [
      kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
    ]
    _ = AXIsProcessTrustedWithOptions(options as CFDictionary)

    globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
      if self?.isHotkeyPressed(event) == true {
        self?.onHotkeyPressed?()
      }
    }
  }


  func unregisterHotkey() {
    if let monitor = globalMonitor {
      NSEvent.removeMonitor(monitor)
      globalMonitor = nil
    }
  }

  /// Cleanup all resources - should be called on app termination
  func cleanup() {
    unregisterHotkey()
    onHotkeyPressed = nil
  }

  private func isHotkeyPressed(_ event: NSEvent) -> Bool {
    let commandShift: NSEvent.ModifierFlags = [.command, .shift]
    let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    let modifiersMatch = modifiers == commandShift
    let keyCodeB: UInt16 = 11
    return modifiersMatch && event.keyCode == keyCodeB
  }
}
