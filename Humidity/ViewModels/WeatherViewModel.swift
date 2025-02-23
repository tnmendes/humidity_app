//
//  WeatherViewModel.swift
//  Humidity
//
//  Created by Tiago N Mendes on 22/02/2025.
//
import SwiftUI
import WeatherKit
import MapKit


@MainActor
class WeatherViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    // User input & suggestions
    @Published var searchText: String = "" {
        didSet {
            if searchText != oldValue {
                selectedSuggestion = nil
            }
            if selectedSuggestion == nil {
                localSearchCompleter.queryFragment = searchText
            }
        }
    }
    @Published var suggestions: [MKLocalSearchCompletion] = []
    @Published var selectedSuggestion: MKLocalSearchCompletion?
    
    // Weather data
    @Published var currentWeather: CurrentWeather?
    @Published var absoluteHumidity: Double?
    
    // Persistence
    @Published var savedLocation: SavedLocation?
    
    // Loading and error state
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Temperature unit preference
    @Published var selectedUnit: UnitTemperature = .celsius {
        didSet {
            saveTemperatureUnit()
        }
    }
    
    @Published var toastMessage: String? {
        didSet {
            // Clear the toast message after 3 seconds
            if toastMessage != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.toastMessage = nil
                }
            }
        }
    }
    private var autoRefreshTimer: Timer?
    private let autoRefreshInterval: TimeInterval = 300 // 5 minutes
    @Published var lastRefresh = Date.distantPast {
        didSet {
            // Schedule next auto-refresh
            scheduleAutoRefresh()
        }
    }
    var canRefresh: Bool {
        Date().timeIntervalSince(lastRefresh) > 30
    }
    var timeSinceLastRefresh: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.second, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: lastRefresh, to: Date()) ?? ""
    }
    
    var shouldDisableRefresh: Bool {
        Date().timeIntervalSince(lastRefresh) < 30
    }
    
    private let localSearchCompleter = MKLocalSearchCompleter()
    private let weatherService = WeatherService()  // WeatherKit service
    
    @Published var homeHours: (start: Date, end: Date) {
        didSet {
            saveHomeHours()
        }
    }
    @Published var optimalWindowTime: (start: Date, end: Date)?
    @Published var hourlyHumidityData: [HourlyHumidity] = []
    @Published var showHumidityExplanation = false
    var optimalWindowHumidity: Double? {
        guard let window = optimalWindowTime,
              let data = hourlyHumidityData.filter({
                  $0.date >= window.start && $0.date <= window.end
              }).min(by: { $0.humidity < $1.humidity })
        else { return nil }
        
        return data.humidity
    }
    
    @Published var indoorTemperature: String = ""
    @Published var indoorHumidity: String = ""
    var indoorAbsoluteHumidity: Double? {
        guard let temp = Double(indoorTemperature),
              let humidity = Double(indoorHumidity),
              (0...100).contains(humidity) else { return nil }
        
        // Convert to Celsius if needed
        let tempCelsius: Double
        if selectedUnit == .celsius {
            tempCelsius = temp
        } else {
            tempCelsius = Measurement(value: temp, unit: UnitTemperature.fahrenheit)
                .converted(to: .celsius).value
        }
        
        return WeatherDataManager.computeAbsoluteHumidity(temp: tempCelsius, rh: humidity)
    }

    var humidityComparisonAdvice: String? {
        guard let indoor = indoorAbsoluteHumidity,
              let outdoor = absoluteHumidity else { return nil }
        
        if indoor > outdoor {
            return "Opening windows now could reduce indoor humidity"
        } else {
            return "Keep windows closed to maintain lower humidity"
        }
    }
    
    override init() {
        self.homeHours = Self.loadHomeHours()
        super.init()
        localSearchCompleter.delegate = self
        localSearchCompleter.resultTypes = .address
        loadSavedLocation()
        loadTemperatureUnit()
        startAutoRefreshTimer()
    }
    
    deinit {
        autoRefreshTimer?.invalidate()
    }
    
    private func saveTemperatureUnit() {
        UserDefaults(suiteName: AppConstants.appGroup)?.setValue(
            selectedUnit == .celsius ? "celsius" : "fahrenheit",
            forKey: AppConstants.unitKey
        )
    }
    
    private func loadTemperatureUnit() {
        guard let unitString = UserDefaults(suiteName: AppConstants.appGroup)?.string(forKey: AppConstants.unitKey)
        else { return }
        selectedUnit = unitString == "celsius" ? .celsius : .fahrenheit
    }
    
    // MARK: - Autocomplete Delegate

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.suggestions = completer.results
        }
    }
    
    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.suggestions = []
            print("Autocomplete error: \(error)")
        }
    }
    
    /// Called when the user selects a suggestion.
    func selectSuggestion(_ suggestion: MKLocalSearchCompletion) {
        selectedSuggestion = suggestion
        searchText = suggestion.title
        suggestions = []
        
        let searchRequest = MKLocalSearch.Request(completion: suggestion)
        let search = MKLocalSearch(request: searchRequest)
        isLoading = true
        
        search.start { [weak self] response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Error retrieving location: \(error.localizedDescription)"
                    self.isLoading = false
                    return
                }
                
                guard let placemark = response?.mapItems.first?.placemark,
                      let location = placemark.location else {
                    self.errorMessage = "Invalid location data"
                    self.isLoading = false
                    return
                }
                
                Task {
                    // Bypass cooldown check for new location selections
                    await self.updateWeather(for: location, enforceCooldown: false)
                    
                    let saved = SavedLocation(
                        name: suggestion.title,
                        subtitle: suggestion.subtitle,
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )
                    self.savedLocation = saved
                    WeatherDataManager.saveLocation(saved)
                }
            }
        }
    }
    
    private func startAutoRefreshTimer() {
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: autoRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let loc = self.savedLocation else { return }
                let location = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
                await self.updateWeather(for: location)
            }
        }
    }
    
    private func scheduleAutoRefresh() {
        autoRefreshTimer?.invalidate()
        startAutoRefreshTimer()
    }
    
    /// Fetch weather data using WeatherKit.
    func updateWeather(for location: CLLocation, enforceCooldown: Bool = true) async {
        let refreshAllowed = Date().timeIntervalSince(lastRefresh) > 30 || !enforceCooldown
        
        if !refreshAllowed {
            toastMessage = "Please wait 30 seconds between refreshes (\(timeSinceLastRefresh))"
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        UserDefaults(suiteName: AppConstants.appGroup)?.set(Date(), forKey: "LastRefresh")
        do {
            let (weather, absHumidity) = try await WeatherDataManager.shared.fetchWeatherData(for: location)
            currentWeather = weather
            absoluteHumidity = absHumidity
            errorMessage = nil
            lastRefresh = Date()
            
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .hour, value: 25, to: startDate) ?? startDate
            let hourlyWeather = try await weatherService.weather(for: location, including: .hourly(startDate: startDate, endDate: endDate))

            // Convert to hourly humidity data
            self.hourlyHumidityData = hourlyWeather.map { HourlyHumidity(date: $0.date, humidity: $0.humidity * 100) }
            do {
                let data = try JSONEncoder().encode(self.hourlyHumidityData)
                UserDefaults(suiteName: AppConstants.appGroup)?.set(data, forKey: AppConstants.hourlyHumidityKey)
            } catch {
                print("Error saving hourly humidity: \(error)")
            }
            
            calculateOptimalWindowTime()
            
            if let optimalWindow = self.optimalWindowTime {
                UserDefaults(suiteName: AppConstants.appGroup)?.set(optimalWindow.0, forKey: AppConstants.optimalWindowStartKey)
                UserDefaults(suiteName: AppConstants.appGroup)?.set(optimalWindow.1, forKey: AppConstants.optimalWindowEndKey)
                
                let minHumidity = self.hourlyHumidityData
                    .filter { $0.date >= optimalWindow.0 && $0.date <= optimalWindow.1 }
                    .min(by: { $0.humidity < $1.humidity })?.humidity
                UserDefaults(suiteName: AppConstants.appGroup)?.set(minHumidity, forKey: AppConstants.predictedHumidityKey)
            }
            
        } catch {
            errorMessage = "Error fetching weather: \(error.localizedDescription)"
            currentWeather = nil
            absoluteHumidity = nil
        }
    }
    
    // MARK: - Persistence
    
    private func loadSavedLocation() {
        if let loc = WeatherDataManager.loadSavedLocation() {
            savedLocation = loc
            let coordinate = CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            isLoading = true
            Task {
                await updateWeather(for: location)
                searchText = loc.name
            }
        }
    }
    
    
    private func saveHomeHours() {
        UserDefaults(suiteName: AppConstants.appGroup)?.set([
            "start": homeHours.start,
            "end": homeHours.end
        ], forKey: AppConstants.homeHoursKey)
    }

    private static func loadHomeHours() -> (Date, Date) {
        guard let dict = UserDefaults(suiteName: AppConstants.appGroup)?.dictionary(forKey: AppConstants.homeHoursKey),
              let start = dict["start"] as? Date,
              let end = dict["end"] as? Date
        else {
            let calendar = Calendar.current
            let components = DateComponents(hour: 8)
            let defaultStart = calendar.date(from: components)!
            let defaultEnd = calendar.date(byAdding: .hour, value: 12, to: defaultStart)! // 8AM + 12h = 8PM
            return (defaultStart, defaultEnd)
        }
        return (start, end)
    }
    
    private func calculateOptimalWindowTime() {
        let calendar = Calendar.current
        let homeStartComponents = calendar.dateComponents([.hour, .minute], from: homeHours.start)
        let homeEndComponents = calendar.dateComponents([.hour, .minute], from: homeHours.end)
        
        // Filter hours within home time range
        let relevantHours = hourlyHumidityData.filter { entry in
            let entryComponents = calendar.dateComponents([.hour, .minute], from: entry.date)
            return entryComponents.hour! >= homeStartComponents.hour! &&
                   entryComponents.hour! <= homeEndComponents.hour!
        }.sorted { $0.humidity < $1.humidity }
        
        guard let bestHour = relevantHours.first else { return }
        
        // Create 2-hour window around best humidity
        let windowStart = bestHour.date
        let windowEnd = calendar.date(byAdding: .hour, value: 2, to: windowStart)!
        
        optimalWindowTime = (windowStart, windowEnd)
    }
}
