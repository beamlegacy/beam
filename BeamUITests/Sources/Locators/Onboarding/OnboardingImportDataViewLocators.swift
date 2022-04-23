//
//  OnboardingImportDataViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 21/03/2022.
//

import Foundation

enum OnboardingImportDataViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case skipButton = "skip_action"
        case backButton = "Back"
        case csvButton = "Choose CSV File"
        case importButton = "import_action"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case viewTitle = "Import your data"
        case historyCheckboxTitle = "History"
        case passwordCheckboxTitle = "Passwords"
        case safariDescription1 = "Open Safari Preferences -> Passwords."
        case safariDescription2 = "Click on “•••” and choose “Export...”"
        case safariMozillaDescription3 = "Click on Choose CSV File button and select the exported CSV file."
        case mozillaDescription1 = "Open Firefox Preferences -> Privacy & Security -> Saved Logins."
        case mozillaDescription2 = "Click on “•••” and choose “Export logins...”"
        case csvDescriptionRow1 = "Export your passwords from other browsers or password managers as a CSV file."
        case csvDescriptionRow2 = "Click the “Choose CSV File” button and select the CSV file."
    }
    
    enum Images: String, CaseIterable, UIElement {
        case browsersDropDownIcon = "editor-breadcrumb_down"
    }
    
    enum Browsers: String, CaseIterable, UIElement {
        case safari = "Safari"
        case chrome = "Google Chrome"
        case firefox = "Mozilla Firefox"
        case brave = "Brave Browser"
        case csv = "Passwords CSV File"
    }
    
}
