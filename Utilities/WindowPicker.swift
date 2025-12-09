import Cocoa
import ScreenCaptureKit

struct WindowInfo {
  let id: CGWindowID
  let bounds: CGRect
  let title: String
  let ownerName: String
}

class WindowPicker {
  static func getAvailableWindows() -> [WindowInfo] {
    return WindowEnumerator.getAvailableWindows(filterLevel: .basic)
  }
  
  /// Shows a window selection dialog
  /// - Returns: The selected WindowInfo, or nil if cancelled or no windows available
  static func showWindowSelectionDialog() async -> WindowInfo? {
    let windows = getAvailableWindows()
    
    if windows.isEmpty {
      await NotificationManager.shared.send(
        title: String(localized: "No Windows Available"),
        body: String(localized: "No selectable windows were found.")
      )
      return nil
    }

    let alert = NSAlert()
    alert.messageText = String(localized: "Select Window")
    alert.informativeText = String(localized: "Choose a window to create a blur area:")
    alert.alertStyle = .informational
    
    let popupButton = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 400, height: 25))
    
    for window in windows {
      let displayName: String
      if !window.title.isEmpty {
        displayName = "\(window.ownerName) - \(window.title)"
      } else {
        displayName = window.ownerName
      }
      popupButton.addItem(withTitle: displayName)
    }
    
    alert.accessoryView = popupButton
    alert.addButton(withTitle: String(localized: "Select"))
    alert.addButton(withTitle: String(localized: "Cancel"))
    
    let response = alert.runModal()
    
    if response == .alertFirstButtonReturn {
      let selectedIndex = popupButton.indexOfSelectedItem
      if selectedIndex >= 0 && selectedIndex < windows.count {
        return windows[selectedIndex]
      }
    }
    
    return nil
  }
}
