import SwiftUI

/// 大会に向けたトレーニングプラン（プレミアム）。今週のメニューと、記録済みかどうかを表示する
struct RacePlanPanel: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var premium: PremiumStore
    @State private var isEditing = false
    @State private var isEndConfirmPresented = false

    var body: some View {
        Group {
            if !premium.isPremium {
                PremiumLockedCard(feature: .racePlan)
            } else if let plan = store.racePlan {
                planContent(plan)
            } else {
                emptyContent
            }
        }
        .sheet(isPresented: $isEditing) {
            RacePlanEditorView(plan: store.racePlan)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: プランなし

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconSeat(systemName: "flag.checkered", color: FF.marathon, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("大会プラン")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FF.textPrimary)
                    Text("大会の日と種目を決めると、今日から大会までの毎週のメニューを組み立てます")
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button {
                isEditing = true
            } label: {
                Label("大会プランを作る", systemImage: "plus.circle")
            }
            .buttonStyle(FFSecondaryButtonStyle())
        }
        .panelStyle()
    }

    // MARK: プランあり

    @ViewBuilder
    private func planContent(_ plan: RacePlan) -> some View {
        if let week = RacePlanner.week(for: plan) {
            let done = RacePlanner.completedWorkoutIDs(in: week, cardio: store.cardioSessions, strength: store.strengthSets)
            VStack(alignment: .leading, spacing: 12) {
                header(plan: plan, week: week)

                Text(week.phase.detail + (week.isRecoveryWeek ? "今週は回復の週なので、いつもより少なめです。" : ""))
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text("今週のメニュー")
                        .font(FF.fontCaption.weight(.semibold))
                        .foregroundStyle(FF.textSecondary)
                    Spacer()
                    Text("\(done.count)/\(week.workouts.count) 完了" + (week.totalKm > 0 ? " ・ 目安 \(week.totalKm.formatted(.number.precision(.fractionLength(0))))km" : ""))
                        .font(FF.fontCaption)
                        .monospacedDigit()
                        .foregroundStyle(FF.textSecondary)
                }

                ForEach(week.workouts) { workout in
                    workoutRow(workout, isDone: done.contains(workout.id))
                }

                Text("記録するときに、種類（ロング・テンポ・インターバル・大会など）を合わせると自動で完了になります。痛みや強い疲れがある日は休みましょう。")
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .panelStyle()
        } else {
            finishedContent(plan)
        }
    }

    private func header(plan: RacePlan, week: RacePlanWeek) -> some View {
        let days = RacePlanner.daysUntilRace(plan)
        return HStack(alignment: .top, spacing: 10) {
            IconSeat(systemName: "flag.checkered", color: FF.marathon, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(plan.raceType.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FF.textPrimary)
                HStack(spacing: 6) {
                    Text(days > 0 ? "あと\(days)日" : "今日が本番")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(FF.marathon)
                    FFBadge(text: week.phase.rawValue, color: FF.marathon)
                    Text(plan.raceDate.formatted(.dateTime.month().day().weekday(.abbreviated).locale(Locale(identifier: "ja_JP"))))
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textSecondary)
                }
            }
            Spacer(minLength: 0)
            Menu {
                Button("プランを編集") { isEditing = true }
                Button("プランを終了", role: .destructive) { isEndConfirmPresented = true }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(FF.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .confirmationDialog("大会プランを終了しますか？", isPresented: $isEndConfirmPresented, titleVisibility: .visible) {
                Button("終了する", role: .destructive) { store.setRacePlan(nil) }
                Button("やめる", role: .cancel) {}
            } message: {
                Text("これまでの運動の記録は消えません。")
            }
        }
    }

    private func workoutRow(_ workout: PlannedWorkout, isDone: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(isDone ? FF.deficit : FF.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isDone ? FF.textSecondary : FF.textPrimary)
                    .strikethrough(isDone)
                Text(workout.detail)
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(FF.surfaceSecondary.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func finishedContent(_ plan: RacePlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("\(plan.raceType.rawValue)のプランが終わりました。おつかれさまでした！", systemImage: "medal.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FF.textPrimary)
            Button {
                isEditing = true
            } label: {
                Label("次の大会のプランを作る", systemImage: "plus.circle")
            }
            .buttonStyle(FFSecondaryButtonStyle())
        }
        .panelStyle()
    }
}

/// 大会プランの作成・編集
struct RacePlanEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var raceType: RaceType
    @State private var raceDate: Date
    @State private var trainingDays: Int
    private let existing: RacePlan?

    init(plan: RacePlan?) {
        // 終わったプランは編集ではなく新しく作り直す
        let isActive = plan.map { RacePlanner.week(for: $0) != nil } ?? false
        existing = isActive ? plan : nil
        _raceType = State(initialValue: plan?.raceType ?? .half)
        _raceDate = State(initialValue: isActive ? (plan?.raceDate ?? .now) : (Calendar.current.date(byAdding: .weekOfYear, value: 12, to: .now) ?? .now))
        _trainingDays = State(initialValue: plan?.trainingDaysPerWeek ?? 3)
    }

    private var minimumDate: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now
    }

    private var maximumDate: Date {
        Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
    }

    private var weeksUntilRace: Int {
        max(0, RacePlanner.weeksBetween(.now, raceDate))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("大会") {
                    Picker("種目", selection: $raceType) {
                        ForEach(RaceType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    DatePicker("大会の日", selection: $raceDate, in: minimumDate...maximumDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                }

                Section {
                    Stepper("週\(trainingDays)日", value: $trainingDays, in: 3...5)
                } header: {
                    Text("トレーニングする日数")
                } footer: {
                    Text("無理なく続けられる日数を選んでください。")
                }

                if weeksUntilRace < 4 {
                    Section {
                        Label("大会まで\(weeksUntilRace)週しかありません。距離を急に増やさず、今の力で完走することを目標にしたメニューになります。", systemImage: "exclamationmark.triangle")
                            .font(FF.fontCaption)
                            .foregroundStyle(FF.textSecondary)
                    }
                }
            }
            .navigationTitle(existing == nil ? "大会プランを作る" : "大会プランを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var plan = existing ?? RacePlan(raceType: raceType, raceDate: raceDate, trainingDaysPerWeek: trainingDays)
                        plan.raceType = raceType
                        plan.raceDate = raceDate
                        plan.trainingDaysPerWeek = trainingDays
                        store.setRacePlan(plan)
                        dismiss()
                    }
                }
            }
        }
    }
}
