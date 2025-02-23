//
//  RefreshIntent.swift
//  Humidity
//
//  Created by Tiago N Mendes on 22/02/2025.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Refresh Intent
struct RefreshIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Weather Data"
    static var description = IntentDescription("Updates weather information with cooldown protection")

    @Parameter(title: "Force Refresh", default: false)
    var forceRefresh: Bool
    
    // Add explicit initializer
    init(forceRefresh: Bool) {
        self.forceRefresh = forceRefresh
    }
    
    init() {}  // Required empty initializer
    
    func perform() async throws -> some IntentResult {
        let lastRefresh = UserDefaults(suiteName: AppConstants.appGroup)?.object(forKey: "LastRefresh") as? Date ?? .distantPast
        let cooldown: TimeInterval = 30
        
        guard forceRefresh || Date().timeIntervalSince(lastRefresh) > cooldown else {
            throw NSError(domain: "WidgetError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Wait 30 seconds between refreshes"])
        }
        
        UserDefaults(suiteName: AppConstants.appGroup)?.set(Date(), forKey: "LastRefresh")
        WidgetCenter.shared.reloadTimelines(ofKind: "WidgetHumidityExtension")
        return .result()
    }
}
