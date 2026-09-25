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
    /// 表示中の生活日（その日に含まれる任意の時刻）
    @State private var selectedDay = Date.now
    /// これから記録する食事の時間帯。日を切り替えるたびに目安の時間帯へリセットする
    @State private var selectedPeriod = MealPeriod.inferred(from: .now)
    @State private var savedCount = 0
    private let ai = MealAIService()
    private static let topAnchor = "mealsTop"

    private var isViewingToday: Bool {
        LifeDayService.isSameLifeDay(selectedDay, .now, preferences: store.preferences)
    }

    private var selectedNutrition: DailyNutrition {
        store.nutrition(onLifeDay: selectedDay)
    }

    /// 新しく記録する食事に付ける日時。今日はその瞬間の時刻、過去の日は選んだ時間帯の目安時刻
    private var entryDate: Date {
        guard !isViewingToday else { return .now }
        let dayStart = LifeDayService.startOfLifeDay(containing: selectedDay, preferences: store.preferences)
        return Calendar.current.date(bySettingHour: selectedPeriod.representativeHour, minute: 0, second: 0, of: dayStart) ?? selectedDay
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        dayNavigator
                            .id(Self.topAnchor)
                        dayPanel
                        if !isViewingToday {
                            periodPickerPanel
                        }
                        if isViewingToday && store.preferences.onboarding.mealTrackingStyle == .loose {
                            looseMealPanel
                        }
                        inputPanel
                        if pendingMeal != nil {
                            confirmationPanel
                        }
                        dayMealsPanel
                        historyPanel { day in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedDay = day
                                proxy.scrollTo(Self.topAnchor, anchor: .top)
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(FF.background)
            .navigationTitle("食事管理")
            .sensoryFeedback(.success, trigger: savedCount)
            .onChange(of: selectedDay) { _, newDay in
                selectedPeriod = LifeDayService.isSameLifeDay(newDay, .now, preferences: store.preferences)
                    ? MealPeriod.inferred(from: .now)
                    : .breakfast
            }
        }
    }

    // MARK: 日付の切り替え

    private var dayNavigator: some View {
        HStack(spacing: 4) {
            dayStepButton("chevron.left", label: "前の日", offset: -1)
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                Text(dayTitle(selectedNutrition.lifeDayStart))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(FF.textPrimary)
                if isViewingToday {
                    Text("今日")
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.accent)
                } else {
                    Button("今日に戻る") {
                        withAnimation(.easeInOut(duration: 0.25)) { selectedDay = .now }
                    }
                    .font(FF.fontCaption.weight(.semibold))
                    .foregroundStyle(FF.accent)
                }
            }
            Spacer(minLength: 0)
            dayStepButton("chevron.right", label: "次の日", offset: 1)
                .disabled(isViewingToday)
                .opacity(isViewingToday ? 0.3 : 1)
        }
        .padding(.horizontal, 4)
    }

    private func dayStepButton(_ symbol: String, label: String, offset: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedDay = Calendar.current.date(byAdding: .day, value: offset, to: selectedDay) ?? selectedDay
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(FF.textSecondary)
                .frame(width: 44, height: 44)
                .background(FF.surface, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func dayTitle(_ day: Date) -> String {
        day.formatted(.dateTime.month().day().weekday(.abbreviated).locale(Locale(identifier: "ja_JP")))
    }

    // MARK: 選択日のカロリー・PFCサマリー（主役カード）

    private var dayPanel: some View {
        let day = selectedNutrition
        let target = store.dailyCalorieBudget
        let proteinTarget = store.proteinTargetG

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: isViewingToday ? "今日の食事バランス" : "この日の食事バランス")
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text("\(day.kcal)")
                        .font(FF.fontNumber)
                        .monospacedDigit()
                        .foregroundStyle(FF.intake)
                    Text("/ \(target) kcal")
                        .font(FF.fontCaption)
                        .monospacedDigit()
                        .foregroundStyle(FF.textSecondary)
                }
            }

            HStack(spacing: 10) {
                IconSeat(systemName: "bolt.heart.fill", color: FF.protein, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("タンパク質")
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textSecondary)
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text("\(day.proteinG)")
                            .font(FF.fontNumber)
                            .monospacedDigit()
                            .foregroundStyle(FF.protein)
                        Text("g / 目標 \(proteinTarget)g")
                            .font(FF.fontCaption)
                            .monospacedDigit()
                            .foregroundStyle(FF.textSecondary)
                    }
                }
                Spacer()
                Text(day.proteinG >= proteinTarget ? "達成" : "あと \(proteinTarget - day.proteinG)g")
                    .font(FF.fontChip)
                    .monospacedDigit()
                    .foregroundStyle(day.proteinG >= proteinTarget ? FF.deficit : FF.protein)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background((day.proteinG >= proteinTarget ? FF.deficit : FF.protein).opacity(0.12), in: Capsule())
            }

            PFCBars(
                protein: day.proteinG,
                fat: day.fatG,
                carb: day.carbG,
                proteinMax: Double(proteinTarget)
            )

            if let ratio = day.energyRatio {
                Text("PFCバランス（カロリー比） P \(ratio.protein)% ・ F \(ratio.fat)% ・ C \(ratio.carb)%")
                    .font(FF.fontCaption)
                    .monospacedDigit()
                    .foregroundStyle(FF.textSecondary)
            }
            Text("タンパク質目標 \(proteinTarget)g（体重×1.6gの目安）")
                .font(FF.fontCaption)
                .foregroundStyle(FF.textTertiary)
        }
        .panelStyle()
    }

    // MARK: 過去の日に記録する時間帯

    private var periodPickerPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "この日のどの時間帯に記録しますか？")
            FFSegmentedPicker(options: Array(MealPeriod.allCases), label: { $0.rawValue }, selection: $selectedPeriod, tint: FF.intake)
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
                date: entryDate,
                title: "\(title)の食事",
                note: "ざっくり記録",
                estimatedKcal: kcal,
                proteinG: protein,
                fatG: fat,
                carbG: carb,
                confidence: 0.45,
                source: .manual,
                period: isViewingToday ? nil : selectedPeriod
            )
            let saved = store.addMeal(from: meal)
            modelContext.insert(MealEntry(from: saved))
            try? modelContext.save()
            savedCount += 1
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
            SectionHeader(
                title: store.preferences.onboarding.mealTrackingStyle == .detailed ? "AIカロリー推定" : "詳しく記録",
                subtitle: isViewingToday ? nil : "\(dayTitle(selectedDay))・\(selectedPeriod.rawValue)として記録します"
            )

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

    // MARK: 選択日の食事（時間帯ごと）

    private var dayMealsPanel: some View {
        let dayMeals = selectedNutrition.meals

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: isViewingToday ? "今日の食事" : "この日の食事",
                subtitle: dayMeals.isEmpty ? nil : "長押しで削除・時間帯の変更ができます"
            )

            if dayMeals.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(FF.textTertiary)
                    Text(isViewingToday ? "まだ記録がありません。最初の食事を記録してみましょう" : "この日の食事記録はありません")
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }

            ForEach(MealPeriod.allCases) { period in
                let periodMeals = selectedNutrition.meals(in: period)
                if !periodMeals.isEmpty {
                    periodSection(period, meals: periodMeals)
                }
            }
        }
        .panelStyle()
    }

    private func periodSection(_ period: MealPeriod, meals: [MealLog]) -> some View {
        let subtotal = meals.map(\.estimatedKcal).reduce(0, +)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(period.rawValue)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(FF.textPrimary)
                Spacer()
                Text("\(subtotal) kcal")
                    .font(FF.fontCaption)
                    .monospacedDigit()
                    .foregroundStyle(FF.textSecondary)
            }

            ForEach(meals) { meal in
                mealRow(meal)
            }
        }
    }

    private func mealRow(_ meal: MealLog) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(meal.date.formatted(date: .omitted, time: .shortened))
                    .font(FF.fontCaption)
                    .monospacedDigit()
                    .foregroundStyle(FF.textSecondary)
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
        .contextMenu {
            Menu {
                ForEach(MealPeriod.allCases.filter { $0 != meal.period }) { period in
                    Button(period.rawValue) {
                        store.updateMealPeriod(meal, to: period)
                        SwiftDataBridge.deleteMealEntry(id: meal.id, context: modelContext)
                        var moved = meal
                        moved.period = period
                        modelContext.insert(MealEntry(from: moved))
                        try? modelContext.save()
                    }
                }
            } label: {
                Label("時間帯を変更", systemImage: "clock")
            }
            Button(role: .destructive) {
                store.deleteMeal(meal)
                SwiftDataBridge.deleteMealEntry(id: meal.id, context: modelContext)
            } label: {
                Label("この記録を削除", systemImage: "trash")
            }
        }
    }

    // MARK: 過去の記録（日別一覧）

    private func historyPanel(onSelect: @escaping (Date) -> Void) -> some View {
        let days = store.recordedNutritionDays(limit: 30)
        let proteinTarget = store.proteinTargetG
        let selectedStart = selectedNutrition.lifeDayStart

        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "過去の記録", subtitle: days.isEmpty ? nil : "日付をタップするとその日の内容を表示します")

            if days.isEmpty {
                Text("食事を記録すると、日ごとのカロリーとPFCがここに並びます")
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }

            ForEach(days) { day in
                let isSelected = day.lifeDayStart == selectedStart
                Button {
                    onSelect(day.lifeDayStart)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(dayTitle(day.lifeDayStart))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(FF.textPrimary)
                            Text("\(day.meals.count)食")
                                .font(FF.fontCaption)
                                .foregroundStyle(FF.textSecondary)
                            Spacer()
                            Text("\(day.kcal) kcal")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(FF.intake)
                        }
                        PFCRow(protein: day.proteinG, fat: day.fatG, carb: day.carbG)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(FF.protein.opacity(0.12))
                                Capsule()
                                    .fill(FF.protein)
                                    .frame(width: geo.size.width * min(1, Double(day.proteinG) / Double(max(1, proteinTarget))))
                            }
                        }
                        .frame(height: 6)
                        .accessibilityLabel("タンパク質 \(day.proteinG)g、目標 \(proteinTarget)g")
                    }
                    .padding(12)
                    .background(
                        isSelected ? FF.accentSoft : FF.surfaceSecondary.opacity(0.6),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? FF.accent : .clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
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
        meal.date = entryDate
        if !isViewingToday { meal.period = selectedPeriod }
        let saved = store.addMeal(from: meal)
        modelContext.insert(MealEntry(from: saved))
        try? modelContext.save()
        pendingMeal = nil
        description = ""
        savedCount += 1
    }
}
