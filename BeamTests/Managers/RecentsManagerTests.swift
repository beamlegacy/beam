//
//  RecentsManagerTests.swift
//  BeamTests
//
//  Created by Remi Santos on 26/03/2021.
//

import XCTest
import Quick
import Nimble

@testable import Beam
class RecentsManagerTests: QuickSpec {

    var documentHelper: DocumentManagerTestsHelper?
    let documentManager = DocumentManager()

    func fillWithRandomDocuments(_ documentManager: DocumentManager) {
        guard documentHelper == nil else {
            return
        }
        let helper = DocumentManagerTestsHelper(documentManager: documentManager,
                                                coreDataManager: CoreDataManager.shared)
        helper.deleteAllDocuments()
        for _ in 0..<7 {
            _ = helper.saveLocally(helper.createDocumentStruct())
        }
        documentHelper = helper
    }

    override func spec() {

        var recentsManager: RecentsManager!
        let newNote = BeamNote(title: "Note")

        beforeEach {
            self.fillWithRandomDocuments(self.documentManager)
            recentsManager = RecentsManager(with: self.documentManager)
        }

        describe("init") {
            it("fetches last 5 notes") {
                expect(recentsManager.recentNotes.count) == 5
            }
        }

        describe("updateCurrentNote") {
            it("inserts in first position") {
                recentsManager.currentNoteChanged(newNote)
                expect(recentsManager.recentNotes.count) == 5
                expect(recentsManager.recentNotes.first?.id) == newNote.id
            }

            context("when too many recent") {
                it("respects max count") {
                    expect(recentsManager.recentNotes.count) == 5
                    recentsManager.currentNoteChanged(BeamNote(title: "1"))
                    recentsManager.currentNoteChanged(BeamNote(title: "2"))
                    expect(recentsManager.recentNotes.count) == 5
                }

                it("removes oldest note") {
                    let firstAddedNote = BeamNote(title:"1")
                    recentsManager.currentNoteChanged(firstAddedNote)
                    recentsManager.currentNoteChanged(BeamNote(title: "2"))
                    recentsManager.currentNoteChanged(BeamNote(title: "3"))
                    recentsManager.currentNoteChanged(BeamNote(title: "4"))
                    recentsManager.currentNoteChanged(BeamNote(title: "5"))

                    expect(recentsManager.recentNotes.last?.id) == firstAddedNote.id
                    recentsManager.currentNoteChanged(newNote)
                    expect(recentsManager.recentNotes.first?.id) == newNote.id
                    expect(recentsManager.recentNotes.last?.id) != firstAddedNote.id
                    expect(recentsManager.recentNotes.count) == 5
                }

                it("removes the less used note") {
                    let firstAddedNote = BeamNote(title: "1")
                    recentsManager.currentNoteChanged(firstAddedNote)
                    recentsManager.currentNoteChanged(BeamNote(title: "2"))
                    recentsManager.currentNoteChanged(BeamNote(title: "3"))
                    recentsManager.currentNoteChanged(firstAddedNote)
                    recentsManager.currentNoteChanged(BeamNote(title: "4"))
                    recentsManager.currentNoteChanged(BeamNote(title: "5"))
                    recentsManager.currentNoteChanged(firstAddedNote)

                    expect(recentsManager.recentNotes.last?.id) == firstAddedNote.id
                    recentsManager.currentNoteChanged(newNote)
                    expect(recentsManager.recentNotes.first?.id) == newNote.id
                    // Note #1 is still here because it was added multiple times
                    expect(recentsManager.recentNotes.last?.id) == firstAddedNote.id
                    expect(recentsManager.recentNotes.count) == 5
                }
            }
            context("when already a recent") {
                it("doesn't change order") {
                    recentsManager.currentNoteChanged(newNote)
                    expect(recentsManager.recentNotes.first?.id) == newNote.id

                    recentsManager.currentNoteChanged(BeamNote(title: "Some"))
                    expect(recentsManager.recentNotes[1].id) == newNote.id

                    recentsManager.currentNoteChanged(newNote)
                    expect(recentsManager.recentNotes[1].id) == newNote.id
                }
            }
        }
    }
}
