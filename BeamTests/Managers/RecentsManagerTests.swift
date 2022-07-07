//
//  RecentsManagerTests.swift
//  BeamTests
//
//  Created by Remi Santos on 26/03/2021.
//

import XCTest
import Combine
import Quick
import Nimble

@testable import Beam
@testable import BeamCore

class RecentsManagerTests: QuickSpec, BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }

    func fillWithRandomDocuments() {
        guard let database = BeamData.shared.currentDatabase else {
            fail("Not currentDatabase found")
            return
        }
        for _ in 0..<7 {
            // swiftlint:disable:next force_try
            let note = try! BeamNote(title: String.randomTitle())
            note.owner = database
            let doc = note.document!
            _ = try? BeamData.shared.currentDocumentCollection?.save(self, doc, indexDocument: true)
        }
    }

    override func spec() {

        var recentsManager: RecentsManager!
        // swiftlint:disable:next force_try
        let newNote = try! BeamNote(title: "Note")

        beforeEach {
            BeamTestsHelper.logout()

            self.fillWithRandomDocuments()
            recentsManager = RecentsManager()
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
                    // swiftlint:disable force_try
                    recentsManager.currentNoteChanged(try! BeamNote(title: "1"))
                    recentsManager.currentNoteChanged(try! BeamNote(title: "2"))
                    // swiftlint:enable force_try
                    expect(recentsManager.recentNotes.count) == 5
                }

                it("removes oldest note") {
                    // swiftlint:disable:next force_try
                    let firstAddedNote = try! BeamNote(title:"1")
                    recentsManager.currentNoteChanged(firstAddedNote)
                    // swiftlint:disable force_try
                    recentsManager.currentNoteChanged(try! BeamNote(title: "2"))
                    recentsManager.currentNoteChanged(try! BeamNote(title: "3"))
                    recentsManager.currentNoteChanged(try! BeamNote(title: "4"))
                    recentsManager.currentNoteChanged(try! BeamNote(title: "5"))
                    // swiftlint:enable force_try

                    expect(recentsManager.recentNotes.last?.id) == firstAddedNote.id
                    recentsManager.currentNoteChanged(newNote)
                    expect(recentsManager.recentNotes.first?.id) == newNote.id
                    expect(recentsManager.recentNotes.last?.id) != firstAddedNote.id
                    expect(recentsManager.recentNotes.count) == 5
                }

                it("removes the less used note") {
                    // swiftlint:disable:next force_try
                    let firstAddedNote = try! BeamNote(title: "1")
                    recentsManager.currentNoteChanged(firstAddedNote)
                    // swiftlint:disable force_try
                    recentsManager.currentNoteChanged(try! BeamNote(title: "2"))
                    recentsManager.currentNoteChanged(try! BeamNote(title: "3"))
                    recentsManager.currentNoteChanged(firstAddedNote)
                    recentsManager.currentNoteChanged(try! BeamNote(title: "4"))
                    recentsManager.currentNoteChanged(try! BeamNote(title: "5"))
                    recentsManager.currentNoteChanged(firstAddedNote)
                    // swiftlint:enable force_try

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

                    // swiftlint:disable:next force_try
                    recentsManager.currentNoteChanged(try! BeamNote(title: "Some"))
                    expect(recentsManager.recentNotes[1].id) == newNote.id

                    recentsManager.currentNoteChanged(newNote)
                    expect(recentsManager.recentNotes[1].id) == newNote.id
                }
            }
            context("on note change") {
                it("publishes renamed notes") {
                    var numberOfPublishes = 0
                    let newTitle = "Updated Title"
                    waitUntil(timeout: .seconds(5)) { done in
                        _ = recentsManager.$recentNotes
                            .sink { _ in
                                numberOfPublishes += 1
                                done()
                        }
                        let note = recentsManager.recentNotes.last
                        note?.title = newTitle
                    }
                    expect(recentsManager.recentNotes.last?.title) == newTitle
                    expect(numberOfPublishes) == 1
                }

                it("handles deleted notes") {
                    expect(recentsManager.recentNotes.count) == 5

                    guard let note = recentsManager.recentNotes.last,
                          let document = note.document
                    else {
                        fail("Last recent notes is nil")
                        return
                    }

                    var cancellable = [AnyCancellable]()
                    waitUntil(timeout: .seconds(10)) { done in
                        BeamDocumentCollection.documentDeleted.receive(on: DispatchQueue(label: "tester")).sink { deleted in
                            guard deleted.id == document.id else { return }
                            done()
                        }.store(in: &cancellable)
                        try? BeamData.shared.currentDocumentCollection?.delete(self, filters: [.id(document.id)])
                    }

                    expect(recentsManager.recentNotes.count) == 4
                    expect(recentsManager.recentNotes.first { $0.id == note.id }).to(beNil())
                }
            }
        }
    }
}
