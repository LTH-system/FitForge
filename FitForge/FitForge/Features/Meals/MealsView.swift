import SwiftUI
import SwiftData

struct MealsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.modelContext) private var modelContext
    @State private var description = ""
    @State private var isAnalyzing = false
    @State private var pendingMeal: MealLog?
    @State private var editableTitle = ""
    @State private var editableKcal = 0
    @State private var editableProtein = 0
    @State private var editableFat = 0
    @State private var editableCarb = 0
    private let ai = MealAIService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if store.preferences.onboarding.mealTrackingStyle == .loose {
                        looseMealPanel
                    }
                    inputPanel
                    if pendingMeal != nil {
                        confirmationPanel
                    }
                    recentMeals
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("食事管理")
        }
    }

    private var looseMealPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ざっくり記録")
                .font(.headline)
            Text("細かい日はAI推定、忙しい日はこれだけでもOKです。")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                quickMealButton(title: "軽め", kcal: 400, protein: 20, fat: 12, carb: 50)
                quickMealButton(title: "普通", kcal: 650, protein: 30, fat: 20, carb: 80)
                quickMealButton(title: "多め", kcal: 950, protein: 40, fat: 32, carb: 120)
            }
        }
        .panelStyle()
    }

    private func quickMealButton(title: String, kcal: Int, protein: Int, fat: Int, carb: Int) -> some View {
        Button {
            let meal = MealLog(
                date: .now,
                title: "\(title)の食事",
                note: "ざっくり記録",
                estimatedKcal: kcal,
                proteinG: protein,
                fatG: fat,
                carbG: carb,
                confidence: 0.45,
                source: .manual
            )
            let saved = store.addMeal(from: meal)
            modelContext.insert(MealEntry(from: saved))
            try? modelContext.save()
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                Text("\(kcal) kcal")
                    .font(.caption.monospacedDigit())
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.preferences.onboarding.mealTrackingStyle == .detailed ? "AIカロリー推定" : "詳しく記録")
                .font(.headline)

            TextField("例: 鶏むね200g、玄米150g、卵、味噌汁", text: $description, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            HStack {
                Button {
                    description = "食事写真からの推定は次の段階でVision APIに接続"
                } label: {
                    Label("写真", systemImage: "camera")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    Task { await analyze() }
                } label: {
                    Label(isAnalyzing ? "分析中" : "分析", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAnalyzing)
            }
        }
        .panelStyle()
    }

    private var confirmationPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("推定結果を確認")
                        .font(.headline)
                    Text("AIの値は目安です。量が違うときは直してから保存してください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            TextField("食事名", text: $editableTitle)
                .textFieldStyle(.roundedBorder)

            Stepper(value: $editableKcal, in: 0...5000, step: 10) {
                Text("カロリー \(editableKcal) kcal")
                    .monospacedDigit()
            }

            Stepper(value: $editableProtein, in: 0...300) {
                Text("P \(editableProtein)g")
                    .monospacedDigit()
            }

            Stepper(value: $editableFat, in: 0...300) {
                Text("F \(editableFat)g")
                    .monospacedDigit()
            }

            Stepper(value: $editableCarb, in: 0...500) {
                Text("C \(editableCarb)g")
                    .monospacedDigit()
            }

            HStack {
                Button("やめる") {
                    pendingMeal = nil
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    savePendingMeal()
                } label: {
                    Label("保存", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(editableTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .panelStyle()
    }

    private var recentMeals: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近の食事")
                .font(.headline)

            ForEach(store.meals) { meal in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(meal.title)
                            .font(.subheadline.bold())
                        Spacer()
                        Text("\(meal.estimatedKcal) kcal")
                            .font(.subheadline.monospacedDigit())
                    }
                    Text(meal.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    PFCRow(protein: meal.proteinG, fat: meal.fatG, carb: meal.carbG)
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .panelStyle()
    }

    private func analyze() async {
        isAnalyzing = true
        let result = await ai.analyze(
            description: description,
            endpointURLString: store.preferences.mealAIEndpointURLString,
            locale: store.preferences.languageCode
        )
        pendingMeal = result
        editableTitle = result.title
        editableKcal = result.estimatedKcal
        editableProtein = result.proteinG
        editableFat = result.fatG
        editableCarb = result.carbG
        isAnalyzing = false
    }

    private func savePendingMeal() {
        guard var meal = pendingMeal else { return }
        meal.title = editableTitle
        meal.estimatedKcal = editableKcal
        meal.proteinG = editableProtein
        meal.fatG = editableFat
        meal.carbG = editableCarb
        let saved = store.addMeal(from: meal)
        modelContext.insert(MealEntry(from: saved))
        try? modelContext.save()
        pendingMeal = nil
        description = ""
    }
}
