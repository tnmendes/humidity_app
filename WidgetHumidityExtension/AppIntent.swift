//
//  AppIntent.swift
//  WidgetHumidityExtension
//
//  Created by Tiago N Mendes on 17/02/2025.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "This is an example widget." }

    // An example configurable parameter.
    //@Parameter(title: "Favorite Emoji", default: "😃")
    //var favoriteEmoji: String
}
