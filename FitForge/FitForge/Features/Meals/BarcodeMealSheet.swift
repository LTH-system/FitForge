import SwiftUI
import SwiftData

/// バーコードを読み取り、Open Food Factsで栄養情報を検索して食事に記録するシート
struct BarcodeMealSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private enum Phase {
        case scanning
        case lookingUp(code: String)
        case found(code: String, result: PackagedFoodLookupResult)
        case notFound(code: String)
        case failed(code: String)
    }

    @State private var phase: Phase = .scanning
    @State private var manualCode = ""
    @State private var gramsText = "100"
    @State private var savedCount = 0

    private let client = BarcodeFoodClient()
    private let isScannerSupported = BarcodeScannerRepresentable.isSupported

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("バーコードで記録")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { dismiss() }
                    }
                }
                .sensoryFeedback(.success, trigger: savedCount)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .scanning:
            scanningView
        case .lookingUp:
            ProgressView("商品情報を検索中…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .found(let code, let result):
            foundView(code: code, result: result)
        case .notFound(let code):
            messageView(
                icon: "questionmark.circle",
                title: "商品が見つかりませんでした",
                detail: "バーコード \(code) はOpen Food Factsに登録がないようです。文章で入力して記録できます。",
                code: code
            )
        case .failed(let code):
            messageView(
                icon: "wifi.exclamationmark",
                title: "検索できませんでした",
                detail: "通信状況を確認してもう一度お試しください。",
                code: code
            )
        }
    }

    // MARK: スキャン

    private var scanningView: some View {
        VStack(spacing: 16) {
            if isScannerSupported {
                BarcodeScannerRepresentable { code in
                    lookUp(code: code)
                }
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(FF.separator, lineWidth: 1)
                )
                .padding(.horizontal)

                Text("商品のバーコードを枠内に写してください")
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.textSecondary)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "camera.metering.unknown")
                        .font(.system(size: 28))
                        .foregroundStyle(FF.textTertiary)
                    Text("この端末（またはシミュレータ）ではカメラでの読み取りに対応していません。下のバーコード番号を直接入力してください。")
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(height: 200)
            }

            manualEntryRow
            Spacer(minLength: 0)
        }
        .padding(.top, 12)
    }

    private var manualEntryRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "バーコード番号を直接入力")
            HStack(spacing: 10) {
                TextField("例: 4901234567890", text: $manualCode)
                    .keyboardType(.numberPad)
                    .ffFieldStyle()
                Button("検索") {
                    let code = manualCode.trimmingCharacters(in: .whitespaces)
                    guard !code.isEmpty else { return }
                    lookUp(code: code)
                }
                .buttonStyle(FFSecondaryButtonStyle())
                .disabled(manualCode.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.horizontal)
    }

    private func lookUp(code: String) {
        guard case .scanning = phase else { return }
        phase = .lookingUp(code: code)
        Task {
            do {
                let result = try await client.lookup(barcode: code)
                gramsText = "100"
                phase = .found(code: code, result: result)
            } catch BarcodeFoodClientError.notFound {
                phase = .notFound(code: code)
            } catch {
                phase = .failed(code: code)
            }
        }
    }

    // MARK: 結果確認

    private func foundView(code: String, result: PackagedFoodLookupResult) -> some View {
        let grams = Double(gramsText) ?? 0
        let factor = grams / 100
        let kcal = Int((Double(result.kcalPer100g) * factor).rounded())
        let protein = Int((result.proteinPer100g * factor).rounded())
        let fat = Int((result.fatPer100g * factor).rounded())
        let carb = Int((result.carbPer100g * factor).rounded())

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(FF.textPrimary)
                    Text("100gあたり \(result.kcalPer100g)kcal")
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textSecondary)
                }
                .panelStyle()

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "食べた量")
                    HStack(spacing: 10) {
                        TextField("100", text: $gramsText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .ffFieldStyle()
                            .frame(width: 90)
                        Text("g")
                            .foregroundStyle(FF.textSecondary)
                        Spacer()
                    }

                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text("\(kcal)")
                            .font(FF.fontNumber)
                            .monospacedDigit()
                            .foregroundStyle(FF.intake)
                        Text("kcal")
                            .font(FF.fontCaption)
                            .foregroundStyle(FF.textSecondary)
                    }
                    PFCRow(protein: protein, fat: fat, carb: carb)
                }
                .panelStyle()

                Button {
                    saveMeal(name: result.name, kcal: kcal, protein: protein, fat: fat, carb: carb, grams: grams)
                } label: {
                    Label("記録する", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(FFPrimaryButtonStyle())
                .disabled(grams <= 0)

                Button("別の商品を読み取る") {
                    phase = .scanning
                }
                .buttonStyle(FFSecondaryButtonStyle())
            }
            .padding()
        }
    }

    private func saveMeal(name: String, kcal: Int, protein: Int, fat: Int, carb: Int, grams: Double) {
        let meal = MealLog(
            date: .now,
            title: name,
            note: "バーコード読み取り（\(Int(grams))g）",
            estimatedKcal: kcal,
            proteinG: protein,
            fatG: fat,
            carbG: carb,
            confidence: 0.9,
            source: .imported
        )
        let saved = store.addMeal(from: meal)
        modelContext.insert(MealEntry(from: saved))
        try? modelContext.save()
        savedCount += 1
        dismiss()
    }

    // MARK: 見つからない・失敗

    private func messageView(icon: String, title: String, detail: String, code: String) -> some View {
        VStack(spacing: 14) {
            Spacer(minLength: 20)
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(FF.textTertiary)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(FF.textPrimary)
            Text(detail)
                .font(FF.fontCaption)
                .foregroundStyle(FF.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("もう一度読み取る") {
                manualCode = ""
                phase = .scanning
            }
            .buttonStyle(FFSecondaryButtonStyle())
            .padding(.horizontal, 40)
            Spacer(minLength: 20)
        }
    }
}
