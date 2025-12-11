import Foundation
import os.log

@MainActor
class AppLogger {
  static let shared = AppLogger()
  
  private let subsystem = "io.twttr.Blurry"
  private let logger: Logger
  
  private init() {
    logger = Logger(subsystem: subsystem, category: "general")
  }
  
  func info(_ message: String) {
    logger.info("\(message)")
  }
  
  func error(_ message: String) {
    logger.error("\(message)")
  }
  
  func warning(_ message: String) {
    logger.warning("\(message)")
  }
  
  func debug(_ message: String) {
    logger.debug("\(message)")
  }
  
  // Specialized logging for restoration
  func logRestorationStart(areaCount: Int) {
    logger.info("Starting restoration of \(areaCount) areas")
  }
  
  func logRestorationSuccess(areaID: UUID, areaName: String) {
    logger.info("Successfully restored area: \(areaName) (\(areaID))")
  }
  
  func logRestorationFailure(areaID: UUID, areaName: String, reason: String) {
    logger.error("Failed to restore area: \(areaName) (\(areaID)) - Reason: \(reason)")
  }
  
  func logWindowCreationFailure(areaID: UUID, areaName: String, reason: String) {
    logger.error("Failed to create window for area: \(areaName) (\(areaID)) - Reason: \(reason)")
  }
}
