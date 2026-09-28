import SwiftUI
import SwiftData

/// セットごとに記録し、前回値の自動入力と休憩タイマーを持つワークアウトセッション画面。
/// 保存先は既存のStrengthSet（1セット＝1行）のままなので、ここでの記録も
/// 従来の「重量×回数×セット」形式の一括入力とグラフ・自己ベストを共有する
struct WorkoutSessionView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var premium: PremiumStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var exerciseName: String
    @State private var weightKg: Double
    @State private var reps: Int
    @State private var rpe = 8
    @State private var sessionStart = Date.now
    @State private var isResting = false
    @State private var restRemaining = 0
    @State private var restTotal = 120
    @State private var completedCount = 0
    @State private var now = Date.now
    @State private var celebratingSet: StrengthSet?
    @State private var routineIndex = 0

    /// ルーティンから始めたときの種目リスト
    private let routine: WorkoutRoutine?
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(initialExercise: String, routine: WorkoutRoutine? = nil) {
        self.routine = routine
        _exerciseName = State(initialValue: initialExercise)
        _weightKg = State(initialValue: 20)
        _reps = State(initialValue: 8)
    }

    /// このセッションで記録したセット（新しい順）
    private var loggedSets: [StrengthSet] {
        store.strengthSets
            .filter { $0.exercise == exerciseName && $0.date >= sessionStart }
            .sorted { $0.date > $1.date }
    }

    /// 前回セッション（このセッションより前）の最新セット
    private var previousSet: StrengthSet? {
        store.strengthSets
            .filter { $0.exercise == exerciseName && $0.date < sessionStart }
            .max { $0.date < $1.date }
    }

    private var elapsedText: String {
        let seconds = max(0, Int(now.timeIntervalSince(sessionStart)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    if let routine {
                        routinePanel(routine)
                    }
                    if let previousSet {
                        referencePanel(previousSet)
                    }
                    if premium.isPremium, loggedSets.isEmpty {
                        ProgressionSuggestionCard(exercise: exerciseName, before: sessionStart) { suggestion in
                            weightKg = suggestion.weightKg
                            reps = suggestion.reps
                        }
                    }
                    if isResting {
                        restPanel
                    }
                    inputPanel
                    if !loggedSets.isEmpty {
                        loggedPanel
                    }
                }
                .padding()
            }
            .background(FF.background)
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("終了") { dismiss() }
                }
            }
            .onAppear { prefillFromPrevious() }
            .onReceive(clock) { tick in
                now = tick
                guard isResting else { return }
                if restRemaining > 0 {
                    restRemaining -= 1
                } else {
                    isResting = false
                }
            }
            .sensoryFeedback(.success, trigger: completedCount)
            .fullScreenCover(item: $celebratingSet) { set in
                PersonalBestCelebrationView(celebrating: set, store: store)
            }
        }
    }

    // MARK: ヘッダー

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("セット \(loggedSets.count + 1)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(FF.textPrimary)
                TextField("種目名", text: $exerciseName)
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.textSecondary)
            }
            Spacer()
            Text(elapsedText)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(FF.textSecondary)
        }
    }

    // MARK: 前回・自己ベスト

    private func referencePanel(_ previous: StrengthSet) -> some View {
        HStack(spacing: 8) {
            FFBadge(text: "前回 \(previous.weightKg.formatted())kg × \(previous.reps)回", color: FF.strength)
            if let best = store.personalBestWeight(for: exerciseName) {
                FFBadge(text: "ベスト \(best.formatted())kg", color: FF.strength)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: 休憩タイマー

    private var restPanel: some View {
        VStack(spacing: 10) {
            HStack {
                Text("休憩中")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FF.textSecondary)
                Spacer()
                Text(String(format: "%d:%02d", restRemaining / 60, restRemaining % 60))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(FF.textPrimary)
            }
            ProgressView(value: Double(restTotal - restRemaining), total: Double(max(1, restTotal)))
                .tint(FF.accent)

            HStack(spacing: 8) {
                restButton("−15秒") { restRemaining = max(0, restRemaining - 15) }
                restButton("+15秒") { restRemaining += 15 }
                restButton("スキップ") { isResting = false }
            }
        }
        .padding(14)
        .background(FF.surfaceSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func restButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(FF.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(FF.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .buttonStyle(.plain)
    }

    // MARK: 入力

    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            FFStepperRow(
                label: "重量",
                valueText: String(format: "%.1fkg", weightKg),
                onMinus: { weightKg = max(0, weightKg - 2.5) },
                onPlus: { weightKg = min(300, weightKg + 2.5) }
            )
            FFStepperRow(
                label: "回数",
                valueText: "\(reps)回",
                onMinus: { reps = max(1, reps - 1) },
                onPlus: { reps = min(30, reps + 1) }
            )
            FFStepperRow(
                label: "きつさ RPE",
                valueText: "\(rpe)",
                onMinus: { rpe = max(1, rpe - 1) },
                onPlus: { rpe = min(10, rpe + 1) }
            )

            Button {
                completeSet()
            } label: {
                Label("このセットを完了", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(FFPrimaryButtonStyle())
            .disabled(exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .panelStyle()
    }

    private func completeSet() {
        let saved = store.addStrengthSet(exercise: exerciseName, weightKg: weightKg, reps: reps, sets: 1, rpe: rpe, note: "")
        modelContext.insert(StrengthSetEntry(from: saved))
        try? modelContext.save()
        restRemaining = restTotal
        isResting = true
        completedCount += 1
        if PersonalBestDetector.isBestWeight(saved, among: store.strengthSets) {
            celebratingSet = saved
        }
    }

    private func prefillFromPrevious() {
        if let previousSet {
            weightKg = previousSet.weightKg
            reps = previousSet.reps
            rpe = previousSet.rpe ?? 8
        }
        // ルーティンの目標回数を優先する
        if let target = currentRoutineExercise {
            reps = target.targetReps
        }
    }

    // MARK: ルーティン

    private var currentRoutineExercise: RoutineExercise? {
        guard let routine, routine.exercises.indices.contains(routineIndex) else { return nil }
        return routine.exercises[routineIndex]
    }

    /// このセッションで、その種目を何セット記録したか
    private func completedSets(for name: String) -> Int {
        store.strengthSets.filter { $0.exercise == name && $0.date >= sessionStart }.count
    }

    private func moveToRoutineExercise(_ index: Int) {
        guard let routine, routine.exercises.indices.contains(index) else { return }
        routineIndex = index
        exerciseName = routine.exercises[index].name
        isResting = false
        prefillFromPrevious()
    }

    private func routinePanel(_ routine: WorkoutRoutine) -> some View {
        let current = currentRoutineExercise
        let done = current.map { completedSets(for: $0.name) } ?? 0
        let isCurrentDone = current.map { done >= $0.targetSets } ?? false
        let isLast = routineIndex >= routine.exercises.count - 1

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(routine.name, systemImage: "list.bullet.rectangle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FF.textPrimary)
                Spacer()
                Text("種目 \(routineIndex + 1) / \(routine.exercises.count)")
                    .font(FF.fontCaption)
                    .monospacedDigit()
                    .foregroundStyle(FF.textSecondary)
            }

            if let current {
                Text("目標 \(current.targetSets)セット × \(current.targetReps)回 ・ 完了 \(min(done, current.targetSets))/\(current.targetSets)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isCurrentDone ? FF.deficit : FF.strength)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(routine.exercises.enumerated()), id: \.element.id) { index, exercise in
                        let finished = completedSets(for: exercise.name) >= exercise.targetSets
                        Button {
                            moveToRoutineExercise(index)
                        } label: {
                            HStack(spacing: 4) {
                                if finished {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                Text(exercise.name)
                            }
                            .font(FF.fontChip)
                            .foregroundStyle(index == routineIndex ? .white : (finished ? FF.deficit : FF.textSecondary))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(index == routineIndex ? FF.strength : FF.surface, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !isLast {
                Button {
                    moveToRoutineExercise(routineIndex + 1)
                } label: {
                    Label("次の種目へ", systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(FFCompactButtonStyle(tint: FF.strength, isSelected: isCurrentDone))
            } else if isCurrentDone {
                Label("ルーティン完了！おつかれさまでした", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FF.deficit)
            }
        }
        .padding(14)
        .background(FF.surfaceSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: このセッションのセット

    private var loggedPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "このセッションのセット", subtitle: "長押しで削除できます")

            ForEach(Array(loggedSets.enumerated()), id: \.element.id) { index, set in
                HStack(spacing: 12) {
                    Text("\(loggedSets.count - index)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(FF.textSecondary)
                        .frame(width: 20)
                    Text("\(set.weightKg.formatted())kg × \(set.reps)回")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(FF.textPrimary)
                    Spacer()
                    if let rpe = set.rpe {
                        Text("RPE \(rpe)")
                            .font(FF.fontCaption)
                            .foregroundStyle(FF.textSecondary)
                    }
                }
                .padding(.vertical, 4)
                .contextMenu {
                    Button(role: .destructive) {
                        store.deleteStrengthSet(set)
                        SwiftDataBridge.deleteStrengthSetEntry(id: set.id, context: modelContext)
                    } label: {
                        Label("このセットを削除", systemImage: "trash")
                    }
                }
            }
        }
        .panelStyle()
    }
}
