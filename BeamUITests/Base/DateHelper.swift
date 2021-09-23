//
//  DateHelper.swift
//  BeamUITests
//
//  Created by Andrii on 03.08.2021.
//

import Foundation
import BeamCore

class DateHelper {
    
    func getTodaysDateString(_ format: DateFormats) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format.rawValue
        return dateFormatter.string(from: BeamDate.now)
    }
    
    enum DateFormats: String {
        case cardViewTitle = "d MMMM yyyy"
        case cardViewCreation = "MMMM dd, yyyy"
        case allCardsViewDates = "d MMM yyyy"
    }
    
}
