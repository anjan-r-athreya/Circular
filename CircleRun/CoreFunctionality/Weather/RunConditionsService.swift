//
//  RunConditionsService.swift
//  CircleRun
//
//  "Is now a good time to run?" — current weather from Open-Meteo (free,
//  no key, same API family the elevation service uses) plus a locally
//  computed sunset, condensed into one nudge line for the map screen.
//

import Foundation
import CoreLocation

struct RunConditionsNudge: Equatable {
    let systemImage: String
    let text: String
}

final class RunConditionsService {
    static let shared = RunConditionsService()

    private var cached: (nudge: RunConditionsNudge, at: Date)?
    private let cacheLifetime: TimeInterval = 30 * 60

    private init() {}

    func nudge(at coordinate: CLLocationCoordinate2D) async -> RunConditionsNudge? {
        if let cached, Date().timeIntervalSince(cached.at) < cacheLifetime {
            return cached.nudge
        }
        guard let weather = await fetchWeather(at: coordinate) else { return nil }

        let nudge = makeNudge(from: weather,
                              sunset: SunTimes.sunset(on: Date(), at: coordinate))
        cached = (nudge, Date())
        return nudge
    }

    // MARK: - Nudge composition

    private func makeNudge(from weather: Weather, sunset: Date?) -> RunConditionsNudge {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        // Rain now or imminently: lead with that, and offer the next dry hour.
        if weather.precipitationProbability >= 55 {
            if let dry = weather.nextDryHour {
                return RunConditionsNudge(
                    systemImage: "cloud.rain.fill",
                    text: "Rain likely — drier around \(timeFormatter.string(from: dry))"
                )
            }
            return RunConditionsNudge(
                systemImage: "cloud.rain.fill",
                text: "Rain likely today (\(weather.precipitationProbability)% chance)"
            )
        }

        // Heat: point at the cool end of the day.
        if weather.temperatureF >= 88 {
            var text = String(format: "%.0f° now — cooler near sunset", weather.temperatureF)
            if let sunset {
                text = String(format: "%.0f° now — cooler after %@",
                              weather.temperatureF, timeFormatter.string(from: sunset))
            }
            return RunConditionsNudge(systemImage: "thermometer.sun.fill", text: text)
        }

        // Daylight running out: worth knowing before picking a distance.
        if let sunset {
            let minutesLeft = sunset.timeIntervalSinceNow / 60
            if minutesLeft > 0 && minutesLeft < 50 {
                return RunConditionsNudge(
                    systemImage: "sunset.fill",
                    text: "Sunset \(timeFormatter.string(from: sunset)) — keep tonight's loop short"
                )
            }
        }

        // Otherwise: a green light with the facts.
        var text = String(format: "Good running weather · %.0f° %@",
                          weather.temperatureF, weather.description)
        if let sunset, sunset > Date() {
            text += " · sunset \(timeFormatter.string(from: sunset))"
        }
        return RunConditionsNudge(systemImage: weather.systemImage, text: text)
    }

    // MARK: - Open-Meteo

    private struct Weather {
        let temperatureF: Double
        let weatherCode: Int
        let precipitationProbability: Int
        /// First upcoming hour today with rain probability under 35%.
        let nextDryHour: Date?

        var description: String {
            switch weatherCode {
            case 0: return "clear"
            case 1, 2: return "mostly clear"
            case 3: return "overcast"
            case 45, 48: return "foggy"
            case 51...67, 80...82: return "rainy"
            case 71...77, 85, 86: return "snowy"
            case 95...99: return "stormy"
            default: return "mild"
            }
        }

        var systemImage: String {
            switch weatherCode {
            case 0: return "sun.max.fill"
            case 1, 2: return "cloud.sun.fill"
            case 3: return "cloud.fill"
            case 45, 48: return "cloud.fog.fill"
            case 51...67, 80...82: return "cloud.rain.fill"
            case 71...77, 85, 86: return "cloud.snow.fill"
            case 95...99: return "cloud.bolt.rain.fill"
            default: return "cloud.sun.fill"
            }
        }
    }

    private func fetchWeather(at coordinate: CLLocationCoordinate2D) async -> Weather? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "hourly", value: "precipitation_probability"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "forecast_days", value: "1"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        guard let url = components?.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ForecastResponse.self, from: data)

            // Hour entries are local to the queried location; find "now" and
            // the next dry hour after it.
            let hourFormatter = DateFormatter()
            hourFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
            let hours = zip(response.hourly.time, response.hourly.precipitation_probability)
                .compactMap { time, probability -> (Date, Int)? in
                    guard let date = hourFormatter.date(from: time) else { return nil }
                    return (date, probability)
                }

            let now = Date()
            let currentProbability = hours.last { $0.0 <= now }?.1 ?? 0
            let nextDry = hours.first { $0.0 > now && $0.1 < 35 }?.0

            return Weather(
                temperatureF: response.current.temperature_2m,
                weatherCode: response.current.weather_code,
                precipitationProbability: currentProbability,
                nextDryHour: nextDry
            )
        } catch {
            print("Weather fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    private struct ForecastResponse: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
        }
        struct Hourly: Decodable {
            let time: [String]
            let precipitation_probability: [Int]
        }
        let current: Current
        let hourly: Hourly
    }
}

// MARK: - Sunset (NOAA sunrise equation, good to a couple of minutes)

enum SunTimes {
    /// Local sunset on the given day, or nil in polar day/night.
    static func sunset(on date: Date, at coordinate: CLLocationCoordinate2D) -> Date? {
        events(on: date, at: coordinate)?.sunset
    }

    static func sunrise(on date: Date, at coordinate: CLLocationCoordinate2D) -> Date? {
        events(on: date, at: coordinate)?.sunrise
    }

    private static func events(on date: Date,
                               at coordinate: CLLocationCoordinate2D) -> (sunrise: Date, sunset: Date)? {
        let julianDate = date.timeIntervalSince1970 / 86400 + 2440587.5
        let n = (julianDate - 2451545.0 + 0.0008).rounded()

        let meanSolarNoon = n - coordinate.longitude / 360
        let meanAnomaly = (357.5291 + 0.98560028 * meanSolarNoon)
            .truncatingRemainder(dividingBy: 360)
        let m = meanAnomaly * .pi / 180
        let center = 1.9148 * sin(m) + 0.02 * sin(2 * m) + 0.0003 * sin(3 * m)
        let eclipticLongitude = (meanAnomaly + center + 180 + 102.9372)
            .truncatingRemainder(dividingBy: 360)
        let lambda = eclipticLongitude * .pi / 180

        let solarTransit = 2451545.0 + meanSolarNoon
            + 0.0053 * sin(m) - 0.0069 * sin(2 * lambda)

        let declination = asin(sin(lambda) * sin(23.4397 * .pi / 180))
        let latitude = coordinate.latitude * .pi / 180

        // -0.833° accounts for refraction and the solar disc's radius.
        let cosHourAngle = (sin(-0.833 * .pi / 180) - sin(latitude) * sin(declination))
            / (cos(latitude) * cos(declination))
        guard cosHourAngle >= -1, cosHourAngle <= 1 else { return nil }

        let hourAngle = acos(cosHourAngle) * 180 / .pi / 360
        let julianRise = solarTransit - hourAngle
        let julianSet = solarTransit + hourAngle

        return (
            sunrise: Date(timeIntervalSince1970: (julianRise - 2440587.5) * 86400),
            sunset: Date(timeIntervalSince1970: (julianSet - 2440587.5) * 86400)
        )
    }
}
