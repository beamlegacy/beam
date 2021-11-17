//
//  DownloadViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 03.08.2021.
//

import Foundation

enum DownloadViewLocators {
    
    enum Labels: String, CaseIterable, UIElement  {
        case downloadsLabel = "Downloads"
    }
    
    enum Buttons: String, CaseIterable, UIElement {
        case clearButton = "Clear"
        case resumeDownloadButton = "download-resume"
        case stopDownloadButton = "download-pause"
        case viewInFinderButton = "download-view"
        case closeDownloadButton = "tool-close"
    }
    
}
