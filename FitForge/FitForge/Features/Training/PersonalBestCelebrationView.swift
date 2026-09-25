import SwiftUI
import Charts

/// 自己ベスト更新の演出画面。筋トレの重量PBと有酸素の距離PBの両方に使う
struct PersonalBestCelebrationView: View {
    @Environment(\.dismiss) private var dismiss

    var exerciseTitle: String
    var valueText: String
    var unitText: String
    var badge: Badge?
    var trend: [TrendPoint]
    var trendTitle: String
    var footerText: String

    struct Badge {
        var label: String
        var value: String
        var delta: String
    }

    struct TrendPoint: Identifiable {
        var id = UUID()
        var dateLabel: String
        var value: Double
        var isLatest: Bool
    }

    init(exerciseTitle: String, valueText: String, unitText: String, badge: Badge?, trend: [TrendPoint], trendTitle: String, footerText: String) {
        self.exerciseTitle = exerciseTitle
        self.valueText = valueText
        self.unitText = unitText
        self.badge = badge
        self.trend = trend
        self.trendTitle = trendTitle
        self.footerText = footerText
    }

    /// 筋トレの重量PB用
    init(celebrating set: StrengthSet, store: AppStore) {
        let allTrend = PersonalBestDetector.oneRepMaxTrend(exercise: set.exercise, among: store.strengthSets)
        let previousBest1RM = allTrend.dropLast().map(\.value).max()

        exerciseTitle = set.exercise
        valueText = set.weightKg.formatted()
        unitText = "kg × \(set.reps)回"
        if let previousBest1RM {
            let delta = set.estimatedOneRepMax - previousBest1RM
            badge = Badge(
                label: "推定1RM",
                value: "\(set.estimatedOneRepMax.formatted(.number.precision(.fractionLength(1))))kg",
                delta: "+\(delta.formatted(.number.precision(.fractionLength(1))))kg"
            )
        } else {
            badge = nil
        }
        trend = Self.points(from: allTrend)
        trendTitle = "推定1RMの推移"
        footerText = Self.footer(store: store)
    }

    /// 有酸素（ラン・HYROX・マラソン）の距離PB用
    init(celebrating session: CardioSession, store: AppStore) {
        let allTrend = PersonalBestDetector.distanceTrend(kind: session.kind, among: store.cardioSessions)

        exerciseTitle = session.kind.rawValue
        valueText = session.distanceKm.formatted(.number.precision(.fractionLength(1)))
        unitText = "km"
        badge = Badge(label: "ペース", value: session.paceText, delta: "自己ベスト")
        trend = Self.points(from: allTrend)
        trendTitle = "距離の推移"
        footerText = Self.footer(store: store)
    }

    private static func points(from trend: [(date: Date, value: Double)]) -> [TrendPoint] {
        let formatter: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "ja_JP")
            f.dateFormat = "M/d"
            return f
        }()
        return trend.enumerated().map { index, item in
            TrendPoint(dateLabel: formatter.string(from: item.date), value: item.value, isLatest: index == trend.count - 1)
        }
    }

    private static func footer(store: AppStore) -> String {
        let monthlyCount = PersonalBestDetector.monthlyBestCount(strengthSets: store.strengthSets, cardioSessions: store.cardioSessions)
        return "\(store.currentStreak)日連続記録中 · 今月のベスト更新 \(monthlyCount)回目"
    }

    var body: some View {
        ZStack {
            Color(hex: 0x15171B).ignoresSafeArea()
            confetti

            VStack(spacing: 14) {
                Spacer(minLength: 40)

                ZStack {
                    Circle()
                        .fill(Color(hex: 0xFF7E5C).opacity(0.16))
                        .frame(width: 108, height: 108)
                    Circle()
                        .fill(Color(hex: 0xFF7E5C))
                        .frame(width: 78, height: 78)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color(hex: 0x15171B))
                }

                Text("自己ベスト更新！")
                    .font(.system(size: 15, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color(hex: 0xFF9D75))

                Text(exerciseTitle)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(valueText)
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(unitText)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xA6ADB8))
                }

                if let badge {
                    HStack(spacing: 8) {
                        Text(badge.label)
                            .foregroundStyle(Color(hex: 0xA6ADB8))
                        Text(badge.value)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .foregroundStyle(.white)
                        Text(badge.delta)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .foregroundStyle(Color(hex: 0x54D6A4))
                    }
                    .font(.system(size: 13))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: 0x1F2228), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color(hex: 0x2E323A), lineWidth: 1))
                }

                if trend.count >= 2 {
                    trendChart
                        .padding(14)
                        .background(Color(hex: 0x1F2228), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.top, 6)
                }

                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Color(hex: 0xFF7E5C))
                    Text(footerText)
                        .foregroundStyle(Color(hex: 0xA6ADB8))
                }
                .font(.system(size: 13))

                Spacer(minLength: 40)

                Button {
                    dismiss()
                } label: {
                    Text("続ける")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            LinearGradient(colors: [Color(hex: 0xCC4A26), Color(hex: 0xC4385A)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
        .preferredColorScheme(.dark)
    }

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(trendTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("直近\(trend.count)件")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: 0xA6ADB8))
            }
            Chart(trend) { point in
                LineMark(x: .value("日付", point.dateLabel), y: .value("値", point.value))
                    .foregroundStyle(Color(hex: 0xFF7E5C))
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                PointMark(x: .value("日付", point.dateLabel), y: .value("値", point.value))
                    .foregroundStyle(point.isLatest ? Color(hex: 0x15171B) : Color(hex: 0xFF7E5C))
                    .symbolSize(point.isLatest ? 90 : 40)
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.system(size: 10))
                                .foregroundStyle(Color(hex: 0xA6ADB8))
                        }
                    }
                }
            }
            .frame(height: 100)
        }
    }

    private var confetti: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<10, id: \.self) { index in
                    let colors: [Color] = [
                        Color(hex: 0xFF7E5C), Color(hex: 0xF7C766), Color(hex: 0x48DCCE),
                        Color(hex: 0xF27BA3), Color(hex: 0x7BA5F5), Color(hex: 0xB07FF0), Color(hex: 0x54D6A4)
                    ]
                    let x = CGFloat((index * 37) % 100) / 100 * geo.size.width
                    let y = CGFloat((index * 53) % 60 + 10) / 100 * geo.size.height
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colors[index % colors.count])
                        .frame(width: index.isMultiple(of: 3) ? 8 : 6, height: index.isMultiple(of: 3) ? 8 : 12)
                        .rotationEffect(.degrees(Double(index * 41 % 360)))
                        .position(x: x, y: y)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
