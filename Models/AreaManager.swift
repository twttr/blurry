import Foundation
import Combine

protocol UserDefaultsProtocol {
  func data(forKey defaultName: String) -> Data?
  func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: UserDefaultsProtocol {}

protocol AreaManaging: AnyObject {
  var areas: [BlurArea] { get }
  var areasPublisher: Published<[BlurArea]>.Publisher { get }
  func add(_ area: BlurArea)
  func remove(withID id: UUID)
  func update(_ area: BlurArea)
  func toggleEnabled(for id: UUID)
  func removeAll()
  func replaceAll(with newAreas: [BlurArea])
  func beginBatchUpdate()
  func endBatchUpdate()
}

@MainActor
class AreaManager: ObservableObject, AreaManaging {
  static let shared = AreaManager()

  @Published var areas: [BlurArea] = []
  var areasPublisher: Published<[BlurArea]>.Publisher { $areas }

  private var batchMode = false
  private let userDefaults: UserDefaultsProtocol
  private let storageKey: String

  convenience init() {
    self.init(userDefaults: UserDefaults.standard)
  }

  init(userDefaults: UserDefaultsProtocol, storageKey: String = "SavedAreas") {
    self.userDefaults = userDefaults
    self.storageKey = storageKey
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
      userDefaults.set(encoded, forKey: storageKey)
    } catch {
      AppLogger.shared.error("Failed to save areas: \(error.localizedDescription)")
    }
  }

  private func load() {
    let logger = AppLogger.shared
    guard let savedData = userDefaults.data(forKey: storageKey) else {
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
