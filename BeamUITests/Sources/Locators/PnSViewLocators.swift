//
//  PnSViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 17.09.2021.
//

import Foundation

enum PnSViewLocators {
    
    enum TextFields: String, CaseIterable, UIElement  {
        case destinationCardToday = "Today"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement  {
        case addedToPopupPartWithNumber = " Added to "
        case addedToPopup = "Added to"
        case failedCollectPopup = "Failed to collect"
    }
    
    enum Other: String, CaseIterable, UIElement  {
        case pointFrame = "PointFrame"
        case shootCardPicker = "ShootCardPicker"
        case shootFrameSelection = "ShootFrameSelection"
        case shootFrameSelectionLabel = "ShootFrameSelectionLabel"
    }
}
