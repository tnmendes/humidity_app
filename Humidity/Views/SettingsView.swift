//
//  S.swift
//  Humidity
//
//  Created by Tiago N Mendes on 21/02/2025.
//
import SwiftUI

struct SettingsView: View {
    @Binding var homeHours: (start: Date, end: Date)
    @Binding var selectedUnit: UnitTemperature
    
    var body: some View {
        Form {
            Section(header: Text("Home Hours")) {
                DatePicker("From", selection: $homeHours.start, displayedComponents: .hourAndMinute)
                DatePicker("To", selection: $homeHours.end, displayedComponents: .hourAndMinute)
            }
            
            Section(header: Text("Units")) {
                Picker("Temperature Unit", selection: $selectedUnit) {
                    Text("°C").tag(UnitTemperature.celsius)
                    Text("°F").tag(UnitTemperature.fahrenheit)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
        .navigationTitle("Settings")
        .environment(\.locale, Locale.current)
    }
}
