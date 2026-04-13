import Cocoa

/// Manages effect parameter adjustments and re-rendering
@MainActor
class EffectParameterManager {
  private let areaManager: AreaManager
  
  init(areaManager: AreaManager) {
    self.areaManager = areaManager
  }
  
  /// Update effect parameters for a given area and re-render
  /// - Parameters:
  ///   - areaID: The UUID of the area to update
  ///   - level: The parameter level ("low", "medium", "high")
  func updateParameters(for areaID: UUID, level: String) {
    guard let areaIndex = areaManager.areas.firstIndex(where: { $0.id == areaID }) else {
      return
    }
    
    var area = areaManager.areas[areaIndex]
    
    switch area.effectType {
    case .blur:
      updateBlurParameters(for: &area, level: level)
    case .darken:
      updateDarkenParameters(for: &area, level: level)
    case .picture:
      return
    }
    
    areaManager.update(area)
    
    reRenderEffect(for: area)
  }
  
  // MARK: - Parameter Updates
  
  /// Update blur effect parameters based on level
  private func updateBlurParameters(for area: inout BlurArea, level: String) {
    guard let intensity = BlurIntensity(rawValue: level) else { return }
    area.effectType = .blur(intensity: intensity)
  }
  
  /// Update darken effect parameters based on level
  private func updateDarkenParameters(for area: inout BlurArea, level: String) {
    let amount: Double
    switch level {
    case "low":
      amount = 0.3
    case "medium":
      amount = 0.5
    case "high":
      amount = 0.7
    default:
      return
    }
    area.effectType = .darken(amount: amount)
  }
  
  // MARK: - Effect Re-rendering
  
  /// Re-render an effect after parameter changes
  /// Removes existing effect view and creates a new one with updated parameters
  func reRenderEffect(for area: BlurArea) {
    guard let window = OverlayWindowManager.shared.getWindow(for: area.id) else {
      return
    }
    
    window.contentView?.subviews.forEach { $0.removeFromSuperview() }
    
    if let effectView = EffectViewFactory.createView(for: area, in: window.contentView?.bounds ?? .zero) {
      window.contentView?.addSubview(effectView)
    }
  }
}
