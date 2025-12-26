#if ENABLE_SPARKLE
import Sparkle

@MainActor
final class SparkleUpdater {
  private var controller: SPUStandardUpdaterController?

  var isAvailable: Bool { controller != nil }
  var canCheckForUpdates: Bool { controller?.updater.canCheckForUpdates ?? false }
  var lastUpdateCheckDate: Date? { controller?.updater.lastUpdateCheckDate }

  var automaticallyChecksForUpdates: Bool {
    get { controller?.updater.automaticallyChecksForUpdates ?? false }
    set { controller?.updater.automaticallyChecksForUpdates = newValue }
  }

  init() {
    if Self.isProperAppBundle() {
      controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
      )
    }
  }

  func checkForUpdates() {
    guard let controller = controller, controller.updater.canCheckForUpdates else { return }
    controller.checkForUpdates(nil)
  }

  func checkForUpdatesInBackground() {
    controller?.updater.checkForUpdatesInBackground()
  }

  private static func isProperAppBundle() -> Bool {
    let bundle = Bundle.main
    guard bundle.bundlePath.hasSuffix(".app"),
          let info = bundle.infoDictionary,
          info["CFBundleIdentifier"] != nil,
          info["CFBundleVersion"] != nil,
          info["SUFeedURL"] != nil else {
      return false
    }
    return true
  }
}
#endif
