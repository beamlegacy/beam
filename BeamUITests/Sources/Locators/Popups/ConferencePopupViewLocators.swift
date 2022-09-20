//
//  ConferencePopupView.swift
//  BeamUITests
//
//  Created by Andrii on 19/09/2022.
//

import Foundation


enum ConferencePopupViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case openInMainWindowButton = "tabs-side-openmain"
        case fullscreenButton = "tabs-side-fullscreen"
        case closeButton = "tabs-side-close"
        case micOffButton = "tabs-mic_off"
        case videoOffButton = "tabs-video_off"
        case tabsButton = "tabs-media"
    }
    
}
