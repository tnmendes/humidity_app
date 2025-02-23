//
//  HumidityChartView.swift
//  Humidity
//
//  Created by Tiago N Mendes on 21/02/2025.
//

import SwiftUI
import Charts


struct HumidityChartView: View {
    let hours: [HourlyHumidity]
    let optimalWindow: (Date, Date)?
    
    var body: some View {
        Chart {
            ForEach(hours) { hour in
                BarMark(
                    x: .value("Time", hour.date, unit: .hour),
                    y: .value("Humidity", hour.humidity)
                )
                .foregroundStyle(isInOptimalWindow(hour.date) ? .blue : .gray)
            }
            
            if let window = optimalWindow {
                RuleMark(
                    xStart: .value("Window Start", window.0, unit: .hour),
                    xEnd: .value("Window End", window.1, unit: .hour),
                    y: .value("Position", 0)
                )
                .foregroundStyle(.blue.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 8))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 8)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formattedChartTime())
                            .font(.system(size: 12))
                    }
                }
            }
        }
        .frame(height: 150)
        .padding()
    }
    
    private func isInOptimalWindow(_ date: Date) -> Bool {
        guard let window = optimalWindow else { return false }
        return date >= window.0 && date <= window.1
    }
}
