//
//  UpdateTestView.swift
//  BeamUITests
//
//  Created by Andrii on 21.09.2021.
//

import Foundation
import XCTest

class UpdateTestView: BaseView {
    
    @discardableResult
    func closeUpdateWindow() -> JournalTestView {
        button(UpdateViewLocators.Buttons.later.accessibilityIdentifier).clickOnExistence()
        return JournalTestView()
    }
}
