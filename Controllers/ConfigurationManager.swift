import Cocoa
import UniformTypeIdentifiers

/// Protocol for configuration manager callbacks
protocol ConfigurationManagerDelegate: AnyObject {
  func configurationDidUpdate()
  func showAlert(title: String, message: String, style: NSAlert.Style)
}

/// Manages configuration export and import functionality
@MainActor
class ConfigurationManager {
  private let areaManager: AreaManager
  weak var delegate: ConfigurationManagerDelegate?
  
  init(areaManager: AreaManager, delegate: ConfigurationManagerDelegate) {
    self.areaManager = areaManager
    self.delegate = delegate
  }
  
  // MARK: - Export
  
  /// Show export dialog and export configuration
  func exportConfiguration() {
    let savePanel = NSSavePanel()
    savePanel.nameFieldStringValue = "BlurryConfig.json"
    savePanel.allowedContentTypes = [.json]
    savePanel.canCreateDirectories = true
    savePanel.isExtensionHidden = false
    savePanel.title = String(localized: "Export Blurry Configuration")
    savePanel.message = String(localized: "Choose a location to save your configuration")
    
    savePanel.begin { [weak self] response in
      guard response == .OK, let url = savePanel.url else { return }
      self?.performExport(to: url)
    }
  }
  
  private func performExport(to url: URL) {
    let areas = areaManager.areas
    
    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let jsonData = try encoder.encode(areas)
      
      try jsonData.write(to: url, options: .atomic)
      
      delegate?.showAlert(
        title: String(localized: "Export Successful"),
        message: String(localized: "Successfully exported \(areas.count) area(s) to \(url.lastPathComponent)"),
        style: .informational
      )
    } catch {
      delegate?.showAlert(
        title: String(localized: "Export Failed"),
        message: String(localized: "Failed to export configuration: \(error.localizedDescription)"),
        style: .critical
      )
    }
  }
  
  // MARK: - Import
  
  /// Show import dialog and import configuration
  func importConfiguration() {
    let openPanel = NSOpenPanel()
    openPanel.canChooseFiles = true
    openPanel.canChooseDirectories = false
    openPanel.allowsMultipleSelection = false
    openPanel.allowedContentTypes = [.json]
    openPanel.title = String(localized: "Import Blurry Configuration")
    openPanel.message = String(localized: "Choose a configuration file to import")
    
    openPanel.begin { [weak self] response in
      guard response == .OK, let url = openPanel.url else { return }
      self?.performImport(from: url)
    }
  }
  
  private func performImport(from url: URL) {
    do {
      let jsonData = try Data(contentsOf: url)
      let decoder = JSONDecoder()
      let importedAreas = try decoder.decode([BlurArea].self, from: jsonData)
      
      guard let validationError = validateAreas(importedAreas) else {
        showImportConfirmation(importedAreas: importedAreas)
        return
      }
      
      delegate?.showAlert(
        title: String(localized: "Invalid Configuration"),
        message: validationError,
        style: .critical
      )
    } catch {
      delegate?.showAlert(
        title: String(localized: "Import Failed"),
        message: String(localized: "Failed to read configuration file: \(error.localizedDescription)"),
        style: .critical
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
      case .blur(let radius):
        if radius <= 0 {
          return String(localized: "Area '\(area.name)' has invalid blur radius: \(radius)")
        }
      case .darken(let amount):
        if amount < 0 || amount > 1 {
          return String(localized: "Area '\(area.name)' has invalid darken amount: \(amount)")
        }
      case .picture(let imagePath):
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: imagePath) {
          return String(localized: "Area '\(area.name)' references a non-existent image file: \(imagePath)")
        }
      }
    }

    return nil
  }
  
  // MARK: - Import Confirmation & Replacement
  
  private func showImportConfirmation(importedAreas: [BlurArea]) {
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
      performImportReplacement(importedAreas: importedAreas)
    }
  }
  
  private func performImportReplacement(importedAreas: [BlurArea]) {
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
    
    delegate?.showAlert(
      title: String(localized: "Import Successful"),
      message: String(localized: "Successfully imported \(importedAreas.count) area(s)"),
      style: .informational
    )
  }
  
  private func recreateOverlayWindow(for area: BlurArea) {
    guard area.isEnabled else { return }

    guard let window = OverlayWindowManager.shared.createWindow(for: area) else { return }

    if let effectView = EffectViewFactory.createView(for: area, in: window.contentView?.bounds ?? .zero) {
      window.contentView?.addSubview(effectView)
    }
  }
}
