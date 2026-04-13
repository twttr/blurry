import Cocoa
import UniformTypeIdentifiers

protocol ConfigurationManagerDelegate: AnyObject {
  func configurationDidUpdate()
}

@MainActor
class ConfigurationManager {
  private let areaManager: AreaManager
  weak var delegate: ConfigurationManagerDelegate?
  
  init(areaManager: AreaManager, delegate: ConfigurationManagerDelegate) {
    self.areaManager = areaManager
    self.delegate = delegate
  }
  
  // MARK: - Export
  
  func exportConfiguration() async {
    let savePanel = NSSavePanel()
    savePanel.nameFieldStringValue = "BlurryConfig.json"
    savePanel.allowedContentTypes = [.json]
    savePanel.canCreateDirectories = true
    savePanel.isExtensionHidden = false
    savePanel.title = String(localized: "Export Blurry Configuration")
    savePanel.message = String(localized: "Choose a location to save your configuration")
    
    let response = savePanel.runModal()
    guard response == .OK, let url = savePanel.url else { return }
    
    await performExport(to: url)
  }
  
  private func performExport(to url: URL) async {
    let areas = areaManager.areas
    
    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let jsonData = try encoder.encode(areas)
      
      try jsonData.write(to: url, options: .atomic)
      
      await NotificationManager.shared.send(
        title: String(localized: "Export Successful"),
        body: String(localized: "Successfully exported \(areas.count) area(s) to \(url.lastPathComponent)")
      )
    } catch {
      await NotificationManager.shared.send(
        title: String(localized: "Export Failed"),
        body: String(localized: "Failed to export configuration: \(error.localizedDescription)")
      )
    }
  }
  
  // MARK: - Import
  
  func importConfiguration() async {
    let openPanel = NSOpenPanel()
    openPanel.canChooseFiles = true
    openPanel.canChooseDirectories = false
    openPanel.allowsMultipleSelection = false
    openPanel.allowedContentTypes = [.json]
    openPanel.title = String(localized: "Import Blurry Configuration")
    openPanel.message = String(localized: "Choose a configuration file to import")
    
    let response = openPanel.runModal()
    guard response == .OK, let url = openPanel.url else { return }
    
    await performImport(from: url)
  }
  
  private func performImport(from url: URL) async {
    do {
      let jsonData = try Data(contentsOf: url)
      let decoder = JSONDecoder()
      let importedAreas = try decoder.decode([BlurArea].self, from: jsonData)
      
      guard let validationError = validateAreas(importedAreas) else {
        await showImportConfirmation(importedAreas: importedAreas)
        return
      }
      
      await NotificationManager.shared.send(
        title: String(localized: "Invalid Configuration"),
        body: validationError
      )
    } catch {
      await NotificationManager.shared.send(
        title: String(localized: "Import Failed"),
        body: String(localized: "Failed to read configuration file: \(error.localizedDescription)")
      )
    }
  }
  
  // MARK: - Validation
  
  private func validateAreas(_ areas: [BlurArea]) -> String? {
    for (index, area) in areas.enumerated() {
      if area.name.isEmpty {
        let areaNumber = index + 1
        return String(localized: "Area \(areaNumber) has an empty name")
      }
      
      if area.frame.width <= 0 || area.frame.height <= 0 {
        return String(localized: "Area '\(area.name)' has invalid dimensions (width: \(area.frame.width), height: \(area.frame.height))")
      }
      
      switch area.effectType {
      case .blur:
        break
      case .darken(let amount):
        if amount < 0 || amount > 1 {
          return String(localized: "Area '\(area.name)' has invalid darken amount: \(amount)")
        }
      case .picture(let imageRef):
        if imageRef.isEmpty {
          return String(localized: "Area '\(area.name)' has empty image reference")
        }
      }
    }
    
    return nil
  }
  
  // MARK: - Import Confirmation & Replacement
  
  private func showImportConfirmation(importedAreas: [BlurArea]) async {
    let existingCount = areaManager.areas.count
    let importCount = importedAreas.count
    
    let alert = NSAlert()
    alert.messageText = String(localized: "Confirm Import")
    alert.informativeText = String(localized: "This will replace \(existingCount) existing area(s) with \(importCount) imported area(s). This action cannot be undone. Continue?")
    alert.alertStyle = .warning
    alert.addButton(withTitle: String(localized: "Import"))
    alert.addButton(withTitle: String(localized: "Cancel"))
    
    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
      await performImportReplacement(importedAreas: importedAreas)
    }
  }
  
  private func performImportReplacement(importedAreas: [BlurArea]) async {
    for area in areaManager.areas {
      if area.disableOnHover {
        MouseTracker.shared.stopTracking(areaID: area.id)
      }
    }
    
    OverlayWindowManager.shared.removeAllWindows()
    
    areaManager.replaceAll(with: importedAreas)
    
    for area in importedAreas {
      recreateOverlayWindow(for: area)
      
      if area.disableOnHover && area.isEnabled {
        MouseTracker.shared.startTracking(area: area)
      }
    }
    
    delegate?.configurationDidUpdate()
    
    await NotificationManager.shared.send(
      title: String(localized: "Import Successful"),
      body: String(localized: "Successfully imported \(importedAreas.count) area(s)")
    )
  }
  
  private func recreateOverlayWindow(for area: BlurArea) {
    guard area.isEnabled else { return }
    
    guard let window = OverlayWindowManager.shared.createWindow(for: area) else { return }
    
    if let effectView = EffectViewFactory.createView(for: area, in: window.contentView?.bounds ?? .zero) {
      window.contentView?.addSubview(effectView)
      window.orderFront(nil)
    }
  }
}
