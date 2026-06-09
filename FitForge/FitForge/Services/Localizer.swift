import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case ja
    case en

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ja: "日本語"
        case .en: "English"
        }
    }
}

enum L10n {
    static func text(_ key: String, languageCode: String = "ja") -> String {
        let table = languageCode == "en" ? en : ja
        return table[key] ?? ja[key] ?? key
    }

    private static let ja: [String: String] = [
        "settings": "設定",
        "language": "言語",
        "life_day": "1日の区切り",
        "life_day_detail": "起床時刻に合わせて、深夜の記録を前日扱いにできます。",
        "wake_time": "起床時刻",
        "japanese_first": "日本人向けを標準にし、多言語対応できる設計です。"
    ]

    private static let en: [String: String] = [
        "settings": "Settings",
        "language": "Language",
        "life_day": "Day Boundary",
        "life_day_detail": "Use your wake time as the start of the day, so late-night logs can belong to the previous day.",
        "wake_time": "Wake Time",
        "japanese_first": "Japanese is the default, with localization-ready text structure."
    ]
}
