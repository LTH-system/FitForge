import Foundation

struct MealAIService {
    private let apiClient = MealAIAPIClient()

    func analyze(description: String, endpointURLString: String = "", locale: String = "ja") async -> MealLog {
        if !endpointURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let remote = try? await apiClient.analyze(description: description, endpointURLString: endpointURLString, locale: locale) {
            return MealLog(
                date: .now,
                title: remote.title,
                note: description,
                estimatedKcal: remote.kcal,
                proteinG: remote.proteinG,
                fatG: remote.fatG,
                carbG: remote.carbG,
                confidence: remote.confidence
            )
        }

        let lowered = description.lowercased()
        let baseKcal: Int

        if lowered.contains("ラーメン") || lowered.contains("ramen") {
            baseKcal = 780
        } else if lowered.contains("鶏") || lowered.contains("chicken") {
            baseKcal = 520
        } else if lowered.contains("サラダ") || lowered.contains("salad") {
            baseKcal = 320
        } else {
            baseKcal = 610
        }

        return MealLog(
            date: .now,
            title: "AI推定の食事",
            note: description,
            estimatedKcal: baseKcal,
            proteinG: max(18, baseKcal / 24),
            fatG: max(8, baseKcal / 36),
            carbG: max(24, baseKcal / 9),
            confidence: 0.72
        )
    }
}
