import SwiftUI
import Charts

struct GoalsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var isEditingGoal = false
    @State private var isEditingBody = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if store.preferences.bodyProfile == nil {
                    profilePrompt
                }
                routePanel
                pacePanel
                budgetPanel
                trendPanel
                balancePanel
            }
            .padding()
        }
        .background(FF.background)
        .navigationTitle("目標までの道のり")
        .toolbar {
            Menu {
                Button("目標体重を変更") { isEditingGoal = true }
                Button("からだの情報を変更") { isEditingBody = true }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(FF.textSecondary)
            }
            .accessibilityLabel("目標と身体情報の編集")
        }
        .sheet(isPresented: $isEditingGoal) {
            GoalEditorView()
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $isEditingBody) {
            BodyProfileEditorView()
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: 身体情報の入力のお願い（既存ユーザー向け）

    private var profilePrompt: some View {
        HStack(alignment: .top, spacing: 12) {
            IconSeat(systemName: "person.text.rectangle", color: FF.accent, size: 36)
            VStack(alignment: .leading, spacing: 6) {
                Text("からだの情報を入れると予算が正確になります")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FF.textPrimary)
                Text("今は体重だけで基礎代謝を推定しています。性別・年齢・身長から計算し直します。")
                    .font(FF.fontCaption)
                    .lineSpacing(3)
                    .foregroundStyle(FF.textSecondary)
                Button("入力する") { isEditingBody = true }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FF.accentText)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(FF.accentSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: 節目の道のり

    private var start: Double { store.goal.currentWeightKg }
    private var target: Double { store.goal.targetWeightKg }
    private var latest: Double { store.latestWeight }

    private var progress: Double {
        let total = start - target
        guard abs(total) > 0.05 else { return 1 }
        return max(0, min(1, (start - latest) / total))
    }

    private var milestones: [Double] {
        let isLoss = target < start
        let range = abs(start - target)
        let step = max(1, (range / 6).rounded(.up))
        var values: [Double] = []
        var value = isLoss ? start.rounded(.down) : start.rounded(.up)
        if value == start { value += isLoss ? -step : step }
        while isLoss ? value > target + 0.05 : value < target - 0.05 {
            values.append(value)
            value += isLoss ? -step : step
        }
        return [start] + values + [target]
    }

    private var routePanel: some View {
        let plan = store.budgetPlan
        let remaining = abs(latest - target)
        let nextMilestone = milestones.dropFirst().first { target < start ? $0 < latest : $0 > latest }

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(target, specifier: "%.1f")kg まで")
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textSecondary)
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("あと")
                            .font(FF.fontBody)
                            .foregroundStyle(FF.textSecondary)
                        Text(String(format: "%.1f", remaining))
                            .font(FF.fontHero)
                            .monospacedDigit()
                            .foregroundStyle(FF.textPrimary)
                        Text("kg")
                            .font(FF.fontBody)
                            .foregroundStyle(FF.textSecondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("到着予定")
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textSecondary)
                    Text(plan.arrivalDate.map(Self.dateText) ?? "—")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FF.textPrimary)
                }
            }

            MilestoneTrack(milestones: milestones, start: start, target: target, progress: progress)
                .frame(height: 52)

            HStack(spacing: 8) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(FF.accent)
                Group {
                    if let nextMilestone {
                        Text("次の節目 \(nextMilestone.formatted(.number.precision(.fractionLength(0...1))))kg まであと \(abs(latest - nextMilestone), specifier: "%.1f")kg")
                    } else {
                        Text("ゴールまであと少しです")
                    }
                }
                .font(FF.fontCaption)
                .foregroundStyle(FF.textPrimary)
                Spacer()
                Text("スタートから \(latest - start, specifier: "%+.1f")kg")
                    .font(FF.fontCaption)
                    .monospacedDigit()
                    .foregroundStyle(FF.textSecondary)
            }
            .padding(10)
            .background(FF.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .panelStyle()
    }

    // MARK: ペース

    private var pacePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "ペースを選ぶ", subtitle: "迷ったら標準がおすすめです")
            HStack(spacing: 8) {
                ForEach(WeightPace.allCases) { pace in
                    paceButton(pace)
                }
            }
        }
        .panelStyle()
    }

    private func paceButton(_ pace: WeightPace) -> some View {
        let isSelected = store.goal.pace == pace
        let plan = store.budgetPlan(for: pace)
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                store.updatePace(pace)
            }
        } label: {
            VStack(spacing: 3) {
                Text(pace.label)
                    .font(FF.fontCaption.weight(isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? FF.accentText : FF.textSecondary)
                Text("\(pace.kgPerWeek.formatted())kg/週")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(FF.textPrimary)
                Text(plan.arrivalDate.map { "\(Self.shortDateText($0)) 到着" } ?? "—")
                    .font(.system(size: 11))
                    .foregroundStyle(FF.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? FF.accentSoft : FF.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? FF.accent : FF.separator, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: 予算の内訳

    private var budgetPanel: some View {
        let plan = store.budgetPlan
        let isLoss = plan.dailyDeltaKcal < 0

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "1日の予算の決まり方")
            HStack(spacing: 6) {
                budgetBox("推定消費", "\(plan.maintenanceKcal)", color: FF.burn)
                Text(isLoss ? "−" : "+")
                    .foregroundStyle(FF.textSecondary)
                budgetBox(isLoss ? "目標の赤字" : "目標の上乗せ", "\(abs(plan.dailyDeltaKcal))", color: FF.textSecondary)
                Text("=")
                    .foregroundStyle(FF.textSecondary)
                budgetBox("1日の予算", "\(plan.budgetKcal)", color: FF.accentText, emphasized: true)
            }
            Text(basalExplanation(plan))
                .font(FF.fontCaption)
                .lineSpacing(3)
                .foregroundStyle(FF.textSecondary)
            if plan.isFlooredAtBasal {
                Label("このペースだと基礎代謝（\(plan.basalKcal)kcal）を下回るため、予算を基礎代謝に合わせています。到着予定はこの予算で計算しています。", systemImage: "info.circle")
                    .font(FF.fontCaption)
                    .lineSpacing(3)
                    .foregroundStyle(FF.over)
            }
        }
        .panelStyle()
    }

    private func budgetBox(_ title: String, _ value: String, color: Color, emphasized: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 17, weight: emphasized ? .heavy : .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(emphasized ? FF.accentText : FF.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background((emphasized ? FF.accent : color).opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func basalExplanation(_ plan: BudgetPlan) -> String {
        let source: String
        switch plan.basalSource {
        case .healthKit: source = "ヘルスケアの実測（直近の平均）"
        case .formula: source = "性別・年齢・身長・体重からの計算"
        case .weightOnly: source = "体重からの概算"
        }
        return "基礎代謝 \(plan.basalKcal)kcal（\(source)）× 活動量 \(plan.activityFactor.formatted()) = 推定消費。脂肪1kg ≒ 7,200kcal で赤字を計算しています。"
    }

    // MARK: カロリー収支と体重の推移

    private var trendPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "カロリー収支と体重")
                Spacer()
                Text("直近42日")
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.textTertiary)
            }

            if store.ledgers.isEmpty && store.bodyMetrics.count < 2 {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 28))
                        .foregroundStyle(FF.textTertiary)
                    Text("食事と体重を記録すると、ここに推移が表示されます")
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                Chart {
                    ForEach(store.ledgers) { ledger in
                        BarMark(
                            x: .value("日付", ledger.date, unit: .day),
                            y: .value("収支", store.dailyBalanceKcal(for: ledger))
                        )
                        .foregroundStyle(store.dailyBalanceKcal(for: ledger) <= 0 ? FF.deficit : FF.over)
                        .cornerRadius(4)
                    }
                    ForEach(store.bodyMetrics) { metric in
                        LineMark(
                            x: .value("日付", metric.date, unit: .day),
                            y: .value("体重", metric.weightKg * 100)
                        )
                        .foregroundStyle(FF.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .frame(height: 200)
            }

            HStack(spacing: 12) {
                DeltaCard(title: "週次理論", kg: store.predictedWeightDeltaKg(from: store.sevenDayBalance))
                DeltaCard(title: "週次実績", kg: store.actualWeightDeltaKg(days: 7))
                DeltaCard(title: "月次理論", kg: store.predictedWeightDeltaKg(from: store.thirtyDayBalance))
            }
        }
        .panelStyle()
    }

    // MARK: 理論値と実績

    private var balancePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "理論値と実績")
            ComparisonRow(label: "週次", predicted: store.predictedWeightDeltaKg(from: store.sevenDayBalance), actual: store.actualWeightDeltaKg(days: 7))
            ComparisonRow(label: "月次", predicted: store.predictedWeightDeltaKg(from: store.thirtyDayBalance), actual: store.actualWeightDeltaKg(days: 30))
        }
        .panelStyle()
    }

    static func dateText(_ date: Date) -> String {
        date.formatted(.dateTime.month().day().weekday(.abbreviated).locale(Locale(identifier: "ja_JP")))
    }

    static func shortDateText(_ date: Date) -> String {
        date.formatted(.dateTime.month().day().locale(Locale(identifier: "ja_JP")))
    }
}

// MARK: - 節目のトラック

private struct MilestoneTrack: View {
    var milestones: [Double]
    var start: Double
    var target: Double
    var progress: Double

    /// スタートからゴールまでのうち、その体重がどこにあたるか(0...1)
    private func fraction(of value: Double) -> Double {
        let total = start - target
        guard abs(total) > 0.05 else { return 1 }
        return max(0, min(1, (start - value) / total))
    }

    var body: some View {
        GeometryReader { geo in
            let inset: CGFloat = 10
            let width = geo.size.width - inset * 2
            let currentX = inset + width * progress

            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(FF.separator)
                    .frame(width: width, height: 4)
                    .offset(x: inset, y: 12)
                Capsule()
                    .fill(FF.accent)
                    .frame(width: max(0, currentX - inset), height: 6)
                    .offset(x: inset, y: 11)

                ForEach(Array(milestones.enumerated()), id: \.offset) { index, value in
                    let x = inset + width * fraction(of: value)
                    let isGoal = index == milestones.count - 1
                    let isPassed = x <= currentX + 0.5
                    Circle()
                        .fill(isGoal ? FF.deficit : (isPassed ? FF.accent : FF.surface))
                        .overlay(Circle().strokeBorder(isPassed || isGoal ? Color.clear : FF.separator, lineWidth: 2))
                        .frame(width: isGoal ? 18 : 14, height: isGoal ? 18 : 14)
                        .position(x: x, y: 14)
                    Text(value.formatted(.number.precision(.fractionLength(0...1))))
                        .font(.system(size: 11, weight: isGoal ? .bold : .regular, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isGoal ? FF.deficit : FF.textSecondary)
                        .position(x: x, y: 42)
                }

                Circle()
                    .fill(FF.surface)
                    .overlay(Circle().strokeBorder(FF.accent, lineWidth: 4))
                    .frame(width: 20, height: 20)
                    .position(x: currentX, y: 14)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("目標までの進み具合 \(Int(progress * 100))%")
    }
}

// MARK: - 目標体重の編集

struct GoalEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var currentWeightKg = 70.0
    @State private var targetWeightKg = 65.0

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                FFStepperRow(
                    label: "今の体重",
                    valueText: String(format: "%.1fkg", currentWeightKg),
                    onMinus: { currentWeightKg = max(30, currentWeightKg - 0.1) },
                    onPlus: { currentWeightKg = min(200, currentWeightKg + 0.1) }
                )
                FFStepperRow(
                    label: "目標",
                    valueText: String(format: "%.1fkg", targetWeightKg),
                    onMinus: { targetWeightKg = max(30, targetWeightKg - 0.1) },
                    onPlus: { targetWeightKg = min(200, targetWeightKg + 0.1) }
                )
                Text("保存すると、今の体重を新しいスタート地点にして予算と到着予定を計算し直します。")
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.textSecondary)
                Spacer()
                Button {
                    store.updateGoal(currentWeightKg: currentWeightKg, targetWeightKg: targetWeightKg, pace: store.goal.pace)
                    dismiss()
                } label: {
                    Label("保存", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(FFPrimaryButtonStyle())
            }
            .padding()
            .background(FF.background)
            .navigationTitle("目標体重")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onAppear {
                currentWeightKg = store.latestWeight
                targetWeightKg = store.goal.targetWeightKg
            }
        }
    }
}

// MARK: - 身体情報の編集

struct BodyProfileEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var sex: BiologicalSex?
    @State private var age = 30
    @State private var heightCm = 165.0
    @State private var weeklyWorkoutDays = 3

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("基礎代謝の計算に使います")
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textSecondary)
                    HStack(spacing: 8) {
                        ForEach(BiologicalSex.allCases) { option in
                            Button {
                                sex = option
                            } label: {
                                Text(option.rawValue)
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 26)
                            }
                            .buttonStyle(FFCompactButtonStyle(tint: FF.accent, isSelected: sex == option))
                        }
                    }
                    FFStepperRow(
                        label: "年齢",
                        valueText: "\(age) 歳",
                        onMinus: { age = max(15, age - 1) },
                        onPlus: { age = min(90, age + 1) }
                    )
                    FFStepperRow(
                        label: "身長",
                        valueText: String(format: "%.0f cm", heightCm),
                        onMinus: { heightCm = max(120, heightCm - 1) },
                        onPlus: { heightCm = min(220, heightCm + 1) }
                    )
                    FFStepperRow(
                        label: "運動する回数",
                        valueText: "週 \(weeklyWorkoutDays) 回",
                        onMinus: { weeklyWorkoutDays = max(0, weeklyWorkoutDays - 1) },
                        onPlus: { weeklyWorkoutDays = min(7, weeklyWorkoutDays + 1) }
                    )
                    Button {
                        guard let sex else { return }
                        let year = Calendar.current.component(.year, from: .now) - age
                        store.updateBodyProfile(
                            BodyProfile(sex: sex, birthYear: year, heightCm: heightCm),
                            weeklyWorkoutDays: weeklyWorkoutDays
                        )
                        dismiss()
                    } label: {
                        Label("保存", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(FFPrimaryButtonStyle())
                    .disabled(sex == nil)
                    .opacity(sex == nil ? 0.5 : 1)
                }
                .padding()
            }
            .background(FF.background)
            .navigationTitle("からだの情報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onAppear {
                weeklyWorkoutDays = store.preferences.onboarding.weeklyWorkoutDays
                if let profile = store.preferences.bodyProfile {
                    sex = profile.sex
                    age = profile.age()
                    heightCm = profile.heightCm
                }
            }
        }
    }
}
