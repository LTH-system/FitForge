import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var primaryGoal: PrimaryGoal = .fatLoss
    @State private var currentWeightKg = 78.0
    @State private var targetWeightKg = 72.0
    @State private var dayStartHour = 5
    @State private var dayStartMinute = 0
    @State private var weeklyWorkoutDays = 3
    @State private var mealTrackingStyle: MealTrackingStyle = .standard

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                FF.background
                    .ignoresSafeArea()

                Circle()
                    .fill(FF.accentGradient)
                    .frame(width: 340, height: 340)
                    .blur(radius: 80)
                    .opacity(0.25)
                    .offset(y: -140)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        goalSection
                        weightSection
                        rhythmSection
                        habitsSection
                        startButton
                    }
                    .padding()
                }
            }
            .navigationTitle("初期設定")
            .onAppear {
                currentWeightKg = store.latestWeight
                targetWeightKg = store.goal.targetWeightKg
                dayStartHour = store.preferences.dayStartHour
                dayStartMinute = store.preferences.dayStartMinute
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("あなた用に整えます")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(FF.textPrimary)
            Text("最初は細かくしすぎません。目的と生活リズムだけ決めて、今日やることが見える状態にします。")
                .font(FF.fontBody)
                .lineSpacing(5)
                .foregroundStyle(FF.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "目的", subtitle: "いちばん近いものを1つ選んでください")
            VStack(spacing: 8) {
                ForEach(PrimaryGoal.allCases) { goal in
                    goalCard(goal)
                }
            }
        }
        .panelStyle()
    }

    private func goalCard(_ goal: PrimaryGoal) -> some View {
        let isSelected = primaryGoal == goal
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                primaryGoal = goal
            }
        } label: {
            HStack(spacing: 12) {
                IconSeat(systemName: icon(for: goal), color: isSelected ? FF.accent : FF.textTertiary, size: 36)
                Text(goal.rawValue)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(FF.textPrimary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? FF.accent : FF.separator)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
            .background(
                isSelected ? FF.accentSoft : FF.surface,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? FF.accent : FF.separator, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "体重目標")
            FFStepperRow(
                label: "現在",
                valueText: String(format: "%.1f kg", currentWeightKg),
                onMinus: { currentWeightKg = max(30, currentWeightKg - 0.1) },
                onPlus: { currentWeightKg = min(200, currentWeightKg + 0.1) }
            )
            FFStepperRow(
                label: "目標",
                valueText: String(format: "%.1f kg", targetWeightKg),
                onMinus: { targetWeightKg = max(30, targetWeightKg - 0.1) },
                onPlus: { targetWeightKg = min(200, targetWeightKg + 0.1) }
            )
            Text("目標はあとで変更できます。急ぎすぎず、週平均で見ていきます。")
                .font(FF.fontCaption)
                .foregroundStyle(FF.textSecondary)
        }
        .panelStyle()
    }

    private var rhythmSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "1日の区切り")
            FFStepperRow(
                label: "起床時刻",
                valueText: "\(dayStartHour):\(String(format: "%02d", dayStartMinute))",
                onMinus: { dayStartHour = max(0, dayStartHour - 1) },
                onPlus: { dayStartHour = min(23, dayStartHour + 1) }
            )
            FFSegmentedPicker(
                options: [0, 15, 30, 45],
                label: { String(format: "%02d", $0) },
                selection: $dayStartMinute,
                tint: FF.accent
            )
            Text("深夜の食事や運動を、あなたの生活リズムに合わせて前日扱いにできます。")
                .font(FF.fontCaption)
                .foregroundStyle(FF.textSecondary)
        }
        .panelStyle()
    }

    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "続け方")
            FFStepperRow(
                label: "運動したい回数",
                valueText: "週 \(weeklyWorkoutDays) 回",
                onMinus: { weeklyWorkoutDays = max(0, weeklyWorkoutDays - 1) },
                onPlus: { weeklyWorkoutDays = min(7, weeklyWorkoutDays + 1) }
            )
            VStack(alignment: .leading, spacing: 6) {
                Text("食事の記録スタイル")
                    .font(FF.fontCaption.weight(.medium))
                    .foregroundStyle(FF.textSecondary)
                FFSegmentedPicker(
                    options: Array(MealTrackingStyle.allCases),
                    label: { $0.rawValue },
                    selection: $mealTrackingStyle,
                    tint: FF.accent
                )
            }
        }
        .panelStyle()
    }

    private var startButton: some View {
        Button {
            store.completeOnboarding(
                primaryGoal: primaryGoal,
                currentWeightKg: currentWeightKg,
                targetWeightKg: targetWeightKg,
                dayStartHour: dayStartHour,
                dayStartMinute: dayStartMinute,
                weeklyWorkoutDays: weeklyWorkoutDays,
                mealTrackingStyle: mealTrackingStyle
            )
        } label: {
            Label("FitForgeを始める", systemImage: "arrow.right.circle.fill")
        }
        .buttonStyle(FFPrimaryButtonStyle())
    }

    private func icon(for goal: PrimaryGoal) -> String {
        switch goal {
        case .fatLoss: "scalemass"
        case .muscleGain: "dumbbell"
        case .running: "figure.run"
        case .hyrox: "figure.cross.training"
        case .health: "heart"
        }
    }
}
