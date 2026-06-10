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

    private let sessionTypes = ["easy", "tempo", "interval", "long", "race", "hyrox"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    inputPanel
                    summaryPanel
                    recentPanel
                }
                .padding()
            }
            .background(FF.background)
            .navigationTitle("運動")
        }
    }

    // MARK: 記録を追加

    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "記録を追加")

            FFSegmentedPicker(
                options: WorkoutKind.allCases.filter { $0 != .strength },
                label: { $0.rawValue },
                selection: $kind,
                tint: FF.workoutColor(kind)
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sessionTypes, id: \.self) { type in
                        FFChip(
                            text: type,
                            color: FF.workoutColor(kind),
                            isSelected: sessionType == type
                        ) {
                            sessionType = type
                        }
                    }
                }
            }

            FFStepperRow(
                label: "距離",
                valueText: String(format: "%.1fkm", distanceKm),
                onMinus: { distanceKm = max(0, distanceKm - 0.5) },
                onPlus: { distanceKm = min(100, distanceKm + 0.5) }
            )

            FFStepperRow(
                label: "時間",
                valueText: "\(durationMinutes)分",
                onMinus: { durationMinutes = max(1, durationMinutes - 1) },
                onPlus: { durationMinutes = min(600, durationMinutes + 1) }
            )

            FFStepperRow(
                label: "消費",
                valueText: "\(calories)kcal",
                onMinus: { calories = max(0, calories - 25) },
                onPlus: { calories = min(3000, calories + 25) }
            )

            FFStepperRow(
                label: "きつさ RPE",
                valueText: "\(rpe)",
                onMinus: { rpe = max(1, rpe - 1) },
                onPlus: { rpe = min(10, rpe + 1) }
            )

            TextField("メモ", text: $note)
                .ffFieldStyle()

            Button {
                let saved = store.addCardioSession(kind: kind, distanceKm: distanceKm, durationMinutes: durationMinutes, calories: calories, note: note, rpe: rpe, sessionType: sessionType)
                modelContext.insert(CardioEntry(from: saved))
                try? modelContext.save()
                note = ""
            } label: {
                Label("追加", systemImage: "plus.circle.fill")
            }
            .buttonStyle(FFPrimaryButtonStyle())
        }
        .panelStyle()
    }

    // MARK: 種目別サマリー

    private var summaryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "種目別サマリー")

            ForEach(WorkoutKind.allCases.filter { $0 != .strength }) { kind in
                let sessions = store.cardioSessions.filter { $0.kind == kind }
                HStack(spacing: 10) {
                    IconSeat(systemName: icon(for: kind), color: FF.workoutColor(kind))
                    Text(kind.rawValue)
                        .font(FF.fontBody)
                        .foregroundStyle(FF.textPrimary)
                    Spacer()
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(String(format: "%.1f", sessions.map(\.distanceKm).reduce(0, +)))
                            .font(FF.fontNumber)
                            .monospacedDigit()
                            .foregroundStyle(FF.workoutColor(kind))
                        Text("km")
                            .font(FF.fontCaption)
                            .foregroundStyle(FF.textSecondary)
                    }
                }
            }
        }
        .panelStyle()
    }

    // MARK: 最近の記録

    private var recentPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "最近の記録", subtitle: store.cardioSessions.isEmpty ? nil : "長押しで削除できます")

            if store.cardioSessions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "figure.run.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(FF.textTertiary)
                    Text("まだ記録がありません。今日の運動から始めましょう")
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }

            ForEach(store.cardioSessions) { session in
                HStack(alignment: .top, spacing: 12) {
                    IconSeat(systemName: icon(for: session.kind), color: FF.workoutColor(session.kind))
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(session.kind.rawValue)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(FF.textPrimary)
                            FFBadge(text: session.sessionType, color: FF.workoutColor(session.kind))
                            Spacer()
                            Text(session.paceText)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(FF.textSecondary)
                        }
                        Text("\(session.distanceKm, specifier: "%.1f")km / \(session.durationMinutes)分 / \(session.calories)kcal")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(FF.workoutColor(session.kind))
                        Text("RPE \(session.rpe ?? 0)\(session.note.isEmpty ? "" : " / \(session.note)")")
                            .font(FF.fontCaption)
                            .foregroundStyle(FF.textSecondary)
                    }
                }
                .padding(12)
                .background(FF.surfaceSecondary.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contextMenu {
                    Button(role: .destructive) {
                        store.deleteCardioSession(session)
                        SwiftDataBridge.deleteCardioEntry(id: session.id, context: modelContext)
                    } label: {
                        Label("この記録を削除", systemImage: "trash")
                    }
                }
            }
        }
        .panelStyle()
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
