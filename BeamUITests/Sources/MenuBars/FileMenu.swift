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
        openMenu().menuItem("Delete all local contents").clickOnExistence()
    }
    
    func deleteAllNotes() {
        openMenu().menuItem("Delete all notes").clickOnExistence()
    }
    
    func openMenu() -> FileMenu {
        menuBarItem(menuBarTitle).clickOnExistence()
        return self
    }

    func hoverImport() -> FileMenu {
        menuItem("Import").hover()
        return self
    }

    func hoverExport() -> FileMenu {
        menuItem("Export").hover()
        return self
    }
    
}
