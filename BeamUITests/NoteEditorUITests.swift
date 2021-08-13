import Foundation
import XCTest
#if canImport(Quick)
import Quick
#endif
#if canImport(Nimble)
import Nimble
#endif
import BeamCore

class NoteEditorUITests: QuickSpec {
    override func spec() {
        let app = XCUIApplication()
        var journalScrollView: XCUIElement!
        var firstJournalEntry: XCUIElement!
        var helper: BeamUITestsHelper!

        func manualBeforeSuite() {
            guard helper == nil else { return }
            app.launch()
            helper = BeamUITestsHelper(app)
            self.continueAfterFailure = false
        }

        beforeEach {
            manualBeforeSuite()
            journalScrollView = app.windows.scrollViews["journalView"]
            firstJournalEntry = journalScrollView.children(matching: .textView).matching(identifier: "TextNode").element(boundBy: 0)
            firstJournalEntry.clear()
        }

        afterEach {
            helper.makeAppScreenShots()
        }

        describe("Typing") {
            it("can type long text") {
                let dateFormatter = DateFormatter()
                // some CI macs don't like to input ":"
                dateFormatter.dateFormat = "dd-MM-yyyy HH-mm Z"
                let textInput = "Testing typing date \(dateFormatter.string(from: BeamDate.now)) ok"

                app.typeSlowly(textInput, everyNChar: 1)
                expect(firstJournalEntry.value as? String) == textInput
            }
        }

        describe("Slash Command") {
            let contextMenuItems = app.staticTexts.matching(NSPredicate(format: "identifier CONTAINS 'ContextMenuItem'"))

            it("shows Menu with a slash") {
                app.typeText("/")
                expect(contextMenuItems.firstMatch.waitForExistence(timeout: 1)) == true
                helper.makeAppScreenShots()
                app.typeKey(.delete, modifierFlags: [])
                contextMenuItems.firstMatch.waitForNonExistence(timeout: 2, for: self)
                expect(contextMenuItems.count) == 0
            }

            it("shows Bold option") {
                app.typeText("/bol")
                expect(contextMenuItems.firstMatch.waitForExistence(timeout: 1)) == true
                expect(app.staticTexts["ContextMenuItem-bold"].exists) == true
                helper.makeAppScreenShots()
                app.typeKey(.enter, modifierFlags: [])
                contextMenuItems.firstMatch.waitForNonExistence(timeout: 2, for: self)
                expect(contextMenuItems.count) == 0
                app.typeText("some bold text")
                
            }
        }
    }
}
