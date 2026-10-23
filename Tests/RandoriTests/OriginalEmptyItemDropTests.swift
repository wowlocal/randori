import Foundation
import XCTest
@testable import RandoriCore

/// ENGINE_SPLIT E9: the random item drop with no candidate. 417170 answers 0
/// for the empty range without touching the RNG; 41f128 then reads candidate 0
/// from stack the call has not written. A full pool after a reserve respawn
/// faults first (41f139). A small synthetic pool on the engine tests' rules.
final class OriginalEmptyItemDropTests: XCTestCase {
    private func zero(_ count: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0, count: count), defined: [Bool](repeating: true, count: count))
    }
    /// Object 0 (ID 300, outside the item range, type 5: neither counted as an
    /// item nor resolved as a character) fills every slot of a full pool, or
    /// every slot but 120. The first draw (146 over 200) answers 0: a drop.
    private func drop(full: Bool, itemSlot: OriginalRequestSlotWord?) throws -> (events: [OriginalHitEvent], error: String?) {
        var world = try zero(0x7d8)
        for slot in 0..<400 where full || slot != 120 { try world.write(UInt8(1), at: 4+slot) }
        var globals = try zero(0xb440)
        for n in 0..<3000 { try globals.write(UInt8(1), at: 0x44ff90-0x44d000+n) }
        try globals.write(UInt8(199), at: 0x44ff90-0x44d000+1)
        var header = try zero(0x7a4); try header.write(Int32(300), at: 0x6f4); try header.write(Int32(5), at: 0x6f8)
        var background = try zero(16); try background.write(Int32(800), at: 0); try background.write(Int32(400), at: 8)
        let frameRecord = try zero(0x178), headerRecord = header, bg = background
        var pass = OriginalHitPass(world: world, actors: [try zero(0x420)], globals: globals, memory: OriginalContactFrameMemory([]),
            crt: OriginalCRTRandom(state: 1), objectCount: 1, header: { _ in headerRecord }, frame: { _, _ in frameRecord },
            rules: .engineTests, sse2: false)
        var events: [OriginalHitEvent] = []
        do { try pass.advance(itemSlot: itemSlot, background: { _ in bg }, observe: { events.append($0) }) } catch { return (events, "\(error)") }
        return (events, nil)
    }

    func testEmptyItemListOutcomes() throws {
        let unknownError = OriginalStateError.invalidStorage("Source state unknown: no item candidate; the random item reads candidate 0 "
            + "from stack this call has not written (41f128)")
        let unknown = "\(unknownError)"
        for (full, word, label) in [(false, OriginalRequestSlotWord?.none, "free slot"), (true, nil, "full pool, no word"),
                                    (true, .respawn(), "full pool after a respawn")] {
            let r = try drop(full: full, itemSlot: word)
            XCTAssertEqual(r.events.first, .random(stream: 146, range: 200, result: 0), label)
            XCTAssertEqual(r.events.last, .random(stream: 154, range: 0, result: 0), label)
            XCTAssertFalse(r.events.contains { if case .reconstruct = $0 { return true }; return false }, label)
            if word == nil { XCTAssertEqual(r.error, unknown, label) }
            else {
                let text = try XCTUnwrap(r.error, label)
                XCTAssertTrue(text.contains("Source fault:") && text.contains("0xff2f6088"), label+": "+text)
            }
        }
    }
}
