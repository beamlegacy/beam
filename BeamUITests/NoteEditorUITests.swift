import Foundation
import XCTest
#if canImport(Quick)
import Quick
#endif
#if canImport(Nimble)
import Nimble
#endif

class NoteEditorUITests: QuickSpec {
    override func spec() {
        let app = XCUIApplication()
        var journalScrollView: XCUIElement!
        var firstJournalEntry: XCUIElement!
        let textInput = "This is a test ab \(Date()) ab"

        beforeSuite {
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
                for text in textInput.split(every: 1) {
                    app.typeText(text)
                    usleep(100000) // 0.5sec
                }
                expect(firstJournalEntry.value as? String) == textInput
                // Leave a bit of time for Coredata to save
                sleep(1)
            }
        }
    }
}
