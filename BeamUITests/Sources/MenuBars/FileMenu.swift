//
//  FileMenu.swift
//  BeamUITests
//
//  Created by Andrii on 06/12/2021.
//

import Foundation
import XCTest

class FileMenu: BaseMenuBar {
    
    let menuBarTitle = "File"
    
    func deleteAllLocalContents() {
        openMenu().hoverImportExport().menuItem("Delete all local contents").clickOnExistence()
    }
    
    func deleteAllNotes() {
        openMenu().hoverImportExport().menuItem("Delete all notes").clickOnExistence()
    }
    
    func openMenu() -> FileMenu {
        menuBarItem(menuBarTitle).click()
        return self
    }
    
    func hoverImportExport() -> FileMenu {
        menuItem("Import and Export").hover()
        return self
    }
    
}
