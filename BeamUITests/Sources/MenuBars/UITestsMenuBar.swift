//
//  UITestsMenuBar.swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation
import XCTest

class UITestsMenuBar: BaseMenuBar {
    
    let menuBarTitle = "UITests"
    
    func destroyDB() {
        menuBarItems(menuBarTitle).click()
        menuItems("Destroy Databases").click()
    }
}
