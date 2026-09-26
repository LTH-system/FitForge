import SwiftUI
import SwiftData

struct DashboardView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var healthKit: HealthKitService
    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var modelContext

    private static let dailyStepGoal = 8_000

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    heroPanel
                    nextActionPanel
                    timelinePanel
                    healthKitRow
                }
                .padding()
            }
            .background(FF.background)
            .refreshable { await syncHealthKitToday() }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - ヘッダー

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "ja_JP"))))
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.textSecondary)
                Text("今日")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(FF.textPrimary)
            }
            Spacer()
            if store.currentStreak > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(FF.accent)
                    Text("\(store.currentStreak)日連続")
                        .monospacedDigit()
                        .foregroundStyle(FF.accentText)
                }
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(FF.surface, in: Capsule())
                .accessibilityLabel("\(store.currentStreak)日連続で記録中。週2日までは休んでも途切れません")
            }
            NavigationLink {
                SettingsView()
                    .toolbar(.visible, for: .navigationBar)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(FF.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("マイページ")
        }
    }

    // MARK: - ヒーロー（3つのリングと残りカロリー）

    private var heroPanel: some View {
        let budget = store.dailyCalorieBudget
        let intake = store.todayIntakeKcal
        let protein = store.todayPFC.protein
        let proteinTarget = store.proteinTargetG
        let steps = store.todayLedger?.stepCount ?? Int(healthKit.latestStepCount)
        let remaining = budget - intake
        let burn = store.expenditureKcal(for: .now)
        let isBurnEstimated = store.isExpenditureEstimated(for: .now)

        let rings = [
            RingSpec(label: "食事", progress: Double(intake) / Double(max(1, budget)), color: remaining >= 0 ? FF.accent : FF.over),
            RingSpec(label: "たんぱく質", progress: Double(protein) / Double(max(1, proteinTarget)), color: FF.protein),
            RingSpec(label: "歩数", progress: Double(steps) / Double(Self.dailyStepGoal), color: FF.burn)
        ]

        return VStack(spacing: 16) {
            HStack(spacing: 16) {
                ActivityRings(rings: rings)
                    .frame(width: 148, height: 148)

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(remaining >= 0 ? "残りカロリー" : "カロリー超過")
                            .font(FF.fontCaption)
                            .foregroundStyle(FF.textSecondary)
                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            Text("\(abs(remaining))")
                                .font(FF.fontHero)
                                .monospacedDigit()
                                .foregroundStyle(remaining >= 0 ? FF.textPrimary : FF.over)
                                .contentTransition(.numericText())
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Text("kcal")
                                .font(FF.fontCaption)
                                .foregroundStyle(FF.textSecondary)
                        }
                    }
                    legendRow(color: rings[0].color, label: "食事", value: "\(intake)", total: "/\(budget)")
                    legendRow(color: FF.protein, label: "たんぱく質", value: "\(protein)", total: "/\(proteinTarget)g")
                    legendRow(color: FF.burn, label: "歩数", value: steps.formatted(), total: "/\(Self.dailyStepGoal / 1000)千")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                MetricCard(title: "食べた", value: "\(intake)", unit: "kcal", color: FF.intake, icon: "fork.knife")
                MetricCard(title: isBurnEstimated ? "消費(推定)" : "消費", value: "\(burn)", unit: "kcal", color: FF.burn, icon: "flame.fill")
                MetricCard(title: "差分", value: "\(intake - burn)", unit: "kcal", color: intake - burn <= 0 ? FF.deficit : FF.over, icon: "scalemass.fill")
            }
        }
        .panelStyle()
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: intake)
    }

    private func legendRow(color: Color, label: String, value: String, total: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(FF.textSecondary)
            Spacer(minLength: 4)
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(FF.textPrimary)
            + Text(total)
                .foregroundStyle(FF.textTertiary)
        }
        .font(FF.fontCaption)
        .monospacedDigit()
        .lineLimit(1)
    }

    // MARK: - 次の一手

    private var nextActionPanel: some View {
        let action = store.nextAction()

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(FF.ctaSolid, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("次の一手 · \(action.title)")
                        .font(FF.fontCaption.weight(.bold))
                        .foregroundStyle(FF.accentText)
                    Text(action.detail)
                        .font(.system(size: 15, weight: .medium))
                        .lineSpacing(4)
                        .foregroundStyle(FF.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            switch action.kind {
            case .meal:
                HStack(spacing: 8) {
                    Button {
                        router.open(.meals)
                    } label: {
                        Label("食事を記録", systemImage: "fork.knife")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(FF.ctaSolid, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Button {
                        router.isQuickAddPresented = true
                    } label: {
                        Text("いつもの")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(FF.accentText)
                            .padding(.horizontal, 18)
                            .frame(minHeight: 44)
                            .background(FF.surface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            case .weight:
                Button {
                    router.isQuickAddPresented = true
                } label: {
                    Label("体重を記録", systemImage: "scalemass")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(FF.ctaSolid, in: Capsule())
                }
                .buttonStyle(.plain)
            case .rest:
                EmptyView()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FF.accentSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - 今日の記録

    private struct TimelineItem: Identifiable {
        var id: UUID
        var date: Date
        var icon: String
        var color: Color
        var title: String
        var detail: String
        var trailing: String?
        var badge: String?
    }

    private var todayItems: [TimelineItem] {
        let isToday = { (date: Date) in LifeDayService.isSameLifeDay(date, .now, preferences: store.preferences) }

        let meals = store.todayMeals.map {
            TimelineItem(id: $0.id, date: $0.date, icon: "fork.knife", color: FF.intake, title: $0.title,
                         detail: "P\($0.proteinG)g・F\($0.fatG)g・C\($0.carbG)g", trailing: "\($0.estimatedKcal) kcal")
        }
        let strength = store.strengthSets.filter { isToday($0.date) }.map { set in
            let isBest = PersonalBestDetector.isBestWeight(set, among: store.strengthSets)
            return TimelineItem(id: set.id, date: set.date, icon: "dumbbell", color: FF.strength, title: set.exercise,
                                detail: "\(set.weightKg.formatted())kg × \(set.reps)回 × \(set.sets)セット",
                                badge: isBest ? "ベスト更新" : nil)
        }
        let cardio = store.cardioSessions.filter { isToday($0.date) }.map {
            TimelineItem(id: $0.id, date: $0.date, icon: "figure.run", color: FF.workoutColor($0.kind), title: $0.kind.rawValue,
                         detail: String(format: "%.1fkm / %d分", $0.distanceKm, $0.durationMinutes), trailing: "\($0.calories) kcal")
        }
        let weights = store.bodyMetrics.filter { isToday($0.date) }.map {
            TimelineItem(id: $0.id, date: $0.date, icon: "scalemass", color: FF.burn, title: "体重",
                         detail: $0.source == .healthKit ? "ヘルスケアから" : "記録", trailing: String(format: "%.1f kg", $0.weightKg))
        }
        let checkIns = store.checkIns.filter { isToday($0.date) }.map {
            TimelineItem(id: $0.id, date: $0.date, icon: "checkmark.circle", color: FF.deficit, title: "チェックイン",
                         detail: "体調 \($0.condition)・気分 \($0.mood)")
        }
        return (meals + strength + cardio + weights + checkIns).sorted { $0.date < $1.date }
    }

    private var timelinePanel: some View {
        let items = todayItems

        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: "今日の記録")
                Spacer()
                Text("\(items.count)件")
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.textSecondary)
            }
            .padding(.bottom, 6)

            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 26))
                        .foregroundStyle(FF.textTertiary)
                    Text("下の＋から、食事や体重を記録してみましょう")
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            ForEach(items) { item in
                HStack(spacing: 12) {
                    Text(item.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 13, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(FF.textSecondary)
                        .frame(width: 44, alignment: .leading)
                    IconSeat(systemName: item.icon, color: item.color, size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FF.textPrimary)
                            .lineLimit(1)
                        Text(item.detail)
                            .font(FF.fontCaption)
                            .foregroundStyle(FF.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if let badge = item.badge {
                        Label(badge, systemImage: "trophy.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(FF.strength)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(FF.strength.opacity(0.12), in: Capsule())
                    } else if let trailing = item.trailing {
                        Text(trailing)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(item.color)
                    }
                }
                .padding(.vertical, 6)
                .overlay(alignment: .top) {
                    Rectangle().fill(FF.separator).frame(height: 1)
                }
            }
        }
        .panelStyle()
    }

    // MARK: - ヘルスケア同期

    private var healthKitRow: some View {
        HStack(spacing: 10) {
            IconSeat(systemName: "heart.fill", color: FF.protein, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("ヘルスケア · \(healthKit.authorizationStatusText)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FF.textPrimary)
                Text("画面を下に引っぱると今日の歩数と消費を同期します")
                    .font(.system(size: 11))
                    .foregroundStyle(FF.textSecondary)
            }
            Spacer()
            Button {
                Task {
                    if healthKit.authorizationStatusText != "連携済み" {
                        await healthKit.requestAuthorization(preferences: store.preferences)
                    }
                    await syncHealthKitToday()
                }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FF.accentText)
                    .frame(width: 44, height: 44)
                    .background(FF.accentSoft, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("ヘルスケアと同期")
        }
        .padding(12)
        .background(FF.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func syncHealthKitToday() async {
        guard healthKit.isAvailable else { return }
        await healthKit.refreshTodaySummary(preferences: store.preferences)
        store.applyHealthKitSummary(
            stepCount: Int(healthKit.latestStepCount),
            activeKcal: Int(healthKit.latestActiveEnergyKcal),
            basalKcal: Int(healthKit.latestBasalEnergyKcal),
            bodyMassKg: healthKit.latestBodyMassKg
        )
        SwiftDataBridge.upsertDailySummary(
            lifeDayStart: LifeDayService.startOfLifeDay(containing: .now, preferences: store.preferences),
            intakeKcal: store.todayLedger?.intakeKcal ?? 0,
            activeKcal: Int(healthKit.latestActiveEnergyKcal),
            basalKcal: Int(healthKit.latestBasalEnergyKcal),
            stepCount: Int(healthKit.latestStepCount),
            preferences: store.preferences,
            context: modelContext
        )
        if let bodyMassKg = healthKit.latestBodyMassKg {
            SwiftDataBridge.replaceHealthKitBodyMetric(weightKg: bodyMassKg, date: .now, preferences: store.preferences, context: modelContext)
        }
        try? modelContext.save()
    }
}
