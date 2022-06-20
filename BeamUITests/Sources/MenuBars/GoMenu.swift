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
        menuBarItem(menuBarTitle).clickOnExistence()
        menuItem("Change Note").clickOnExistence()
    }
    
    func goBack() {
        menuBarItem(menuBarTitle).clickOnExistence()
        menuItem("Back").clickOnExistence()
    }
    
    func goForward() {
        menuBarItem(menuBarTitle).clickOnExistence()
        menuItem("Forward").clickOnExistence()
    }
    
}
