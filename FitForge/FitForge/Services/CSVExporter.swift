import Foundation

/// 記録をCSVファイルに書き出す（プレミアム）。
/// Excelで文字化けしないよう、UTF-8のBOM付きで保存する
@MainActor
enum CSVExporter {
    static func makeFiles(from store: AppStore, now: Date = .now) throws -> [URL] {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("FitForgeExport", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let stamp = fileDate(now)
        let files: [(name: String, header: [String], rows: [[String]])] = [
            (
                "FitForge_食事_\(stamp).csv",
                ["日時", "時間帯", "食事名", "カロリー(kcal)", "たんぱく質(g)", "脂質(g)", "炭水化物(g)", "記録方法", "メモ"],
                store.meals.sorted { $0.date < $1.date }.map { meal in
                    [dateTime(meal.date), meal.period.rawValue, meal.title, "\(meal.estimatedKcal)", "\(meal.proteinG)", "\(meal.fatG)", "\(meal.carbG)", meal.source.rawValue, meal.note]
                }
            ),
            (
                "FitForge_筋トレ_\(stamp).csv",
                ["日時", "種目", "重量(kg)", "回数", "セット数", "RPE", "推定1RM(kg)", "メモ"],
                store.strengthSets.sorted { $0.date < $1.date }.map { set in
                    [dateTime(set.date), set.exercise, number(set.weightKg), "\(set.reps)", "\(set.sets)", set.rpe.map { "\($0)" } ?? "", number(set.estimatedOneRepMax), set.note]
                }
            ),
            (
                "FitForge_運動_\(stamp).csv",
                ["日時", "種類", "距離(km)", "時間(分)", "消費カロリー(kcal)", "ペース", "RPE", "メモ"],
                store.cardioSessions.sorted { $0.date < $1.date }.map { session in
                    [dateTime(session.date), session.kind.rawValue, number(session.distanceKm), "\(session.durationMinutes)", "\(session.calories)", session.paceText, session.rpe.map { "\($0)" } ?? "", session.note]
                }
            ),
            (
                "FitForge_体重_\(stamp).csv",
                ["日時", "体重(kg)", "体脂肪率(%)", "ウエスト(cm)", "記録方法"],
                store.bodyMetrics.sorted { $0.date < $1.date }.map { metric in
                    [dateTime(metric.date), number(metric.weightKg), metric.bodyFatPercent.map(number) ?? "", metric.waistCm.map(number) ?? "", metric.source.rawValue]
                }
            )
        ]

        return try files.map { file in
            let url = directory.appendingPathComponent(file.name)
            let lines = ([file.header] + file.rows).map { $0.map(escape).joined(separator: ",") }
            let text = "\u{FEFF}" + lines.joined(separator: "\r\n") + "\r\n"
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        }
    }

    /// カンマ・改行・ダブルクォートを含む値はダブルクォートで囲む
    private static func escape(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func dateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }

    private static func fileDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    private static func number(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
