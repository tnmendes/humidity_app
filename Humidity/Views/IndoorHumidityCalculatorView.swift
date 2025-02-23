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
    
    var body: some View {
        VStack(spacing: 12) {
            Text("🏠 Indoor Humidity Calculator")
                .font(.headline)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Indoor Temperature")
                        .font(.caption)
                    TextField("Temp", text: $indoorTemperature)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                }
                
                VStack(alignment: .leading) {
                    Text("Indoor Humidity")
                        .font(.caption)
                    TextField("RH%", text: $indoorHumidity)
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
        .frame(maxWidth: .infinity) // Add this line
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.1))
        )
        .padding(.horizontal)
    }
}
