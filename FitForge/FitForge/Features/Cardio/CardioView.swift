import SwiftUI
import SwiftData

struct CardioView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.modelContext) private var modelContext
    @State private var kind: WorkoutKind = .running
    @State private var distanceKm = 5.0
    @State private var durationMinutes = 30
    @State private var calories = 350
    @State private var note = ""
    @State private var rpe = 5
    @State private var sessionType = "easy"

    var body: some View {
        NavigationStack {
            List {
                Section("記録を追加") {
                    Picker("種目", selection: $kind) {
                        ForEach(WorkoutKind.allCases.filter { $0 != .strength }) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }

                    Picker("タイプ", selection: $sessionType) {
                        ForEach(["easy", "tempo", "interval", "long", "race", "hyrox"], id: \.self) { Text($0).tag($0) }
                    }

                    Stepper(value: $distanceKm, in: 0...100, step: 0.5) {
                        Text("距離 \(distanceKm, specifier: "%.1f")km")
                            .monospacedDigit()
                    }

                    Stepper(value: $durationMinutes, in: 1...600) {
                        Text("時間 \(durationMinutes)分")
                            .monospacedDigit()
                    }

                    Stepper(value: $calories, in: 0...3000, step: 25) {
                        Text("消費 \(calories)kcal")
                            .monospacedDigit()
                    }

                    Stepper(value: $rpe, in: 1...10) {
                        Text("きつさ RPE \(rpe)")
                            .monospacedDigit()
                    }

                    TextField("メモ", text: $note)

                    Button {
                        let saved = store.addCardioSession(kind: kind, distanceKm: distanceKm, durationMinutes: durationMinutes, calories: calories, note: note, rpe: rpe, sessionType: sessionType)
                        modelContext.insert(CardioEntry(from: saved))
                        try? modelContext.save()
                        note = ""
                    } label: {
                        Label("追加", systemImage: "plus.circle.fill")
                    }
                }

                Section("種目別サマリー") {
                    ForEach(WorkoutKind.allCases.filter { $0 != .strength }) { kind in
                        let sessions = store.cardioSessions.filter { $0.kind == kind }
                        HStack {
                            Label(kind.rawValue, systemImage: icon(for: kind))
                            Spacer()
                            Text("\(sessions.map(\.distanceKm).reduce(0, +), specifier: "%.1f") km")
                                .monospacedDigit()
                        }
                    }
                }

                Section("最近の記録") {
                    ForEach(store.cardioSessions) { session in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(session.kind.rawValue, systemImage: icon(for: session.kind))
                                Spacer()
                                Text(session.paceText)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(session.distanceKm, specifier: "%.1f")km / \(session.durationMinutes)分 / \(session.calories)kcal")
                                .font(.subheadline)
                            Text("\(session.sessionType) / RPE \(session.rpe ?? 0) / \(session.note)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("運動")
        }
    }

    private func icon(for kind: WorkoutKind) -> String {
        switch kind {
        case .strength: "dumbbell"
        case .running: "figure.run"
        case .hyrox: "figure.cross.training"
        case .marathon: "medal"
        }
    }
}
