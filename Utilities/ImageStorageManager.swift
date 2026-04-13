import Foundation

@MainActor
class ImageStorageManager {
  static let shared = ImageStorageManager()

  private let imagesDirectory: URL

  private init() {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    imagesDirectory = appSupport.appendingPathComponent("Blurry/Images")
    try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
  }

  func saveImage(_ data: Data, id: UUID) -> String {
    let filename = "\(id.uuidString).png"
    let url = imagesDirectory.appendingPathComponent(filename)
    do {
      try data.write(to: url, options: .atomic)
    } catch {
      AppLogger.shared.error("Failed to save image \(filename): \(error.localizedDescription)")
    }
    return filename
  }

  func loadImage(filename: String) -> Data? {
    let url = imagesDirectory.appendingPathComponent(filename)
    return try? Data(contentsOf: url)
  }

  func deleteImage(filename: String) {
    let url = imagesDirectory.appendingPathComponent(filename)
    try? FileManager.default.removeItem(at: url)
  }

  func imageExists(filename: String) -> Bool {
    let url = imagesDirectory.appendingPathComponent(filename)
    return FileManager.default.fileExists(atPath: url.path)
  }
}
