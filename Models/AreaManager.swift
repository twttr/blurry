import Foundation
import Combine

@MainActor
class AreaManager: ObservableObject {
  static let shared = AreaManager()

  @Published var areas: [BlurArea] = []
  private var batchMode = false
  private var skipCloudSync = false

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

  func setSkipCloudSync(_ skip: Bool) {
    skipCloudSync = skip
  }

  func add(_ area: BlurArea) {
    areas.append(area)
    save()
    syncToCloud(area)
  }

  func remove(withID id: UUID) {
    let area = areas.first { $0.id == id }
    let isSyncable = area?.isSyncable ?? false
    areas.removeAll { $0.id == id }
    save()
    deleteFromCloud(id: id, isSyncable: isSyncable)
  }

  func update(_ area: BlurArea) {
    if let index = areas.firstIndex(where: { $0.id == area.id }) {
      areas[index] = area
      save()
      syncToCloud(area)
    }
  }

  func toggleEnabled(for id: UUID) {
    if let index = areas.firstIndex(where: { $0.id == id }) {
      areas[index].isEnabled.toggle()
      save()
      syncToCloud(areas[index])
    }
  }

  func removeAll() {
    let syncableIDs = areas.filter { $0.isSyncable }.map { $0.id }
    areas.removeAll()
    save()
    for id in syncableIDs {
      deleteFromCloud(id: id, isSyncable: true)
    }
  }

  func replaceAll(with newAreas: [BlurArea]) {
    areas = newAreas
    save()
  }

  private func save() {
    guard !batchMode else { return }

    do {
      let localOnlyAreas = areas.filter { !$0.isSyncable }
      let encoded = try JSONEncoder().encode(localOnlyAreas)
      UserDefaults.standard.set(encoded, forKey: "LocalOnlyAreas")

      let allEncoded = try JSONEncoder().encode(areas)
      UserDefaults.standard.set(allEncoded, forKey: "SavedAreas")
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

  private func syncToCloud(_ area: BlurArea) {
    guard !batchMode && !skipCloudSync && area.isSyncable else { return }
    Task {
      await SyncCoordinator.shared.syncArea(area)
    }
  }

  private func deleteFromCloud(id: UUID, isSyncable: Bool) {
    guard !batchMode && !skipCloudSync else { return }
    Task {
      await SyncCoordinator.shared.deleteArea(withID: id, isSyncable: isSyncable)
    }
  }
}
