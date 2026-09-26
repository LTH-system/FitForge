import Foundation

/// Open Food Facts（無料・APIキー不要の公開商品データベース）からバーコードで商品の栄養情報を取得する。
/// 日本のJANコードはEAN-13と同じ規格なので、そのまま照会できる
struct PackagedFoodLookupResult {
    var name: String
    var kcalPer100g: Int
    var proteinPer100g: Double
    var fatPer100g: Double
    var carbPer100g: Double
}

enum BarcodeFoodClientError: Error {
    case notFound
    case invalidResponse
}

struct BarcodeFoodClient {
    private struct Response: Decodable {
        var product: Product?
    }

    private struct Product: Decodable {
        var productName: String?
        var productNameJa: String?
        var brands: String?
        var nutriments: Nutriments?

        enum CodingKeys: String, CodingKey {
            case productName = "product_name"
            case productNameJa = "product_name_ja"
            case brands
            case nutriments
        }
    }

    private struct Nutriments: Decodable {
        var energyKcal100g: Double?
        var proteins100g: Double?
        var fat100g: Double?
        var carbohydrates100g: Double?

        enum CodingKeys: String, CodingKey {
            case energyKcal100g = "energy-kcal_100g"
            case proteins100g = "proteins_100g"
            case fat100g = "fat_100g"
            case carbohydrates100g = "carbohydrates_100g"
        }
    }

    func lookup(barcode: String) async throws -> PackagedFoodLookupResult {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json?fields=product_name,product_name_ja,brands,nutriments") else {
            throw BarcodeFoodClientError.invalidResponse
        }

        var request = URLRequest(url: url)
        // Open Food Facts はUser-Agentでの発信元明記を求めている
        request.setValue("FitForge-iOS/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw BarcodeFoodClientError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let product = decoded.product, let kcal = product.nutriments?.energyKcal100g else {
            throw BarcodeFoodClientError.notFound
        }

        let name = [product.productNameJa, product.productName]
            .compactMap { $0 }
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let name else {
            throw BarcodeFoodClientError.notFound
        }

        let title = [product.brands, name]
            .compactMap { $0 }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: " ")

        return PackagedFoodLookupResult(
            name: title,
            kcalPer100g: Int(kcal.rounded()),
            proteinPer100g: product.nutriments?.proteins100g ?? 0,
            fatPer100g: product.nutriments?.fat100g ?? 0,
            carbPer100g: product.nutriments?.carbohydrates100g ?? 0
        )
    }
}
