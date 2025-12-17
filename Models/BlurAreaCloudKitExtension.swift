import Foundation
import CloudKit
import CoreGraphics

extension BlurArea {
  private static let recordType = "BlurArea"

  var isSyncable: Bool {
    !effectType.isPicture
  }

  func toCKRecord() -> CKRecord {
    let recordID = CKRecord.ID(recordName: id.uuidString)
    let record = CKRecord(recordType: Self.recordType, recordID: recordID)

    record["name"] = name as CKRecordValue
    record["frameX"] = frame.origin.x as CKRecordValue
    record["frameY"] = frame.origin.y as CKRecordValue
    record["frameWidth"] = frame.width as CKRecordValue
    record["frameHeight"] = frame.height as CKRecordValue
    record["isEnabled"] = (isEnabled ? 1 : 0) as CKRecordValue
    record["disableOnHover"] = (disableOnHover ? 1 : 0) as CKRecordValue

    switch effectType {
    case .blur(let radius):
      record["effectType"] = "blur" as CKRecordValue
      record["effectValue"] = radius as CKRecordValue
    case .darken(let amount):
      record["effectType"] = "darken" as CKRecordValue
      record["effectValue"] = amount as CKRecordValue
    case .picture:
      break
    }

    if let displayUUID = displayUUID {
      record["displayUUID"] = displayUUID as CKRecordValue
    }

    record["displayRelativeFrameX"] = displayRelativeFrame.origin.x as CKRecordValue
    record["displayRelativeFrameY"] = displayRelativeFrame.origin.y as CKRecordValue
    record["displayRelativeFrameWidth"] = displayRelativeFrame.width as CKRecordValue
    record["displayRelativeFrameHeight"] = displayRelativeFrame.height as CKRecordValue

    return record
  }

  init?(from record: CKRecord) {
    guard record.recordType == Self.recordType else { return nil }
    guard let idString = record.recordID.recordName as String?,
          let id = UUID(uuidString: idString) else { return nil }
    guard let name = record["name"] as? String else { return nil }

    guard let frameX = record["frameX"] as? Double,
          let frameY = record["frameY"] as? Double,
          let frameWidth = record["frameWidth"] as? Double,
          let frameHeight = record["frameHeight"] as? Double else { return nil }

    guard let effectTypeString = record["effectType"] as? String,
          let effectValue = record["effectValue"] as? Double else { return nil }

    let effectType: EffectType
    switch effectTypeString {
    case "blur":
      effectType = .blur(radius: effectValue)
    case "darken":
      effectType = .darken(amount: effectValue)
    default:
      return nil
    }

    let isEnabled = (record["isEnabled"] as? Int64 ?? 1) == 1
    let disableOnHover = (record["disableOnHover"] as? Int64 ?? 0) == 1
    let displayUUID = record["displayUUID"] as? String

    let relativeFrameX = record["displayRelativeFrameX"] as? Double ?? 0
    let relativeFrameY = record["displayRelativeFrameY"] as? Double ?? 0
    let relativeFrameWidth = record["displayRelativeFrameWidth"] as? Double ?? frameWidth
    let relativeFrameHeight = record["displayRelativeFrameHeight"] as? Double ?? frameHeight

    self.init(
      id: id,
      name: name,
      frame: CGRect(x: frameX, y: frameY, width: frameWidth, height: frameHeight),
      effectType: effectType,
      isEnabled: isEnabled,
      disableOnHover: disableOnHover,
      displayID: nil,
      displayUUID: displayUUID,
      displayRelativeFrame: CGRect(
        x: relativeFrameX,
        y: relativeFrameY,
        width: relativeFrameWidth,
        height: relativeFrameHeight
      )
    )
  }
}
