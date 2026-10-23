import Foundation
import XCTest
@testable import RandoriCore
@testable import RandoriRuntime

/// ENGINE_SPLIT E10: a game started through the runtime with its own branding
/// shows and opens its own strings at every call site the session reaches, not
/// only where a test passes the branding itself. The pack is a variant of the
/// synthetic pack (`SyntheticContentPack.make`): its rules carry the invented
/// branding of OriginalGameBrandingTests and its record sets 0x44d794 (Alt+Enter
/// recreates the window only while it is nonzero, OriginalWindowLifecycle.swift:79).
/// The shared pack, and every pinned digest, keep LF2 2.0a's branding.
final class SyntheticBrandingTests: XCTestCase {
    static let branding = OriginalGameBrandingTests.invented

    static func brandedPack() throws -> SyntheticContentPack {
        let base = OriginalGameRules.syntheticPack
        let rules = OriginalGameRules(profile: base.profile, reflection: base.reflection, armour: base.armour,
            interaction: base.interaction, impact: base.impact, items: base.items, roster: base.roster, modes: base.modes,
            physics: base.physics, drawing: base.drawing, effects: base.effects, lifecycle: base.lifecycle,
            fusion: base.fusion, weaponBreak: base.weaponBreak, interface: base.interface, characterAI: base.characterAI,
            characterAISpecial: base.characterAISpecial, library: base.library, branding: branding)
        return try SyntheticContentPack.make(rules: rules, extraRecordWords: [
            .init(offset: 0x44d794, value: 1, check: "OriginalWindowLifecycle.swift:79 (E10's branded variant only)")])
    }
    static func text(_ bytes: [UInt8]) -> String { String(decoding: bytes, as: UTF8.self) }
    static func shell(_ file: [UInt8]) -> String { "shell open " + text(file) }

    /// One run: the startup's window, the front screen's credits and spans,
    /// OFFICIAL WEBSITE, the first loading's background 99, the mode screen's
    /// three credit links; then the demo notice and the mode screen's state
    /// entry on the run's own catalog.
    func testTheGamesStringsFromStartupToTheModeScreen() throws {
        let b = Self.branding
        try SyntheticContentPack.withWritten(Self.brandedPack()) { root, pack in
            try MainActor.assumeIsolated {
                let run = try SyntheticRun(root: root, pack: pack)
                // Bootstrap -> WinMain -> CreateWindowExA: the host's title, and the
                // backend accepted the request only with the game's class and title.
                XCTAssertEqual(run.windowHost.windows.map(\.title), [Self.text(b.windowTitle)])
                XCTAssertEqual(run.started.windows.operations.filter { $0.request.kind == "createWindow" }.map(\.request.strings),
                               [[b.windowClass, b.windowTitle]])
                XCTAssertEqual(run.started.host.snapshot.session?.state.branding, b)

                // The front screen: the credit lines, and the first line's spans while hovered.
                for _ in 0..<8 { _ = try run.step() }
                let y = try run.global(0x45757c) &+ 491
                run.script[9, default: []].append(.mouse(0x200, x: 650, y: y &+ 10, buttons: 0))
                run.script[12, default: []].append(.mouse(0x200, x: 720, y: y &+ 10, buttons: 0))
                // OFFICIAL WEBSITE: the main menu's fifth row (OriginalMainMenu.swift:166-167).
                run.click(x: 398, y: try run.global(0x453da4) &+ 202 &+ 150, at: 15)
                try run.run(limit: 40) { run.committed >= 30 }
                let drawn = run.log.texts
                for line in b.credits + [Array(b.credits[0][3..<13]), Array(b.credits[0][15..<27])] {
                    XCTAssertTrue(drawn.contains(line), Self.text(line))
                }
                for line in OriginalGameRules.Branding.lf2.credits { XCTAssertFalse(drawn.contains(line), Self.text(line)) }
                XCTAssertEqual(run.log.shown, [Self.shell(b.website)])

                // START, the first loading: background 99's name in the catalog.
                try run.clickStart(at: run.committed + 1)
                while run.cycles == 0 && run.steps < 200 { _ = try run.step() }
                let match = try XCTUnwrap(run.match)
                let built = match.catalog.backgrounds[99].bytes
                XCTAssertEqual(Array(built[0x3cc..<built[0x3cc...].firstIndex(of: 0)!]), b.builtInBackgroundName)

                // The loaded menu's mode screen: a fresh press on each credit span.
                var at = run.cycles
                for x: Int32 in [600, 650, 720] {
                    let py = x == 600 ? y &+ 45 : y &+ 10
                    run.loadedScript[at, default: []].append(.mouse(0x200, x: x, y: py, buttons: 0))
                    run.loadedScript[at + 2, default: []].append(.mouse(0x201, x: x, y: py, buttons: 1))
                    run.loadedScript[at + 4, default: []].append(.mouse(0x202, x: x, y: py, buttons: 0))
                    at += 6
                }
                try run.run(limit: 60) { run.cycles >= at + 2 }
                XCTAssertEqual(run.log.shown, [Self.shell(b.website)] + b.creditLinks.map(Self.shell))

                // The demo notice (0x450c2c = 1) on the run's catalog: its third credit line.
                var demo = match
                try demo.globals.write(Int32(1), at: 0x450c2c - OriginalMatchPreparation.globalBase)
                var notice = try OriginalStateRecord(bytes: [UInt8](repeating: 0, count: OriginalPostHUDNotices.localSize),
                                                     defined: [Bool](repeating: true, count: OriginalPostHUDNotices.localSize))
                var noticeTexts: [[UInt8]] = []
                do {
                    try OriginalPostHUDNotices.apply(state: demo, local: &notice, dcResult: 0, dc: 0x1234,
                        fillBacking: { [UInt8](repeating: 0, count: 100) }, resourceBitmap: { _ in throw SyntheticRunError.noState },
                        performFill: { _ in 0 }, performBlit: { _ in 0 }, observe: { e in if e.kind == "text" { noticeTexts += e.strings } })
                } catch SyntheticRunError.noState {}
                XCTAssertTrue(noticeTexts.contains(b.credits[2]), "\(noticeTexts.map(Self.text))")

                // OriginalModeScreen.advance(state:) on the run's catalog: the three lines.
                var screen = match, memory = OriginalMenuPresentationMemory(replayPointers: try OriginalStateRecord(
                    bytes: [UInt8](repeating: 0, count: 8), defined: [Bool](repeating: true, count: 8)))
                var local = try OriginalStateRecord(bytes: [UInt8](repeating: 0, count: 0x704), defined: [Bool](repeating: false, count: 0x704))
                var screenTexts: [[UInt8]] = []
                _ = try? OriginalModeScreen.advance(state: &screen, memory: &memory, local: &local, worldAddress: 0x458b00, target: 1,
                    input: .init(dcResult: 0, dc: 0x1234, methodResult: 0, drawResults: [0], shellResult: 0),
                    fillBacking: [UInt8](repeating: 0, count: 100), background: { _, _ in }, update: { _ in }, panel: { _ in },
                    draw: { _, _, _ in }, observe: { e in if e.kind == "textOut" { screenTexts += e.strings } })
                XCTAssertEqual(Array(screenTexts.prefix(3)), b.credits)
            }
        }
    }

    /// Alt+Enter recreates the window through the session's lifecycle call with
    /// the game's names; ESC's quit dialog has the game's caption.
    func testAltEnterAndQuitUseTheGamesStrings() throws {
        let b = Self.branding
        try SyntheticContentPack.withWritten(Self.brandedPack()) { root, pack in
            try MainActor.assumeIsolated {
                let run = try SyntheticRun(root: root, pack: pack)
                try run.run(limit: 10) { run.committed >= 8 }
                run.script[9] = [.key(0x12, down: true)]; run.script[10] = [.key(0x0d, down: true)]
                run.script[11] = [.key(0x0d, down: false)]; run.script[12] = [.key(0x12, down: false)]
                try run.run(limit: 30) { run.windowHost.windows.count == 2 && run.committed >= 16 }
                XCTAssertEqual(run.windowHost.windows.map(\.title), [Self.text(b.windowTitle), Self.text(b.windowTitle)])
                XCTAssertEqual(run.started.windows.operations.filter { $0.request.kind == "createWindow" }.map(\.request.strings),
                               [[b.windowClass, b.windowTitle], [b.windowClass, b.windowTitle]])
                run.script[run.committed + 1] = [.key(0x1b, down: true)]
                XCTAssertThrowsError(try run.run(limit: 20) { false }) { error in
                    XCTAssertEqual(error as? SyntheticRunError, .messageBox("Are you sure to quit?"))
                }
                XCTAssertEqual(run.log.shown, ["box " + Self.text(b.shortName) + ": Are you sure to quit?"])
            }
        }
    }

    /// CONTROL SETTINGS' help link (rect 46..540 x 475..498,
    /// OriginalFrontControlSettings.swift:74-80), reached from the main menu's third row.
    func testControlSettingsHelpIsTheGames() throws {
        let b = Self.branding
        try SyntheticContentPack.withWritten(Self.brandedPack()) { root, pack in
            try MainActor.assumeIsolated {
                let run = try SyntheticRun(root: root, pack: pack)
                try run.run(limit: 10) { run.committed >= 8 }
                run.click(x: 398, y: try run.global(0x453da4) &+ 202 &+ 90, at: 9)
                try run.run(limit: 40) { try run.global(0x44d064) == 6 && run.committed >= 22 }
                run.click(x: 100, y: 485, at: run.committed + 1, frames: 4)
                try run.run(limit: 40) { !run.log.shown.isEmpty }
                XCTAssertEqual(Set(run.log.shown), [Self.shell(b.controlHelp)])
            }
        }
    }

    /// RECORDING INFO's help link (44..483 x 461..484), its OK (page 8) and
    /// the challenge link (96..639 x 348..372), OriginalFrontRecordingInfo.swift.
    func testRecordingInfoLinksAreTheGames() throws {
        let b = Self.branding
        try SyntheticContentPack.withWritten(Self.brandedPack()) { root, pack in
            try MainActor.assumeIsolated {
                let run = try SyntheticRun(root: root, pack: pack)
                try run.run(limit: 10) { run.committed >= 8 }
                run.click(x: 398, y: try run.global(0x453da4) &+ 202 &+ 120, at: 9)
                try run.run(limit: 40) { try run.global(0x44d064) == 7 && run.committed >= 22 }
                run.click(x: 100, y: 470, at: run.committed + 1, frames: 4)
                try run.run(limit: 40) { !run.log.shown.isEmpty }
                XCTAssertEqual(Set(run.log.shown), [Self.shell(b.recordingHelp)])
                run.click(x: 300, y: 428, at: run.committed + 4, frames: 4)
                try run.run(limit: 40) { try run.global(0x44d064) == 8 && run.committed >= 50 }
                run.click(x: 300, y: 360, at: run.committed + 1, frames: 4)
                let before = run.log.shown.count
                try run.run(limit: 40) { run.log.shown.count > before }
                XCTAssertEqual(Set(run.log.shown.dropFirst(before)), [Self.shell(b.challenge)])
            }
        }
    }
}
