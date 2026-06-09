import Foundation

struct MealAIRequest: Codable {
    var description: String
    var locale: String
}

struct MealAIResponse: Codable {
    var title: String
    var kcal: Int
    var proteinG: Int
    var fatG: Int
    var carbG: Int
    var confidence: Double
}

struct MealAIAPIClient {
    func analyze(description: String, endpointURLString: String, locale: String) async throws -> MealAIResponse {
        guard let url = URL(string: endpointURLString), !endpointURLString.isEmpty else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(MealAIRequest(description: description, locale: locale))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(MealAIResponse.self, from: data)
    }
}
