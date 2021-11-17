import Nimble
import XCTest
import Foundation
@testable import Beam
@testable import BeamCore

class SuggestedNoteSourceUpdaterTests: XCTestCase {
    private var updater: SuggestedNoteSourceUpdater!
    private var pageIDs: [UUID] = []

    override func setUp() {
        super.setUp()
        updater = SuggestedNoteSourceUpdater(sessionId: UUID())
        for _ in 0...6 {
            pageIDs.append(UUID())
        }
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
        let urlGroups = [[self.pageIDs[0], self.pageIDs[1], self.pageIDs[2]], [self.pageIDs[3], self.pageIDs[4], self.pageIDs[5]], [self.pageIDs[6]]]
        expect(self.updater.groupFromPage(pageId: self.pageIDs[3], urlGroups: urlGroups)) == [self.pageIDs[3], self.pageIDs[4], self.pageIDs[5]]
        expect(self.updater.groupFromPage(pageId: self.pageIDs[6], urlGroups: urlGroups)) == [self.pageIDs[6]]
    }

    func testCreateUpdateInstructionsWithoutActiveSources() throws {
        updater.oldUrlGroups = [[self.pageIDs[0], self.pageIDs[1], self.pageIDs[2]], [self.pageIDs[3], self.pageIDs[4], self.pageIDs[5]], [self.pageIDs[6]]]
        let noteId1 = UUID()
        let noteId2 = UUID()
        let noteId3 = UUID()
        updater.oldNoteGroups = [[noteId1, noteId2], [], [noteId3]]

        if let (sourcesToAdd, sourcesToRemove) = updater.createUpdateInstructions(urlGroups: [[self.pageIDs[0], self.pageIDs[1]], [self.pageIDs[2], self.pageIDs[3], self.pageIDs[4], self.pageIDs[5]], [self.pageIDs[6]]], noteGroups: [[noteId1], [noteId2], [noteId3]], activeSources: [UUID: [UUID]]()) {
            expect(sourcesToAdd[noteId1]) == []
            expect(Set(sourcesToAdd[noteId2] ?? [])) == Set([self.pageIDs[3], self.pageIDs[4], self.pageIDs[5]])
            expect(sourcesToAdd[noteId3]) == []
            expect(Set(sourcesToRemove[noteId1] ?? [])) == Set([self.pageIDs[2]])
            expect(Set(sourcesToRemove[noteId2] ?? [])) == Set([self.pageIDs[0], self.pageIDs[1]])
            expect(sourcesToRemove[noteId3]) == []
        } else { fail("sourcesToAdd and sourcesToRemove not created") }
    }

    func testCreateUpdateInstructionsWithActiceSources() throws {
        updater.oldUrlGroups = [[self.pageIDs[0], self.pageIDs[1], self.pageIDs[2]], [self.pageIDs[3], self.pageIDs[4], self.pageIDs[5]], [self.pageIDs[6]]]
        let noteId1 = UUID()
        let noteId2 = UUID()
        let noteId3 = UUID()
        updater.oldNoteGroups = [[noteId1], [noteId2], [noteId3]]
        let activeSources: [UUID: [UUID]] = [noteId1: [self.pageIDs[6]], noteId3: [self.pageIDs[1], self.pageIDs[6]]]

        if let (sourcesToAdd, sourcesToRemove) = updater.createUpdateInstructions(urlGroups: [[self.pageIDs[0], self.pageIDs[1]], [self.pageIDs[2], self.pageIDs[3], self.pageIDs[4]], [self.pageIDs[5], self.pageIDs[6]]], noteGroups: [[noteId1], [noteId2], [noteId3]], activeSources: activeSources) {
            expect(sourcesToAdd[noteId1]) == [self.pageIDs[5]]
            expect(sourcesToAdd[noteId2]) == [self.pageIDs[2]]
            expect(Set(sourcesToAdd[noteId3] ?? [])) == Set([self.pageIDs[0], self.pageIDs[5]])
            expect(sourcesToRemove[noteId1]) == [self.pageIDs[2]]
            expect(sourcesToRemove[noteId2]) == [self.pageIDs[5]]
            expect(sourcesToRemove[noteId3]) == [self.pageIDs[2]]
        } else { fail("sourcesToAdd and sourcesToRemove not created") }
    }
}
