//
//  WidgetHumidityExtension.swift
//  WidgetHumidityExtension
//
//  Created by Tiago N Mendes on 17/02/2025.
//

import WidgetKit
import SwiftUI
import WeatherKit
import CoreLocation


struct Provider: AppIntentTimelineProvider {
    private let weatherService = WeatherService.shared
    private let dataManager = WeatherDataManager.shared

    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            lastRefresh: Date(),
            relativeHumidity: 65,
            absoluteHumidity: 12.3,
            dewPoint: 9.0,
            temperature: 22.5,
            feelsLike: 24.0,
            unit: .celsius
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        await fetchWeatherEntry()
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let entry = await fetchWeatherEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 60, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func fetchWeatherEntry() async -> SimpleEntry {
        let lastRefresh = UserDefaults(suiteName: AppConstants.appGroup)?.object(forKey: "LastRefresh") as? Date ?? .distantPast
        
        guard let savedLocation = WeatherDataManager.loadSavedLocation() else {
            print("Widget Error: No saved location in App Group")
            return errorEntry(lastRefresh: lastRefresh)
        }
        
        print("Widget using location: \(savedLocation.debugDescription)")
        
        let location = CLLocation(
            latitude: savedLocation.latitude,
            longitude: savedLocation.longitude
        )
        
        // Get saved unit
        let unit: UnitTemperature = {
            guard let unitString = UserDefaults(suiteName: AppConstants.appGroup)?
                .string(forKey: AppConstants.unitKey)
            else { return .celsius }
            
            return unitString == "celsius" ? .celsius : .fahrenheit
        }()
        
        do {
            let (weather, absHumidity) = try await dataManager.fetchWeatherData(for: location)
            
            // Convert values to selected unit
            let temp = weather.temperature.converted(to: unit).value
            let feels = weather.apparentTemperature.converted(to: unit).value
            let dewPoint = weather.dewPoint.converted(to: unit).value
            
            return SimpleEntry(
                date: Date(),
                lastRefresh: Date(),
                relativeHumidity: weather.humidity * 100,
                absoluteHumidity: absHumidity,
                dewPoint: dewPoint,
                temperature: temp,
                feelsLike: feels,
                unit: unit
            )
        } catch {
            print("Widget Weather Error: \(error.localizedDescription)")
            return errorEntry()
        }
    }
    
    
    private func errorEntry(lastRefresh: Date = .distantPast) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            lastRefresh: lastRefresh,
            relativeHumidity: nil,
            absoluteHumidity: nil,
            dewPoint: nil,
            temperature: nil,
            feelsLike: nil,
            unit: nil
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let lastRefresh: Date
    let relativeHumidity: Double?
    let absoluteHumidity: Double?
    let dewPoint: Double?
    let temperature: Double?
    let feelsLike: Double?
    let unit: UnitTemperature?
}


struct WidgetHumidityExtensionEntryView: View {
    var entry: Provider.Entry
    
    private var lastUpdateTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: entry.lastRefresh)
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Top Header Row
                HStack(alignment: .top) {
                    // Humidity Header
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "humidity.fill")
                                .font(.system(size: geo.size.height * 0.09))
                                .foregroundColor(.blue)
                            
                            Text("HUMIDITY")
                                .font(.system(size: geo.size.height * 0.08, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                        
                        if let humidity = entry.relativeHumidity {
                            Text("\(Int(humidity))%")
                                .font(.system(size: geo.size.height * 0.4, weight: .bold))
                                .foregroundColor(.blue)
                                .minimumScaleFactor(0.5)
                                .padding(.top, geo.size.height * 0.02)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Refresh Button and Time
                    VStack(alignment: .trailing, spacing: 2) {
                        Button(intent: RefreshIntent(forceRefresh: true)) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: geo.size.height * 0.12))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        
                        Text(lastUpdateTime)
                            .font(.system(size: geo.size.height * 0.06))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, geo.size.width * 0.05)
                .padding(.top, geo.size.height * 0.04)
                
                Spacer()
                
                // Data Rows
                VStack(alignment: .leading, spacing: geo.size.height * 0.04) {
                    if let absHumidity = entry.absoluteHumidity {
                        DataRow(
                            label: "Abs Humidity:",
                            value: "\(String(format: "%.1f", absHumidity)) g/m³",
                            geo: geo
                        )
                    }
                    
                    if let dewPoint = entry.dewPoint {
                        DataRow(
                            label: "Dew Point:",
                            value: "\(String(format: "%.1f", dewPoint))\(entry.unit?.symbol ?? "")",
                            geo: geo
                        )
                    }
                    
                    if let temp = entry.temperature {
                        DataRow(
                            label: "Temperature:",
                            value: "\(String(format: "%.1f", temp))\(entry.unit?.symbol ?? "")",
                            geo: geo
                        )
                    }
                    
                    if let feels = entry.feelsLike {
                        DataRow(
                            label: "Feels Like:",
                            value: "\(String(format: "%.1f", feels))\(entry.unit?.symbol ?? "")",
                            geo: geo
                        )
                    }
                }
                .padding(.horizontal, geo.size.width * 0.05)
                .padding(.bottom, geo.size.height * 0.04)
                
                // No Location Warning
                if entry.relativeHumidity == nil {
                    Spacer()
                    Text("No location set")
                        .font(.system(size: geo.size.height * 0.12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }
    }
}

struct DataRow: View {
    let label: String
    let value: String
    let geo: GeometryProxy
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: geo.size.height * 0.07))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: geo.size.height * 0.07))
                .foregroundColor(.primary)
        }
    }
}

struct WidgetHumidityExtension: Widget {
    let kind: String = "WidgetHumidityExtension"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: Provider()
        ) { entry in
            WidgetHumidityExtensionEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Humidity Widget")
        .description("Displays current humidity and temperature")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
