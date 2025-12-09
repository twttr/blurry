#if DIRECT
import Cocoa
import Darwin

private typealias CGSIsScreenWatcherPresentFunc = @convention(c) () -> Bool

private let skyLightHandle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)
private let _CGSIsScreenWatcherPresent: CGSIsScreenWatcherPresentFunc? = {
  guard let handle = skyLightHandle,
        let sym = dlsym(handle, "CGSIsScreenWatcherPresent") else {
    return nil
  }
  return unsafeBitCast(sym, to: CGSIsScreenWatcherPresentFunc.self)
}()

@MainActor
class ScreenCaptureMonitor {
  static let shared = ScreenCaptureMonitor()
  static var isAvailable: Bool { _CGSIsScreenWatcherPresent != nil }
  
  var onCaptureStateChanged: ((Bool) -> Void)?
  
  private var isMonitoring = false
  private var timer: Timer?
  private var lastCaptureState = false
  
  private init() {}
  
  func startMonitoring() {
    guard !isMonitoring else { return }
    guard _CGSIsScreenWatcherPresent != nil else { return }
    
    isMonitoring = true
    lastCaptureState = _CGSIsScreenWatcherPresent?() ?? false
    
    if lastCaptureState {
      onCaptureStateChanged?(true)
    }
    
    timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
      guard let self else { return }
      Task { @MainActor [weak self] in
        self?.checkCaptureState()
      }
    }
  }
  
  func stopMonitoring() {
    guard isMonitoring else { return }
    timer?.invalidate()
    timer = nil
    isMonitoring = false
  }
  
  func cleanup() {
    stopMonitoring()
    onCaptureStateChanged = nil
  }
  
  var isScreenBeingCaptured: Bool {
    _CGSIsScreenWatcherPresent?() ?? false
  }
  
  private func checkCaptureState() {
    let currentState = _CGSIsScreenWatcherPresent?() ?? false
    if currentState != lastCaptureState {
      lastCaptureState = currentState
      onCaptureStateChanged?(currentState)
    }
  }
}
#endif
