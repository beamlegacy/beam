//
//  PrivacyPreferencesViewLocators.swift
//  BeamUITests
//
//  Created by Quentin Valero on 10/05/2022.
//

import Foundation

enum PrivacyPreferencesViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case allowListManage = "Manage..."
    }
    
    enum CheckboxTexts: String, CaseIterable, UIElement {
        case websiteTracking = "Prevent cross-site tracking"
        case adsCheckbox = "Remove most advertisements while browsing"
        case trackersHistory = "Prevent Internet history tracking"
        case trackersSocialMedia = "Block Social Media Buttons"
        case annoyancesBanners = "Remove banners and popups from websites"
        case annoyancesCookieBanners = "Hide cookie banners"
    }
}
