import Testing
@testable import Zhen
// The fixture text, checked for the things that make it worth having.
//
// A2's previews section says to use the real device data rather than lorem ipsum, because
// lorem ipsum hides exactly the problems this design has to solve: long Spanish names,
// non-ASCII punctuation, and rows where almost every field is empty. That only works if
// the non-ASCII stays non-ASCII — and a curly apostrophe is one careless editor, one
// find-and-replace, or one "smart quotes off" paste away from silently becoming U+0027.
//
// Nothing about that failure is visible in a diff at a glance, and nothing about it
// breaks a build. The row would still render; it would just no longer be testing the
// thing it was chosen to test.

@Suite("Fixture text keeps the characters that make it real")
@MainActor
struct FixtureTextTests {
    /// Every user-visible string the fixtures carry.
    static var allStrings: [String] {
        var strings: [String] = []
        for device in DeviceRowModel.sampleNetwork {
            strings += [device.name, device.subtitle, device.lastSeen, device.ip]
            if let mac = device.mac { strings.append(mac) }
        }
        for detail in [DeviceDetailModel.jcMacBookPro, .salaDeEntretenimiento, .unidentified] {
            strings += [detail.name, detail.summary, detail.identityCaption]
            strings += detail.names.map(\.source)
            strings += detail.names.compactMap(\.candidate)
            strings += detail.names.map(\.absenceNote)
            strings += detail.identityHistory.flatMap { [$0.mac, $0.reason, $0.range] }
            strings += detail.ports.flatMap { [$0.port, $0.service] }
        }
        for day in EventDayModel.sampleDays {
            strings.append(day.title)
            strings += day.events.flatMap { [$0.time, $0.subject, $0.detail] }
        }
        strings += DegradationModel.sampleDegradations.flatMap {
            [$0.cause, $0.consequence, $0.actionTitle].compactMap { $0 }
        }
        strings += StageModel.sampleStages.map(\.detail)
        strings += ScanFindingModel.sampleFindings.flatMap {
            [$0.name, $0.detail, $0.note].compactMap { $0 }
        }
        return strings
    }

    @Test("The MacBook's apostrophe is the typographic one, not the ASCII one")
    func curlyApostropheSurvives() throws {
        // The single most fragile character in the fixture set, and the one A2 calls out
        // by name. It comes off the wire as U+2019 and has to reach the screen unmangled.
        let device = try #require(
            DeviceRowModel.sampleNetwork.first { $0.name.contains("MacBook Pro") }
        )
        #expect(device.name == "JC\u{2019}s MacBook Pro")
        #expect(device.name.unicodeScalars.contains("\u{2019}"))
        #expect(!device.name.unicodeScalars.contains("'"))
        // And it survives into the detail screen and the event log, which is where a
        // partial find-and-replace would show up.
        #expect(DeviceDetailModel.jcMacBookPro.name.unicodeScalars.contains("\u{2019}"))
        #expect(EventModel.macBookMoved.subject.unicodeScalars.contains("\u{2019}"))
    }

    @Test("No fixture string contains a straight ASCII apostrophe")
    func noStraightApostrophes() {
        // A blanket rule rather than a list of known strings, so a NEW fixture written
        // with a straight quote fails too. Every apostrophe in this product's copy is
        // typographic — "isn't", "can't", "it's" — and there is no case where U+0027 is
        // the right character in user-visible text.
        for string in Self.allStrings where string.unicodeScalars.contains("'") {
            Issue.record("fixture string uses an ASCII apostrophe: \(string)")
        }
    }

    @Test("The non-ASCII device names are still non-ASCII")
    func nonASCIINamesSurvive() {
        // Three of the ten devices carry characters outside ASCII, and each is testing
        // something different: the apostrophe is punctuation substitution, and the two
        // Spanish names are long strings that push a flexible column.
        let names = DeviceRowModel.sampleNetwork.map(\.name)
        let nonASCII = names.filter { !$0.allSatisfy(\.isASCII) }
        #expect(nonASCII.contains("JC\u{2019}s MacBook Pro"))
        #expect(!nonASCII.isEmpty, "the fixture set has lost every non-ASCII name")
        // And the long Spanish names are still the long ones, since a column width was
        // chosen against them.
        #expect(names.contains("Sala de entretenimiento"))
        #expect(names.contains("MacBook Air de Geovanna"))
    }

    @Test("The em dashes in the absence copy are em dashes")
    func emDashes() {
        // "— not advertised" and "— not set" are how an absent name reads, and an ASCII
        // hyphen there looks like a typo rather than a considered answer.
        let notes = DeviceDetailModel.jcMacBookPro.names.map(\.absenceNote)
        #expect(notes.allSatisfy { $0.unicodeScalars.contains("\u{2014}") })
    }

    @Test("The anonymous majority is still the majority")
    func theAcceptanceCaseIsStillTheBulkOfTheFixture() {
        // The design's whole claim is that it holds up when most of the network is
        // anonymous. If somebody "improves" the fixtures by naming more devices, the
        // previews stop exercising the case they exist for.
        let devices = DeviceRowModel.sampleNetwork
        let unnamed = devices.filter { $0.name == "Unidentified device" }
        #expect(unnamed.count * 2 > devices.count,
                "fewer than half the fixture devices are unidentified — the acceptance case has been diluted")
        // Including at least one with no round trip at all, which is the emptiest row
        // the product can produce.
        #expect(devices.contains { $0.subtitle.contains("no ping reply") })
        // And at least one offline, so the dimming correction stays covered.
        #expect(devices.contains { $0.presence == .offline })
    }
}
