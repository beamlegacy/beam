//
//  DownloadTestView.swift
//  BeamUITests
//
//  Created by Andrii on 03.08.2021.
//

import Foundation
import XCTest

class DownloadTestView: BaseView {
    
    @discardableResult
    func isDownloadedFileDisplayed(fileToSearch: String) -> Bool{
        return app.staticTexts[fileToSearch].waitForExistence(timeout: minimumWaitTimeout)
    }
}
