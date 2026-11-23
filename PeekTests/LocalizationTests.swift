import XCTest
@testable import Peek

final class LocalizationTests: XCTestCase {
    private let shippedLanguages = ["en", "it", "de", "fr", "es"]

    func testAppShipsEveryLanguage() {
        let localizations = Set(Bundle.main.localizations)
        for language in shippedLanguages {
            XCTAssertTrue(localizations.contains(language), "Missing localization: \(language)")
        }
    }

    func testEachLanguageTranslatesTheJoinAlert() throws {
        let expected = [
            "it": "Invio per entrare · Esc per chiudere",
            "de": "Return zum Beitreten · Esc zum Schließen",
            "fr": "Entrée pour rejoindre · Échap pour fermer",
            "es": "Intro para unirte · Esc para cerrar"
        ]
        for (language, translation) in expected {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"), language)
            let bundle = try XCTUnwrap(Bundle(path: path), language)
            XCTAssertEqual(
                bundle.localizedString(forKey: "Return to join · Esc to dismiss", value: nil, table: nil),
                translation
            )
        }
    }

    func testPermissionPromptsAreLocalized() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "it", ofType: "lproj"))
        let bundle = try XCTUnwrap(Bundle(path: path))
        let prompt = bundle.localizedString(forKey: "NSCalendarsUsageDescription", value: nil, table: "InfoPlist")
        XCTAssertTrue(prompt.hasPrefix("Peek ha bisogno"), prompt)
    }
}
