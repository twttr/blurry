import Foundation
@testable import Blurry

final class MockUserDefaults: UserDefaultsProtocol {
  var storage: [String: Any] = [:]
  var setCallCount = 0
  var dataCallCount = 0

  func data(forKey defaultName: String) -> Data? {
    dataCallCount += 1
    return storage[defaultName] as? Data
  }

  func set(_ value: Any?, forKey defaultName: String) {
    setCallCount += 1
    storage[defaultName] = value
  }

  func reset() {
    storage.removeAll()
    setCallCount = 0
    dataCallCount = 0
  }
}
