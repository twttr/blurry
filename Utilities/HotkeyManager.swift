import Carbon
import Cocoa

@MainActor
class HotkeyManager {
  static let shared = HotkeyManager()
  
  private var eventHandler: EventHandlerRef?
  private var hotKeyRef: EventHotKeyRef?
  
  var onHotkeyPressed: (() -> Void)?
  
  private init() {}
  
  func registerHotkey() {
    guard eventHandler == nil else { return }
    
    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )
    
    let status = InstallEventHandler(
      GetEventDispatcherTarget(),
      { (_, event, _) -> OSStatus in
        _ = HotkeyManager.shared.handleHotKeyEvent(event)
        return noErr
      },
      1,
      &eventType,
      nil,
      &eventHandler
    )
    
    guard status == noErr else { return }
    
    let hotKeyID = EventHotKeyID(signature: OSType(0x424C5259), id: 1)
    
    RegisterEventHotKey(
      UInt32(kVK_ANSI_B),
      UInt32(cmdKey | shiftKey),
      hotKeyID,
      GetEventDispatcherTarget(),
      0,
      &hotKeyRef
    )
  }
  
  private nonisolated func handleHotKeyEvent(_ event: EventRef?) -> OSStatus {
    Task { @MainActor in
      self.onHotkeyPressed?()
    }
    return noErr
  }
  
  func unregisterHotkey() {
    if let hotKeyRef = hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
      self.hotKeyRef = nil
    }
    if let eventHandler = eventHandler {
      RemoveEventHandler(eventHandler)
      self.eventHandler = nil
    }
  }
  
  func cleanup() {
    unregisterHotkey()
    onHotkeyPressed = nil
  }
}
