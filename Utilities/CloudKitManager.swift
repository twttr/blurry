import Foundation
import CloudKit

@MainActor
class CloudKitManager {
  static let shared = CloudKitManager()

  private let container: CKContainer
  private let privateDatabase: CKDatabase
  private let recordType = "BlurArea"
  private let changeTokenKey = "CloudKitServerChangeToken"

  var isAvailable: Bool = false
  var onRemoteChanges: (([BlurArea], [UUID]) -> Void)?

  private init() {
    container = CKContainer.default()
    privateDatabase = container.privateCloudDatabase
  }

  func checkAccountStatus() async -> Bool {
    let logger = AppLogger.shared

    do {
      let status = try await container.accountStatus()
      switch status {
      case .available:
        isAvailable = true
        logger.info("iCloud account available")
        return true
      case .noAccount:
        logger.warning("No iCloud account configured")
      case .restricted:
        logger.warning("iCloud account restricted")
      case .couldNotDetermine:
        logger.warning("Could not determine iCloud account status")
      case .temporarilyUnavailable:
        logger.warning("iCloud temporarily unavailable")
      @unknown default:
        logger.warning("Unknown iCloud account status")
      }
    } catch {
      logger.error("Failed to check iCloud account status: \(error.localizedDescription)")
    }

    isAvailable = false
    return false
  }

  func saveArea(_ area: BlurArea) async throws {
    guard isAvailable else {
      throw CloudKitError.notAvailable
    }

    let record = area.toCKRecord()
    _ = try await privateDatabase.save(record)
    AppLogger.shared.info("Saved area to CloudKit: \(area.name)")
  }

  func deleteArea(withID id: UUID) async throws {
    guard isAvailable else {
      throw CloudKitError.notAvailable
    }

    let recordID = CKRecord.ID(recordName: id.uuidString)
    try await privateDatabase.deleteRecord(withID: recordID)
    AppLogger.shared.info("Deleted area from CloudKit: \(id)")
  }

  func fetchAllAreas() async throws -> [BlurArea] {
    guard isAvailable else {
      throw CloudKitError.notAvailable
    }

    let logger = AppLogger.shared
    let predicate = NSPredicate(value: true)
    let query = CKQuery(recordType: recordType, predicate: predicate)

    var allAreas: [BlurArea] = []
    var cursor: CKQueryOperation.Cursor? = nil

    repeat {
      let result: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)

      if let existingCursor = cursor {
        result = try await privateDatabase.records(continuingMatchFrom: existingCursor)
      } else {
        result = try await privateDatabase.records(matching: query)
      }

      for (_, recordResult) in result.matchResults {
        if case .success(let record) = recordResult {
          if let area = BlurArea(from: record) {
            allAreas.append(area)
          }
        }
      }

      cursor = result.queryCursor
    } while cursor != nil

    logger.info("Fetched \(allAreas.count) areas from CloudKit")
    return allAreas
  }

  func subscribeToChanges() async throws {
    guard isAvailable else { return }

    let logger = AppLogger.shared
    let subscriptionID = "blur-area-changes"

    do {
      _ = try await privateDatabase.subscription(for: subscriptionID)
      logger.debug("CloudKit subscription already exists")
      return
    } catch {
      logger.debug("Creating new CloudKit subscription")
    }

    let subscription = CKQuerySubscription(
      recordType: recordType,
      predicate: NSPredicate(value: true),
      subscriptionID: subscriptionID,
      options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
    )

    let notificationInfo = CKSubscription.NotificationInfo()
    notificationInfo.shouldSendContentAvailable = true
    subscription.notificationInfo = notificationInfo

    _ = try await privateDatabase.save(subscription)
    logger.info("Created CloudKit subscription for changes")
  }

  func fetchChanges() async throws {
    guard isAvailable else { return }

    let logger = AppLogger.shared
    var changedAreas: [BlurArea] = []
    var deletedIDs: [UUID] = []

    let savedToken = loadServerChangeToken()

    let zoneID = CKRecordZone.ID(zoneName: CKRecordZone.default().zoneID.zoneName, ownerName: CKCurrentUserDefaultName)

    var configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
    configuration.previousServerChangeToken = savedToken

    let operation = CKFetchRecordZoneChangesOperation(
      recordZoneIDs: [zoneID],
      configurationsByRecordZoneID: [zoneID: configuration]
    )

    operation.recordWasChangedBlock = { recordID, result in
      switch result {
      case .success(let record):
        if let area = BlurArea(from: record) {
          changedAreas.append(area)
        }
      case .failure(let error):
        logger.error("Failed to fetch changed record: \(error.localizedDescription)")
      }
    }

    operation.recordWithIDWasDeletedBlock = { recordID, _ in
      if let uuid = UUID(uuidString: recordID.recordName) {
        deletedIDs.append(uuid)
      }
    }

    operation.recordZoneChangeTokensUpdatedBlock = { [weak self] zoneID, token, _ in
      if let token = token {
        self?.saveServerChangeToken(token)
      }
    }

    operation.recordZoneFetchResultBlock = { [weak self] (zoneID: CKRecordZone.ID, result: Result<(serverChangeToken: CKServerChangeToken, clientChangeTokenData: Data?, moreComing: Bool), Error>) in
      switch result {
      case .success(let data):
        self?.saveServerChangeToken(data.serverChangeToken)
      case .failure(let error):
        logger.error("Zone fetch failed: \(error.localizedDescription)")
      }
    }

    operation.qualityOfService = .userInitiated

    return try await withCheckedThrowingContinuation { continuation in
      operation.fetchRecordZoneChangesResultBlock = { [weak self] result in
        switch result {
        case .success:
          if !changedAreas.isEmpty || !deletedIDs.isEmpty {
            logger.info("Fetched \(changedAreas.count) changed, \(deletedIDs.count) deleted from CloudKit")
            Task { @MainActor in
              self?.onRemoteChanges?(changedAreas, deletedIDs)
            }
          }
          continuation.resume()
        case .failure(let error):
          continuation.resume(throwing: error)
        }
      }

      privateDatabase.add(operation)
    }
  }

  private func loadServerChangeToken() -> CKServerChangeToken? {
    guard let data = UserDefaults.standard.data(forKey: changeTokenKey) else {
      return nil
    }
    return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
  }

  private func saveServerChangeToken(_ token: CKServerChangeToken) {
    if let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
      UserDefaults.standard.set(data, forKey: changeTokenKey)
    }
  }

  func clearServerChangeToken() {
    UserDefaults.standard.removeObject(forKey: changeTokenKey)
  }
}

enum CloudKitError: LocalizedError {
  case notAvailable
  case recordNotFound

  var errorDescription: String? {
    switch self {
    case .notAvailable:
      return String(localized: "iCloud is not available")
    case .recordNotFound:
      return String(localized: "Record not found in CloudKit")
    }
  }
}
