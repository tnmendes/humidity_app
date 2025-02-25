//
//  IndoorHumidityCalculatorView.swift
//  Humidity
//
//  Created by Tiago N Mendes on 22/02/2025.
//

import SwiftUI

struct IndoorHumidityCalculator: View {
    @Binding var indoorTemperature: String
    @Binding var indoorHumidity: String
    let unit: UnitTemperature
    let indoorAbsolute: Double?
    let outdoorAbsolute: Double?
    let advice: String?
    
    private var temperatureProxy: Binding<String> {
        Binding<String>(
            get: { self.indoorTemperature },
            set: { newValue in
                // Convert commas to periods first
                let converted = newValue.replacingOccurrences(of: ",", with: ".")
                
                // Filter invalid characters and handle decimal point
                let filtered = converted
                    .filter { "0123456789.".contains($0) }
                    .replacingOccurrences(of: #"(?<=.)\.(?=.*\.)"#,
                                        with: "",
                                        options: .regularExpression) // Remove extra dots
                
                // Split into components and limit decimal places
                let components = filtered.components(separatedBy: ".")
                var final = components[0]
                
                if components.count > 1 {
                    let decimalPart = String(components[1].prefix(2)) // Allow max 2 decimal places
                    final += "." + decimalPart
                }
                
                // Handle leading decimal point
                if final.hasPrefix(".") {
                    final = "0" + final
                }
                
                self.indoorTemperature = final
            }
        )
    }
    
    private var humidityProxy: Binding<String> {
        Binding<String>(
            get: { self.indoorHumidity },
            set: {
                let filtered = $0
                    .filter { "0123456789".contains($0) }
                    .prefix(3) // Max 100% humidity
                self.indoorHumidity = String(filtered)
            }
        )
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("🏠 Indoor Absolute Humidity Calculator")
                .font(.headline)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Indoor Temperature")
                        .font(.caption)
                    TextField("Temp", text: temperatureProxy)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                }
                
                VStack(alignment: .leading) {
                    Text("Indoor Humidity")
                        .font(.caption)
                    TextField("RH%", text: humidityProxy)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                }
            }
            
            if let indoor = indoorAbsolute, let outdoor = outdoorAbsolute {
                VStack(spacing: 6) {
                    HStack {
                        Text("Indoor Absolute:")
                        Text("\(String(format: "%.1f", indoor)) g/m³")
                            .bold()
                    }
                    
                    HStack {
                        Text("Outdoor Absolute:")
                        Text("\(String(format: "%.1f", outdoor)) g/m³")
                            .bold()
                    }
                    
                    if let advice = advice {
                        Text(advice)
                            .font(.subheadline)
                            .foregroundColor(indoor > outdoor ? .green : .orange)
                            .padding(.top, 8)
                    }
                }
            } else if outdoorAbsolute == nil {
                Text("Set a location first to compare")
                    .foregroundColor(.secondary)
            } else if indoorTemperature.isEmpty && indoorHumidity.isEmpty {
                Text("Enter your indoor conditions to compare")
                    .foregroundColor(.secondary)
            } else {
                Text("Invalid input")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.1))
        )
        .padding(.horizontal)
    }
}
