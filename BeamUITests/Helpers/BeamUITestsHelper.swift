import Foundation
import XCTest
#if canImport(Quick)
import Quick
#endif
import Fakery
import BeamCore

class BeamUITestsHelper {
    var app: XCUIApplication!

    let helper = ShortcutsHelper()

    init(_ app: XCUIApplication) {
        self.app = app
    }
    
}


