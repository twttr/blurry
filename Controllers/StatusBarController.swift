import Cocoa
import Combine

@MainActor
class StatusBarController: NSObject, AreaMenuDelegate, ConfigurationManagerDelegate, ResizeHandleDelegate, NSMenuDelegate {
  private var statusItem: NSStatusItem!
  private var cancellables = Set<AnyCancellable>()
  private var currentSelectionController: AreaSelectionController?
  private var currentWindowPicker: VisualWindowPicker?
  private var areaManager: AreaManager
  private var menuBuilder: AreaMenuBuilder!
  private var parameterManager: EffectParameterManager!
  private var configurationManager: ConfigurationManager!
  private var preScreenShareEnabledStates: [UUID: Bool]?

  init(areaManager: AreaManager) {
    self.areaManager = areaManager
    super.init()
    commonInit()
  }

  private func commonInit() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem.isVisible = true

    if let button = statusItem.button {
      if let image = NSImage(systemSymbolName: "eye.trianglebadge.exclamationmark", accessibilityDescription: String(localized: "Blurry")) {
        image.isTemplate = true
        button.image = image
      } else {
        button.title = "Blurry"
      }
    }

    menuBuilder = AreaMenuBuilder(areaManager: areaManager, delegate: self)
    parameterManager = EffectParameterManager(areaManager: areaManager)
    configurationManager = ConfigurationManager(areaManager: areaManager, delegate: self)
    setupMenu()
    observeAreaChanges()
    setupMouseTrackingCallbacks()

    HotkeyManager.shared.onHotkeyPressed = { [weak self] in
      self?.toggleAllAreas()
    }

    initializeDisableTracking()
#if DIRECT
    setupScreenCaptureMonitoring()
#endif
  }
  
  private func setupMouseTrackingCallbacks() {
    MouseTracker.shared.onMouseEnter = { [weak self] areaID in
      self?.handleMouseEnterArea(areaID)
    }
    
    MouseTracker.shared.onMouseExit = { [weak self] areaID in
      self?.handleMouseExitArea(areaID)
    }
  }
  
  private func initializeDisableTracking() {
    for area in areaManager.areas {
      if area.disableOnHover && area.isEnabled {
        MouseTracker.shared.startTracking(area: area)
      }
    }
  }
  
#if DIRECT
  private func setupScreenCaptureMonitoring() {
    guard UserDefaults.standard.bool(forKey: "AutoBlurOnScreenShare") else { return }
    
    ScreenCaptureMonitor.shared.onCaptureStateChanged = { [weak self] isCapturing in
      if isCapturing {
        self?.handleScreenShareStarted()
      } else {
        self?.handleScreenShareEnded()
      }
    }
    ScreenCaptureMonitor.shared.startMonitoring()
  }
#endif
  
  private func handleScreenShareStarted() {
    preScreenShareEnabledStates = Dictionary(
      uniqueKeysWithValues: areaManager.areas.map { ($0.id, $0.isEnabled) }
    )
    enableAllAreas()
    MouseTracker.shared.stopAllTracking()
  }
  
  private func handleScreenShareEnded() {
    guard let savedStates = preScreenShareEnabledStates else { return }
    for area in areaManager.areas {
      let wasEnabled = savedStates[area.id] ?? false
      if area.isEnabled != wasEnabled {
        areaManager.toggleEnabled(for: area.id)
        if let updatedArea = areaManager.areas.first(where: { $0.id == area.id }) {
          OverlayWindowManager.shared.updateWindow(for: updatedArea)
        }
      }
    }
    
    for area in areaManager.areas where area.disableOnHover && area.isEnabled {
      MouseTracker.shared.startTracking(area: area)
    }
    
    preScreenShareEnabledStates = nil
  }
  
#if DIRECT
  func updateScreenCaptureMonitoring() {
    if UserDefaults.standard.bool(forKey: "AutoBlurOnScreenShare") {
      ScreenCaptureMonitor.shared.onCaptureStateChanged = { [weak self] isCapturing in
        if isCapturing {
          self?.handleScreenShareStarted()
        } else {
          self?.handleScreenShareEnded()
        }
      }
      ScreenCaptureMonitor.shared.startMonitoring()
    } else {
      ScreenCaptureMonitor.shared.stopMonitoring()
      ScreenCaptureMonitor.shared.onCaptureStateChanged = nil
      if preScreenShareEnabledStates != nil {
        handleScreenShareEnded()
      }
    }
  }
#endif
  
  private func handleMouseEnterArea(_ areaID: UUID) {
    guard let window = OverlayWindowManager.shared.getWindow(for: areaID) else { return }
    guard let area = areaManager.areas.first(where: { $0.id == areaID }),
          area.isEnabled else { return }
    
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.15
      window.animator().alphaValue = 0.0
    }
  }
  
  private func handleMouseExitArea(_ areaID: UUID) {
    guard let window = OverlayWindowManager.shared.getWindow(for: areaID) else { return }
    guard let area = areaManager.areas.first(where: { $0.id == areaID }),
          area.isEnabled else { return }
    
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.15
      window.animator().alphaValue = 1.0
    }
  }
  
  private func observeAreaChanges() {
    areaManager.$areas
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.setupMenu()
      }
      .store(in: &cancellables)
  }
  
  private func setupMenu() {
    let menu = menuBuilder.buildMainMenu()
    menu.delegate = self
    statusItem.menu = menu
  }
  
  // MARK: - AreaMenuDelegate Implementation
  
  @objc func addBlurArea() {
    let controller = AreaSelectionController()
    currentSelectionController = controller
    
    Task { [weak self] in
      if let result = await controller.beginSelection() {
        self?.createBlurArea(rect: result.rect, name: result.name)
        self?.currentSelectionController = nil
      } else {
        self?.currentSelectionController = nil
      }
    }
  }
  
  @objc func addDarkenArea() {
    let controller = AreaSelectionController()
    currentSelectionController = controller
    
    Task { [weak self] in
      if let result = await controller.beginSelection() {
        self?.createDarkenArea(rect: result.rect, name: result.name)
        self?.currentSelectionController = nil
      } else {
        self?.currentSelectionController = nil
      }
    }
  }
  
  @objc func addAreaFromWindow() {
    let picker = VisualWindowPicker()
    currentWindowPicker = picker
    
    Task { [weak self] in
      guard let windowInfo = await picker.pickWindow() else {
        self?.currentWindowPicker = nil
        return
      }
      
      let alert = NSAlert()
      alert.messageText = String(localized: "Name Your Area")
      alert.informativeText = String(localized: "Enter a name for this blur area:")
      alert.alertStyle = .informational
      
      let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
      inputTextField.placeholderString = windowInfo.title.isEmpty ? windowInfo.ownerName : windowInfo.title
      inputTextField.stringValue = windowInfo.title.isEmpty ? windowInfo.ownerName : windowInfo.title
      alert.accessoryView = inputTextField
      
      alert.addButton(withTitle: String(localized: "Create"))
      alert.addButton(withTitle: String(localized: "Cancel"))
      
      alert.window.initialFirstResponder = inputTextField
      
      let response = alert.runModal()
      
      if response == .alertFirstButtonReturn {
        let areaName = inputTextField.stringValue.isEmpty ? String(localized: "Untitled Area") : inputTextField.stringValue
        self?.createBlurArea(rect: windowInfo.bounds, name: areaName)
      }
      
      self?.currentWindowPicker = nil
    }
  }
  
  private func createBlurArea(rect: CGRect, name: String) {
    let displayID = DisplayManager.shared.getCurrentDisplayID(for: rect.origin)
    
    var area = BlurArea(
      name: name,
      frame: rect,
      effectType: .blur(radius: 20.0)
    )
    area.displayID = displayID
    
    if let displayID = displayID {
      area.displayUUID = DisplayManager.shared.getDisplayUUID(for: displayID)
      
      if let screen = DisplayManager.shared.getScreen(for: displayID) {
        area.displayRelativeFrame = area.makeDisplayRelative(screen: screen)
      }
    }
    
    areaManager.add(area)
    
    guard let window = OverlayWindowManager.shared.createWindow(for: area) else { return }
    
    let localBounds = CGRect(origin: .zero, size: area.frame.size)
    if let effectView = EffectViewFactory.createView(for: area, in: localBounds) {
      window.contentView?.addSubview(effectView)
      window.orderFront(nil)
    }
  }
  
  private func createDarkenArea(rect: CGRect, name: String) {
    let displayID = DisplayManager.shared.getCurrentDisplayID(for: rect.origin)
    
    var area = BlurArea(
      name: name,
      frame: rect,
      effectType: .darken(amount: 0.5)
    )
    area.displayID = displayID
    
    if let displayID = displayID {
      area.displayUUID = DisplayManager.shared.getDisplayUUID(for: displayID)
      
      if let screen = DisplayManager.shared.getScreen(for: displayID) {
        area.displayRelativeFrame = area.makeDisplayRelative(screen: screen)
      }
    }
    
    areaManager.add(area)
    
    guard let window = OverlayWindowManager.shared.createWindow(for: area) else { return }
    
    let localBounds = CGRect(origin: .zero, size: area.frame.size)
    if let effectView = EffectViewFactory.createView(for: area, in: localBounds) {
      window.contentView?.addSubview(effectView)
      window.orderFront(nil)
    }
    
  }
  
  @objc func toggleAreaEnabled(_ sender: NSMenuItem) {
    guard let areaID = sender.representedObject as? UUID else { return }
    areaManager.toggleEnabled(for: areaID)
    
    if let area = areaManager.areas.first(where: { $0.id == areaID }) {
      OverlayWindowManager.shared.updateWindow(for: area)
      
      if area.disableOnHover {
        if area.isEnabled {
          MouseTracker.shared.startTracking(area: area)
        } else {
          MouseTracker.shared.stopTracking(areaID: areaID)
        }
      }
    }
  }
  
  @objc func toggleDisable(_ sender: NSMenuItem) {
    guard let areaID = sender.representedObject as? UUID else { return }
    
    guard var area = areaManager.areas.first(where: { $0.id == areaID }) else { return }
    area.disableOnHover.toggle()
    areaManager.update(area)
    
    if area.disableOnHover && area.isEnabled {
      MouseTracker.shared.startTracking(area: area)
    } else {
      MouseTracker.shared.stopTracking(areaID: areaID)
      if let window = OverlayWindowManager.shared.getWindow(for: areaID) {
        window.alphaValue = 1.0
      }
    }
  }
  
  @objc func resizeArea(_ sender: NSMenuItem) {
    guard let areaID = sender.representedObject as? UUID else { return }
    guard let area = areaManager.areas.first(where: { $0.id == areaID }) else { return }
    
    if area.disableOnHover {
      MouseTracker.shared.stopTracking(areaID: areaID)
    }
    
    OverlayWindowManager.shared.disableAllResizeModes()
    OverlayWindowManager.shared.enableResizeMode(for: areaID, delegate: self)
  }
  
  @objc func removeArea(_ sender: NSMenuItem) {
    guard let areaID = sender.representedObject as? UUID else { return }
    
    MouseTracker.shared.stopTracking(areaID: areaID)
    
    OverlayWindowManager.shared.removeWindow(for: areaID)
    areaManager.remove(withID: areaID)
  }
  
  @objc func quit() {
    NSApplication.shared.terminate(nil)
  }
  
  // MARK: - Resize Area Management
  
  /// Updates the frame of an existing area and repositions its window
  private func updateAreaFrame(areaID: UUID, newFrame: CGRect) {
    guard let areaIndex = areaManager.areas.firstIndex(where: { $0.id == areaID }) else {
      return
    }
    
    var area = areaManager.areas[areaIndex]
    area.frame = newFrame
    
    if let displayID = area.displayID,
       let screen = DisplayManager.shared.getScreen(for: displayID) {
      area.displayRelativeFrame = area.makeDisplayRelative(screen: screen)
    }
    
    areaManager.update(area)
    
    guard let window = OverlayWindowManager.shared.getWindow(for: areaID) else {
      return
    }
    
    window.setFrame(newFrame, display: true)
    
    window.contentView?.frame = NSRect(origin: .zero, size: newFrame.size)
    
    window.contentView?.subviews.forEach { $0.removeFromSuperview() }
    
    let localBounds = CGRect(origin: .zero, size: newFrame.size)
    if let effectView = EffectViewFactory.createView(for: area, in: localBounds) {
      window.contentView?.addSubview(effectView)
    }
    
    setupMenu()
  }
  
  // MARK: - Enable/Disable All Areas
  
  private func enableAllAreas() {
    for area in areaManager.areas {
      if !area.isEnabled {
        areaManager.toggleEnabled(for: area.id)
        if let updatedArea = areaManager.areas.first(where: { $0.id == area.id }) {
          OverlayWindowManager.shared.updateWindow(for: updatedArea)
          
          if updatedArea.disableOnHover {
            MouseTracker.shared.startTracking(area: updatedArea)
          }
        }
      }
    }
  }
  
  private func disableAllAreas() {
    for area in areaManager.areas {
      if area.isEnabled {
        if area.disableOnHover {
          MouseTracker.shared.stopTracking(areaID: area.id)
        }
        
        areaManager.toggleEnabled(for: area.id)
        if let updatedArea = areaManager.areas.first(where: { $0.id == area.id }) {
          OverlayWindowManager.shared.updateWindow(for: updatedArea)
        }
      }
    }
  }
  
  @objc func toggleAllAreas() {
    let anyEnabled = areaManager.areas.contains { $0.isEnabled }
    if anyEnabled {
      disableAllAreas()
    } else {
      enableAllAreas()
    }
  }
  
  // MARK: - Change Effect Management
  
  /// Creates a submenu for changing the effect type of an existing area
  /// Shows all available effect types with a checkmark next to the current one
  /// Handles menu action for changing an area's effect type
  /// Manages special cases for Picture (file picker)
  @objc func changeEffect(_ sender: NSMenuItem) {
    guard let info = sender.representedObject as? [String: Any],
          let areaID = info["areaID"] as? UUID,
          let effectType = info["effectType"] as? EffectType else {
      return
    }
    
    guard let area = areaManager.areas.first(where: { $0.id == areaID }) else {
      return
    }
    
    if area.effectType.isSameKind(as: effectType) {
      return
    }
    
    if effectType.isPicture {
      OverlayWindowManager.shared.getWindow(for: areaID)?.orderOut(nil)
      
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        guard let imageData = self?.captureScreenshot(of: area.frame) else {
          OverlayWindowManager.shared.getWindow(for: areaID)?.orderFront(nil)
          return
        }
        self?.switchEffect(for: areaID, to: effectType, imageData: imageData)
      }
      return
    }
    
    switchEffect(for: areaID, to: effectType)
  }
  
  private func captureScreenshot(of frame: CGRect) -> Data? {
    let mainDisplayBounds = CGDisplayBounds(CGMainDisplayID())
    let quartzY = mainDisplayBounds.height - frame.origin.y - frame.height
    let quartzFrame = CGRect(x: frame.origin.x, y: quartzY, width: frame.width, height: frame.height)
    
    guard let cgImage = CGWindowListCreateImage(
      quartzFrame,
      .optionOnScreenBelowWindow,
      kCGNullWindowID,
      [.bestResolution]
    ) else {
      return nil
    }
    
    let nsImage = NSImage(cgImage: cgImage, size: frame.size)
    guard let tiffData = nsImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
      return nil
    }
    
    return pngData
  }
  
  private func switchEffect(for areaID: UUID, to newEffect: EffectType, imageData: Data? = nil) {
    guard let areaIndex = areaManager.areas.firstIndex(where: { $0.id == areaID }) else {
      return
    }
    
    var area = areaManager.areas[areaIndex]
    
    let preservedFrame = area.frame
    let preservedName = area.name
    let preservedIsEnabled = area.isEnabled
    let preservedDisableOnHover = area.disableOnHover
    
    switch newEffect {
    case .blur:
      area.effectType = .blur(radius: 20.0)
    case .darken:
      area.effectType = .darken(amount: 0.5)
    case .picture:
      if let imageData = imageData {
        area.effectType = .picture(imageData: imageData)
      } else {
        return
      }
    }
    
    area.frame = preservedFrame
    area.name = preservedName
    area.isEnabled = preservedIsEnabled
    area.disableOnHover = preservedDisableOnHover
    
    areaManager.update(area)
    
    guard let window = OverlayWindowManager.shared.getWindow(for: areaID) else {
      return
    }
    
    window.contentView?.subviews.forEach { $0.removeFromSuperview() }
    
    let localBounds = CGRect(origin: .zero, size: area.frame.size)
    if let effectView = EffectViewFactory.createView(for: area, in: localBounds) {
      window.contentView?.addSubview(effectView)
    } else if newEffect.isPicture {
      return
    }
    
    if area.isEnabled { window.orderFront(nil) }
    setupMenu()
  }
  
  // MARK: - Parameters Management
  
  @objc func adjustParameters(_ sender: NSMenuItem) {
    guard let info = sender.representedObject as? [String: Any],
          let areaID = info["areaID"] as? UUID,
          let level = info["level"] as? String else {
      return
    }
    
    parameterManager.updateParameters(for: areaID, level: level)
    setupMenu()
  }
  
  // MARK: - Configuration Export/Import
  
  @objc func exportConfiguration() {
    Task { await configurationManager.exportConfiguration() }
  }
  
  @objc func importConfiguration() {
    Task { await configurationManager.importConfiguration() }
  }
  
#if DIRECT
  @objc func toggleAutoBlurOnScreenShare(_ sender: NSMenuItem) {
    let currentValue = UserDefaults.standard.bool(forKey: "AutoBlurOnScreenShare")
    UserDefaults.standard.set(!currentValue, forKey: "AutoBlurOnScreenShare")
    updateScreenCaptureMonitoring()
    setupMenu()
  }
#endif
  
  // MARK: - ConfigurationManagerDelegate
  
  func configurationDidUpdate() {
    setupMenu()
  }
  
  func resizeHandleView(_ view: ResizeHandleView, didUpdateFrame frame: CGRect) {
    guard let window = OverlayWindowManager.shared.getWindow(for: view.areaID) else { return }
    window.setFrame(frame, display: true)
    window.contentView?.frame = NSRect(origin: .zero, size: frame.size)
  }
  
  func resizeHandleView(_ view: ResizeHandleView, didExitResizeMode frame: CGRect) {
    let areaID = view.areaID
    OverlayWindowManager.shared.disableResizeMode(for: areaID)
    updateAreaFrame(areaID: areaID, newFrame: frame)
    
    if let area = areaManager.areas.first(where: { $0.id == areaID }), area.disableOnHover {
      MouseTracker.shared.startTracking(area: area)
    }
  }
}
