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
            .background(Color(.systemGroupedBackground))
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
                .font(.largeTitle.bold())
            Text("最初は細かくしすぎません。目的と生活リズムだけ決めて、今日やることが見える状態にします。")
                .foregroundStyle(.secondary)
        }
        .panelStyle()
    }

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("目的")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                ForEach(PrimaryGoal.allCases) { goal in
                    Button {
                        primaryGoal = goal
                    } label: {
                        Label(goal.rawValue, systemImage: icon(for: goal))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .tint(primaryGoal == goal ? .teal : .secondary)
                }
            }
        }
        .panelStyle()
    }

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("体重目標")
                .font(.headline)
            Stepper(value: $currentWeightKg, in: 30...200, step: 0.1) {
                Text("現在 \(currentWeightKg, specifier: "%.1f")kg")
                    .monospacedDigit()
            }
            Stepper(value: $targetWeightKg, in: 30...200, step: 0.1) {
                Text("目標 \(targetWeightKg, specifier: "%.1f")kg")
                    .monospacedDigit()
            }
            Text("目標はあとで変更できます。急ぎすぎず、週平均で見ていきます。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .panelStyle()
    }

    private var rhythmSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("1日の区切り")
                .font(.headline)
            Stepper(value: $dayStartHour, in: 0...23) {
                Text("起床時刻 \(dayStartHour):\(String(format: "%02d", dayStartMinute))")
                    .monospacedDigit()
            }
            Picker("分", selection: $dayStartMinute) {
                Text("00").tag(0)
                Text("15").tag(15)
                Text("30").tag(30)
                Text("45").tag(45)
            }
            .pickerStyle(.segmented)
            Text("深夜の食事や運動を、あなたの生活リズムに合わせて前日扱いにできます。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .panelStyle()
    }

    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("続け方")
                .font(.headline)
            Stepper(value: $weeklyWorkoutDays, in: 0...7) {
                Text("週 \(weeklyWorkoutDays) 回運動したい")
                    .monospacedDigit()
            }
            Picker("食事記録", selection: $mealTrackingStyle) {
                ForEach(MealTrackingStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)
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
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
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
