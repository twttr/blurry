import XCTest
import Combine
@testable import Blurry

@MainActor
final class AreaManagerTests: XCTestCase {
  var mockUserDefaults: MockUserDefaults!
  var sut: AreaManager!
  var cancellables: Set<AnyCancellable>!

  override func setUp() async throws {
    try await super.setUp()
    mockUserDefaults = MockUserDefaults()
    sut = AreaManager(userDefaults: mockUserDefaults, storageKey: "TestAreas")
    cancellables = []
  }

  override func tearDown() async throws {
    cancellables = nil
    sut = nil
    mockUserDefaults = nil
    try await super.tearDown()
  }

  func testInitializationWithEmptyStorage() async {
    XCTAssertTrue(sut.areas.isEmpty)
    XCTAssertEqual(mockUserDefaults.dataCallCount, 1)
  }

  func testInitializationLoadsExistingAreas() async throws {
    let existingArea = TestHelpers.makeBlurArea(name: "Existing")
    let data = try JSONEncoder().encode([existingArea])
    mockUserDefaults.storage["TestAreas"] = data

    let manager = AreaManager(userDefaults: mockUserDefaults, storageKey: "TestAreas")

    XCTAssertEqual(manager.areas.count, 1)
    XCTAssertEqual(manager.areas.first?.name, "Existing")
  }

  func testAddArea() async {
    let area = TestHelpers.makeBlurArea(name: "New Area")

    sut.add(area)

    XCTAssertEqual(sut.areas.count, 1)
    XCTAssertEqual(sut.areas.first?.name, "New Area")
    XCTAssertEqual(mockUserDefaults.setCallCount, 1)
  }

  func testAddMultipleAreas() async {
    let area1 = TestHelpers.makeBlurArea(name: "Area 1")
    let area2 = TestHelpers.makeBlurArea(name: "Area 2")

    sut.add(area1)
    sut.add(area2)

    XCTAssertEqual(sut.areas.count, 2)
    XCTAssertEqual(mockUserDefaults.setCallCount, 2)
  }

  func testRemoveArea() async {
    let area = TestHelpers.makeBlurArea(name: "To Remove")
    sut.add(area)
    let initialSetCount = mockUserDefaults.setCallCount

    sut.remove(withID: area.id)

    XCTAssertTrue(sut.areas.isEmpty)
    XCTAssertEqual(mockUserDefaults.setCallCount, initialSetCount + 1)
  }

  func testRemoveNonExistentArea() async {
    let area = TestHelpers.makeBlurArea()
    sut.add(area)
    let initialSetCount = mockUserDefaults.setCallCount

    sut.remove(withID: UUID())

    XCTAssertEqual(sut.areas.count, 1)
    XCTAssertEqual(mockUserDefaults.setCallCount, initialSetCount + 1)
  }

  func testUpdateArea() async {
    var area = TestHelpers.makeBlurArea(name: "Original")
    sut.add(area)

    area.name = "Updated"
    sut.update(area)

    XCTAssertEqual(sut.areas.first?.name, "Updated")
  }

  func testUpdateNonExistentArea() async {
    let area = TestHelpers.makeBlurArea(name: "Original")
    sut.add(area)
    let initialSetCount = mockUserDefaults.setCallCount

    let nonExistent = TestHelpers.makeBlurArea(name: "Non-existent")
    sut.update(nonExistent)

    XCTAssertEqual(sut.areas.count, 1)
    XCTAssertEqual(sut.areas.first?.name, "Original")
    XCTAssertEqual(mockUserDefaults.setCallCount, initialSetCount)
  }

  func testToggleEnabled() async {
    let area = TestHelpers.makeBlurArea(isEnabled: true)
    sut.add(area)

    sut.toggleEnabled(for: area.id)

    XCTAssertFalse(sut.areas.first?.isEnabled ?? true)

    sut.toggleEnabled(for: area.id)

    XCTAssertTrue(sut.areas.first?.isEnabled ?? false)
  }

  func testToggleEnabledNonExistentArea() async {
    let area = TestHelpers.makeBlurArea(isEnabled: true)
    sut.add(area)
    let initialSetCount = mockUserDefaults.setCallCount

    sut.toggleEnabled(for: UUID())

    XCTAssertTrue(sut.areas.first?.isEnabled ?? false)
    XCTAssertEqual(mockUserDefaults.setCallCount, initialSetCount)
  }

  func testRemoveAll() async {
    sut.add(TestHelpers.makeBlurArea(name: "Area 1"))
    sut.add(TestHelpers.makeBlurArea(name: "Area 2"))
    sut.add(TestHelpers.makeBlurArea(name: "Area 3"))

    sut.removeAll()

    XCTAssertTrue(sut.areas.isEmpty)
  }

  func testReplaceAll() async {
    sut.add(TestHelpers.makeBlurArea(name: "Original"))

    let newAreas = [
      TestHelpers.makeBlurArea(name: "New 1"),
      TestHelpers.makeBlurArea(name: "New 2")
    ]
    sut.replaceAll(with: newAreas)

    XCTAssertEqual(sut.areas.count, 2)
    XCTAssertEqual(sut.areas[0].name, "New 1")
    XCTAssertEqual(sut.areas[1].name, "New 2")
  }

  func testBatchUpdateSuppressesSaves() async {
    sut.beginBatchUpdate()
    let initialSetCount = mockUserDefaults.setCallCount

    sut.add(TestHelpers.makeBlurArea(name: "Area 1"))
    sut.add(TestHelpers.makeBlurArea(name: "Area 2"))
    sut.add(TestHelpers.makeBlurArea(name: "Area 3"))

    XCTAssertEqual(mockUserDefaults.setCallCount, initialSetCount)
    XCTAssertEqual(sut.areas.count, 3)
  }

  func testEndBatchUpdateTriggersSave() async {
    sut.beginBatchUpdate()

    sut.add(TestHelpers.makeBlurArea(name: "Area 1"))
    sut.add(TestHelpers.makeBlurArea(name: "Area 2"))

    let countBeforeEnd = mockUserDefaults.setCallCount
    sut.endBatchUpdate()

    XCTAssertEqual(mockUserDefaults.setCallCount, countBeforeEnd + 1)
  }

  func testBatchUpdateRemoveOperations() async {
    let area1 = TestHelpers.makeBlurArea(name: "Area 1")
    let area2 = TestHelpers.makeBlurArea(name: "Area 2")
    sut.add(area1)
    sut.add(area2)

    sut.beginBatchUpdate()
    let countBeforeBatch = mockUserDefaults.setCallCount

    sut.remove(withID: area1.id)
    sut.remove(withID: area2.id)

    XCTAssertEqual(mockUserDefaults.setCallCount, countBeforeBatch)

    sut.endBatchUpdate()

    XCTAssertEqual(mockUserDefaults.setCallCount, countBeforeBatch + 1)
    XCTAssertTrue(sut.areas.isEmpty)
  }

  func testPublishedAreasEmitsOnAdd() async {
    var receivedAreas: [[BlurArea]] = []
    let expectation = XCTestExpectation(description: "Areas published")

    sut.areasPublisher
      .dropFirst()
      .sink { areas in
        receivedAreas.append(areas)
        expectation.fulfill()
      }
      .store(in: &cancellables)

    sut.add(TestHelpers.makeBlurArea())

    await fulfillment(of: [expectation], timeout: 1.0)
    XCTAssertEqual(receivedAreas.count, 1)
    XCTAssertEqual(receivedAreas.first?.count, 1)
  }

  func testLoadHandlesCorruptedData() async {
    mockUserDefaults.storage["TestCorrupted"] = Data([0x00, 0x01, 0x02])

    let manager = AreaManager(userDefaults: mockUserDefaults, storageKey: "TestCorrupted")

    XCTAssertTrue(manager.areas.isEmpty)
  }

  func testSavePersistsCorrectly() async throws {
    let area = TestHelpers.makeBlurArea(name: "Persist Test")
    sut.add(area)

    guard let savedData = mockUserDefaults.storage["TestAreas"] as? Data else {
      XCTFail("No data saved")
      return
    }

    let decoded = try JSONDecoder().decode([BlurArea].self, from: savedData)
    XCTAssertEqual(decoded.count, 1)
    XCTAssertEqual(decoded.first?.name, "Persist Test")
  }

  func testMultipleUpdatesInBatchMode() async {
    var area = TestHelpers.makeBlurArea(name: "Original", isEnabled: true)
    sut.add(area)

    sut.beginBatchUpdate()
    let countBeforeBatch = mockUserDefaults.setCallCount

    area.name = "Updated 1"
    sut.update(area)
    area.name = "Updated 2"
    sut.update(area)
    sut.toggleEnabled(for: area.id)

    XCTAssertEqual(mockUserDefaults.setCallCount, countBeforeBatch)

    sut.endBatchUpdate()

    XCTAssertEqual(mockUserDefaults.setCallCount, countBeforeBatch + 1)
    XCTAssertEqual(sut.areas.first?.name, "Updated 2")
    XCTAssertFalse(sut.areas.first?.isEnabled ?? true)
  }
}
