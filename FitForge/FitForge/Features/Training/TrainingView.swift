import SwiftUI
import Charts
import SwiftData

struct TrainingView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.modelContext) private var modelContext
    @State private var selectedExercise = "ベンチプレス"
    @State private var exerciseName = "ベンチプレス"
    @State private var weightKg = 70.0
    @State private var reps = 8
    @State private var sets = 3
    @State private var rpe = 8
    @State private var note = ""
    @State private var selectedCategory: ExerciseCategory?

    /// 記録済み種目のみ表示する。カタログ全70種をセグメントに並べると幅が壊れるため。
    var exercises: [String] {
        let recorded = store.strengthSets.map(\.exercise)
        guard !recorded.isEmpty else { return ["ベンチプレス"] }
        return Array(Set(recorded)).sorted()
    }

    var selectedSets: [StrengthSet] {
        store.strengthSets.filter { $0.exercise == selectedExercise }.sorted { $0.date < $1.date }
    }

    var catalogSuggestions: [ExerciseCatalogItem] {
        let suggestions = ExerciseCatalog.suggestions(for: exerciseName)
        guard let selectedCategory else { return Array(suggestions.prefix(12)) }
        return Array(suggestions.filter { $0.category == selectedCategory }.prefix(12))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    exercisePickerCapsule
                    inputPanel
                    progressPanel
                    reminderPanel
                }
                .padding()
            }
            .background(FF.background)
            .navigationTitle("筋トレ")
        }
    }

    // MARK: 種目選択（カプセル包み）

    private var exercisePickerCapsule: some View {
        HStack(spacing: 8) {
            IconSeat(systemName: "dumbbell.fill", color: FF.strength, size: 28)
            Picker("記録を見る種目", selection: $selectedExercise) {
                ForEach(exercises, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(FF.strength)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(FF.surfaceSecondary, in: Capsule())
    }

    // MARK: 記録を追加

    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "記録を追加")

            TextField("種目名", text: $exerciseName)
                .ffFieldStyle()

            HStack(spacing: 8) {
                Text("部位")
                    .font(FF.fontCaption.weight(.medium))
                    .foregroundStyle(FF.textSecondary)
                Picker("部位", selection: $selectedCategory) {
                    Text("すべて").tag(nil as ExerciseCategory?)
                    ForEach(ExerciseCategory.allCases) { category in
                        Text(category.rawValue).tag(category as ExerciseCategory?)
                    }
                }
                .pickerStyle(.menu)
                .tint(FF.strength)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(FF.surfaceSecondary, in: Capsule())

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                ForEach(catalogSuggestions) { item in
                    Button {
                        exerciseName = item.nameJa
                        selectedExercise = item.nameJa
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.nameJa)
                                .lineLimit(1)
                            Text(item.category.rawValue)
                                .font(.system(size: 10))
                                .foregroundStyle(FF.textTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(FFCompactButtonStyle(tint: FF.strength, isSelected: exerciseName == item.nameJa))
                }
            }

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
                label: "セット",
                valueText: "\(sets)セット",
                onMinus: { sets = max(1, sets - 1) },
                onPlus: { sets = min(12, sets + 1) }
            )

            FFStepperRow(
                label: "きつさ RPE",
                valueText: "\(rpe)",
                onMinus: { rpe = max(1, rpe - 1) },
                onPlus: { rpe = min(10, rpe + 1) }
            )

            TextField("メモ 例: フォーム、疲労感、痛みなし", text: $note)
                .ffFieldStyle()

            Button {
                let saved = store.addStrengthSet(exercise: exerciseName, weightKg: weightKg, reps: reps, sets: sets, rpe: rpe, note: note)
                modelContext.insert(StrengthSetEntry(from: saved))
                try? modelContext.save()
                selectedExercise = exerciseName
                note = ""
            } label: {
                Label("追加", systemImage: "plus.circle.fill")
            }
            .buttonStyle(FFPrimaryButtonStyle())
            .disabled(exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .panelStyle()
    }

    // MARK: 重量と推定1RM

    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "重量と推定1RM")

            HStack(spacing: 8) {
                legendChip(color: FF.strength, label: "重量")
                legendChip(color: FF.hyrox, label: "推定1RM")
                Spacer()
            }

            Chart {
                ForEach(selectedSets) { set in
                    LineMark(x: .value("日付", set.date), y: .value("重量", set.weightKg))
                        .foregroundStyle(FF.strength)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    PointMark(x: .value("日付", set.date), y: .value("1RM", set.estimatedOneRepMax))
                        .foregroundStyle(FF.hyrox)
                }
            }
            .frame(height: 220)

            ForEach(selectedSets.reversed()) { set in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(set.exercise)
                            .font(FF.fontBody)
                            .foregroundStyle(FF.textPrimary)
                        Spacer()
                        Text("\(set.weightKg, specifier: "%.1f")kg x \(set.reps) x \(set.sets)")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(FF.strength)
                    }
                    if !set.note.isEmpty {
                        Text(set.note)
                            .font(FF.fontCaption)
                            .foregroundStyle(FF.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .panelStyle()
    }

    private func legendChip(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(FF.fontCaption.weight(.medium))
                .foregroundStyle(FF.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(FF.surfaceSecondary, in: Capsule())
    }

    // MARK: 次回の判断

    private var reminderPanel: some View {
        HStack(alignment: .top, spacing: 12) {
            IconSeat(systemName: "arrow.up.right", color: FF.strength)
            VStack(alignment: .leading, spacing: 6) {
                Text("次回の判断")
                    .font(FF.fontSection)
                    .foregroundStyle(FF.textPrimary)
                Text(nextProgressionText)
                    .font(FF.fontBody)
                    .lineSpacing(5)
                    .foregroundStyle(FF.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    private var nextProgressionText: String {
        guard let latest = selectedSets.last else { return "記録を追加すると提案が出ます。" }
        if latest.reps >= 8 {
            return "\(selectedExercise) は次回 +2.5kg が候補です。きつさが高い日は同重量でフォーム優先でもOK。"
        }
        return "\(selectedExercise) は同重量で合計レップ数を増やす段階です。8回到達で増量候補にします。"
    }
}
