//
//  BaseMenuBar.swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation

import XCTest

//As far as menu bar is different from Views
//The same Page Object pattern is reused here for interaction with Menu bars
class BaseMenuBar {
    
    var app: XCUIApplication { XCUIApplication() }
    let implicitWaitTimeout = TimeInterval(10)
    let defaultPressDurationSeconds = 1.5
    
    func menuBarItems(_ element: String) -> XCUIElement {
        return app.menuBars.menuBarItems[element]
    }
    
    func menuItems(_ element: String) -> XCUIElement {
        return app.menuBars.menuItems[element]
    }
}
