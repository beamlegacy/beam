import Nimble
import XCTest
import Foundation
@testable import Beam
@testable import BeamCore

class SuggestedNoteSourceUpdaterTests: XCTestCase {
    private var updater: SuggestedNoteSourceUpdater!

    override func setUp() {
        super.setUp()
        updater = SuggestedNoteSourceUpdater(sessionId: UUID(), documentManager: DocumentManager())
    }

    func testNoteToGroup() throws {
        var noteGroups: [[UUID]] = [[], []]
        for i in 0...5 {
            noteGroups[i % 2].append(UUID())
        }
        let noteToGroupDict = updater.noteToGroup(noteGroups: noteGroups)
        for group in noteGroups.enumerated() {
            for id in group.element {
                expect(noteToGroupDict[id]) == group.offset
            }
        }
    }

    func testGroupFromPage() throws {
        let urlGroups: [[UInt64]] = [[0, 1, 2], [3, 4, 5], [6]]
        expect(self.updater.groupFromPage(pageId: 3, urlGroups: urlGroups)) == [3, 4, 5]
        expect(self.updater.groupFromPage(pageId: 6, urlGroups: urlGroups)) == [6]
    }

    func testCreateUpdateInstructionsWithoutActiveSources() throws {
        updater.oldUrlGroups = [[0, 1, 2], [3, 4, 5], [6]]
        let noteId1 = UUID()
        let noteId2 = UUID()
        let noteId3 = UUID()
        updater.oldNoteGroups = [[noteId1, noteId2], [], [noteId3]]

        if let (sourcesToAdd, sourcesToRemove) = updater.createUpdateInstructions(urlGroups: [[0, 1], [2, 3, 4, 5], [6]], noteGroups: [[noteId1], [noteId2], [noteId3]], activeSources: [UUID: [UInt64]]()) {
            expect(sourcesToAdd[noteId1]) == []
            expect(Set(sourcesToAdd[noteId2] ?? [])) == Set([3, 4, 5])
            expect(sourcesToAdd[noteId3]) == []
            expect(Set(sourcesToRemove[noteId1] ?? [])) == Set([2])
            expect(Set(sourcesToRemove[noteId2] ?? [])) == Set([0, 1])
            expect(sourcesToRemove[noteId3]) == []
        } else { fail("sourcesToAdd and sourcesToRemove not created") }
    }

    func testCreateUpdateInstructionsWithActiceSources() throws {
        updater.oldUrlGroups = [[0, 1, 2], [3, 4, 5], [6]]
        let noteId1 = UUID()
        let noteId2 = UUID()
        let noteId3 = UUID()
        updater.oldNoteGroups = [[noteId1], [noteId2], [noteId3]]
        let activeSources: [UUID: [UInt64]] = [noteId1: [6], noteId3: [1, 6]]

        if let (sourcesToAdd, sourcesToRemove) = updater.createUpdateInstructions(urlGroups: [[0, 1], [2, 3, 4], [5, 6]], noteGroups: [[noteId1], [noteId2], [noteId3]], activeSources: activeSources) {
            expect(sourcesToAdd[noteId1]) == [5]
            expect(sourcesToAdd[noteId2]) == [2]
            expect(Set(sourcesToAdd[noteId3] ?? [])) == Set([0, 5])
            expect(sourcesToRemove[noteId1]) == [2]
            expect(sourcesToRemove[noteId2]) == [5]
            expect(sourcesToRemove[noteId3]) == [2]
        } else { fail("sourcesToAdd and sourcesToRemove not created") }
    }
}
