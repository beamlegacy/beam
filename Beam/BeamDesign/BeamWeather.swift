//
//  BeamWeather.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 13/04/2021.
//

import Foundation

enum BeamWeather: CaseIterable {
    case sun
    case wind
    case snow
    case rain
    case moon
    case cloud
}

extension BeamWeather {
    var imgName: String {
        switch self {
        case .sun:
            return "weather-sun"
        case .wind:
            return "weather-wind"
        case .snow:
            return  "weather-snow"
        case .rain:
            return "weather-rain"
        case .moon:
            return "weather-moon"
        case .cloud:
            return "weather-cloud"
        }
    }
}
