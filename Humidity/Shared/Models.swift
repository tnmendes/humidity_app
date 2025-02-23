//
//  Models.swift
//  Humidity
//
//  Created by Tiago Mendes on 22/02/2025.
//

import Foundation

struct SavedLocation: Codable {
    let name: String
    let subtitle: String
    let latitude: Double
    let longitude: Double
    
    // Add explicit coding keys
    enum CodingKeys: String, CodingKey {
        case name, subtitle, latitude, longitude
    }
    
    // Add debug description
    var debugDescription: String {
        "\(name) @ \(latitude),\(longitude)"
    }
}


struct HourlyHumidity: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let humidity: Double
    
    enum CodingKeys: String, CodingKey {
        case date, humidity
    }
}
