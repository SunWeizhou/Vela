import Foundation
import UIKit

// MARK: - Food Analysis Result Types

struct FoodAnalysisResult: Sendable {
    var foods: [IdentifiedFood]
    var totalCalories: Int
    var macros: MacroBreakdown
    var micronutrients: [NutritionMicronutrientAmount]
    var healthScore: String   // e.g., "good", "moderate", "needs_improvement"
    var suggestions: [String]
    var rawAnalysis: String

    init(
        foods: [IdentifiedFood],
        totalCalories: Int,
        macros: MacroBreakdown,
        micronutrients: [NutritionMicronutrientAmount] = [],
        healthScore: String,
        suggestions: [String],
        rawAnalysis: String
    ) {
        self.foods = foods
        self.totalCalories = totalCalories
        self.macros = macros
        self.micronutrients = micronutrients
        self.healthScore = healthScore
        self.suggestions = suggestions
        self.rawAnalysis = rawAnalysis
    }

    func formattedMarkdown() -> String {
        var md = "## Food Analysis\n\n"
        md += "### Identified Items\n"
        for food in foods {
            md += "- **\(food.name)** — \(food.portion), ~\(food.calories) kcal\n"
        }
        md += "\n**Total Calories:** \(totalCalories) kcal\n\n"
        md += "### Macros\n"
        md += "| Nutrient | Amount |\n"
        md += "|----------|--------|\n"
        md += "| Protein  | \(macros.protein)g |\n"
        md += "| Carbs    | \(macros.carbs)g |\n"
        md += "| Fat      | \(macros.fat)g |\n"
        md += "| Fiber    | \(macros.fiber)g |\n\n"
        if !micronutrients.isEmpty {
            md += "### Label Micronutrients\n"
            for nutrient in micronutrients {
                md += "- \(nutrient.label): \(nutrient.formattedValue)\n"
            }
            md += "\n"
        }
        let scoreLabel: String = {
            switch healthScore {
            case "good": return "Good"
            case "moderate": return "Moderate"
            case "needs_improvement": return "Needs Improvement"
            default: return healthScore.capitalized
            }
        }()
        md += "**Health Score:** \(scoreLabel)\n\n"
        if !suggestions.isEmpty {
            md += "### Suggestions\n"
            for s in suggestions {
                md += "- \(s)\n"
            }
            md += "\n"
        }
        return md
    }

    func plainTextSummary() -> String {
        let foodNames = foods.map { "\($0.name)" }.joined(separator: ", ")
        return "Meal: \(foodNames) | \(totalCalories) kcal | P:\(macros.protein)g C:\(macros.carbs)g F:\(macros.fat)g Fiber:\(macros.fiber)g | Score: \(healthScore)"
    }
}

struct NutritionMicronutrientAmount: Codable, Hashable, Sendable, Identifiable {
    var id: String { key }
    var key: String
    var label: String
    var value: Double
    var unit: String
    var source: String

    var formattedValue: String {
        let decimals = value < 10 && value.rounded() != value ? 1 : 0
        return "\(value.formatted(.number.precision(.fractionLength(decimals)))) \(unit)"
    }
}

private struct NutritionAnalysisArchive: Codable {
    var schema: String
    var originalAnalysis: String
    var micronutrients: [NutritionMicronutrientAmount]
}

enum NutritionAnalysisArchiveCodec {
    static func encode(original: String, micronutrients: [NutritionMicronutrientAmount]) -> String {
        guard !micronutrients.isEmpty,
              let data = try? JSONEncoder().encode(NutritionAnalysisArchive(
                schema: "nutritionAnalysis.v1",
                originalAnalysis: original,
                micronutrients: micronutrients
              )) else { return original }
        return String(data: data, encoding: .utf8) ?? original
    }

    static func micronutrients(from raw: String) -> [NutritionMicronutrientAmount] {
        guard let data = raw.data(using: .utf8),
              let archive = try? JSONDecoder().decode(NutritionAnalysisArchive.self, from: data),
              archive.schema == "nutritionAnalysis.v1" else { return [] }
        return archive.micronutrients.filter { $0.value.isFinite && $0.value >= 0 }
    }
}

struct IdentifiedFood: Sendable {
    var name: String
    var portion: String
    var calories: Int
}

struct MacroBreakdown: Sendable {
    var protein: Int   // grams
    var carbs: Int     // grams
    var fat: Int       // grams
    var fiber: Int     // grams
}

// MARK: - FoodPhotoAnalyzer

final class FoodPhotoAnalyzer: Sendable {
    static let keychainAccount = "kimi_api_key"
    static let providerDisplayName = "Kimi Vision"
    static let defaultModel = "kimi-k2.6"
    static let defaultEndpoint = URL(string: "https://api.moonshot.cn/v1/chat/completions")!

    private let apiKey: String
    private let model: String
    private let endpoint: URL

    init(
        apiKey: String,
        model: String = FoodPhotoAnalyzer.defaultModel,
        endpoint: URL = FoodPhotoAnalyzer.defaultEndpoint
    ) {
        self.apiKey = apiKey
        self.model = model
        self.endpoint = endpoint
    }

    func analyzeFoodPhoto(_ image: UIImage) async throws -> FoodAnalysisResult {
        // Compress and convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw FoodAnalysisError.imageConversionFailed
        }
        let base64 = imageData.base64EncodedString()

        let requestBody = Self.makeRequestBody(imageBase64: base64, model: model)

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 60
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await PrivateAIURLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoodAnalysisError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw FoodAnalysisError.requestFailed("Kimi vision request failed with status \(httpResponse.statusCode): \(body.prefix(200))")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw FoodAnalysisError.invalidResponse
        }

        return try Self.parseResponse(content)
    }

    static func makeRequestBody(
        imageBase64: String,
        model: String = FoodPhotoAnalyzer.defaultModel
    ) -> [String: Any] {
        let systemPrompt = """
        You are a professional nutritionist and food analyst. When shown a meal photo, you must:
        1. Identify each distinct food item visible in the photo
        2. Estimate the portion size for each item (e.g., "1 cup", "150g", "1 medium piece")
        3. Estimate calories for each item based on typical serving sizes
        4. Calculate the total macros (protein, carbs, fat, fiber in grams)
        5. Provide an overall health score and improvement suggestions

        You MUST respond ONLY with valid JSON in the following format. Do not include any other text:
        {
          "foods": [
            {"name": "Grilled Chicken Breast", "portion": "150g", "calories": 240},
            {"name": "Steamed Rice", "portion": "1 cup", "calories": 205}
          ],
          "total_calories": 445,
          "macros": {"protein": 35, "carbs": 45, "fat": 12, "fiber": 3},
          "health_score": "good",
          "suggestions": ["Add more vegetables for fiber", "Consider brown rice instead of white rice"]
        }

        health_score must be one of: "good", "moderate", "needs_improvement"
        All calorie and macro values must be integers.
        If you cannot confidently identify a food, estimate based on visual cues.
        """

        let userPrompt = "Analyze this meal photo and provide the nutritional breakdown in the EXACT JSON format specified."
        return [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": userPrompt],
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(imageBase64)"]]
                    ]
                ]
            ],
            "temperature": 0.2,
            "stream": false
        ]
    }

    private static func parseResponse(_ text: String) throws -> FoodAnalysisResult {
        // Try to extract JSON from response (may be wrapped in markdown code blocks)
        let cleaned: String
        if let match = text.range(of: "```(?:json)?\\s*\\n?([\\s\\S]*?)\\n?```", options: .regularExpression) {
            cleaned = String(text[match]).replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // Try to find JSON directly
            if let start = text.firstIndex(of: "{"),
               let end = text.lastIndex(of: "}") {
                cleaned = String(text[start...end])
            } else {
                cleaned = text
            }
        }

        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FoodAnalysisError.parseFailed("Could not parse JSON from response: \(text.prefix(300))")
        }

        // Parse foods
        var foods: [IdentifiedFood] = []
        if let foodsArray = json["foods"] as? [[String: Any]] {
            for item in foodsArray {
                foods.append(IdentifiedFood(
                    name: item["name"] as? String ?? "Unknown",
                    portion: item["portion"] as? String ?? "Unknown",
                    calories: item["calories"] as? Int ?? 0
                ))
            }
        }

        let totalCalories = json["total_calories"] as? Int ?? foods.reduce(0) { $0 + $1.calories }

        // Parse macros
        let macrosJson = json["macros"] as? [String: Any]
        let macros = MacroBreakdown(
            protein: macrosJson?["protein"] as? Int ?? 0,
            carbs: macrosJson?["carbs"] as? Int ?? 0,
            fat: macrosJson?["fat"] as? Int ?? 0,
            fiber: macrosJson?["fiber"] as? Int ?? 0
        )

        let healthScore = json["health_score"] as? String ?? "moderate"

        let suggestions = json["suggestions"] as? [String] ?? []

        return FoodAnalysisResult(
            foods: foods,
            totalCalories: totalCalories,
            macros: macros,
            healthScore: healthScore,
            suggestions: suggestions,
            rawAnalysis: text
        )
    }
}

// MARK: - Errors

enum FoodAnalysisError: LocalizedError {
    case imageConversionFailed
    case invalidResponse
    case requestFailed(String)
    case parseFailed(String)

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image to JPEG data."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .requestFailed(let msg):
            return "Request failed: \(msg)"
        case .parseFailed(let msg):
            return "Failed to parse analysis result: \(msg)"
        }
    }
}
