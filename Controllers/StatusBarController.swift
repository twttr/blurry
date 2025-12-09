import Cocoa
import Combine
import UniformTypeIdentifiers

@MainActor
class StatusBarController: AreaMenuDelegate, ConfigurationManagerDelegate, ResizeHandleDelegate {
  private var statusItem: NSStatusItem!
  private var cancellables = Set<AnyCancellable>()
  private var currentSelectionController: AreaSelectionController?
  private var currentWindowPicker: VisualWindowPicker?
  private var areaManager: AreaManager
  private var menuBuilder: AreaMenuBuilder!
  private var parameterManager: EffectParameterManager!
  private var configurationManager: ConfigurationManager!
  
  init(areaManager: AreaManager) {
    self.areaManager = areaManager
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem.isVisible = true
    
    if let button = statusItem.button {
      if let image = NSImage(systemSymbolName: "eye.trianglebadge.exclamationmark", accessibilityDescription: String(localized: "Blurry")) {
        image.isTemplate = true
        button.image = image
      } else {
        button.title = "⚫️ Blurry"
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
    statusItem.menu = menuBuilder.buildMainMenu()
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
  
  @objc func addPictureArea() {
    let openPanel = NSOpenPanel()
    openPanel.canChooseFiles = true
    openPanel.canChooseDirectories = false
    openPanel.allowsMultipleSelection = false
    openPanel.allowedContentTypes = [.png, .jpeg, .gif, .bmp, .tiff]
    
    if openPanel.runModal() == .OK, let url = openPanel.url {
      let imagePath = url.path
      let controller = AreaSelectionController()
      currentSelectionController = controller
      
      Task { [weak self] in
        if let result = await controller.beginSelection() {
          self?.createPictureArea(rect: result.rect, name: result.name, imagePath: imagePath)
          self?.currentSelectionController = nil
        } else {
          self?.currentSelectionController = nil
        }
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

    if let displayID = displayID,
       let screen = DisplayManager.shared.getScreen(for: displayID) {
      area.displayRelativeFrame = area.makeDisplayRelative(screen: screen)
    }

    areaManager.add(area)

    guard let window = OverlayWindowManager.shared.createWindow(for: area) else { return }

    let localBounds = CGRect(origin: .zero, size: area.frame.size)
    if let effectView = EffectViewFactory.createView(for: area, in: localBounds) {
      window.contentView?.addSubview(effectView)
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

    if let displayID = displayID,
       let screen = DisplayManager.shared.getScreen(for: displayID) {
      area.displayRelativeFrame = area.makeDisplayRelative(screen: screen)
    }

    areaManager.add(area)

    guard let window = OverlayWindowManager.shared.createWindow(for: area) else { return }

    let localBounds = CGRect(origin: .zero, size: area.frame.size)
    if let effectView = EffectViewFactory.createView(for: area, in: localBounds) {
      window.contentView?.addSubview(effectView)
    }

  }

  private func createPictureArea(rect: CGRect, name: String, imagePath: String) {
    let displayID = DisplayManager.shared.getCurrentDisplayID(for: rect.origin)

    var area = BlurArea(
      name: name,
      frame: rect,
      effectType: .picture(imagePath: imagePath)
    )
    area.displayID = displayID

    if let displayID = displayID,
       let screen = DisplayManager.shared.getScreen(for: displayID) {
      area.displayRelativeFrame = area.makeDisplayRelative(screen: screen)
    }

    areaManager.add(area)

    guard let window = OverlayWindowManager.shared.createWindow(for: area) else { return }

    let localBounds = CGRect(origin: .zero, size: area.frame.size)
    if let effectView = EffectViewFactory.createView(for: area, in: localBounds) {
      window.contentView?.addSubview(effectView)
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
      let openPanel = NSOpenPanel()
      openPanel.canChooseFiles = true
      openPanel.canChooseDirectories = false
      openPanel.allowsMultipleSelection = false
      openPanel.allowedContentTypes = [.png, .jpeg, .gif, .bmp, .tiff]
      
      if openPanel.runModal() == .OK, let url = openPanel.url {
        switchEffect(for: areaID, to: effectType, imagePath: url.path)
      }
      return
    }
    
    switchEffect(for: areaID, to: effectType)
  }
  
  /// Switches an area's effect type while preserving its state (frame, name, enabled, disableOnHover)
  /// Removes the old effect view and creates a new one based on the new effect type
  private func switchEffect(for areaID: UUID, to newEffect: EffectType, imagePath: String? = nil) {
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
      if let imagePath = imagePath {
        area.effectType = .picture(imagePath: imagePath)
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
