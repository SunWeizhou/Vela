import Foundation
import UIKit

// MARK: - Food Analysis Result Types

struct FoodAnalysisResult: Sendable {
    var foods: [IdentifiedFood]
    var totalCalories: Int
    var macros: MacroBreakdown
    var healthScore: String   // e.g., "good", "moderate", "needs_improvement"
    var suggestions: [String]
    var rawAnalysis: String

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
    private let apiKey: String
    private let model: String = "deepseek-chat"
    private let endpoint: URL = URL(string: "https://api.deepseek.com/chat/completions")!

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func analyzeFoodPhoto(_ image: UIImage) async throws -> FoodAnalysisResult {
        // Compress and convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw FoodAnalysisError.imageConversionFailed
        }
        let base64 = imageData.base64EncodedString()

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

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 60

        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": userPrompt],
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]]
                    ]
                ]
            ],
            "temperature": 0.2,
            "stream": false
        ]

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoodAnalysisError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw FoodAnalysisError.requestFailed("DeepSeek vision request failed with status \(httpResponse.statusCode): \(body.prefix(200))")
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
