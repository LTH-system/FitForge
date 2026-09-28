import SwiftUI
import StoreKit

/// プレミアムで使えるようになる機能。各画面で有料機能を案内するときにも使う
enum PremiumFeature: String, CaseIterable, Identifiable {
    case trends
    case muscleVolume
    case nutritionBalance
    case progression
    case unlimitedRoutines
    case racePlan
    case export

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trends: "長期の推移と分析"
        case .muscleVolume: "部位別のトレーニング量"
        case .nutritionBalance: "栄養バランスの過不足"
        case .progression: "次回の重量の提案"
        case .unlimitedRoutines: "ルーティンを無制限に作成"
        case .racePlan: "大会に向けたトレーニングプラン"
        case .export: "記録のCSV書き出し"
        }
    }

    var detail: String {
        switch self {
        case .trends: "体重・カロリー収支を3ヶ月・1年単位で振り返り、理論値と実測を比べられます"
        case .muscleVolume: "胸・背中・脚など、どこをどれだけ鍛えたかを週ごとに確認できます"
        case .nutritionBalance: "たんぱく質・脂質・炭水化物が目標に対して足りているかを日ごとに確認できます"
        case .progression: "前回の記録から、次に挑戦する重量と回数を提案します"
        case .unlimitedRoutines: "無料では\(PremiumStore.freeRoutineLimit)個までのルーティンを、いくつでも作れます"
        case .racePlan: "マラソン・ハーフ・10km・5km・HYROXの大会日から逆算して、毎週のメニューを組み立てます"
        case .export: "食事・筋トレ・運動・体重の記録を表計算ソフトで開ける形式で書き出せます"
        }
    }

    var icon: String {
        switch self {
        case .trends: "chart.line.uptrend.xyaxis"
        case .muscleVolume: "figure.strengthtraining.traditional"
        case .nutritionBalance: "chart.pie"
        case .progression: "arrow.up.forward.circle"
        case .unlimitedRoutines: "list.bullet.rectangle"
        case .racePlan: "flag.checkered"
        case .export: "square.and.arrow.up"
        }
    }
}

/// FitForge プレミアムの案内と購入画面
struct PremiumPaywallView: View {
    @EnvironmentObject private var premium: PremiumStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: PremiumStore.Plan = .yearly
    @State private var purchaseCount = 0
    @State private var pendingMessage: String?

    /// どの機能から開かれたか。先頭に表示する
    var highlightedFeature: PremiumFeature?

    private var selectedProduct: Product? {
        premium.product(for: selectedPlan)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if premium.isPremium {
                        activePanel
                    } else {
                        featureList
                        planPicker
                        purchaseSection
                    }
                    footer
                }
                .padding()
            }
            .background(FF.background)
            .navigationTitle("FitForge プレミアム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sensoryFeedback(.success, trigger: purchaseCount)
            .task { await premium.refresh() }
        }
    }

    // MARK: 見出し

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("記録はずっと無料。\n振り返りと提案で、目標までの近道を。")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(FF.textPrimary)
            Text("食事・筋トレ・運動・体重の記録、目標摂取カロリーの計算、iCloudバックアップはこれまでどおり無料で使えます。")
                .font(FF.fontCaption)
                .foregroundStyle(FF.textSecondary)
        }
    }

    private var orderedFeatures: [PremiumFeature] {
        guard let highlightedFeature else { return PremiumFeature.allCases }
        return [highlightedFeature] + PremiumFeature.allCases.filter { $0 != highlightedFeature }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(orderedFeatures) { feature in
                HStack(alignment: .top, spacing: 12) {
                    IconSeat(systemName: feature.icon, color: FF.accent, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FF.textPrimary)
                        Text(feature.detail)
                            .font(FF.fontCaption)
                            .foregroundStyle(FF.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .panelStyle()
    }

    // MARK: プラン選択

    @ViewBuilder
    private var planPicker: some View {
        if premium.products.isEmpty {
            VStack(spacing: 8) {
                if premium.isLoading {
                    ProgressView()
                } else {
                    Text(premium.errorMessage ?? "プランの情報を取得できませんでした")
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textSecondary)
                    Button("もう一度読み込む") {
                        Task { await premium.refresh() }
                    }
                    .buttonStyle(FFSecondaryButtonStyle())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        } else {
            VStack(spacing: 10) {
                ForEach(PremiumStore.Plan.allCases, id: \.self) { plan in
                    if let product = premium.product(for: plan) {
                        planCard(plan: plan, product: product)
                    }
                }
            }
        }
    }

    private func planCard(plan: PremiumStore.Plan, product: Product) -> some View {
        let isSelected = selectedPlan == plan
        return Button {
            selectedPlan = plan
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? FF.accent : FF.textTertiary)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(plan == .yearly ? "年額プラン" : "月額プラン")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FF.textPrimary)
                        if plan == .yearly, let savings = yearlySavingsText {
                            FFBadge(text: savings, color: FF.deficit)
                        }
                    }
                    if let monthly = PremiumStore.monthlyEquivalentText(for: product) {
                        Text(monthly)
                            .font(FF.fontCaption)
                            .foregroundStyle(FF.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                Text(priceText(for: product))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(FF.textPrimary)
            }
            .padding(14)
            .background(isSelected ? FF.accentSoft : FF.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? FF.accent : FF.separator, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func priceText(for product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else { return product.displayPrice }
        return "\(product.displayPrice) / \(PremiumStore.periodText(period))"
    }

    /// 月額12ヶ月分と比べて、年額がどれだけお得か（例：「14%お得」）
    private var yearlySavingsText: String? {
        guard let monthly = premium.product(for: .monthly), let yearly = premium.product(for: .yearly) else { return nil }
        let twelveMonths = monthly.price * 12
        guard twelveMonths > 0, yearly.price < twelveMonths else { return nil }
        let ratio = NSDecimalNumber(decimal: (twelveMonths - yearly.price) / twelveMonths).doubleValue
        let percent = Int((ratio * 100).rounded(.down))
        return percent > 0 ? "\(percent)%お得" : nil
    }

    // MARK: 購入

    private var purchaseSection: some View {
        VStack(spacing: 12) {
            if let product = selectedProduct {
                let trial = premium.freeTrialText(for: product)
                Button {
                    Task { await purchase(product) }
                } label: {
                    if premium.isLoading {
                        ProgressView()
                    } else {
                        Text(trial.map { "\($0)無料で試す" } ?? "プレミアムに登録する")
                    }
                }
                .buttonStyle(FFPrimaryButtonStyle())
                .disabled(premium.isLoading)

                Text(renewalText(for: product, trial: trial))
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let pendingMessage {
                Text(pendingMessage)
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.textSecondary)
            }
            if let error = premium.errorMessage, !premium.products.isEmpty {
                Text(error)
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.destructive)
            }
        }
    }

    private func renewalText(for product: Product, trial: String?) -> String {
        let price = priceText(for: product)
        if let trial {
            return "\(trial)の無料期間のあと、\(price)で自動更新されます。無料期間中に解約すれば料金はかかりません。"
        }
        return "\(price)で自動更新されます。"
    }

    private func purchase(_ product: Product) async {
        pendingMessage = nil
        switch await premium.purchase(product) {
        case .purchased:
            purchaseCount += 1
        case .pending:
            pendingMessage = "購入の承認待ちです。承認されると自動でプレミアムが使えるようになります"
        case .cancelled:
            break
        }
    }

    // MARK: 登録中

    private var activePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(premium.isInTrial ? "無料お試し中です" : "プレミアムをご利用中です", systemImage: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(FF.deficit)
            if let expiration = premium.expirationDate {
                Text("次回の更新日：\(expiration.formatted(.dateTime.year().month().day()))")
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.textSecondary)
            }
            ForEach(PremiumFeature.allCases) { feature in
                Label(feature.title, systemImage: feature.icon)
                    .font(FF.fontBody)
                    .foregroundStyle(FF.textPrimary)
            }
        }
        .panelStyle()
    }

    // MARK: 注意事項・リンク

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("・お支払いは購入の確定時にApple IDに請求されます。\n・サブスクリプションは、現在の期間が終わる24時間前までに解約しない限り自動で更新されます。更新料金は期間終了前の24時間以内に請求されます。\n・解約やプランの変更は、iPhoneの「設定」＞ Apple ID ＞「サブスクリプション」からいつでもできます。\n・無料お試しは、初めて登録する方が対象です。")
                .font(FF.fontCaption)
                .foregroundStyle(FF.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Button("購入を復元") {
                    Task { await premium.restore() }
                }
                Link("利用規約", destination: PremiumStore.termsOfUseURL)
                Link("プライバシーポリシー", destination: PremiumStore.privacyPolicyURL)
            }
            .font(FF.fontCaption.weight(.semibold))
            .tint(FF.accentText)
        }
    }
}
