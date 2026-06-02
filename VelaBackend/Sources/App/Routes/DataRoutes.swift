import Vapor

struct DataRoutes: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get("api", "data-coverage", use: getCoverage)
    }

    /// GET /api/data-coverage?lang=zh&sleep=true&hrv=true&rhr=true&strain=true&weight=false&vo2max=false
    func getCoverage(req: Request) async throws -> DataCoverageResponse {
        let queryDimensions: [(String, String?)] = [
            ("sleep", queryString(req, "sleep")),
            ("hrv", queryString(req, "hrv")),
            ("resting_heart_rate", queryString(req, "rhr")),
            ("strain", queryString(req, "strain")),
            ("weight", queryString(req, "weight")),
            ("body_fat", queryString(req, "bodyFat")),
            ("vo2max", queryString(req, "vo2max")),
            ("blood_pressure", queryString(req, "bloodPressure")),
            ("blood_glucose", queryString(req, "bloodGlucose")),
            ("respiratory_rate", queryString(req, "respiratoryRate")),
            ("steps", queryString(req, "steps")),
            ("workouts", queryString(req, "workouts")),
        ]
        let dimensions = queryDimensions.map { name, available in
            DataCoverageResponse.DimensionCoverage(
                name: name,
                coverage: available == "true" ? 1.0 : 0.0,
                freshness: available == "true" ? "today" : "missing"
            )
        }

        let overall = dimensions.map(\.coverage).reduce(0, +) / Double(dimensions.count)
        let missing = dimensions.filter { $0.coverage == 0 }.map { $0.name }

        return DataCoverageResponse(
            overall: overall,
            dimensions: dimensions,
            missingMetrics: missing,
            recommendations: generateRecommendations(for: missing)
        )
    }

    private func queryString(_ req: Request, _ key: String) -> String? {
        req.query[String.self, at: key]
    }

    private func generateRecommendations(for missing: [String]) -> [String] {
        var recs: [String] = []
        if missing.contains("hrv") { recs.append("佩戴 Apple Watch 睡觉以获取 HRV 数据") }
        if missing.contains("weight") { recs.append("在 Apple Health 中录入体重数据") }
        if missing.contains("blood_pressure") { recs.append("连接蓝牙血压计或手动录入血压") }
        if missing.contains("vo2max") { recs.append("进行户外步行或跑步运动以计算 VO2 Max") }
        return recs
    }
}
