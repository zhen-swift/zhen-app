import Foundation
import Testing

@testable import Zhen

/// The languages the app speaks. English is the source; Spanish is the first translation
/// (`Scripts/translations/es.json`, applied by `Scripts/apply-translations.py`).
@MainActor
struct LocalizationTests {
  /// Every key the built app has, in one language: plain strings and plurals.
  static func keys(_ language: String) -> Set<String> {
    var keys = Set<String>()
    for (name, type) in [("Localizable", "strings"), ("Localizable", "stringsdict")] {
      if let path = Bundle.main.path(forResource: name, ofType: type, inDirectory: nil, forLocalization: language),
         let table = NSDictionary(contentsOfFile: path) as? [String: Any] {
        keys.formUnion(table.keys)
      }
    }
    return keys
  }

  static func spanish(_ resource: LocalizedStringResource) -> String {
    var resource = resource
    resource.locale = Locale(identifier: "es")
    return String(localized: resource)
  }

  /// Gate. Break: remove one key from `es.json` (apply-translations refuses) or from the
  /// catalogue's `es` localizations.
  @Test("Every English key has a Spanish one")
  func spanishIsComplete() {
    let english = Self.keys("en")
    let spanish = Self.keys("es")
    #expect(english.count > 200)
    #expect(english.subtracting(spanish).isEmpty, "untranslated: \(english.subtracting(spanish).sorted())")
  }

  @Test("Spanish plurals and substitutions resolve, with their arguments")
  func spanishPlurals() {
    #expect(Self.spanish(.hardwareAddressesSeen(1)) == "1 dirección de hardware")
    #expect(Self.spanish(.hardwareAddressesSeen(3)) == "3 direcciones de hardware")
    #expect(Self.spanish(.devicesOnlineUnidentified(devices: 1, 1, 0)) == "1 dispositivo · 1 en línea · 0 sin identificar")
    #expect(Self.spanish(.stoppedAfterDevicesFound("0:05", devices: 2)) == "Detenido después de 0:05 · 2 dispositivos encontrados")
    #expect(Self.spanish(.scanNow) == "Escanear ahora")
  }

  @Test("Siri's phrases are in Spanish too, each still naming the app")
  func spanishPhrases() throws {
    let path = try #require(Bundle.main.path(forResource: "AppShortcuts", ofType: "strings", inDirectory: nil, forLocalization: "es"))
    let phrases = try #require(NSDictionary(contentsOfFile: path) as? [String: String])
    #expect(phrases.count == 3)
    #expect(phrases.values.allSatisfy { $0.contains("${applicationName}") })
  }
}
