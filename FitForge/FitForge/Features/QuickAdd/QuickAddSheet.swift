import SwiftUI
import SwiftData

/// 中央の＋から開く記録シート。どの記録にも1〜2タップで入れるようにする
struct QuickAddSheet: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isWeightExpanded = false
    @State private var weightInput = 0.0
    @State private var isCheckInPresented = false
    @State private var savedCount = 0
    @State private var justSavedTitle: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    LazyVGrid(columns: columns, spacing: 10) {
                        tile("食事", detail: "文章で記録", icon: "fork.knife", color: FF.intake) {
                            go(to: .meals)
                        }
                        tile("体重", detail: String(format: "前回 %.1fkg", store.latestWeight), icon: "scalemass", color: FF.burn, isSelected: isWeightExpanded) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                isWeightExpanded.toggle()
                            }
                        }
                        tile("筋トレ", detail: "重量・回数", icon: "dumbbell", color: FF.strength) {
                            router.trainingMode = .strength
                            go(to: .training)
                        }
                        tile("ラン・運動", detail: "距離・時間", icon: "figure.run", color: FF.run) {
                            router.trainingMode = .cardio
                            go(to: .training)
                        }
                        tile("チェックイン", detail: "30秒で体調", icon: "checkmark.circle", color: FF.deficit) {
                            isCheckInPresented = true
                        }
                    }

                    if isWeightExpanded {
                        weightEntry
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    usualMeals
                }
                .padding()
            }
            .background(FF.surface)
            .navigationTitle("記録する")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sensoryFeedback(.success, trigger: savedCount)
            .sheet(isPresented: $isCheckInPresented) {
                CheckInSheet()
                    .presentationDetents([.medium])
            }
            .onAppear { weightInput = store.latestWeight }
        }
    }

    private func go(to tab: AppTab) {
        dismiss()
        router.open(tab)
    }

    private func tile(_ title: String, detail: String, icon: String, color: Color, isSelected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                IconSeat(systemName: icon, color: color, size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FF.textPrimary)
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(FF.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
            .padding(12)
            .background(isSelected ? color.opacity(0.12) : FF.surfaceSecondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? color : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: 体重

    private var weightEntry: some View {
        HStack(spacing: 12) {
            FFStepperRow(
                label: "",
                valueText: String(format: "%.1fkg", weightInput),
                onMinus: { weightInput = max(30, weightInput - 0.1) },
                onPlus: { weightInput = min(200, weightInput + 0.1) }
            )
            Button("記録") {
                store.logWeight(weightInput)
                modelContext.insert(BodyMetricEntry(from: BodyMetric(date: .now, weightKg: weightInput, bodyFatPercent: nil)))
                try? modelContext.save()
                markSaved("体重 \(String(format: "%.1f", weightInput))kg")
                withAnimation { isWeightExpanded = false }
            }
            .buttonStyle(FFCompactButtonStyle(tint: FF.accent, isSelected: true))
        }
        .padding(12)
        .background(FF.surfaceSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: いつもの

    private var yesterdayMeals: [MealLog] {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
        return store.meals(onLifeDay: yesterday)
    }

    private var usualMeals: some View {
        let meals = store.frequentMeals(limit: 4)
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "いつもの", subtitle: meals.isEmpty ? "食事を記録すると、よく食べるものがここに並びます" : "1タップで今の時刻に記録します")

            if !yesterdayMeals.isEmpty {
                let yesterdayKcal = yesterdayMeals.map(\.estimatedKcal).reduce(0, +)
                Button {
                    let saved = store.repeatYesterdayMeals()
                    for meal in saved {
                        modelContext.insert(MealEntry(from: meal))
                    }
                    try? modelContext.save()
                    markSaved("昨日の食事\(saved.count)件")
                } label: {
                    HStack(spacing: 12) {
                        IconSeat(systemName: "calendar.badge.clock", color: FF.accent, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("昨日の食事をまとめて記録")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(FF.textPrimary)
                            Text("\(yesterdayMeals.count)件・\(yesterdayKcal) kcal を各時間帯の目安時刻で追加")
                                .font(FF.fontCaption)
                                .monospacedDigit()
                                .foregroundStyle(FF.textSecondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(FF.accentText)
                    }
                    .padding(10)
                    .background(FF.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if let justSavedTitle {
                Label("\(justSavedTitle) を記録しました", systemImage: "checkmark.circle.fill")
                    .font(FF.fontCaption.weight(.semibold))
                    .foregroundStyle(FF.deficit)
                    .transition(.opacity)
            }

            ForEach(meals) { meal in
                HStack(spacing: 12) {
                    IconSeat(systemName: "arrow.triangle.2.circlepath", color: FF.textSecondary, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FF.textPrimary)
                            .lineLimit(1)
                        Text("\(meal.estimatedKcal) kcal · たんぱく質 \(meal.proteinG)g")
                            .font(FF.fontCaption)
                            .monospacedDigit()
                            .foregroundStyle(FF.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Button {
                        let saved = store.repeatMeal(meal)
                        modelContext.insert(MealEntry(from: saved))
                        try? modelContext.save()
                        markSaved(meal.title)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(FF.accentText)
                            .frame(width: 44, height: 44)
                            .background(FF.accentSoft, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(meal.title)を追加")
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func markSaved(_ title: String) {
        savedCount += 1
        withAnimation(.easeOut(duration: 0.2)) { justSavedTitle = title }
    }
}

// MARK: - チェックイン

struct CheckInSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var mealAmount = "普通"
    @State private var activity = "少しやった"
    @State private var condition = "普通"
    @State private var mood = "前向き"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("完璧じゃなくて大丈夫。休む日も記録に入ります。")
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textSecondary)
                    row("食事", ["少なめ", "普通", "多め"], $mealAmount, FF.intake)
                    row("運動", ["休んだ", "少しやった", "やった"], $activity, FF.burn)
                    row("体調", ["だるい", "普通", "よい"], $condition, FF.accent)
                    row("気分", ["しんどい", "普通", "前向き"], $mood, FF.protein)
                    Button {
                        store.addCheckIn(mealAmount: mealAmount, activity: activity, condition: condition, mood: mood)
                        dismiss()
                    } label: {
                        Label("今日はここまででOK", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(FFPrimaryButtonStyle())
                }
                .padding()
            }
            .background(FF.background)
            .navigationTitle("30秒チェックイン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func row(_ label: String, _ options: [String], _ selection: Binding<String>, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(FF.fontCaption.weight(.medium))
                .foregroundStyle(FF.textSecondary)
            FFSegmentedPicker(options: options, label: { $0 }, selection: selection, tint: tint)
        }
    }
}
