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
        var textInput = ""

        beforeEach {
            let dateFormatter = DateFormatter()
            // some CI macs don't like to input ":"
            dateFormatter.dateFormat = "dd-MM-yyyy HHhmm Z"
            textInput = "Testing typing date \(dateFormatter.string(from: Date())) ok"
            self.continueAfterFailure = false
        }

        beforeEach {
            app.launch()
            journalScrollView = app.windows.scrollViews["journalView"]
            firstJournalEntry = journalScrollView.children(matching: .textView).matching(identifier: "TextNode").element(boundBy: 0)
            firstJournalEntry.clear()
        }

        describe("Editing") {
            it("adds text inputs") {
                app.typeSlowly(textInput, everyNChar: 1)
                expect(firstJournalEntry.value as? String) == textInput
                // Leave a bit of time for Coredata to save
                sleep(1)
            }
        }
    }
}
