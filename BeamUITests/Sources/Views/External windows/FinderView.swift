//
//  FinderView.swift
//  BeamUITests
//
//  Created by Andrii on 07/09/2022.
//

import Foundation
import XCTest

class FinderView {
    
    private var window: XCUIElement!
    
    init() {
        window = XCUIApplication().dialogs.firstMatch
    }
    
    func isFinderOpened() -> Bool {
        return window.waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    @discardableResult
    func clickCancel() -> BaseView {
        window.buttons["Cancel"].firstMatch.hoverAndTapInTheMiddle()
        return BaseView()
    }
    
    @discardableResult
    func clickOkSelect() -> BaseView {
        window.buttons["OKButton"].firstMatch.hoverAndTapInTheMiddle()
        return BaseView()
    }
    
    func getWindowElement() -> XCUIElement {
        return window
    }
    
    func getButtonBy(identifier: Buttons) -> XCUIElement {
        return window.buttons[identifier.accessibilityIdentifier].firstMatch
    }
    
    enum Buttons: String, CaseIterable, UIElement {
        case cancelButton = "Cancel"
        case okSelectButton = "Fill"
        case openButton = "Open"
        case saveButton = "Save"
        case exportButton = "Export"
    }
    
}
