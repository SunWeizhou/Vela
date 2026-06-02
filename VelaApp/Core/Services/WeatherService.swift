import Foundation
import Combine

struct WeatherLocationSnapshot: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    var displayName: String
    var capturedAt: Date
}

enum WeatherLocationPolicy {
    static let cacheTTL: TimeInterval = 7 * 24 * 60 * 60

    static func preferredSnapshot(
        live: WeatherLocationSnapshot?,
        cached: WeatherLocationSnapshot?,
        now: Date = Date()
    ) -> WeatherLocationSnapshot? {
        if let live {
            return live
        }

        guard let cached else {
            return nil
        }

        let age = now.timeIntervalSince(cached.capturedAt)
        guard age >= 0, age <= cacheTTL else {
            return nil
        }

        return cached
    }
}

enum WeatherLocationStore {
    private static let snapshotKey = "vela_weather_location_snapshot"

    static func load(defaults: UserDefaults = .standard) -> WeatherLocationSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else {
            return nil
        }

        return try? JSONDecoder().decode(WeatherLocationSnapshot.self, from: data)
    }

    static func save(_ snapshot: WeatherLocationSnapshot, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }

        defaults.set(data, forKey: snapshotKey)
    }
}

struct VelaWeather: Hashable, Codable {
    var temperature: Double
    var humidity: Double
    var apparentTemperature: Double
    var windSpeed: Double
    var isDay: Bool
    var conditionCode: Int
    
    var conditionName: String {
        let isZH = AppLanguage.stored.isChinese
        switch conditionCode {
        case 0: return isZH ? "晴朗" : "Sunny"
        case 1, 2, 3: return isZH ? "多云" : "Cloudy"
        case 45, 48: return isZH ? "大雾" : "Foggy"
        case 51, 53, 55: return isZH ? "小雨" : "Drizzle"
        case 61, 63, 65: return isZH ? "中雨" : "Rainy"
        case 71, 73, 75: return isZH ? "小雪" : "Snowy"
        case 80, 81, 82: return isZH ? "阵雨" : "Showers"
        case 95, 96, 99: return isZH ? "雷阵雨" : "Thunderstorm"
        default: return isZH ? "晴朗" : "Sunny"
        }
    }
    
    var iconName: String {
        switch conditionCode {
        case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 71, 73, 75: return "snowflake"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.sun.fill"
        }
    }
}

actor WeatherService {
    static let shared = WeatherService()
    
    private init() {}
    
    func fetchWeather(latitude: Double, longitude: Double) async throws -> VelaWeather {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let openMeteo = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        
        return VelaWeather(
            temperature: openMeteo.current.temperature_2m,
            humidity: openMeteo.current.relative_humidity_2m,
            apparentTemperature: openMeteo.current.apparent_temperature,
            windSpeed: openMeteo.current.wind_speed_10m,
            isDay: openMeteo.current.is_day == 1,
            conditionCode: openMeteo.current.weather_code
        )
    }
}

// MARK: - OpenMeteoResponse

private struct OpenMeteoResponse: Codable {
    let current: CurrentWeather
    
    struct CurrentWeather: Codable {
        let temperature_2m: Double
        let relative_humidity_2m: Double
        let apparent_temperature: Double
        let is_day: Int
        let weather_code: Int
        let wind_speed_10m: Double
    }
}
