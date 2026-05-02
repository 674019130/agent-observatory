import XCTest
@testable import AgentObservatoryCore

final class LocalizationTests: XCTestCase {
    func testLanguageDisplayNamesAreStable() {
        XCTAssertEqual(AppLanguage.english.displayName, "English")
        XCTAssertEqual(AppLanguage.simplifiedChinese.displayName, "简体中文")
    }

    func testKnownLabelsRenderInSelectedLanguage() {
        XCTAssertEqual(L10n.text(.settingsTitle, language: .english), "Settings")
        XCTAssertEqual(L10n.text(.settingsTitle, language: .simplifiedChinese), "设置")
        XCTAssertEqual(L10n.text(.language, language: .english), "Language")
        XCTAssertEqual(L10n.text(.language, language: .simplifiedChinese), "语言")
        XCTAssertEqual(L10n.text(.archiveCenter, language: .english), "Archive Center")
        XCTAssertEqual(L10n.text(.archiveCenter, language: .simplifiedChinese), "归档中心")
    }

    func testEveryLocalizationKeyHasEnglishAndSimplifiedChineseText() {
        for key in L10n.Key.allCases {
            XCTAssertFalse(
                L10n.text(key, language: .english).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "Missing English text for \(key)"
            )
            XCTAssertFalse(
                L10n.text(key, language: .simplifiedChinese).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "Missing Simplified Chinese text for \(key)"
            )
        }
    }
}
