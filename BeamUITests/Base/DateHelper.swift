//
//  DateHelper.swift
//  BeamUITests
//
//  Created by Andrii on 03.08.2021.
//

import Foundation

class DateHelper {
    
    func getTodaysDateString(_ format: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: Date())
    }
    
    enum DateFormats: String {
        case cardViewTitle = "d MMMM yyyy"
        case cardViewCreation = "MMMM dd, yyyy"
        case allCardsViewDates = "d MMM yyyy"
    }
    
}
