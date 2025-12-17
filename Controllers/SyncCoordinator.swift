import Foundation
import Combine

@MainActor
class SyncCoordinator {
  static let shared = SyncCoordinator()

  private let cloudKit = CloudKitManager.shared
  private let migrationKey = "CloudKitMigrationCompleted"
  private let localOnlyAreasKey = "LocalOnlyAreas"
  private let cloudCacheKey = "CloudKitCachedAreas"

  private var cancellables = Set<AnyCancellable>()
  private var isSyncing = false

  private init() {
    setupRemoteChangeHandler()
  }

  func initialize() async {
    let logger = AppLogger.shared
    let available = await cloudKit.checkAccountStatus()

    if available {
      await performMigrationIfNeeded()
      await performInitialSync()

      do {
        try await cloudKit.subscribeToChanges()
      } catch {
        logger.error("Failed to subscribe to CloudKit changes: \(error.localizedDescription)")
      }
    } else {
      logger.info("CloudKit not available, using local storage only")
      loadCachedCloudAreas()
    }
  }

  private func performMigrationIfNeeded() async {
    let logger = AppLogger.shared

    guard !UserDefaults.standard.bool(forKey: migrationKey) else {
      logger.debug("CloudKit migration already completed")
      return
    }

    logger.info("Starting CloudKit migration")

    let areaManager = AreaManager.shared
    let allAreas = areaManager.areas

    let localOnlyAreas = allAreas.filter { !$0.isSyncable }
    let syncableAreas = allAreas.filter { $0.isSyncable }

    if !localOnlyAreas.isEmpty {
      saveLocalOnlyAreas(localOnlyAreas)
      logger.info("Saved \(localOnlyAreas.count) local-only areas (picture effects)")
    }

    for area in syncableAreas {
      do {
        try await cloudKit.saveArea(area)
      } catch {
        logger.error("Failed to migrate area '\(area.name)' to CloudKit: \(error.localizedDescription)")
      }
    }

    UserDefaults.standard.set(true, forKey: migrationKey)
    logger.info("CloudKit migration completed: \(syncableAreas.count) areas synced")
  }

  func performInitialSync() async {
    let logger = AppLogger.shared
    guard cloudKit.isAvailable else { return }
    guard !isSyncing else { return }

    isSyncing = true
    defer { isSyncing = false }

    do {
      let cloudAreas = try await cloudKit.fetchAllAreas()
      cacheCloudAreas(cloudAreas)

      let localOnlyAreas = loadLocalOnlyAreas()
      let mergedAreas = mergeAreas(cloud: cloudAreas, localOnly: localOnlyAreas)

      let areaManager = AreaManager.shared
      areaManager.beginBatchUpdate()
      areaManager.replaceAll(with: mergedAreas)
      areaManager.endBatchUpdate()

      logger.info("Initial sync complete: \(cloudAreas.count) cloud + \(localOnlyAreas.count) local-only areas")
    } catch {
      logger.error("Initial sync failed: \(error.localizedDescription)")
      loadCachedCloudAreas()
    }
  }

  func syncArea(_ area: BlurArea) async {
    guard area.isSyncable else { return }
    guard cloudKit.isAvailable else { return }

    do {
      try await cloudKit.saveArea(area)
      updateCachedArea(area)
    } catch {
      AppLogger.shared.error("Failed to sync area '\(area.name)': \(error.localizedDescription)")
    }
  }

  func deleteArea(withID id: UUID, isSyncable: Bool) async {
    if isSyncable && cloudKit.isAvailable {
      do {
        try await cloudKit.deleteArea(withID: id)
        removeCachedArea(withID: id)
      } catch {
        AppLogger.shared.error("Failed to delete area from CloudKit: \(error.localizedDescription)")
      }
    } else if !isSyncable {
      var localAreas = loadLocalOnlyAreas()
      localAreas.removeAll { $0.id == id }
      saveLocalOnlyAreas(localAreas)
    }
  }

  func fetchRemoteChanges() async {
    guard cloudKit.isAvailable else { return }

    do {
      try await cloudKit.fetchChanges()
    } catch {
      AppLogger.shared.error("Failed to fetch remote changes: \(error.localizedDescription)")
    }
  }

  private func setupRemoteChangeHandler() {
    cloudKit.onRemoteChanges = { [weak self] changedAreas, deletedIDs in
      Task { @MainActor in
        self?.handleRemoteChanges(changed: changedAreas, deleted: deletedIDs)
      }
    }
  }

  private func handleRemoteChanges(changed: [BlurArea], deleted: [UUID]) {
    let logger = AppLogger.shared
    let areaManager = AreaManager.shared

    areaManager.beginBatchUpdate()

    for id in deleted {
      areaManager.remove(withID: id)
      removeCachedArea(withID: id)
    }

    for area in changed {
      if areaManager.areas.contains(where: { $0.id == area.id }) {
        areaManager.update(area)
      } else {
        areaManager.add(area)
      }
      updateCachedArea(area)
    }

    areaManager.endBatchUpdate()
    logger.info("Applied remote changes: \(changed.count) updated, \(deleted.count) deleted")
  }

  private func mergeAreas(cloud: [BlurArea], localOnly: [BlurArea]) -> [BlurArea] {
    var merged = cloud
    merged.append(contentsOf: localOnly)
    return merged
  }

  private func loadLocalOnlyAreas() -> [BlurArea] {
    guard let data = UserDefaults.standard.data(forKey: localOnlyAreasKey),
          let areas = try? JSONDecoder().decode([BlurArea].self, from: data) else {
      return []
    }
    return areas
  }

  func saveLocalOnlyAreas(_ areas: [BlurArea]) {
    if let data = try? JSONEncoder().encode(areas) {
      UserDefaults.standard.set(data, forKey: localOnlyAreasKey)
    }
  }

  private func cacheCloudAreas(_ areas: [BlurArea]) {
    if let data = try? JSONEncoder().encode(areas) {
      UserDefaults.standard.set(data, forKey: cloudCacheKey)
    }
  }

  private func loadCachedCloudAreas() {
    guard let data = UserDefaults.standard.data(forKey: cloudCacheKey),
          let cachedAreas = try? JSONDecoder().decode([BlurArea].self, from: data) else {
      return
    }

    let localOnlyAreas = loadLocalOnlyAreas()
    let mergedAreas = mergeAreas(cloud: cachedAreas, localOnly: localOnlyAreas)

    let areaManager = AreaManager.shared
    areaManager.beginBatchUpdate()
    areaManager.replaceAll(with: mergedAreas)
    areaManager.endBatchUpdate()

    AppLogger.shared.info("Loaded \(cachedAreas.count) cached cloud areas")
  }

  private func updateCachedArea(_ area: BlurArea) {
    var cached = loadCachedCloudAreasArray()
    if let index = cached.firstIndex(where: { $0.id == area.id }) {
      cached[index] = area
    } else {
      cached.append(area)
    }
    cacheCloudAreas(cached)
  }

  private func removeCachedArea(withID id: UUID) {
    var cached = loadCachedCloudAreasArray()
    cached.removeAll { $0.id == id }
    cacheCloudAreas(cached)
  }

  private func loadCachedCloudAreasArray() -> [BlurArea] {
    guard let data = UserDefaults.standard.data(forKey: cloudCacheKey),
          let areas = try? JSONDecoder().decode([BlurArea].self, from: data) else {
      return []
    }
    return areas
  }
}
