import SwiftUI
import UIKit

/// プレミアムの機能を、未登録の人に案内するカード。タップするとプレミアム画面を開く
struct PremiumLockedCard: View {
    @EnvironmentObject private var premium: PremiumStore
    @State private var isPaywallPresented = false

    var feature: PremiumFeature

    private var actionTitle: String {
        if let product = premium.product(for: .yearly) ?? premium.products.first,
           let trial = premium.freeTrialText(for: product) {
            return "\(trial)無料で試す"
        }
        return "プレミアムで使う"
    }

    var body: some View {
        Button {
            isPaywallPresented = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    IconSeat(systemName: feature.icon, color: FF.accent, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(feature.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(FF.textPrimary)
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(FF.textTertiary)
                        }
                        Text(feature.detail)
                            .font(FF.fontCaption)
                            .foregroundStyle(FF.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                HStack {
                    Spacer()
                    Text(actionTitle)
                        .font(FF.fontChip)
                        .foregroundStyle(FF.accentText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(FF.accentSoft, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .panelStyle()
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPaywallPresented) {
            PremiumPaywallView(highlightedFeature: feature)
        }
    }
}

/// ファイルなどを共有・保存するための標準の共有シート
struct ActivityShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
