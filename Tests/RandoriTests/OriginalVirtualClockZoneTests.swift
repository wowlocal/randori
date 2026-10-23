import Foundation
import XCTest
@testable import RandoriCore
@testable import RandoriRuntime

/// ENGINE_SPLIT E9: `--virtual-clock` pins the zone as well as the date.
final class OriginalVirtualClockZoneTests: XCTestCase {
    /// The virtual clock's zone does not follow the host: GetLocalTime reads
    /// 2026-01-01 01:00:00, a Thursday, and the startup zone has no daylight time.
    func testVirtualClockZoneIsFixed() throws {
        try MainActor.assumeIsolated {
            let zone = OriginalRuntimeSession.virtualZone, date = OriginalRuntimeSession.virtualDate
            let t = OriginalMacRuntimeLoading.localTime(date, in: zone)
            XCTAssertEqual([t.year, t.month, t.day, t.dayOfWeek, t.hour, t.minute, t.second, t.milliseconds], [2026, 1, 1, 4, 1, 0, 0, 0])
            let information = try OriginalMacRuntimeZone.information(zone, now: date)
            XCTAssertEqual(information.result, OriginalMacRuntimeZone.unknown)
            let value = try XCTUnwrap(information.value)
            XCTAssertEqual(value.bias, -60)
            XCTAssertEqual(value.standard, [Int32](repeating: 0, count: 8)); XCTAssertEqual(value.daylight, [Int32](repeating: 0, count: 8))
        }
    }
}
