import Cocoa

/// Protocol for handling menu actions
@objc protocol AreaMenuDelegate: AnyObject {
  func addBlurArea()
  func addDarkenArea()
  func addPictureArea()
  func addAreaFromWindow()
  
  func toggleAreaEnabled(_ sender: NSMenuItem)
  func toggleDisable(_ sender: NSMenuItem)
  func resizeArea(_ sender: NSMenuItem)
  func removeArea(_ sender: NSMenuItem)
  
  func toggleAllAreas()
  
  func exportConfiguration()
  func importConfiguration()
  
  func adjustParameters(_ sender: NSMenuItem)
  
  func changeEffect(_ sender: NSMenuItem)
  
  func quit()
}

/// Builds and manages menu structure for the status bar
class AreaMenuBuilder {
  weak var delegate: AreaMenuDelegate?
  private let areaManager: AreaManager
  
  init(areaManager: AreaManager, delegate: AreaMenuDelegate) {
    self.areaManager = areaManager
    self.delegate = delegate
  }
  
  /// Builds the complete status bar menu
  func buildMainMenu() -> NSMenu {
    let menu = NSMenu()
    
    let addAreaMenuItem = NSMenuItem(title: String(localized: "Add New Area"), action: nil, keyEquivalent: "")
    addAreaMenuItem.submenu = createAddAreaSubmenu()
    menu.addItem(addAreaMenuItem)
    
    menu.addItem(NSMenuItem.separator())

    let anyEnabled = areaManager.areas.contains { $0.isEnabled }
    let toggleTitle = anyEnabled ? String(localized: "Disable All") : String(localized: "Enable All")
    let toggleItem = createMenuItem(title: toggleTitle, action: #selector(AreaMenuDelegate.toggleAllAreas), keyEquivalent: "b")
    toggleItem.keyEquivalentModifierMask = [.command, .shift]
    menu.addItem(toggleItem)

    menu.addItem(NSMenuItem.separator())
    
    let configurationMenuItem = NSMenuItem(title: String(localized: "Configuration"), action: nil, keyEquivalent: "")
    configurationMenuItem.submenu = createConfigurationSubmenu()
    menu.addItem(configurationMenuItem)
    
    if !areaManager.areas.isEmpty {
      menu.addItem(NSMenuItem.separator())
      
      let areasMenuItem = NSMenuItem(title: String(localized: "Areas"), action: nil, keyEquivalent: "")
      areasMenuItem.submenu = buildAreasSubmenu()
      menu.addItem(areasMenuItem)
    }
    
    menu.addItem(NSMenuItem.separator())
    
    menu.addItem(createMenuItem(title: String(localized: "Quit"), action: #selector(AreaMenuDelegate.quit), keyEquivalent: "q"))
    
    return menu
  }
  
  // MARK: - Submenus
  
  private func createAddAreaSubmenu() -> NSMenu {
    let submenu = NSMenu()
    
    submenu.addItem(createMenuItem(title: String(localized: "Manually"), action: #selector(AreaMenuDelegate.addBlurArea)))
    submenu.addItem(createMenuItem(title: String(localized: "Select Window"), action: #selector(AreaMenuDelegate.addAreaFromWindow)))
    
    return submenu
  }
  
  private func createConfigurationSubmenu() -> NSMenu {
    let submenu = NSMenu()
    
    submenu.addItem(
      createMenuItem(
        title: String(localized: "Export"),
        action: #selector(AreaMenuDelegate.exportConfiguration)
      )
    )
    submenu.addItem(
      createMenuItem(
        title: String(localized: "Import"),
        action: #selector(AreaMenuDelegate.importConfiguration)
      )
    )
    
    return submenu
  }
  
  private func buildAreasSubmenu() -> NSMenu {
    let submenu = NSMenu()
    
    for area in areaManager.areas {
      let areaMenuItem = NSMenuItem(title: area.name, action: nil, keyEquivalent: "")
      areaMenuItem.submenu = buildAreaSubmenu(for: area)
      submenu.addItem(areaMenuItem)
    }
    
    return submenu
  }
  
  private func buildAreaSubmenu(for area: BlurArea) -> NSMenu {
    let submenu = NSMenu()
    
    let enabledItem = createMenuItem(
      title: String(localized: "Enabled"),
      action: #selector(AreaMenuDelegate.toggleAreaEnabled(_:)),
      representedObject: area.id
    )
    enabledItem.state = area.isEnabled ? .on : .off
    submenu.addItem(enabledItem)
    
    let parametersMenuItem = NSMenuItem(title: String(localized: "Parameters"), action: nil, keyEquivalent: "")
    parametersMenuItem.submenu = buildParametersSubmenu(for: area)
    submenu.addItem(parametersMenuItem)
    
    let changeEffectMenuItem = NSMenuItem(title: String(localized: "Change Effect"), action: nil, keyEquivalent: "")
    changeEffectMenuItem.submenu = buildChangeEffectSubmenu(for: area)
    submenu.addItem(changeEffectMenuItem)
    
    let disableItem = createMenuItem(
      title: String(localized: "Hover to Reveal"),
      action: #selector(AreaMenuDelegate.toggleDisable(_:)),
      representedObject: area.id
    )
    disableItem.state = area.disableOnHover ? .on : .off
    submenu.addItem(disableItem)
    
    submenu.addItem(createMenuItem(
      title: String(localized: "Resize Area"),
      action: #selector(AreaMenuDelegate.resizeArea(_:)),
      representedObject: area.id
    ))

    submenu.addItem(createMenuItem(
      title: String(localized: "Remove"),
      action: #selector(AreaMenuDelegate.removeArea(_:)),
      representedObject: area.id
    ))
    
    return submenu
  }
  
  func buildParametersSubmenu(for area: BlurArea) -> NSMenu {
    let submenu = NSMenu()
    
    switch area.effectType {
    case .blur(let radius):
      submenu.addItem(createParameterItem(title: String(localized: "Low"), areaID: area.id, level: "low",
                                          isSelected: radius == 10.0))
      submenu.addItem(createParameterItem(title: String(localized: "Medium"), areaID: area.id, level: "medium",
                                          isSelected: radius == 20.0))
      submenu.addItem(createParameterItem(title: String(localized: "High"), areaID: area.id, level: "high",
                                          isSelected: radius == 30.0))

    case .darken(let amount):
      submenu.addItem(createParameterItem(title: String(localized: "Low"), areaID: area.id, level: "low",
                                          isSelected: amount == 0.3))
      submenu.addItem(createParameterItem(title: String(localized: "Medium"), areaID: area.id, level: "medium",
                                          isSelected: amount == 0.5))
      submenu.addItem(createParameterItem(title: String(localized: "High"), areaID: area.id, level: "high",
                                          isSelected: amount == 0.7))

    case .picture:
      let noParamsItem = NSMenuItem(title: String(localized: "No adjustable parameters"), action: nil, keyEquivalent: "")
      noParamsItem.isEnabled = false
      submenu.addItem(noParamsItem)
    }
    
    return submenu
  }
  
  private func buildChangeEffectSubmenu(for area: BlurArea) -> NSMenu {
    let submenu = NSMenu()
    
    let blurItem = createMenuItem(
      title: String(localized: "Blur"),
      action: #selector(AreaMenuDelegate.changeEffect(_:)),
      representedObject: ["areaID": area.id, "effectType": EffectType.blur(radius: 20.0)] as [String: Any]
    )
    blurItem.state = area.effectType.isBlur ? .on : .off
    submenu.addItem(blurItem)

    let darkenItem = createMenuItem(
      title: String(localized: "Darken"),
      action: #selector(AreaMenuDelegate.changeEffect(_:)),
      representedObject: ["areaID": area.id, "effectType": EffectType.darken(amount: 0.5)] as [String: Any]
    )
    darkenItem.state = area.effectType.isDarken ? .on : .off
    submenu.addItem(darkenItem)

    let pictureItem = createMenuItem(
      title: String(localized: "Picture"),
      action: #selector(AreaMenuDelegate.changeEffect(_:)),
      representedObject: ["areaID": area.id, "effectType": EffectType.picture(imagePath: "")] as [String: Any]
    )
    pictureItem.state = area.effectType.isPicture ? .on : .off
    submenu.addItem(pictureItem)
    
    return submenu
  }
  
  // MARK: - Helper Methods
  
  private func createMenuItem(
    title: String,
    action: Selector?,
    keyEquivalent: String = "",
    representedObject: Any? = nil
  ) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
    item.target = delegate
    item.representedObject = representedObject
    return item
  }
  
  private func createParameterItem(
    title: String,
    areaID: UUID,
    level: String,
    isSelected: Bool
  ) -> NSMenuItem {
    let item = createMenuItem(
      title: title,
      action: #selector(AreaMenuDelegate.adjustParameters(_:)),
      representedObject: ["areaID": areaID, "level": level] as [String: Any]
    )
    item.state = isSelected ? .on : .off
    return item
  }
}
