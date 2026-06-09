import Foundation

enum ExerciseCategory: String, CaseIterable, Identifiable, Codable {
    case chest = "胸"
    case back = "背中"
    case shoulders = "肩"
    case arms = "腕"
    case legs = "脚"
    case glutes = "尻"
    case core = "体幹・腹筋"
    case olympic = "全身・パワー"
    case machine = "マシン"
    case bodyweight = "自重"
    case hyrox = "HYROX"

    var id: String { rawValue }
}

struct ExerciseCatalogItem: Identifiable, Hashable, Codable {
    var id = UUID()
    var nameJa: String
    var nameEn: String
    var category: ExerciseCategory
    var aliasesJa: [String] = []
}

enum ExerciseCatalog {
    static let items: [ExerciseCatalogItem] = [
        ExerciseCatalogItem(nameJa: "ベンチプレス", nameEn: "Bench Press", category: .chest, aliasesJa: ["バーベルベンチ", "フラットベンチ"]),
        ExerciseCatalogItem(nameJa: "インクラインベンチプレス", nameEn: "Incline Bench Press", category: .chest),
        ExerciseCatalogItem(nameJa: "ダンベルベンチプレス", nameEn: "Dumbbell Bench Press", category: .chest),
        ExerciseCatalogItem(nameJa: "インクラインダンベルプレス", nameEn: "Incline Dumbbell Press", category: .chest),
        ExerciseCatalogItem(nameJa: "チェストプレス", nameEn: "Chest Press", category: .machine),
        ExerciseCatalogItem(nameJa: "ダンベルフライ", nameEn: "Dumbbell Fly", category: .chest),
        ExerciseCatalogItem(nameJa: "ケーブルクロスオーバー", nameEn: "Cable Crossover", category: .chest),
        ExerciseCatalogItem(nameJa: "ディップス", nameEn: "Dips", category: .bodyweight),
        ExerciseCatalogItem(nameJa: "腕立て伏せ", nameEn: "Push-up", category: .bodyweight, aliasesJa: ["プッシュアップ"]),
        ExerciseCatalogItem(nameJa: "デッドリフト", nameEn: "Deadlift", category: .back),
        ExerciseCatalogItem(nameJa: "ルーマニアンデッドリフト", nameEn: "Romanian Deadlift", category: .legs, aliasesJa: ["RDL"]),
        ExerciseCatalogItem(nameJa: "懸垂", nameEn: "Pull-up", category: .bodyweight, aliasesJa: ["チンニング"]),
        ExerciseCatalogItem(nameJa: "ラットプルダウン", nameEn: "Lat Pulldown", category: .back),
        ExerciseCatalogItem(nameJa: "シーテッドロー", nameEn: "Seated Row", category: .back),
        ExerciseCatalogItem(nameJa: "ベントオーバーロー", nameEn: "Bent-over Row", category: .back),
        ExerciseCatalogItem(nameJa: "ワンハンドダンベルロー", nameEn: "One-arm Dumbbell Row", category: .back),
        ExerciseCatalogItem(nameJa: "Tバーロー", nameEn: "T-bar Row", category: .back),
        ExerciseCatalogItem(nameJa: "フェイスプル", nameEn: "Face Pull", category: .shoulders),
        ExerciseCatalogItem(nameJa: "バックエクステンション", nameEn: "Back Extension", category: .back),
        ExerciseCatalogItem(nameJa: "ショルダープレス", nameEn: "Shoulder Press", category: .shoulders),
        ExerciseCatalogItem(nameJa: "ミリタリープレス", nameEn: "Military Press", category: .shoulders),
        ExerciseCatalogItem(nameJa: "ダンベルショルダープレス", nameEn: "Dumbbell Shoulder Press", category: .shoulders),
        ExerciseCatalogItem(nameJa: "サイドレイズ", nameEn: "Lateral Raise", category: .shoulders),
        ExerciseCatalogItem(nameJa: "リアレイズ", nameEn: "Rear Delt Raise", category: .shoulders),
        ExerciseCatalogItem(nameJa: "フロントレイズ", nameEn: "Front Raise", category: .shoulders),
        ExerciseCatalogItem(nameJa: "アップライトロー", nameEn: "Upright Row", category: .shoulders),
        ExerciseCatalogItem(nameJa: "シュラッグ", nameEn: "Shrug", category: .shoulders),
        ExerciseCatalogItem(nameJa: "アームカール", nameEn: "Biceps Curl", category: .arms),
        ExerciseCatalogItem(nameJa: "ダンベルカール", nameEn: "Dumbbell Curl", category: .arms),
        ExerciseCatalogItem(nameJa: "ハンマーカール", nameEn: "Hammer Curl", category: .arms),
        ExerciseCatalogItem(nameJa: "プリーチャーカール", nameEn: "Preacher Curl", category: .arms),
        ExerciseCatalogItem(nameJa: "トライセプスプレスダウン", nameEn: "Triceps Pressdown", category: .arms),
        ExerciseCatalogItem(nameJa: "フレンチプレス", nameEn: "Overhead Triceps Extension", category: .arms),
        ExerciseCatalogItem(nameJa: "ナローベンチプレス", nameEn: "Close-grip Bench Press", category: .arms),
        ExerciseCatalogItem(nameJa: "スカルクラッシャー", nameEn: "Skull Crusher", category: .arms),
        ExerciseCatalogItem(nameJa: "スクワット", nameEn: "Squat", category: .legs),
        ExerciseCatalogItem(nameJa: "フロントスクワット", nameEn: "Front Squat", category: .legs),
        ExerciseCatalogItem(nameJa: "ブルガリアンスクワット", nameEn: "Bulgarian Split Squat", category: .legs),
        ExerciseCatalogItem(nameJa: "レッグプレス", nameEn: "Leg Press", category: .machine),
        ExerciseCatalogItem(nameJa: "レッグエクステンション", nameEn: "Leg Extension", category: .machine),
        ExerciseCatalogItem(nameJa: "レッグカール", nameEn: "Leg Curl", category: .machine),
        ExerciseCatalogItem(nameJa: "ランジ", nameEn: "Lunge", category: .legs),
        ExerciseCatalogItem(nameJa: "ウォーキングランジ", nameEn: "Walking Lunge", category: .legs),
        ExerciseCatalogItem(nameJa: "カーフレイズ", nameEn: "Calf Raise", category: .legs),
        ExerciseCatalogItem(nameJa: "ヒップスラスト", nameEn: "Hip Thrust", category: .glutes),
        ExerciseCatalogItem(nameJa: "グルートブリッジ", nameEn: "Glute Bridge", category: .glutes),
        ExerciseCatalogItem(nameJa: "アブダクション", nameEn: "Hip Abduction", category: .glutes),
        ExerciseCatalogItem(nameJa: "アダクション", nameEn: "Hip Adduction", category: .legs),
        ExerciseCatalogItem(nameJa: "クランチ", nameEn: "Crunch", category: .core),
        ExerciseCatalogItem(nameJa: "シットアップ", nameEn: "Sit-up", category: .core),
        ExerciseCatalogItem(nameJa: "レッグレイズ", nameEn: "Leg Raise", category: .core),
        ExerciseCatalogItem(nameJa: "プランク", nameEn: "Plank", category: .core),
        ExerciseCatalogItem(nameJa: "サイドプランク", nameEn: "Side Plank", category: .core),
        ExerciseCatalogItem(nameJa: "アブローラー", nameEn: "Ab Wheel Rollout", category: .core),
        ExerciseCatalogItem(nameJa: "ロシアンツイスト", nameEn: "Russian Twist", category: .core),
        ExerciseCatalogItem(nameJa: "ケーブルクランチ", nameEn: "Cable Crunch", category: .core),
        ExerciseCatalogItem(nameJa: "クリーン", nameEn: "Clean", category: .olympic),
        ExerciseCatalogItem(nameJa: "パワークリーン", nameEn: "Power Clean", category: .olympic),
        ExerciseCatalogItem(nameJa: "スナッチ", nameEn: "Snatch", category: .olympic),
        ExerciseCatalogItem(nameJa: "ケトルベルスイング", nameEn: "Kettlebell Swing", category: .olympic),
        ExerciseCatalogItem(nameJa: "バーピー", nameEn: "Burpee", category: .bodyweight),
        ExerciseCatalogItem(nameJa: "ボックスジャンプ", nameEn: "Box Jump", category: .olympic),
        ExerciseCatalogItem(nameJa: "スラスター", nameEn: "Thruster", category: .olympic),
        ExerciseCatalogItem(nameJa: "スキーエルゴ", nameEn: "SkiErg", category: .hyrox, aliasesJa: ["スキー"]),
        ExerciseCatalogItem(nameJa: "スレッドプッシュ", nameEn: "Sled Push", category: .hyrox),
        ExerciseCatalogItem(nameJa: "スレッドプル", nameEn: "Sled Pull", category: .hyrox),
        ExerciseCatalogItem(nameJa: "バーピーブロードジャンプ", nameEn: "Burpee Broad Jump", category: .hyrox),
        ExerciseCatalogItem(nameJa: "ローイング", nameEn: "Rowing", category: .hyrox, aliasesJa: ["ロー"]),
        ExerciseCatalogItem(nameJa: "ファーマーズキャリー", nameEn: "Farmers Carry", category: .hyrox),
        ExerciseCatalogItem(nameJa: "サンドバッグランジ", nameEn: "Sandbag Lunge", category: .hyrox),
        ExerciseCatalogItem(nameJa: "ウォールボール", nameEn: "Wall Ball", category: .hyrox)
    ]

    static func suggestions(for query: String) -> [ExerciseCatalogItem] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return items }

        return items.filter { item in
            item.nameJa.lowercased().contains(normalized)
                || item.nameEn.lowercased().contains(normalized)
                || item.aliasesJa.contains { $0.lowercased().contains(normalized) }
        }
    }
}
