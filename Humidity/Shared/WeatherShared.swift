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

// Add to WeatherDataManager
@MainActor
final class WeatherDataManager {
    static let shared = WeatherDataManager()
    private let weatherService = WeatherService.shared
    private let cooldown: TimeInterval = 300 // 5 minutes
    
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
    
    static func loadTemperatureUnit() -> UnitTemperature {
        guard let unitString = UserDefaults(suiteName: AppConstants.appGroup)?.string(forKey: AppConstants.unitKey)
        else { return .celsius }
        return unitString == "celsius" ? .celsius : .fahrenheit
    }
    
    // Unified fetch method for all weather data
    func fetchAllWeatherData(for location: CLLocation, forceRefresh: Bool = true) async throws -> (
           current: CurrentWeather,
           absoluteHumidity: Double,
           hourly: [HourlyHumidity],
           optimalWindow: (Date, Date)?
       ) {
           
        let weather = try await weatherService.weather(for: location)
        let currentWeather = weather.currentWeather
        
        // Process current weather
        let tempCelsius = currentWeather.temperature.converted(to: .celsius).value
        let absoluteHumidity = Self.computeAbsoluteHumidity(
            temp: tempCelsius,
            rh: currentWeather.humidity * 100
        )
        
        // Process hourly data
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endDate = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            throw NSError(domain: "DateError", code: 1, userInfo: nil)
        }
                
        let hourlyForecast = try await weatherService.weather(
            for: location,
            including: .hourly(startDate: startOfDay, endDate: endDate))
        let hourlyWeather = hourlyForecast.forecast.map {
            HourlyHumidity(date: $0.date, humidity: $0.humidity * 100)
        }
        
        // Calculate optimal window
        let homeHours: (Date, Date) = {
            guard let dict = UserDefaults(suiteName: AppConstants.appGroup)?.dictionary(forKey: AppConstants.homeHoursKey),
                  let start = dict["start"] as? Date,
                  let end = dict["end"] as? Date else {
                return (Calendar.current.startOfDay(for: Date()),
                Calendar.current.date(byAdding: .hour, value: 12, to: Calendar.current.startOfDay(for: Date()))!)
            }
            return (start, end)
        }()
        
        let optimalWindow = Self.calculateOptimalWindow(
            hourly: hourlyWeather,
            homeHours: homeHours
        )
        
        // Persist data
        UserDefaults(suiteName: AppConstants.appGroup)?.set(Date(), forKey: "LastWeatherFetch")
        persistWeatherData(
            current: currentWeather,
            absoluteHumidity: absoluteHumidity,
            hourly: hourlyWeather,
            optimalWindow: optimalWindow
        )
        
        return (currentWeather, absoluteHumidity, hourlyWeather, optimalWindow)
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
    
    static func calculateOptimalWindow(hourly: [HourlyHumidity], homeHours: (start: Date, end: Date)) -> (Date, Date)? {
        let calendar = Calendar.current
        
        // Get home hours components
        let homeStartComponents = calendar.dateComponents([.hour, .minute], from: homeHours.start)
        let homeEndComponents = calendar.dateComponents([.hour, .minute], from: homeHours.end)
        
        // Filter hours within home time range
        let relevantHours = hourly.filter { entry in
            let entryComponents = calendar.dateComponents([.hour, .minute], from: entry.date)
            guard let entryHour = entryComponents.hour,
                  let startHour = homeStartComponents.hour,
                  let endHour = homeEndComponents.hour else { return false }
            
            return entryHour >= startHour && entryHour <= endHour
        }.sorted { $0.humidity < $1.humidity }
        
        guard let bestHour = relevantHours.first else {
            return nil
        }
        
        // Create 2-hour window around best humidity
        guard let windowEnd = calendar.date(byAdding: .hour, value: 2, to: bestHour.date) else {
            return nil
        }
        
        return (bestHour.date, windowEnd)
    }
    
    private func persistWeatherData(
        current: CurrentWeather,
        absoluteHumidity: Double,
        hourly: [HourlyHumidity],
        optimalWindow: (Date, Date)?
    ) {
        let encoder = JSONEncoder()
        UserDefaults(suiteName: AppConstants.appGroup)?.set(current.humidity * 100, forKey: "relativeHumidity")
        UserDefaults(suiteName: AppConstants.appGroup)?.set(absoluteHumidity, forKey: "absoluteHumidity")
        
        if let data = try? encoder.encode(hourly) {
            UserDefaults(suiteName: AppConstants.appGroup)?.set(data, forKey: AppConstants.hourlyHumidityKey)
        }
        
        if let window = optimalWindow {
            UserDefaults(suiteName: AppConstants.appGroup)?.set(window.0, forKey: AppConstants.optimalWindowStartKey)
            UserDefaults(suiteName: AppConstants.appGroup)?.set(window.1, forKey: AppConstants.optimalWindowEndKey)
        }
    }
    
}
