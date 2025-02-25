//
//  WidgetOptimalVentilationExtension.swift
//  WidgetOptimalVentilationExtension
//
//  Created by Tiago N Mendes on 22/02/2025.
//


import WidgetKit
import SwiftUI
import Charts
import AppIntents
import CoreLocation

struct OptimalEntry: TimelineEntry {
    let date: Date
    let lastRefresh: Date
    let optimalWindow: (start: Date, end: Date)?
    let predictedHumidity: Double?
    let hourlyHumidity: [HourlyHumidity]
    let relativeHumidity: Double?
    let unit: UnitTemperature?
}

extension OptimalEntry {
    static func errorEntry() -> OptimalEntry {
        OptimalEntry(
            date: Date(),
            lastRefresh: .distantPast,
            optimalWindow: nil,
            predictedHumidity: nil,
            hourlyHumidity: [],
            relativeHumidity: nil,
            unit: nil
        )
    }
}


// MARK: - Optimal Ventilation Widget
struct OptimalProvider: AppIntentTimelineProvider {
    private let dataManager = WeatherDataManager.shared
    
    func placeholder(in context: Context) -> OptimalEntry {
        OptimalEntry.errorEntry()
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> OptimalEntry {
        await fetchOptimalEntry()
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<OptimalEntry> {
        let entry = await fetchOptimalEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 60, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func fetchOptimalEntry() async -> OptimalEntry {
        guard let location = await WeatherDataManager.loadSavedLocation() else {
            return OptimalEntry.errorEntry()
        }
        
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        do {
            let (_, _, hourly, optimalWindow) = try await dataManager.fetchAllWeatherData(for: clLocation)
            
            return OptimalEntry(
                date: Date(),
                lastRefresh: Date(),
                optimalWindow: optimalWindow,
                predictedHumidity: optimalWindow.flatMap { window in
                    hourly.first { $0.date >= window.0 && $0.date <= window.1 }?.humidity
                },
                hourlyHumidity: hourly,
                relativeHumidity: UserDefaults(suiteName: AppConstants.appGroup)?.double(forKey: "relativeHumidity"),
                unit: await WeatherDataManager.loadTemperatureUnit()
            )
        } catch {
            return OptimalEntry.errorEntry()
        }
    }
}

struct OptimalVentilationWidgetEntryView: View {
    var entry: OptimalProvider.Entry
    @Environment(\.widgetFamily) var family
    
    private var lastUpdateTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: entry.lastRefresh)
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Header
                HStack(alignment: .top) {
                    // Optimal Window Header
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "window.awning.closed")
                                .font(.system(size: geo.size.height * 0.09))
                                .foregroundColor(.blue)
                            
                            Text(family == .systemSmall ? "OPTIMAL WINDOW" : "OPTIMAL VENTILATION WINDOWS")
                                .font(.system(size: geo.size.height * 0.08, weight: .semibold))
                                .foregroundColor(.blue)
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
                
                // Optimal Window Time
                if let window = entry.optimalWindow {
                    VStack(alignment: .leading) {
                        Text("\(window.start.formattedTime()) - \(window.end.formattedTime())")
                            .font(.system(size: family == .systemSmall ? geo.size.height * 0.14 : geo.size.height * 0.17, weight: family == .systemSmall ? .semibold : .bold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, geo.size.width * 0.05)
                            .padding(.top, family == .systemSmall ? 0 : -15)
                        
                        if let humidity = entry.predictedHumidity {
                            Text("Predicted Humidity: \(Int(humidity))%")
                                .font(.system(size: geo.size.height * 0.07))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, geo.size.width * 0.05)
                                .padding(.top, 0)
                        }
                    }
                    //.padding(.top, family == .systemSmall ? 2 : 2)
                    .padding(.top, 0)
                }
                
                // Chart
                ChartView(entry: entry, family: family)
                    .padding(.horizontal, geo.size.width * 0.05)
                    .frame(height: family == .systemSmall ? geo.size.height * 0.4 : geo.size.height * 0.5)
                    .padding(.top, family == .systemSmall ? 6 : 4)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct ChartView: View {
    let entry: OptimalProvider.Entry
    let family: WidgetFamily
    
    var body: some View {
        Chart {
            ForEach(entry.hourlyHumidity.prefix(24)) { hour in
                if family == .systemMedium {
                    BarMark(
                        x: .value("Time", hour.date, unit: .hour),
                        y: .value("Humidity", hour.humidity)
                    )
                    .foregroundStyle(isInWindow(hour.date) ? .blue : .gray)
                } else {
                    LineMark(
                        x: .value("Time", hour.date, unit: .hour),
                        y: .value("Humidity", hour.humidity)
                    )
                    .foregroundStyle(isInWindow(hour.date) ? .blue : .gray)
                }
            }
            
            if let window = entry.optimalWindow {
                RectangleMark(
                    xStart: .value("Start", window.start, unit: .hour),
                    xEnd: .value("End", window.end, unit: .hour),
                    yStart: .value("Min", 0),
                    yEnd: .value("Max", 100)
                )
                .foregroundStyle(.blue.opacity(0.1))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: family == .systemSmall ? 6 : 3)) { _ in
                AxisValueLabel(format: .dateTime.hour())
                    .font(.system(size: family == .systemSmall ? 8 : 10))
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel()
                    .font(.system(size: family == .systemSmall ? 8 : 10))
            }
        }
    }
    
    private func isInWindow(_ date: Date) -> Bool {
        guard let window = entry.optimalWindow else { return false }
        return date >= window.start && date <= window.end
    }
}

struct OptimalVentilationWidget: Widget {
    let kind: String = "OptimalVentilationWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: OptimalProvider()
        ) { entry in
            OptimalVentilationWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Ventilation Window")
        .description("Best time to ventilate based on humidity")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
