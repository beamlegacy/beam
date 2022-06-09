//
//  GoMenu.swift
//  BeamUITests
//
//  Created by Andrii on 10.08.2021.
//

import Foundation
import XCTest

class GoMenu: BaseMenuBar {
    
    let menuBarTitle = "Go"
    
    func changeNote() {
        menuBarItem(menuBarTitle).click()
        menuItem("Change Note").click()
    }
    
    func goBack() {
        menuBarItem(menuBarTitle).click()
        menuItem("Back").click()
    }
    
    func goForward() {
        menuBarItem(menuBarTitle).click()
        menuItem("Forward").click()
    }
    
}
