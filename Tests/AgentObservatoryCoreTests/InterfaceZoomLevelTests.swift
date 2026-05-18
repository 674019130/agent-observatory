import XCTest
@testable import AgentObservatoryCore

final class InterfaceZoomLevelTests: XCTestCase {
    func testZoomInAndOutClampAtSupportedBounds() {
        XCTAssertEqual(InterfaceZoomLevel.standard.zoomedIn, .larger)
        XCTAssertEqual(InterfaceZoomLevel.standard.zoomedOut, .smaller)
        XCTAssertEqual(InterfaceZoomLevel.accessibility.zoomedIn, .accessibility)
        XCTAssertEqual(InterfaceZoomLevel.smallest.zoomedOut, .smallest)
    }

    func testStoredRawValueFallsBackToStandardWhenUnknown() {
        XCTAssertEqual(InterfaceZoomLevel.stored(rawValue: nil), .standard)
        XCTAssertEqual(InterfaceZoomLevel.stored(rawValue: 99), .standard)
        XCTAssertEqual(InterfaceZoomLevel.stored(rawValue: -1), .smaller)
    }

    func testZoomScaleIsVisibleAndOrdered() {
        XCTAssertEqual(InterfaceZoomLevel.standard.scale, 1.0)
        XCTAssertLessThan(InterfaceZoomLevel.smaller.scale, InterfaceZoomLevel.standard.scale)
        XCTAssertLessThan(InterfaceZoomLevel.standard.scale, InterfaceZoomLevel.larger.scale)
        XCTAssertLessThan(InterfaceZoomLevel.largest.scale, InterfaceZoomLevel.accessibility.scale)
    }
}
