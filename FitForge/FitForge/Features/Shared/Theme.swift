import SwiftUI
import UIKit

// FitForge デザインシステム v1.0
// コンセプト: ウォームライト基調 × エンバー(残り火)グラデのエナジーアクセント
// 全色はここに一元定義する。ビュー内での直接 hex 記述は禁止。

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

enum FF {
    // MARK: ベース
    static let background = Color(light: Color(hex: 0xF7F4F0), dark: Color(hex: 0x15171B))
    static let surface = Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x1F2228))
    static let surfaceSecondary = Color(light: Color(hex: 0xF0ECE6), dark: Color(hex: 0x2A2E36))
    static let separator = Color(light: Color(hex: 0xE5E0D8), dark: Color.white.opacity(0.08))
    /// ダークモードでのみカード輪郭を出すボーダー色
    static let cardBorder = Color(light: .clear, dark: Color.white.opacity(0.08))

    // MARK: アクセント（エンバーコーラル）
    static let accent = Color(light: Color(hex: 0xFF6B4A), dark: Color(hex: 0xFF7E5C))
    static let gradientStart = Color(light: Color(hex: 0xFF7A3D), dark: Color(hex: 0xFF8A50))
    static let gradientEnd = Color(light: Color(hex: 0xFF4E6A), dark: Color(hex: 0xFF5E78))
    static let accentSoft = Color(
        light: Color(hex: 0xFF6B4A).opacity(0.12),
        dark: Color(hex: 0xFF7E5C).opacity(0.18)
    )
    /// CTA・ヒーロー要素専用。常に topLeading → bottomTrailing
    static let accentGradient = LinearGradient(
        colors: [gradientStart, gradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: 機能色 — カロリー（「赤=悪」を使わない。超過はアンバー）
    static let intake = Color(light: Color(hex: 0xFF8A5C), dark: Color(hex: 0xFF9D75))
    static let burn = Color(light: Color(hex: 0x4DA3FF), dark: Color(hex: 0x6BB5FF))
    static let over = Color(light: Color(hex: 0xE8A13D), dark: Color(hex: 0xF0B45C))
    static let deficit = Color(light: Color(hex: 0x3DBE8B), dark: Color(hex: 0x54D6A4))

    // MARK: 機能色 — PFC
    static let protein = Color(light: Color(hex: 0xE8618C), dark: Color(hex: 0xF27BA3))
    static let fat = Color(light: Color(hex: 0xF2B544), dark: Color(hex: 0xF7C766))
    static let carb = Color(light: Color(hex: 0x5B8DEF), dark: Color(hex: 0x7BA5F5))

    // MARK: 機能色 — 種目
    static let strength = Color(light: Color(hex: 0xF25C54), dark: Color(hex: 0xFF7670))
    static let run = Color(light: Color(hex: 0x2EC4B6), dark: Color(hex: 0x48DCCE))
    static let hyrox = Color(light: Color(hex: 0x9B5DE5), dark: Color(hex: 0xB07FF0))
    static let marathon = Color(light: Color(hex: 0x5E60CE), dark: Color(hex: 0x7E80E8))

    static func workoutColor(_ kind: WorkoutKind) -> Color {
        switch kind {
        case .strength: strength
        case .running: run
        case .hyrox: hyrox
        case .marathon: marathon
        }
    }

    // MARK: テキスト
    static let textPrimary = Color(light: Color(hex: 0x1C1E22), dark: Color(hex: 0xF2F3F5))
    static let textSecondary = Color(light: Color(hex: 0x5C636E), dark: Color(hex: 0xA6ADB8))
    static let textTertiary = Color(light: Color(hex: 0x9AA1AC), dark: Color(hex: 0x6A7079))

    /// 破壊的操作
    static let destructive = Color(light: Color(hex: 0xD95C5C), dark: Color(hex: 0xE87878))

    // MARK: タイポグラフィ — 数値は rounded、日本語ラベルは標準の2系統のみ
    /// ヒーロー数値（残りkcal等）。各画面に1つだけ
    static let fontHero = Font.system(size: 42, weight: .bold, design: .rounded)
    /// サブ数値（PFCグラム、セット重量）
    static let fontNumber = Font.system(size: 22, weight: .semibold, design: .rounded)
    /// セクション見出し
    static let fontSection = Font.system(size: 17, weight: .semibold)
    /// 本文（lineSpacing(5) を併用すること）
    static let fontBody = Font.system(size: 15)
    /// キャプション
    static let fontCaption = Font.system(size: 12)
    /// チップ内テキスト
    static let fontChip = Font.system(size: 13, weight: .medium)
}
