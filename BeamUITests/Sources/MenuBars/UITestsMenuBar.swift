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
        menuBarItem(menuBarTitle).click()
        menuItem("Destroy Databases").click()
    }

    func deleteSFSymbolsFromDownloadFolder() {
        menuBarItem(menuBarTitle).click()
        menuItem("Clean SF-Symbols-3.dmg from Downloads").click()
    }
}
