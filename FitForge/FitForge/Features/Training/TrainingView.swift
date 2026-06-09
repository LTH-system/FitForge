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
                VStack(spacing: 18) {
                    Picker("記録を見る種目", selection: $selectedExercise) {
                        ForEach(exercises, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)

                    inputPanel
                    progressPanel
                    reminderPanel
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("筋トレ")
        }
    }

    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("記録を追加")
                .font(.headline)

            TextField("種目名", text: $exerciseName)
                .textFieldStyle(.roundedBorder)

            Picker("部位", selection: $selectedCategory) {
                Text("すべて").tag(nil as ExerciseCategory?)
                ForEach(ExerciseCategory.allCases) { category in
                    Text(category.rawValue).tag(category as ExerciseCategory?)
                }
            }
            .pickerStyle(.menu)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(catalogSuggestions) { item in
                    Button {
                        exerciseName = item.nameJa
                        selectedExercise = item.nameJa
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.nameJa)
                                .font(.caption.bold())
                                .lineLimit(1)
                            Text(item.category.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }
            }

            HStack(spacing: 12) {
                Stepper(value: $weightKg, in: 0...300, step: 2.5) {
                    Text("\(weightKg, specifier: "%.1f")kg")
                        .monospacedDigit()
                }
                Stepper(value: $reps, in: 1...30) {
                    Text("\(reps)回")
                        .monospacedDigit()
                }
            }

            Stepper(value: $sets, in: 1...12) {
                Text("\(sets)セット")
                    .monospacedDigit()
            }

            Stepper(value: $rpe, in: 1...10) {
                Text("きつさ RPE \(rpe)")
                    .monospacedDigit()
            }

            TextField("メモ 例: フォーム、疲労感、痛みなし", text: $note)
                .textFieldStyle(.roundedBorder)

            Button {
                let saved = store.addStrengthSet(exercise: exerciseName, weightKg: weightKg, reps: reps, sets: sets, rpe: rpe, note: note)
                modelContext.insert(StrengthSetEntry(from: saved))
                try? modelContext.save()
                selectedExercise = exerciseName
                note = ""
            } label: {
                Label("追加", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .panelStyle()
    }

    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("重量と推定1RM")
                .font(.headline)

            Chart {
                ForEach(selectedSets) { set in
                    LineMark(x: .value("日付", set.date), y: .value("重量", set.weightKg))
                        .foregroundStyle(.teal)
                    PointMark(x: .value("日付", set.date), y: .value("1RM", set.estimatedOneRepMax))
                        .foregroundStyle(.purple)
                }
            }
            .frame(height: 220)

            ForEach(selectedSets.reversed()) { set in
                HStack {
                    Text(set.exercise)
                    Spacer()
                    Text("\(set.weightKg, specifier: "%.1f")kg x \(set.reps) x \(set.sets)")
                        .monospacedDigit()
                }
                .font(.subheadline)
                if !set.note.isEmpty {
                    Text(set.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .panelStyle()
    }

    private var reminderPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("次回の判断")
                .font(.headline)

            Text(nextProgressionText)
                .font(.body)
                .foregroundStyle(.primary)
        }
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
