import Cocoa

/// Consolidated window enumeration logic with configurable filtering levels
enum WindowEnumerator {
  /// Filtering strictness level
  enum FilterLevel {
    case basic
    case strict
  }
  
  /// Known overlay apps to skip in strict mode
  private static let overlayApps = ["Magnet", "Rectangle", "BetterSnapTool", "LanguageTool for Desktop"]
  
  /// Get available windows with specified filtering level
  /// - Parameter filterLevel: The filtering strictness to apply
  /// - Returns: Array of WindowInfo objects for available windows
  static func getAvailableWindows(filterLevel: FilterLevel = .basic) -> [WindowInfo] {
    guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
      return []
    }
    
    var windows: [WindowInfo] = []
    
    let primaryDisplayBounds = CGDisplayBounds(CGMainDisplayID())
    let screenHeight = primaryDisplayBounds.height
    let screenWidth = primaryDisplayBounds.width
    
    for windowDict in windowList {
      guard let boundsDict = windowDict[kCGWindowBounds as String] as? [String: Any],
            let cgX = boundsDict["X"] as? CGFloat,
            let cgY = boundsDict["Y"] as? CGFloat,
            let width = boundsDict["Width"] as? CGFloat,
            let height = boundsDict["Height"] as? CGFloat,
            let windowID = windowDict[kCGWindowNumber as String] as? CGWindowID,
            let ownerName = windowDict[kCGWindowOwnerName as String] as? String else {
        continue
      }
      
      if width < 50 || height < 50 {
        continue
      }
      
      if ownerName == "Blurry" {
        continue
      }
      
      let title = windowDict[kCGWindowName as String] as? String ?? ""
      
      if filterLevel == .strict {
        if overlayApps.contains(ownerName) {
          continue
        }
        
        if cgX == 0 && cgY == 0 && width >= screenWidth - 10 && height >= screenHeight - 50 {
          if title.isEmpty || title.contains("Overlay") {
            continue
          }
        }
      }
      
      let screenY = screenHeight - cgY - height
      let bounds = CGRect(x: cgX, y: screenY, width: width, height: height)
      
      windows.append(WindowInfo(
        id: windowID,
        bounds: bounds,
        title: title,
        ownerName: ownerName
      ))
    }
    
    return windows
  }
}
