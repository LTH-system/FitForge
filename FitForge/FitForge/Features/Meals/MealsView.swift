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

    /// 当日（生活日）の食事を合算したPFCとカロリー
    private var todayTotals: (kcal: Int, protein: Int, fat: Int, carb: Int) {
        let todayMeals = store.meals.filter {
            LifeDayService.isSameLifeDay($0.date, .now, preferences: store.preferences)
        }
        return (
            todayMeals.map(\.estimatedKcal).reduce(0, +),
            todayMeals.map(\.proteinG).reduce(0, +),
            todayMeals.map(\.fatG).reduce(0, +),
            todayMeals.map(\.carbG).reduce(0, +)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    todayPanel
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
            .background(FF.background)
            .navigationTitle("食事管理")
        }
    }

    // MARK: 当日PFCサマリー（主役カード）

    private var todayPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: "今日の食事バランス")
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text("\(todayTotals.kcal)")
                        .font(FF.fontNumber)
                        .monospacedDigit()
                        .foregroundStyle(FF.intake)
                    Text("kcal")
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textSecondary)
                }
            }
            PFCBars(protein: todayTotals.protein, fat: todayTotals.fat, carb: todayTotals.carb)
        }
        .panelStyle()
    }

    // MARK: ざっくり記録

    private var looseMealPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "ざっくり記録", subtitle: "細かい日はAI推定、忙しい日はこれだけでもOKです。")

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
                    .font(FF.fontChip)
                Text("\(kcal) kcal")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(FFCompactButtonStyle(tint: FF.intake))
    }

    // MARK: 入力

    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: store.preferences.onboarding.mealTrackingStyle == .detailed ? "AIカロリー推定" : "詳しく記録")

            TextField("例: 鶏むね200g、玄米150g、卵、味噌汁", text: $description, axis: .vertical)
                .lineLimit(3...6)
                .ffFieldStyle()

            HStack(spacing: 12) {
                Button {
                    description = "食事写真からの推定は次の段階でVision APIに接続"
                } label: {
                    Label("写真", systemImage: "camera")
                }
                .buttonStyle(FFSecondaryButtonStyle())
                .frame(maxWidth: 130)

                Button {
                    Task { await analyze() }
                } label: {
                    Label(isAnalyzing ? "分析中" : "分析", systemImage: "sparkles")
                }
                .buttonStyle(FFPrimaryButtonStyle())
                .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAnalyzing)
            }
        }
        .panelStyle()
    }

    // MARK: 推定結果確認

    private var confirmationPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: "推定結果を確認",
                subtitle: "AIの値は目安です。量が違うときは直してから保存してください。"
            )

            TextField("食事名", text: $editableTitle)
                .ffFieldStyle()

            FFStepperRow(
                label: "カロリー",
                valueText: "\(editableKcal) kcal",
                onMinus: { editableKcal = max(0, editableKcal - 10) },
                onPlus: { editableKcal = min(5000, editableKcal + 10) }
            )

            macroStepper("P タンパク質", value: $editableProtein, max: 300, color: FF.protein)
            macroStepper("F 脂質", value: $editableFat, max: 300, color: FF.fat)
            macroStepper("C 炭水化物", value: $editableCarb, max: 500, color: FF.carb)

            HStack(spacing: 12) {
                Button("やめる") {
                    pendingMeal = nil
                }
                .buttonStyle(FFCompactButtonStyle())

                Button {
                    savePendingMeal()
                } label: {
                    Label("保存", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(FFSecondaryButtonStyle(tint: FF.deficit))
                .disabled(editableTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .panelStyle()
    }

    /// FFStepperRowと同じレイアウトで、値テキストだけPFC色を付けたステッパー行
    private func macroStepper(_ label: String, value: Binding<Int>, max maxValue: Int, color: Color) -> some View {
        HStack {
            Text(label)
                .font(FF.fontBody)
                .foregroundStyle(FF.textSecondary)
            Spacer()
            HStack(spacing: 14) {
                macroStepButton("minus") { value.wrappedValue = max(0, value.wrappedValue - 1) }
                Text("\(value.wrappedValue)g")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .frame(minWidth: 76)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                macroStepButton("plus") { value.wrappedValue = min(maxValue, value.wrappedValue + 1) }
            }
        }
    }

    private func macroStepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FF.accent)
                .frame(width: 38, height: 38)
                .background(FF.surfaceSecondary, in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: 最近の食事

    private var recentMeals: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "最近の食事")

            ForEach(store.meals) { meal in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(meal.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FF.textPrimary)
                        if meal.confidence < 0.6 {
                            FFBadge(text: "目安", color: FF.over)
                        }
                        Spacer()
                        Text("\(meal.estimatedKcal) kcal")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(FF.intake)
                    }
                    if !meal.note.isEmpty {
                        Text(meal.note)
                            .font(FF.fontCaption)
                            .foregroundStyle(FF.textSecondary)
                    }
                    PFCRow(protein: meal.proteinG, fat: meal.fatG, carb: meal.carbG)
                }
                .padding(12)
                .background(FF.surfaceSecondary.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
