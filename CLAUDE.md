# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Blurry is a macOS menu bar utility application that allows users to create blur, darken, or picture overlay effects on specific screen areas. The app runs as an accessory application (no dock icon) and provides persistent overlays across multiple displays and workspaces.

**Technology Stack:**
- macOS 12+ target
- Swift with Cocoa (NSWindow, NSStatusBar, CALayer)
- SwiftUI (minimal - Settings scene only)
- Combine framework for reactive data flow
- Core Graphics for display and window management

## Build Commands

```bash
# Build the application
xcodebuild -scheme Blurry -configuration Debug build

# Clean build artifacts
xcodebuild -scheme Blurry clean

# Build for release
xcodebuild -scheme Blurry -configuration Release build
```

**Running the app:** Open `Blurry.xcodeproj` in Xcode and press Cmd+R, or build and run the resulting `.app` bundle.

**Note:** No test suite currently exists in this project.

## Architecture Overview

### Singleton Coordination Pattern
The application uses multiple singleton managers that coordinate with each other:
- **AreaManager**: Source of truth for all blur areas, uses `@Published` for reactive updates
- **OverlayWindowManager**: Creates and destroys overlay windows based on AreaManager state
- **HotkeyManager**: Handles global hotkey (Cmd+Shift+B)
- **DisplayManager**: Monitors display configuration changes
- **MouseTracker**: Provides hover detection for "disable on hover" feature

### Reactive Data Flow
```
AreaManager (@Published areas)
    ↓ (Combine .sink)
StatusBarController (rebuilds menus)
    ↓
OverlayWindowManager (creates/destroys windows)
```

### Application Lifecycle
1. **BlurryApp** (SwiftUI entry point) sets `NSApplicationDelegateAdaptor` to AppDelegate
2. **AppDelegate.applicationDidFinishLaunching**:
   - Configures app as accessory (menu bar only)
   - Loads saved areas from UserDefaults
   - Initializes StatusBarController (creates menu bar item)
   - Registers global hotkey
   - Starts display monitoring
3. **AppDelegate.restoreBlurAreas()** recreates overlay windows for all enabled areas

### Custom Codable Implementation
**BlurArea** implements custom encoding/decoding because `CGRect` is not directly Codable. The model uses `CodingKeys` enum to serialize rectangles as separate origin and size components, then persists to UserDefaults as JSON.

### Floating Window System
Overlay windows use `NSWindow.Level.floating` and `.canJoinAllSpaces` collection behavior to:
- Appear above most other windows
- Persist across all Spaces/Desktops
- Remain visible during app switching

## Core Component Interactions

### Area Creation Workflow
1. User selects effect type from StatusBar menu
2. **AreaSelectionController** displays full-screen overlay on all displays
3. User draws rectangle via mouse drag
4. Controller prompts for area name
5. New **BlurArea** added to **AreaManager**
6. **AreaManager** publishes change
7. **StatusBarController** observes change and rebuilds menu
8. **OverlayWindowManager** creates new overlay window with appropriate effect view
9. **AreaManager** persists to UserDefaults

### Display Change Handling
- **DisplayManager** monitors `NSApplication.didChangeScreenParametersNotification`
- When display disconnects: Disables all areas associated with that display ID
- Shows alert to user about affected areas
- On reconnect: Areas remain disabled (user must manually re-enable)

### Mouse Hover Behavior
- When "disableOnHover" is enabled for an area:
  - **MouseTracker** uses `NSEvent.addGlobalMonitorForEvents` to track mouse position
  - On mouse enter: Animates window alpha to 0.0 (0.15s duration)
  - On mouse exit: Animates window alpha to 1.0 (0.15s duration)
- Global monitoring is necessary because overlays are separate windows

### Data Persistence
- **Storage**: UserDefaults with key "SavedAreas"
- **Format**: JSON-encoded array of BlurArea objects
- **Restoration**: On launch, all previously enabled areas are recreated
- **Save Trigger**: Automatic on any area addition, removal, or modification

## Key Implementation Details

### Entitlements
The app is sandboxed with these entitlements (Blurry.entitlements):
- `com.apple.security.app-sandbox`: true
- `com.apple.security.files.user-selected.read-write`: true (for picture effect image selection)

### Accessory App Configuration
- App runs without dock icon (LSUIElement behavior)
- Only visible via menu bar status item
- Configured in AppDelegate: `NSApp.setActivationPolicy(.accessory)`

### Global Hotkey
- **Shortcut**: Cmd+Shift+B
- **Action**: Toggles all areas enabled/disabled
- **Implementation**: `NSEvent.addLocalMonitorForEvents(matching: .keyDown)`

### Effect View Implementations
- **BlurEffectView**: Wraps `NSVisualEffectView` with material mapping (.sidebar → 10px blur, .menu → 30px, .hudWindow → other)
- **DarkenEffectView**: Uses `CALayer` with black background and configurable opacity
- **PictureEffectView**: Uses `NSImageView` with aspect-fit scaling

### Multi-Display Support
Each **BlurArea** stores:
- `displayID`: UUID of the display it belongs to
- `screenFrame`: Full screen frame at creation time for coordinate validation

## Critical Files

| File | Lines | Purpose |
|------|-------|---------|
| **AppDelegate.swift** | - | App lifecycle orchestration, initialization sequence, area restoration |
| **StatusBarController.swift** | 994 | Menu bar UI, all user interactions, menu building logic |
| **AreaManager.swift** | - | Central data model, Combine publishing, UserDefaults persistence |
| **OverlayWindowManager.swift** | - | Window lifecycle (create/destroy/update), singleton window registry |
| **BlurArea.swift** | - | Core model with custom Codable for CGRect serialization |
| **AreaSelectionController.swift** | - | Interactive rectangle selection UI with mouse tracking |
| **HotkeyManager.swift** | - | Global keyboard shortcut registration and handling |
| **DisplayManager.swift** | - | Screen configuration monitoring, display disconnect detection |

## Project Structure

```
/
├── AppDelegate.swift              # App initialization and lifecycle
├── BlurryApp.swift                # SwiftUI entry point
├── Controllers/
│   ├── StatusBarController.swift     # Menu bar UI (994 lines)
│   ├── AreaSelectionController.swift # Area selection modal
│   └── OverlayWindowManager.swift    # Window management singleton
├── Models/
│   ├── BlurArea.swift             # Core model (custom Codable)
│   ├── AreaManager.swift          # Data manager (Combine)
│   ├── EffectType.swift           # Enum: blur/darken/picture
│   └── EffectParameters.swift     # Effect configuration
├── Views/
│   ├── OverlayWindow.swift        # Custom NSWindow
│   └── EffectViews/
│       ├── BlurEffectView.swift
│       ├── DarkenEffectView.swift
│       └── PictureEffectView.swift
└── Utilities/
    ├── HotkeyManager.swift        # Cmd+Shift+B handling
    ├── DisplayManager.swift       # Display monitoring
    ├── MouseTracker.swift         # Hover detection
    ├── WindowPicker.swift         # CGWindowList integration
    └── VisualWindowPicker.swift   # Visual window selection
```
