import SwiftUI

@main
struct BlurryApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  
  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}
