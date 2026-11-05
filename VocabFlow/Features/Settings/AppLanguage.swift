import Foundation
import os

/// The languages the app's interface is translated into. Learning content is not affected:
/// meanings and explanations follow the backend's `explanationLocale`.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case vietnamese = "vi"
    case english = "en"

    var id: String { rawValue }

    var locale: Locale { Locale(identifier: rawValue) }

    /// The value `PUT /me/settings` accepts. The backend localizes the catalog with it.
    var uiLocale: String {
        switch self {
        case .vietnamese: "vi-VN"
        case .english: "en-US"
        }
    }

    /// Each language's own name, deliberately not translated so people can always find theirs.
    var nativeName: String {
        switch self {
        case .vietnamese: "Tiếng Việt"
        case .english: "English"
        }
    }

    /// Accepts region-qualified tags such as `vi-VN`.
    init?(languageTag: String) {
        guard let code = Locale(identifier: languageTag).language.languageCode?.identifier else { return nil }
        self.init(rawValue: code)
    }

    /// What iOS picked from the device's languages; the fallback before a choice is made.
    static var device: AppLanguage {
        Bundle.main.preferredLocalizations.first.flatMap(AppLanguage.init(languageTag:)) ?? .english
    }

    /// The language strings are built in right now, readable from any isolation domain
    /// because models and errors build strings too. `AppSettingsStore` is what changes it.
    static var active: AppLanguage {
        get { activeLanguage.withLock { $0 } }
        set { activeLanguage.withLock { $0 = newValue } }
    }

    private static let activeLanguage = OSAllocatedUnfairLock(initialState: device)

    fileprivate static let bundles: [AppLanguage: Bundle] = Dictionary(uniqueKeysWithValues: allCases.map { language in
        (language, Bundle.main.path(forResource: language.rawValue, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main)
    })
}

extension Bundle {
    /// Pass to every `String(localized:)`. `Text` follows the `\.locale` environment value, but
    /// `String(localized:)` only follows its bundle, and `Bundle.main` keeps the launch language.
    static var appLanguage: Bundle { AppLanguage.bundles[AppLanguage.active] ?? .main }
}
