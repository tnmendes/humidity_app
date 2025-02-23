//
//  Extension.swift
//  Humidity
//
//  Created by Tiago N Mendes on 21/02/2025.
//

import Swift
import SwiftUI

extension Date {
    func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    func formattedChartTime() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateFormat = Locale.current.hourFormat
        return formatter.string(from: self)
    }
}

extension Locale {
    var hourFormat: String {
        
        let is24Hour = Locale.current.is24Hour
        return is24Hour ? "HH" : "ha"
    }
    
    var is24Hour: Bool { DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: self)?.contains("a") == false }
}
