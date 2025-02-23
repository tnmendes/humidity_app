import SwiftUI
import WeatherKit
import CoreLocation
import Charts


// MARK: - Main ContentView

struct ContentView: View {
    @StateObject var viewModel = WeatherViewModel()
    @FocusState private var isFocused: Bool
    
    var body: some View {
            NavigationView {
                ZStack(alignment: .bottom) {
                    // Background layer
                    LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.05)]),
                                   startPoint: .top,
                                   endPoint: .bottom)
                    .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 20) {

                            // City input field
                            TextField("Enter your city", text: $viewModel.searchText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                                .focused($isFocused)
                                .onChange(of: isFocused) { _, newValue in
                                    if !newValue {
                                        viewModel.suggestions = []
                                    }
                                }
                            
                            // Autocomplete suggestions
                            if isFocused && !viewModel.suggestions.isEmpty {
                                ScrollView {
                                    LazyVStack(alignment: .leading) {
                                        ForEach(viewModel.suggestions, id: \.self) { suggestion in
                                            Button {
                                                viewModel.selectSuggestion(suggestion)
                                                isFocused = false
                                            } label: {
                                                VStack(alignment: .leading) {
                                                    Text(suggestion.title)
                                                        .foregroundColor(.primary)
                                                    Text(suggestion.subtitle)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal)
                                            
                                            if suggestion != viewModel.suggestions.last {
                                                Divider()
                                                    .padding(.leading)
                                            }
                                        }
                                    }
                                }
                                .frame(maxHeight: 200)
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(10)
                                .shadow(radius: 3)
                                .padding(.horizontal)
                                .transition(.opacity)
                                .zIndex(1) // Ensure suggestions appear above other content
                            }
                            
                            if let windowTime = viewModel.optimalWindowTime {
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text("🪟 Optimal Ventilation Window")
                                            .font(.headline)
                                        
                                        Button {
                                            viewModel.showHumidityExplanation = true
                                        } label: {
                                            Image(systemName: "info.circle")
                                                .foregroundColor(.blue)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    
                                    VStack(alignment: .leading) {
                                        Text("\(windowTime.start.formattedTime()) - \(windowTime.end.formattedTime())")
                                            .font(.subheadline)
                                        
                                        if let minHumidity = viewModel.optimalWindowHumidity {
                                            Text("Predicted Humidity: \(String(format: "%.0f", minHumidity))%")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    HumidityChartView(
                                        hours: viewModel.hourlyHumidityData,
                                        optimalWindow: viewModel.optimalWindowTime
                                    )
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.blue.opacity(0.1))
                                    )
                                .padding(.horizontal)
                                .alert("Optimal Ventilation Window", isPresented: $viewModel.showHumidityExplanation) {
                                    Button("OK") { }
                                } message: {
                                    Text("Recommendation based on lowest humidity levels during your specified home hours. Opening windows during this time helps reduce indoor moisture and prevent mold growth.")
                                }
                            }

                            // Loading indicator
                            if viewModel.isLoading {
                                ProgressView("Loading...")
                            }

                            // Error message
                            if let errorMessage = viewModel.errorMessage {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .padding(.horizontal)
                            }

                            // Weather content
                            if let weather = viewModel.currentWeather {
                                WeatherDisplayView(
                                    weather: weather,
                                    absoluteHumidity: viewModel.absoluteHumidity ?? 0.0,
                                    unit: viewModel.selectedUnit,
                                    lastRefresh: viewModel.lastRefresh
                                )
                            }
                            
                            IndoorHumidityCalculator(
                                indoorTemperature: $viewModel.indoorTemperature,
                                indoorHumidity: $viewModel.indoorHumidity,
                                unit: viewModel.selectedUnit,
                                indoorAbsolute: viewModel.indoorAbsoluteHumidity,
                                outdoorAbsolute: viewModel.absoluteHumidity,
                                advice: viewModel.humidityComparisonAdvice
                            )
                            
                            VStack(spacing: 4) {
                                Link(destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!) {
                                    HStack(spacing: 4) {
                                        Text(" Weather")
                                            .font(.footnote)
                                        Image(systemName: "arrow.up.forward.app")
                                            .font(.caption2)
                                    }
                                }
                                Text("Data source: Apple Weather")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.bottom, 8)
                            
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                    
                    // Toast message overlay
                    if let message = viewModel.toastMessage {
                        Text(message)
                            .padding()
                            .background(Material.regular)
                            .cornerRadius(8)
                            .shadow(radius: 5)
                            .transition(.opacity)
                            .padding(.bottom, 50)
                            .onAppear {
                                // Automatically dismiss after 3 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    viewModel.toastMessage = nil
                                }
                            }
                    }
                }
                .navigationTitle("Humidity Check")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        NavigationLink {
                            SettingsView(
                                homeHours: $viewModel.homeHours,
                                selectedUnit: $viewModel.selectedUnit
                            )
                        } label: {
                            Image(systemName: "gear")
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        refreshButton
                    }
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    
    private var refreshButton: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Button {
                Task {
                      if let loc = viewModel.savedLocation {
                          let location = CLLocation(
                              latitude: loc.latitude,
                              longitude: loc.longitude
                          )
                          // Respect cooldown for manual refreshes
                          await viewModel.updateWeather(for: location)
                      }
                  }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
            }
            
            Text("Last update: \(viewModel.lastRefresh.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .animation(.easeInOut, value: viewModel.shouldDisableRefresh)
                .padding(.top, -6)
        }
    }
}


struct WeatherDisplayView: View {
    let weather: CurrentWeather
    let absoluteHumidity: Double
    let unit: UnitTemperature
    let lastRefresh: Date
    
    var body: some View {
        let displayedTemp = weather.temperature.converted(to: unit).value
        let apparentTemp = weather.apparentTemperature.converted(to: unit).value
        let dewPointTemp = weather.dewPoint.converted(to: unit).value
        let unitSymbol = (unit == .celsius) ? "°C" : "°F"
        let relativeHum = weather.humidity * 100
        
        VStack(spacing: 12) {
            HalfCircleComfortMeter(humidity: relativeHum)
                .frame(width: 220, height: 120)
                .padding(.top, 10)
            
            // Relative humidity display
            Text("Relative Humidity: \(String(format: "%.0f", relativeHum))%")
                .font(.headline)
            
            Divider().padding(.horizontal, 60)
            
            // Weather metrics grid
            HStack(spacing: 20) {
                // Temperature Column
                VStack(spacing: 8) {
                    WeatherMetricView(
                        icon: "thermometer",
                        color: .red,
                        title: "Temperature",
                        value: "\(String(format: "%.1f", displayedTemp))\(unitSymbol)"
                    )
                    
                    WeatherMetricView(
                        icon: "thermometer.sun",
                        color: .orange,
                        title: "Feels Like",
                        value: "\(String(format: "%.1f", apparentTemp))\(unitSymbol)"
                    )
                }
                
                // Humidity Column
                VStack(spacing: 8) {
                    WeatherMetricView(
                        icon: "drop.fill",
                        color: .blue,
                        title: "Dew Point",
                        value: "\(String(format: "%.1f", dewPointTemp))\(unitSymbol)"
                    )
                    
                    WeatherMetricView(
                        icon: "aqi.medium",
                        color: .gray,
                        title: "Abs Humidity",
                        value: "\(String(format: "%.1f", absoluteHumidity)) g/m³"
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Material.regular) //.fill(Color(.systemBackground).opacity(0.9)) // Adaptive color
        )
        .padding(.horizontal)
    }
}

// MARK: - New Component for Weather Metrics
struct WeatherMetricView: View {
    let icon: String
    let color: Color
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .padding(.bottom, 4)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.body)
                .bold()
        }
        .frame(minWidth: 80)
    }
}

// MARK: - A half-circle segmented meter with an arrow pointer and labels at 30%, 40%, 60%, 70%.

struct HalfCircleComfortMeter: View {
    let humidity: Double  // 0..100
    
    // Segment definitions: (start%, end%, color)
    let segments: [(Double, Double, Color)] = [
        (0,   30,  .red),
        (70,  100, .red),
        (30,  40,  .yellow),
        (60,  70,  .yellow),
        (40,  60,  .green)
    ]
    
    // The labeled percentages
    let labels: [Double] = [0, 30, 40, 60, 70, 100]
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let radius = min(width, height * 2) / 2 - 8
            let center = CGPoint(x: width / 2, y: height)
            
            ZStack {
                // Draw arcs for each segment
                ForEach(segments, id: \.0) { seg in
                    HalfArcShape(center: center,
                                 radius: radius-18,
                                 startPercent: seg.0,
                                 endPercent: seg.1)
                    .stroke(seg.2, style: StrokeStyle(lineWidth: 50, lineCap: .butt))
                }
                
                // Labels for 30%, 40%, 60%, 70%
                ForEach(labels, id: \.self) { lbl in
                    let angleDeg = angleForPercentlabelPos(lbl)
                    let labelPos = pointOnArc(center: center,
                                              radius: radius + 24,
                                              angleDeg: angleDeg)
                    let tempAngleDeg = (lbl == 0) ? 180 : angleDeg
                    Text("\(Int(lbl))%")
                        .font(.caption)
                        .rotationEffect(.degrees(tempAngleDeg - 180), anchor: .center)
                        .position(labelPos)
                }
                
                // Arrow pointer for current humidity
                PointerArrowShape()
                    .fill(Color.black)
                    .frame(width: 28, height: 60)
                    .shadow(radius: 2, y: 2)
                // Position arrow base at center of arc
                    .position(x: center.x, y: center.y-28)
                // Rotate around that base
                    .rotationEffect(.degrees(angleForPercent(humidity) - 270), anchor: .bottom)
            }
        }
    }
    
    /// Convert percentage to degrees in [0..180]
    private func angleForPercent(_ p: Double) -> Double {
        // 0% => 0 deg (far left)
        // 100% => 180 deg (far right)
        return 1.8 * p + 180
    }
    
    private func angleForPercentlabelPos(_ p: Double) -> Double {
        // 0% => 0 deg (far left)
        // 100% => 180 deg (far right)
        return 1.8 * p
    }
    
    /// Get a point on the arc for labeling
    private func pointOnArc(center: CGPoint, radius: CGFloat, angleDeg: Double) -> CGPoint {
        // For half-circle, 0 deg is far left, 180 deg is far right
        // We'll treat 0 deg as at the left, going clockwise
        let radians = angleDeg * .pi / 180
        let x = center.x + radius * cos(radians - .pi) // subtract pi to shift 0 deg to left side
        let y = center.y + radius * sin(radians - .pi)
        return CGPoint(x: x, y: y)
    }
}

// MARK: - A shape that draws an arc for [startPercent..endPercent] in a half-circle

struct HalfArcShape: Shape {
    let center: CGPoint
    let radius: CGFloat
    let startPercent: Double
    let endPercent: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let startAngle = Angle.degrees(1.8 * startPercent + 180)
        let endAngle   = Angle.degrees(1.8 * endPercent + 180)
        
        // Note: Arc is drawn clockwise, so startAngle > endAngle
        path.addArc(center: center,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false)
        return path
    }
}

// MARK: - A simple arrow shape for the pointer

struct PointerArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        // Create a rounded arrow shape with perfect center alignment
        path.move(to: CGPoint(x: width * 0.25, y: height))  // Start at left base
        path.addQuadCurve(to: CGPoint(x: width * 0.75, y: height), control: CGPoint(x: width/2, y: height))
        
        path.addCurve(to: CGPoint(x: width/2, y: height * 0.1),
                      control1: CGPoint(x: width * 0.8, y: height * 0.5),
                      control2: CGPoint(x: width * 0.6, y: height * 0.15))
        
        path.addCurve(to: CGPoint(x: width * 0.25, y: height),
                      control1: CGPoint(x: width * 0.4, y: height * 0.15),
                      control2: CGPoint(x: width * 0.2, y: height * 0.5))
        
        return path
    }
}

struct ContentView_Previews: PreviewProvider {
    
    init() {
        let locationKey = "SavedLocation"
        let saved = SavedLocation(name: "Vila Nova de Gaia", subtitle: "Portugal", latitude: 41.1299474, longitude: -8.6258354)
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: locationKey)
        }
    }
    
    static var previews: some View {
        ContentView()
            .previewDevice("iPhone 16")
    }
}
