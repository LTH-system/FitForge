import SwiftUI

// MARK: - カード

extension View {
    /// 標準カード。角丸20pt continuous、ライトは影・ダークはボーダーで輪郭
    func panelStyle() -> some View {
        self
            .padding(16)
            .background(FF.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(FF.cardBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 16, y: 4)
    }
}

// MARK: - ボタンスタイル

/// プライマリCTA。1画面に1つまで。グラデ塗り+色付き影
struct FFPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(FF.accentGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: FF.accent.opacity(0.3), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// セカンダリボタン。accentSoft背景・枠線なし
struct FFSecondaryButtonStyle: ButtonStyle {
    var tint: Color = FF.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// コンパクトなセカンダリボタン（横並び・グリッド用、高さ可変）
struct FFCompactButtonStyle: ButtonStyle {
    var tint: Color = FF.accent
    var isSelected = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FF.fontChip)
            .foregroundStyle(isSelected ? tint : FF.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                isSelected ? tint.opacity(0.14) : FF.surfaceSecondary.opacity(0.9),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

// MARK: - メトリクスカード

/// アイコン台座つきメトリクスカード
struct MetricCard: View {
    var title: String
    var value: String
    var unit: String
    var color: Color
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let icon {
                    IconSeat(systemName: icon, color: color, size: 24)
                }
                Text(title)
                    .font(FF.fontCaption.weight(.medium))
                    .foregroundStyle(FF.textSecondary)
            }
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(FF.fontNumber)
                    .monospacedDigit()
                    .foregroundStyle(FF.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(unit)
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// SF Symbolを機能色の角丸台座に載せる
struct IconSeat: View {
    var systemName: String
    var color: Color
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.36, style: .continuous))
    }
}

struct DeltaCard: View {
    var title: String
    var kg: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(FF.fontCaption)
                .foregroundStyle(FF.textSecondary)
            Text("\(kg, specifier: "%+.2f")kg")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(kg <= 0 ? FF.deficit : FF.over)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(FF.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - PFC

struct PFCRow: View {
    var protein: Int
    var fat: Int
    var carb: Int

    var body: some View {
        HStack(spacing: 8) {
            macro("P", protein, FF.protein)
            macro("F", fat, FF.fat)
            macro("C", carb, FF.carb)
        }
    }

    private func macro(_ label: String, _ value: Int, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Text(label).bold()
            Text("\(value)g").monospacedDigit()
        }
        .font(FF.fontChip)
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
    }
}

/// PFCの3本ヨコバー。各色12%のトラックの上に実値バー
struct PFCBars: View {
    var protein: Int
    var fat: Int
    var carb: Int
    /// 目安最大値（バーのスケール基準）
    var proteinMax = 150.0
    var fatMax = 90.0
    var carbMax = 350.0

    var body: some View {
        VStack(spacing: 10) {
            bar("P", "タンパク質", protein, proteinMax, FF.protein)
            bar("F", "脂質", fat, fatMax, FF.fat)
            bar("C", "炭水化物", carb, carbMax, FF.carb)
        }
    }

    private func bar(_ short: String, _ name: String, _ value: Int, _ max: Double, _ color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text("\(short) \(name)")
                    .font(FF.fontCaption.weight(.medium))
                    .foregroundStyle(FF.textSecondary)
                Spacer()
                Text("\(value)g")
                    .font(FF.fontChip)
                    .monospacedDigit()
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.12))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * min(1, Double(value) / max))
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - 比較行

struct ComparisonRow: View {
    var label: String
    var predicted: Double
    var actual: Double

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FF.textPrimary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("理論 \(predicted, specifier: "%+.2f")kg")
                Text("実績 \(actual, specifier: "%+.2f")kg")
            }
            .font(FF.fontCaption)
            .monospacedDigit()
            .foregroundStyle(FF.textSecondary)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - セグメント選択（標準SegmentedPicker代替）

/// Capsuleコンテナ内をピルがスライドする自作セグメント
struct FFSegmentedPicker<T: Hashable>: View {
    var options: [T]
    var label: (T) -> String
    @Binding var selection: T
    var tint: Color = FF.accent
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selection = option
                    }
                } label: {
                    Text(label(option))
                        .font(FF.fontChip)
                        .foregroundStyle(selection == option ? .white : FF.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background {
                            if selection == option {
                                Capsule()
                                    .fill(tint)
                                    .matchedGeometryEffect(id: "pill", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(FF.surfaceSecondary, in: Capsule())
    }
}

// MARK: - チップ

struct FFChip: View {
    var text: String
    var color: Color = FF.accent
    var isSelected = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(FF.fontChip)
                .foregroundStyle(isSelected ? color : FF.textSecondary)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(
                    isSelected ? color.opacity(0.14) : FF.surfaceSecondary,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}

/// 静的表示用バッジ
struct FFBadge: View {
    var text: String
    var color: Color = FF.accent

    var body: some View {
        Text(text)
            .font(FF.fontCaption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - 数値入力（標準Stepper代替）

/// 「− 値 ＋」の横並び数値入力
struct FFStepperRow: View {
    var label: String
    var valueText: String
    var onMinus: () -> Void
    var onPlus: () -> Void

    var body: some View {
        HStack {
            Text(label)
                .font(FF.fontBody)
                .foregroundStyle(FF.textSecondary)
            Spacer()
            HStack(spacing: 14) {
                stepButton("minus", action: onMinus)
                Text(valueText)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(FF.textPrimary)
                    .frame(minWidth: 76)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                stepButton("plus", action: onPlus)
            }
        }
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FF.accent)
                .frame(width: 38, height: 38)
                .background(FF.surfaceSecondary, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 入力フィールド

extension View {
    /// TextField用: surfaceSecondary塗り・角丸12pt
    func ffFieldStyle() -> some View {
        self
            .font(FF.fontBody)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(FF.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - リングゲージ（ダッシュボードのヒーロー）

struct RingGauge: View {
    /// 0...1
    var progress: Double
    var lineWidth: CGFloat = 12
    @State private var animated = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(FF.surfaceSecondary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: animated ? min(1, max(0, progress)) : 0)
                .stroke(
                    AngularGradient(
                        colors: [FF.gradientStart, FF.gradientEnd],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * min(1, max(0.001, progress)))
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.1)) {
                animated = true
            }
        }
    }
}

// MARK: - セクション見出し

struct SectionHeader: View {
    var title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(FF.fontSection)
                .foregroundStyle(FF.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
