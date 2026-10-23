import XCTest
@testable import RandoriCore

/// ENGINE_SPLIT E10: a game's branding (OriginalGameRules.Branding) replaces
/// LF2 2.0a's strings where the EXE model shows or opens them; LF2's are the
/// default. Every branding here but `.lf2` is invented.
final class OriginalGameBrandingTests: XCTestCase {
    /// The first credit line's clickable spans, bytes 3..<13 and 15..<27, are
    /// its two names, "Ann Sample" and "Bob Samplers".
    static let invented = try! OriginalGameRules.Branding(windowClass: Array("SyClass".utf8),
        windowTitle: Array("Synthetic Brawl".utf8), shortName: Array("SYB".utf8),
        credits: [Array("by Ann Sample, Bob Samplers".utf8), Array("2026-2027, no rights reserved.".utf8),
                  Array("http://www.synthetic.example".utf8)],
        creditLinks: [Array("http://synthetic.example".utf8), Array("http://ann.example".utf8), Array("http://bob.example".utf8)],
        website: Array("http://synthetic.example/home".utf8), controlHelp: Array("http://synthetic.example/controls".utf8),
        recordingHelp: Array("http://synthetic.example/record".utf8), challenge: Array("http://synthetic.example/challenge".utf8),
        advertise: Array("http://synthetic.example/ads".utf8), forum: Array("http://synthetic.example/forum".utf8),
        builtInBackgroundName: Array("Sy Built In".utf8))

    private func record(_ count: Int) throws -> OriginalStateRecord {
        try OriginalStateRecord(bytes: [UInt8](repeating: 0, count: count), defined: [Bool](repeating: true, count: count))
    }
    private func globals(_ words: [(Int, Int32)] = []) throws -> OriginalStateRecord {
        var globals = try record(OriginalMatchPreparation.globalSize)
        for (address, value) in words { try globals.write(value, at: address-OriginalMatchPreparation.globalBase) }
        return globals
    }

    /// The public initializer's checks run on `b`'s fields.
    static func rebuilt(_ b: OriginalGameRules.Branding, windowClass: [UInt8]? = nil, windowTitle: [UInt8]? = nil,
                        shortName: [UInt8]? = nil, credits: [[UInt8]]? = nil, creditLinks: [[UInt8]]? = nil,
                        background: [UInt8]? = nil) throws -> OriginalGameRules.Branding {
        try .init(windowClass: windowClass ?? b.windowClass, windowTitle: windowTitle ?? b.windowTitle, shortName: shortName ?? b.shortName,
                  credits: credits ?? b.credits, creditLinks: creditLinks ?? b.creditLinks, website: b.website,
                  controlHelp: b.controlHelp, recordingHelp: b.recordingHelp, challenge: b.challenge, advertise: b.advertise,
                  forum: b.forum, builtInBackgroundName: background ?? b.builtInBackgroundName)
    }

    /// The obfuscated credit literals the EXE model copies and its links are
    /// LF2's branding encoded, and the LF2 rules carry it by default. `.lf2` is
    /// built without the checks; they accept it.
    func testLF2BrandingIsTheEXELiterals() throws {
        let lf2 = OriginalGameRules.Branding.lf2
        XCTAssertEqual(try Self.rebuilt(lf2), lf2)
        XCTAssertEqual(Array(Self.invented.credits[0][3..<13]), Array("Ann Sample".utf8))
        XCTAssertEqual(Array(Self.invented.credits[0][15..<27]), Array("Bob Samplers".utf8))
        XCTAssertEqual(lf2.encodedCredits, OriginalFrontScreenBody.literals.map { $0.bytes })
        XCTAssertEqual(lf2.creditLinks, OriginalFrontScreenBody.links.prefix(3).map { $0.bytes })
        XCTAssertEqual(lf2.credits.map(\.count), OriginalGameRules.Branding.creditLengths)
        let decoded = lf2.encodedCredits.map { line in line.dropLast().enumerated().map { $0.element &- UInt8($0.offset & 3) } }
        XCTAssertEqual(decoded, lf2.credits)
        let interface = OriginalGameRules.engineTests.interface
        XCTAssertEqual(OriginalGameRules.lf2(profile: "p", interface: interface).branding, .lf2)
        XCTAssertEqual(OriginalGameRules.engineTests.branding, .lf2)
        let branded = OriginalGameRules.lf2(profile: "p", interface: interface, branding: Self.invented)
        XCTAssertEqual(branded.branding, Self.invented)
        XCTAssertNotEqual(branded, OriginalGameRules.lf2(profile: "p", interface: interface))
    }

    /// CreateWindowExA's class and window names (the host's title).
    func testWindowNamesAreTheGames() throws {
        func names(_ branding: OriginalGameRules.Branding?) throws -> [[UInt8]]? {
            var state = try globals(), strings: [[UInt8]]?
            let perform: (OriginalWindowInitialization.Request) throws -> OriginalWindowInitialization.Response = { q in
                if q.kind == "createWindow" { strings = q.strings }
                return .init()
            }
            let backing: (String, Int) throws -> [UInt8] = { _, count in [UInt8](repeating: 0, count: count) }
            if let branding {
                _ = try OriginalWindowInitialization.initialize(instance: 0x400000, show: 10, globals: &state, backing: backing,
                                                                perform: perform, branding: branding)
            } else {
                _ = try OriginalWindowInitialization.initialize(instance: 0x400000, show: 10, globals: &state, backing: backing, perform: perform)
            }
            return strings
        }
        XCTAssertEqual(try names(nil), [Array("Marti".utf8), Array("Little Fighter 2".utf8)])
        XCTAssertEqual(try names(Self.invented), [Self.invented.windowClass, Self.invented.windowTitle])
    }

    /// The front screen copies the encoded first credit line and draws it decoded
    /// (a null back surface stops the body after its first text).
    func testFrontScreenDrawsTheGamesCredits() throws {
        func firstText(_ branding: OriginalGameRules.Branding?) throws -> [[UInt8]]? {
            var state = try globals(), local = try record(0xc0), strings: [[UInt8]]?
            let input = OriginalFrontScreenBodyInput(dcResult: 0, dc: 0, methodResult: 0, drawResults: [], shellResult: 0)
            let observe: (OriginalFrontScreenEvent) throws -> Void = { e in if e.kind == "text" && strings == nil { strings = e.strings } }
            let end: OriginalFrontScreenBody.Continuation
            if let branding {
                end = try OriginalFrontScreenBody.advance(globals: &state, local: &local, input: input, draw: { _ in }, observe: observe,
                                                          branding: branding)
            } else {
                end = try OriginalFrontScreenBody.advance(globals: &state, local: &local, input: input, draw: { _ in }, observe: observe)
            }
            XCTAssertEqual(end, .nullTextTarget)
            return strings
        }
        XCTAssertEqual(try firstText(nil), [Array("by Marti Wong, Starsky Wong".utf8)])
        XCTAssertEqual(try firstText(Self.invented), [Self.invented.credits[0]])
    }

    /// ESC's MessageBoxA caption.
    func testQuitCaptionIsTheGames() throws {
        func caption(_ branding: OriginalGameRules.Branding?) throws -> [[UInt8]]? {
            var state = try globals(), local = try record(OriginalWindowInput.localCount)
            var memory = OriginalMenuPresentationMemory(replayPointers: try record(8)), strings: [[UInt8]]?
            let escape = OriginalWindowInput.Message(window: 7, message: 0x100, wParam: 27, lParam: 0)
            let request: (OriginalWindowInput.Request) throws -> Int32 = { q in
                if q.kind == .message { strings = q.strings }
                return 7 // IDNO
            }
            let result: Int32
            if let branding {
                result = try OriginalWindowInput.receive(escape, globals: &state, local: &local, memory: &memory, request: request,
                                                         branding: branding)
            } else {
                result = try OriginalWindowInput.receive(escape, globals: &state, local: &local, memory: &memory, request: request)
            }
            XCTAssertEqual(result, 0)
            return strings
        }
        XCTAssertEqual(try caption(nil), [Array("Are you sure to quit?".utf8), Array("LF2".utf8)])
        XCTAssertEqual(try caption(Self.invented), [Array("Are you sure to quit?".utf8), Self.invented.shortName])
    }

    /// The main menu's OFFICIAL WEBSITE row (row 5), clicked.
    func testMainMenuWebsiteIsTheGames() throws {
        func opened(_ branding: OriginalGameRules.Branding?) throws -> [[UInt8]]? {
            var world = try record(OriginalStateRecord.worldPrefixSize)
            var state = try globals([(0x4546f0, 300), (0x453cdc, 202+140), (0x457580, 1)]), crt = OriginalCRTRandom()
            let input = OriginalMainMenuInput(targetSurface: 1, panelWord: nil, network: .init(startupResult: 0, version: 0,
                hostnameResult: 0, hostname: [], hostEntryAddress: 0, addresses: [], socketResult: 0, asyncResult: 0, bindResult: 0, listenResult: 0))
            var strings: [[UInt8]]?
            let observe: (OriginalMainMenuEvent) throws -> Void = { e in if e.kind == .shell { strings = e.strings } }
            let end: OriginalMainMenuExit
            if let branding {
                end = try OriginalMainMenu.run(world: &world, globals: &state, crt: &crt, input: input, branding: branding, observe: observe)
            } else {
                end = try OriginalMainMenu.run(world: &world, globals: &state, crt: &crt, input: input, observe: observe)
            }
            XCTAssertEqual(end, .present)
            return strings
        }
        XCTAssertEqual(try opened(nil), [Array("open".utf8), Array("http://littlefighter.com".utf8)])
        XCTAssertEqual(try opened(Self.invented), [Array("open".utf8), Self.invented.website])
    }

    /// The replay loader's two rejections name the game; every other byte stays.
    func testReplayRejectionsNameTheGame() throws {
        /// The data checksum (+0x744 vs 44f620, here 0) differs, or the version
        /// (+0x748 vs 44d03c, here 0x1f) is 0x1e.
        func message(_ branding: OriginalGameRules.Branding?, checksumDiffers: Bool) throws -> [UInt8]? {
            var recording = try record(0x900), state = try globals([(0x44d03c, 0x1f)])
            if checksumDiffers { try recording.write(Int32(1), at: 0x744) } else { try recording.write(Int32(0x1e), at: 0x748) }
            let start: OriginalReplayPlayback.Start
            if let branding { start = try OriginalReplayPlayback.start(recording: recording, globals: &state, branding: branding) }
            else { start = try OriginalReplayPlayback.start(recording: recording, globals: &state) }
            guard case .rejected(let text) = start else { return nil }
            return text
        }
        let checksum = "Error!  Recording file are recorded in a LF2 with some data files (character or stage files) different from yours.  Your LF2 has to use the same set of data files in order in replay this recording file!"
        let version = "Version error.  Recording file are recorded in v2.0. (your LF2 is )!"
        XCTAssertEqual(try message(nil, checksumDiffers: true), Array(checksum.utf8))
        XCTAssertEqual(try message(nil, checksumDiffers: false), Array(version.utf8))
        XCTAssertEqual(try message(Self.invented, checksumDiffers: true), Array(checksum.replacingOccurrences(of: "LF2", with: "SYB").utf8))
        XCTAssertEqual(try message(Self.invented, checksumDiffers: false), Array(version.replacingOccurrences(of: "LF2", with: "SYB").utf8))
    }

    /// Background 99's name in the catalog parent's built-in record.
    func testBuiltInBackgroundNameIsTheGames() throws {
        func name(_ branding: OriginalGameRules.Branding?) throws -> [UInt8] {
            let backing = Dictionary(uniqueKeysWithValues: try OriginalCatalogRegistry.regionSizes.map { ($0.key, try record($0.value)) })
            let registry: OriginalCatalogRegistry
            if let branding {
                registry = try OriginalCatalogRegistry(source: Array("x".utf8), fileName: Array("sy.txt".utf8), initialChecksum: 0,
                                                       backing: backing, branding: branding)
            } else {
                registry = try OriginalCatalogRegistry(source: Array("x".utf8), fileName: Array("sy.txt".utf8), initialChecksum: 0,
                                                       backing: backing)
            }
            let bytes = registry.records[0x4d81060]!.bytes
            return Array(bytes[0x3cc..<bytes[0x3cc...].firstIndex(of: 0)!])
        }
        XCTAssertEqual(try name(nil), Array("Lee On Road".utf8))
        XCTAssertEqual(try name(Self.invented), Self.invented.builtInBackgroundName)
    }

    /// The fields the model cannot hold are rejected: credit lines of other
    /// lengths or with bytes outside printable ASCII, window names or a short
    /// name outside printable ASCII, a NUL inside a URL, a background name
    /// longer than 29 bytes.
    func testInvalidBrandingIsRejected() {
        let b = Self.invented
        func rejected(_ field: String, _ attempt: () throws -> OriginalGameRules.Branding, line: UInt = #line) {
            XCTAssertThrowsError(try attempt(), line: line) { error in
                XCTAssertEqual(error as? OriginalGameRules.Branding.Invalid, OriginalGameRules.Branding.Invalid(field: field), line: line)
            }
        }
        XCTAssertEqual(try Self.rebuilt(b), b)
        rejected("credits") { try Self.rebuilt(b, credits: [b.credits[0] + [0x2e], b.credits[1], b.credits[2]]) }
        rejected("credits") { try Self.rebuilt(b, credits: [b.credits[0], Array(b.credits[1].dropLast()), b.credits[2]]) }
        rejected("credits") { try Self.rebuilt(b, credits: [b.credits[0], b.credits[1], b.credits[2] + b.credits[2]]) }
        rejected("credits") { try Self.rebuilt(b, credits: [b.credits[0], b.credits[1]]) }
        rejected("credits") { try Self.rebuilt(b, credits: [b.credits[0], b.credits[1], [0x09] + b.credits[2].dropFirst()]) }
        rejected("credits") { try Self.rebuilt(b, credits: [b.credits[0], b.credits[1], [0x7f] + b.credits[2].dropFirst()]) }
        rejected("creditLinks") { try Self.rebuilt(b, creditLinks: Array(b.creditLinks.prefix(2))) }
        rejected("creditLinks") { try Self.rebuilt(b, creditLinks: [b.creditLinks[0], b.creditLinks[1] + [0], b.creditLinks[2]]) }
        rejected("windowClass") { try Self.rebuilt(b, windowClass: [0x53, 0x0a]) }
        rejected("windowTitle") { try Self.rebuilt(b, windowTitle: Array("Synthétique".utf8)) }
        rejected("shortName") { try Self.rebuilt(b, shortName: [0x53, 0, 0x42]) }
        rejected("shortName") { try Self.rebuilt(b, shortName: [0x53, 0x7f]) }
        rejected("builtInBackgroundName") { try Self.rebuilt(b, background: [UInt8](repeating: 0x61, count: 30)) }
        XCTAssertNoThrow(try Self.rebuilt(b, background: [UInt8](repeating: 0x61, count: 29)))
    }

    /// 43e890's recreation after a failed restore (OriginalApplicationRecovery).
    func testRecoveryRecreatesTheGamesWindow() throws {
        var state = try globals([(0x455608, 0x100)]), context = 0, strings: [[UInt8]]?
        _ = try OriginalApplicationRecovery.recover(globals: &state, context: &context,
            backing: { _, count in [UInt8](repeating: 0, count: count) }, perform: { q, _ in
                if q.kind == "createWindow" { strings = q.strings }
                return .init(result: q.kind == "restore" ? -1 : 0)
            }, branding: Self.invented)
        XCTAssertEqual(strings, [Self.invented.windowClass, Self.invented.windowTitle])
    }

    /// The loading panel's advertising link (x <= 146, y >= 535;
    /// OriginalLibLoadingProgress.swift:91-94), on its second drawn update.
    func testLoadingAdvertiseIsTheGames() throws {
        var state = try globals([(0x455608, 0x100), (0x4546f0, 10), (0x453cdc, 540), (0x457580, 1)])
        var text = OriginalLibSurfaceText(), clock: UInt32 = 1000, opened: [[UInt8]]?
        let labels = OriginalLibData.LoadingLabels(belowTwo: Array("a".utf8), fiveToSeven: Array("b".utf8), others: Array("c".utf8))
        let input = OriginalMenuPresentationInput(targetSurface: 1, methodResult: 0, queryResult: 0, audioGetResult: 0,
                                                  audioSetResult: 0, queriedAudio: 0, audioVolume: 0, dcResult: 0, dc: 0x1234, postResult: 0)
        for _ in 0..<2 {
            try? OriginalLibLoadingProgress.update(globals: &state, libraryText: &text, input: input, labels: labels,
                branding: Self.invented, time: { clock += 100; return clock }, panelFirstWord: { _ in 0 }, draw: { _ in },
                fillBacking: { [UInt8](repeating: 0, count: 100) }, performFill: { _ in 0 }, message: { _, _ in .init() },
                observe: { e in if e.kind == "shell" { opened = e.strings } })
        }
        XCTAssertEqual(opened, [Array("open".utf8), Self.invented.advertise])
    }

    /// The network menu's forum link (selector 1, 368..790 x 449..536;
    /// OriginalNetworkMenu.swift:104-111).
    func testNetworkForumIsTheGames() throws {
        var world = try record(0x7d8), host = try record(51), state = try globals([(0x455608, 0x100), (0x4546f0, 600), (0x453cdc, 500), (0x457580, 1)])
        var local = try record(0x400), text = OriginalLibSurfaceText()
        var memory = OriginalMenuPresentationMemory(replayPointers: try record(8)), opened: [[UInt8]]?
        _ = try? OriginalNetworkMenu.run(world: &world, hostname: &host, globals: &state, local: &local, libraryText: &text, memory: &memory,
            input: .init(selector: 1, worldAddress: 0x458b00, drawTarget: 1, dcResult: 0, dc: 0x1234), branding: Self.invented,
            background: { _, _ in }, draw: { _, _ in }, fill: { _ in }, timer: { 0 }, keyState: { _ in 0 },
            client: { _, _, _ in throw OriginalStateError.invalidStorage("no client") }, exit: { _ in },
            observe: { e in if e.kind == "shell" { opened = e.strings } })
        XCTAssertEqual(opened, [Array("open".utf8), Self.invented.forum])
    }
}
