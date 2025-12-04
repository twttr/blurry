import Foundation
import Combine

@MainActor
class AreaManager: ObservableObject {
  static let shared = AreaManager()
  
  @Published var areas: [BlurArea] = []
  
  private init() {
    load()
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
    do {
      let encoded = try JSONEncoder().encode(areas)
      UserDefaults.standard.set(encoded, forKey: "SavedAreas")
    } catch {
    }
  }
  
  private func load() {
    guard let savedData = UserDefaults.standard.data(forKey: "SavedAreas") else {
      areas = []
      return
    }
    
    do {
      areas = try JSONDecoder().decode([BlurArea].self, from: savedData)
    } catch {
      areas = []
    }
  }
}
