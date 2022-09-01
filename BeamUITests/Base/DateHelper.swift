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
    
    func getDateString(daysDifferenceFromToday: Int, _ format: DateFormats) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format.rawValue
        let calendar = Calendar(identifier: .iso8601)
        let requestedDay = calendar.date(byAdding: .day, value: daysDifferenceFromToday, to: BeamDate.now) ?? BeamDate.now
        return dateFormatter.string(from: requestedDay)
    }
    
    enum DateFormats: String {
        case noteViewTitle = "d MMMM yyyy"
        case noteViewCreation = "MMMM dd, yyyy"
        case noteViewCreationNoZeros = "MMMM d, yyyy"
        case allNotesViewDates = "d MMM yyyy"
    }
    
}
