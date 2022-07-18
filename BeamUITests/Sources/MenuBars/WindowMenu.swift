//
//  WindowMenu.swift
//  BeamUITests
//
//  Created by Thomas on 07/12/2022.
//

import Foundation
import XCTest

class WindowMenu: BaseMenuBar {
    
    let menuBarTitle = "Window"

    func reopenAllWindowsFromLastSession() {
        windowMenu()
            .hoverReopenAllWindowsFromLastSession()
            .menuItem("Reopen All Windows from Last Session").clickOnExistence()
    }
    
    func windowMenu() -> WindowMenu {
        menuBarItem(menuBarTitle).clickOnExistence()
        return self
    }
    
    func hoverReopenAllWindowsFromLastSession() -> WindowMenu {
        menuItem("Reopen All Windows from Last Session").hover()
        return self
    }
    
}
