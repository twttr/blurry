import Cocoa

class HotkeyManager {
  static let shared = HotkeyManager()

  private var keyMonitor = KeyMonitor()
  var onHotkeyPressed: (() -> Void)?

  private init() {}

  func registerHotkey() {
    let options: NSDictionary = [
      kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
    ]
    _ = AXIsProcessTrustedWithOptions(options as CFDictionary)

    keyMonitor.start(
      keyCode: 11,
      modifiers: [.command, .shift],
      scope: .global
    ) { [weak self] in
      self?.onHotkeyPressed?()
    }
  }

  func unregisterHotkey() {
    keyMonitor.stop()
  }

  func cleanup() {
    unregisterHotkey()
    onHotkeyPressed = nil
  }
}
