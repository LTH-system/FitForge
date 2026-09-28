import SwiftUI

/// ルーティンの一覧。タップでワークアウトを始める。無料は3個まで作れる
struct RoutinesPanel: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var premium: PremiumStore
    @State private var editingRoutine: WorkoutRoutine?
    @State private var routinePendingDeletion: WorkoutRoutine?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "ルーティン",
                subtitle: premium.isPremium
                    ? "タップで順番に記録を始めます。長押しで編集できます"
                    : "無料で\(PremiumStore.freeRoutineLimit)個まで作れます。長押しで編集できます"
            )

            if store.routines.isEmpty {
                Text("よく行う種目の組み合わせを登録しておくと、ジムで迷わず記録できます")
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.textSecondary)
            }

            ForEach(store.routines) { routine in
                routineRow(routine)
            }

            if store.canAddRoutine(isPremium: premium.isPremium) {
                Button {
                    editingRoutine = WorkoutRoutine(name: "", exercises: [])
                } label: {
                    Label("ルーティンを作る", systemImage: "plus.circle")
                }
                .buttonStyle(FFSecondaryButtonStyle())
            } else {
                PremiumLockedCard(feature: .unlimitedRoutines)
            }
        }
        .panelStyle()
        .sheet(item: $editingRoutine) { routine in
            RoutineEditorView(routine: routine)
        }
        .confirmationDialog(
            "このルーティンを削除しますか？",
            isPresented: Binding(
                get: { routinePendingDeletion != nil },
                set: { if !$0 { routinePendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: routinePendingDeletion
        ) { routine in
            Button("削除する", role: .destructive) {
                store.deleteRoutine(routine)
            }
            Button("やめる", role: .cancel) {}
        } message: { _ in
            Text("これまでの筋トレの記録は消えません。")
        }
    }

    private func routineRow(_ routine: WorkoutRoutine) -> some View {
        Button {
            router.startRoutine(routine)
        } label: {
            HStack(spacing: 12) {
                IconSeat(systemName: "list.bullet.rectangle", color: FF.strength, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(routine.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FF.textPrimary)
                    Text(summary(routine))
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(FF.strength)
            }
            .padding(10)
            .background(FF.surfaceSecondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(routine.exercises.isEmpty)
        .contextMenu {
            Button {
                editingRoutine = routine
            } label: {
                Label("編集", systemImage: "pencil")
            }
            Button(role: .destructive) {
                routinePendingDeletion = routine
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    private func summary(_ routine: WorkoutRoutine) -> String {
        let names = routine.exercises.map(\.name)
        guard let first = names.first else { return "種目がありません" }
        if names.count <= 2 { return names.joined(separator: "・") }
        return "\(first)・\(names[1]) ほか\(names.count - 2)種目"
    }
}

/// ルーティンの作成・編集
struct RoutineEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var routine: WorkoutRoutine
    @State private var newExerciseName = ""

    init(routine: WorkoutRoutine) {
        _routine = State(initialValue: routine)
    }

    private var isNew: Bool {
        !store.routines.contains { $0.id == routine.id }
    }

    private var canSave: Bool {
        !routine.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !routine.exercises.isEmpty
    }

    /// 記録したことのある種目を先に、続けてカタログから候補を出す
    private var suggestions: [String] {
        let query = newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let recorded = Array(Set(store.strengthSets.map(\.exercise))).sorted()
            .filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }
        let catalog = ExerciseCatalog.suggestions(for: query).map(\.nameJa)
        var seen = Set(routine.exercises.map(\.name))
        return (recorded + catalog).filter { seen.insert($0).inserted }.prefix(8).map { $0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("名前") {
                    TextField("例：胸の日、脚の日", text: $routine.name)
                }

                Section {
                    if routine.exercises.isEmpty {
                        Text("下から種目を追加してください")
                            .font(FF.fontCaption)
                            .foregroundStyle(FF.textSecondary)
                    }
                    ForEach($routine.exercises) { $exercise in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(exercise.name)
                                .font(.system(size: 15, weight: .semibold))
                            Stepper("\(exercise.targetSets)セット", value: $exercise.targetSets, in: 1...10)
                                .font(FF.fontCaption)
                            Stepper("\(exercise.targetReps)回", value: $exercise.targetReps, in: 1...30)
                                .font(FF.fontCaption)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { routine.exercises.remove(atOffsets: $0) }
                    .onMove { routine.exercises.move(fromOffsets: $0, toOffset: $1) }
                } header: {
                    HStack {
                        Text("種目（上から順に記録）")
                        Spacer()
                        if routine.exercises.count > 1 {
                            EditButton()
                                .font(FF.fontCaption)
                        }
                    }
                }

                Section("種目を追加") {
                    HStack {
                        TextField("種目名", text: $newExerciseName)
                        Button("追加") {
                            addExercise(newExerciseName)
                        }
                        .disabled(newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    ForEach(suggestions, id: \.self) { name in
                        Button {
                            addExercise(name)
                        } label: {
                            Label(name, systemImage: "plus")
                                .foregroundStyle(FF.textPrimary)
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "ルーティンを作る" : "ルーティンを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        routine.name = routine.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.saveRoutine(routine)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func addExercise(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // 前回の記録があれば、その回数を目標の初期値にする
        let lastReps = store.latestSet(for: trimmed)?.reps ?? 10
        routine.exercises.append(RoutineExercise(name: trimmed, targetSets: 3, targetReps: lastReps))
        newExerciseName = ""
    }
}
