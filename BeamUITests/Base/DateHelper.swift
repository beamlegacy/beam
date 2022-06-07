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
        case noteViewTitle = "d MMMM yyyy"
        case noteViewCreation = "MMMM dd, yyyy"
        case noteViewCreationNoZeros = "MMMM d, yyyy"
        case allNotesViewDates = "d MMM yyyy"
    }
    
}
