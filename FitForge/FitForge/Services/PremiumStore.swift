import Foundation
import StoreKit

/// FitForge プレミアム（自動更新サブスクリプション）の購入状態を管理する。
/// 価格・お試し期間はApp Store Connectの設定をそのまま表示し、アプリには金額を書かない。
@MainActor
final class PremiumStore: ObservableObject {
    enum Plan: String, CaseIterable {
        case monthly = "com.fitforge.app.premium.monthly"
        case yearly = "com.fitforge.app.premium.yearly"
    }

    enum PurchaseOutcome {
        case purchased
        case pending
        case cancelled
    }

    /// 無料で使える、ルーティンの上限数
    static let freeRoutineLimit = 3

    /// App Storeの標準の利用規約（EULA）
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyPolicyURL = URL(string: "https://fitforge-privacy.vercel.app/")!

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPremium = false
    @Published private(set) var activePlan: Plan?
    @Published private(set) var expirationDate: Date?
    @Published private(set) var isInTrial = false
    @Published private(set) var isEligibleForTrial = false
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        // 別の端末での購入、更新、解約、返金などをアプリ起動中に受け取る
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
    }

    func product(for plan: Plan) -> Product? {
        products.first { $0.id == plan.rawValue }
    }

    // MARK: 読み込み

    /// 商品情報と購入状態を読み込む。起動時と有料プラン画面を開いたときに呼ぶ
    func refresh() async {
        await loadProducts()
        await refreshEntitlements()
    }

    private func loadProducts() async {
        guard products.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: Plan.allCases.map(\.rawValue))
            products = Plan.allCases.compactMap { plan in loaded.first { $0.id == plan.rawValue } }
            if let subscription = products.first?.subscription {
                isEligibleForTrial = await subscription.isEligibleForIntroOffer
            }
            errorMessage = products.isEmpty ? "プランの情報を取得できませんでした" : nil
        } catch {
            errorMessage = "プランの情報を取得できませんでした。通信状況を確認してください"
        }
    }

    func refreshEntitlements() async {
        var foundPlan: Plan?
        var foundExpiration: Date?
        var foundTrial = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  let plan = Plan(rawValue: transaction.productID),
                  transaction.revocationDate == nil else { continue }
            if let expiration = transaction.expirationDate, expiration < .now { continue }
            // 月額と年額の両方がある場合（プラン変更の途中など）は期限の遅い方を採る
            if let current = foundExpiration, let expiration = transaction.expirationDate, expiration <= current { continue }
            foundPlan = plan
            foundExpiration = transaction.expirationDate
            foundTrial = transaction.offerType == .introductory
        }

        activePlan = foundPlan
        expirationDate = foundExpiration
        isInTrial = foundTrial
        isPremium = foundPlan != nil

        if let subscription = products.first?.subscription {
            isEligibleForTrial = await subscription.isEligibleForIntroOffer
        }
    }

    // MARK: 購入・復元

    func purchase(_ product: Product) async -> PurchaseOutcome {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    errorMessage = "購入を確認できませんでした。時間をおいて「購入を復元」をお試しください"
                    return .cancelled
                }
                await transaction.finish()
                await refreshEntitlements()
                return .purchased
            case .pending:
                // ファミリー共有の承認待ちなど。承認されると Transaction.updates で反映される
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .cancelled
            }
        } catch {
            errorMessage = "購入できませんでした。時間をおいてもう一度お試しください"
            return .cancelled
        }
    }

    /// 機種変更後などに、App Storeから購入状態を取り直す
    func restore() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPremium {
                errorMessage = "このApple IDで有効なプレミアムの購入は見つかりませんでした"
            }
        } catch {
            errorMessage = "購入を復元できませんでした。時間をおいてもう一度お試しください"
        }
    }

    // MARK: 表示用

    /// 「2週間」「1ヶ月」など、お試し期間や更新期間の表示
    static func periodText(_ period: Product.SubscriptionPeriod) -> String {
        let value = period.value
        switch period.unit {
        case .day: return value == 7 ? "1週間" : "\(value)日"
        case .week: return "\(value)週間"
        case .month: return value == 12 ? "1年" : "\(value)ヶ月"
        case .year: return "\(value)年"
        @unknown default: return "\(value)"
        }
    }

    /// 無料お試しの期間（使える場合だけ）
    func freeTrialText(for product: Product) -> String? {
        guard isEligibleForTrial,
              let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        return Self.periodText(offer.period)
    }

    /// 年額プランの月あたりの金額（例：「月あたり ¥415」）
    static func monthlyEquivalentText(for product: Product) -> String? {
        guard let period = product.subscription?.subscriptionPeriod, period.unit == .year, period.value == 1 else { return nil }
        let monthly = product.price / 12
        return "月あたり " + monthly.formatted(product.priceFormatStyle.precision(.fractionLength(0)))
    }
}
