//
//  UITestPageBrowserWindow.swift
//  BeamUITests
//
//  Created by Stef Kors on 04/04/2022.
//

import Foundation
import XCTest

class UITestPageBrowserWindow: BaseView {
    func tapOpenWindow() {
        let target = "Open window.open as Window"
        let parent = app.webViews.containing(.button, identifier: target).element
        let button = parent.buttons[target].firstMatch
        XCTAssert(button.waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        button.tapInTheMiddle()
    }

    func tapOpenTab() {
        let target = "Open window.open as Tab"
        let parent = app.webViews.containing(.button, identifier: target).element
        let button = parent.buttons[target].firstMatch
        XCTAssert(button.waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        button.tapInTheMiddle()
    }
}
