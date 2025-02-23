//
//  WeatherShared.swift
//  Humidity
//
//  Created by Tiago N Mendes on 18/02/2025.
//

import Foundation
import WeatherKit
import CoreLocation

struct AppConstants {
    static let appGroup = "group.com.github.tnmendes.humidityApp"
    static let locationKey = "SavedLocation"
    static let unitKey = "TemperatureUnit"
    static let homeHoursKey = "HomeHours"
    
    static let optimalWindowStartKey = "OptimalWindowStart"
    static let optimalWindowEndKey = "OptimalWindowEnd"
    static let hourlyHumidityKey = "HourlyHumidity"
    static let predictedHumidityKey = "PredictedHumidity"
}

final class WeatherDataManager {
    static let shared = WeatherDataManager()
    private let weatherService = WeatherService.shared
    
    private init() {}
    
    // MARK: - Shared Methods
    
    static func computeAbsoluteHumidity(temp: Double, rh: Double) -> Double {
        let e = 6.112 * exp((17.67 * temp) / (temp + 243.5))
        return (e * rh * 2.1674) / (temp + 273.15)
    }
    
    static func saveLocation(_ location: SavedLocation) {
        if let data = try? JSONEncoder().encode(location) {
            UserDefaults(suiteName: AppConstants.appGroup)?.set(data, forKey: AppConstants.locationKey)
        }
    }
    
    static func loadSavedLocation() -> SavedLocation? {
        guard let data = UserDefaults(suiteName: AppConstants.appGroup)?.data(forKey: AppConstants.locationKey) else {
            print("No location data found in App Group")
            return nil
        }
        
        do {
            let location = try JSONDecoder().decode(SavedLocation.self, from: data)
            print("Loaded location: \(location.debugDescription)")
            return location
        } catch {
            print("Error decoding location: \(error)")
            return nil
        }
    }
    
    func fetchWeatherData(for location: CLLocation) async throws -> (CurrentWeather, Double) {
        
        let weather = try await weatherService.weather(for: location)
        let currentWeather = weather.currentWeather
        
        // Get temperature in original units
        let temp = currentWeather.temperature
        
        // Compute absolute humidity using Celsius (formula requires it)
        let tempCelsius = temp.converted(to: .celsius).value
        let absoluteHumidity = Self.computeAbsoluteHumidity(
            temp: tempCelsius,
            rh: currentWeather.humidity * 100
        )
        
        return (currentWeather, absoluteHumidity)
    }
}
