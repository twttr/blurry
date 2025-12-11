import Foundation
import Combine

@MainActor
class AreaManager: ObservableObject {
  static let shared = AreaManager()
  
  @Published var areas: [BlurArea] = []
  private var batchMode = false
  
  private init() {
    load()
  }
  
  func beginBatchUpdate() {
    batchMode = true
  }
  
  func endBatchUpdate() {
    batchMode = false
    save()
  }
  
  func add(_ area: BlurArea) {
    areas.append(area)
    save()
  }
  
  func remove(withID id: UUID) {
    areas.removeAll { $0.id == id }
    save()
  }
  
  func update(_ area: BlurArea) {
    if let index = areas.firstIndex(where: { $0.id == area.id }) {
      areas[index] = area
      save()
    }
  }
  
  func toggleEnabled(for id: UUID) {
    if let index = areas.firstIndex(where: { $0.id == id }) {
      areas[index].isEnabled.toggle()
      save()
    }
  }
  
  func removeAll() {
    areas.removeAll()
    save()
  }
  
  func replaceAll(with newAreas: [BlurArea]) {
    areas = newAreas
    save()
  }
  
  private func save() {
    guard !batchMode else { return }
    
    do {
      let encoded = try JSONEncoder().encode(areas)
      UserDefaults.standard.set(encoded, forKey: "SavedAreas")
    } catch {
      AppLogger.shared.error("Failed to save areas: \(error.localizedDescription)")
    }
  }
  
  private func load() {
    let logger = AppLogger.shared
    guard let savedData = UserDefaults.standard.data(forKey: "SavedAreas") else {
      logger.info("No saved areas found in UserDefaults")
      areas = []
      return
    }
    
    do {
      areas = try JSONDecoder().decode([BlurArea].self, from: savedData)
      logger.info("Loaded \(areas.count) areas from UserDefaults")
    } catch {
      logger.error("Failed to load areas: \(error.localizedDescription)")
      areas = []
    }
  }
}
